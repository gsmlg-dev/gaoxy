defmodule Gaoxy.Proxy.UpstreamGroupsTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Proxy.UpstreamGroups
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Lifecycle

  test "group compilation is strict, origin-only, bounded and idempotent" do
    assert Code.ensure_loaded?(UpstreamGroups)
    options = %{id: "api", members: [%{id: "a", upstream: "http://127.0.0.1:1234"}]}
    assert {:ok, compiled} = apply(UpstreamGroups, :compile, [options])
    assert {:ok, ^compiled} = apply(UpstreamGroups, :compile, [compiled])

    for invalid <- [
          Map.put(options, :retry, true),
          %{options | members: []},
          %{options | members: options.members ++ options.members},
          %{options | members: [%{id: "a", upstream: "http://user:secret@localhost"}]},
          %{options | members: [%{id: "a", upstream: "https://localhost/path"}]},
          %{options | members: [%{id: "a", upstream: "http://localhost", max_inflight: 0}]}
        ] do
      assert {:error, _} = apply(UpstreamGroups, :compile, [invalid])
    end
  end

  test "real initial HEAD probes enable round robin and saturation has no queue" do
    assert Code.ensure_loaded?(UpstreamGroups)
    {a, a_peer} = head_peer()
    {b, b_peer} = head_peer()
    owner = start_supervised!({UpstreamGroups, instance: self()})

    {:ok, compiled} =
      apply(UpstreamGroups, :compile, [
        %{
          id: "api",
          max_inflight: 2,
          members: [
            %{id: "a", upstream: a, max_inflight: 1},
            %{id: "b", upstream: b, max_inflight: 1}
          ]
        }
      ])

    deadline = Lifecycle.deadline(2_000)

    {:ok, handle, preparation} =
      apply(UpstreamGroups, :prepare, [owner, compiled, self(), deadline])

    assert_receive {:head_probe, ^a_peer}, 1_500
    assert_receive {:head_probe, ^b_peer}, 1_500

    eventually(fn ->
      Enum.all?(apply(UpstreamGroups, :status, [handle]).members, &(&1.health == :healthy))
    end)

    {:ok, baseline} = apply(Resources, :pin_many, [[handle], self(), :baseline, deadline])
    {:ok, pins} = apply(Resources, :pin_many, [[handle], self(), :request, deadline])

    assert {:ok, %{id: "a"}, first} =
             apply(UpstreamGroups, :checkout, [handle, pins, self(), %{}, deadline])

    assert {:ok, %{id: "b"}, second} =
             apply(UpstreamGroups, :checkout, [handle, pins, self(), %{}, deadline])

    assert {:error, :unavailable} =
             apply(UpstreamGroups, :checkout, [handle, pins, self(), %{}, deadline])

    assert :ok = apply(UpstreamGroups, :finish, [handle, first, :success])
    assert :ok = apply(UpstreamGroups, :finish, [handle, second, :success])
    assert :ok = apply(Resources, :release, [pins])
    assert :ok = apply(Resources, :release, [preparation])
    assert :ok = apply(Resources, :release, [baseline])
    eventually(fn -> match?({:error, :stale_group}, apply(UpstreamGroups, :status, [handle])) end)
  end

  test "retiring group stays pinned for an old snapshot and guardian death retains unbound selection" do
    assert Code.ensure_loaded?(UpstreamGroups)
    {url, _peer} = head_peer()
    owner = start_supervised!({UpstreamGroups, instance: self()})

    {:ok, compiled} =
      apply(UpstreamGroups, :compile, [%{id: "api", members: [%{id: "a", upstream: url}]}])

    deadline = Lifecycle.deadline(2_000)

    {:ok, handle, preparation} =
      apply(UpstreamGroups, :prepare, [owner, compiled, self(), deadline])

    eventually(fn -> hd(apply(UpstreamGroups, :status, [handle]).members).health == :healthy end)
    {:ok, baseline} = apply(Resources, :pin_many, [[handle], self(), :baseline, deadline])
    {:ok, request} = apply(Resources, :pin_many, [[handle], self(), :request, deadline])
    :ok = apply(Resources, :release, [preparation])
    :ok = apply(Resources, :release, [baseline])
    assert apply(UpstreamGroups, :status, [handle]).lifecycle == :retiring
    assert {:error, _} = apply(Resources, :pin_many, [[handle], self(), :request, deadline])
    parent = self()

    guardian =
      spawn(fn ->
        send(
          parent,
          {:checkout, apply(UpstreamGroups, :checkout, [handle, request, self(), %{}, deadline])}
        )

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:checkout, {:ok, %{id: "a"}, _token}}, 1_000
    Process.exit(guardian, :kill)
    eventually(fn -> apply(UpstreamGroups, :status, [handle]).lifecycle == :failed end)
    assert apply(UpstreamGroups, :status, [handle]).inflight == 1
    :ok = apply(Resources, :release, [request])
    assert apply(UpstreamGroups, :status, [handle]).inflight == 1
  end

  test "owner record, config and pin bounds reject without side effects and groups remain isolated" do
    {url, _peer} = head_peer()
    {:ok, config} = UpstreamGroups.compile(%{id: "one", members: [%{id: "a", upstream: url}]})

    owner =
      start_supervised!(
        {UpstreamGroups, instance: self(), limits: %{max_groups: 1, max_pins: 1, probe_bytes: 1}}
      )

    deadline = Lifecycle.deadline(1_000)
    {:ok, handle, preparation} = UpstreamGroups.prepare(owner, config, self(), deadline)

    assert {:error, :group_capacity} =
             UpstreamGroups.prepare(owner, %{config | id: "two"}, self(), deadline)

    assert {:error, :group_capacity} = Resources.pin_many([handle], self(), :request, deadline)
    assert UpstreamGroups.status(handle).inflight == 0
    assert hd(UpstreamGroups.status(handle).members).health == :unknown

    denied =
      start_supervised!({UpstreamGroups, instance: self(), limits: %{max_config_bytes: 1}},
        id: :denied
      )

    assert {:error, :group_capacity} = UpstreamGroups.prepare(denied, config, self(), deadline)

    other =
      start_supervised!({UpstreamGroups, instance: self(), limits: %{probe_bytes: 1}}, id: :other)

    {:ok, isolated, other_preparation} =
      UpstreamGroups.prepare(other, %{config | id: "two"}, self(), deadline)

    assert {:error, :invalid_resource_pin} =
             UpstreamGroups.pin_many([handle, isolated], self(), :request, make_ref(), deadline)

    assert UpstreamGroups.status(isolated).inflight == 0
    :ok = Resources.release(preparation)
    :ok = Resources.release(other_preparation)
  end

  @tag :handle_identity
  test "request holder death cannot free a live selection and only its guardian may finish" do
    {url, _peer} = head_peer()
    owner = start_supervised!({UpstreamGroups, instance: self()})
    {:ok, config} = UpstreamGroups.compile(%{id: "api", members: [%{id: "a", upstream: url}]})
    deadline = Lifecycle.deadline(2_000)
    {:ok, handle, preparation} = UpstreamGroups.prepare(owner, config, self(), deadline)
    eventually(fn -> hd(UpstreamGroups.status(handle).members).health == :healthy end)
    parent = self()

    holder =
      spawn(fn ->
        {:ok, pin} = Resources.pin_many([handle], self(), :request, deadline)
        send(parent, {:request_pin, pin})

        receive do
          :stop -> :ok
        end
      end)

    assert_receive {:request_pin, request}, 1_000
    assert {:ok, _, token} = UpstreamGroups.checkout(handle, request, self(), %{}, deadline)
    assert {:error, :unauthorized_pin_release} = Resources.release(request)
    tampered = %{handle | max_url_bytes: handle.max_url_bytes - 1}
    assert {:error, :stale_group} = Resources.pin_many([tampered], self(), :request, deadline)
    forged = %{handle | owner_epoch: make_ref()}
    assert {:error, :invalid_selection_token} = UpstreamGroups.finish(forged, token, :success)
    unauthorized = Task.async(fn -> UpstreamGroups.finish(handle, token, :success) end)
    assert {:error, :invalid_selection_token} = Task.await(unauthorized)
    Process.exit(holder, :kill)
    eventually(fn -> UpstreamGroups.status(handle).pins == 1 end)
    assert UpstreamGroups.status(handle).inflight == 1

    assert {:error, :unavailable} =
             UpstreamGroups.checkout(handle, request, self(), %{}, deadline)

    assert :ok = UpstreamGroups.finish(handle, token, :cancelled)
    assert UpstreamGroups.status(handle).inflight == 0
    :ok = Resources.release(preparation)
  end

  test "prepared and request pins expire absolutely while a baseline outlives its acquisition deadline" do
    {url, _peer} = head_peer()
    owner = start_supervised!({UpstreamGroups, instance: self(), limits: %{probe_bytes: 1}})
    {:ok, config} = UpstreamGroups.compile(%{id: "api", members: [%{id: "a", upstream: url}]})
    deadline = Lifecycle.deadline(30)
    {:ok, handle, _preparation} = UpstreamGroups.prepare(owner, config, self(), deadline)
    {:ok, baseline} = Resources.pin_many([handle], self(), :baseline, deadline)
    {:ok, _request} = Resources.pin_many([handle], self(), :request, deadline)
    eventually(fn -> UpstreamGroups.status(handle).pins == 1 end)
    assert UpstreamGroups.status(handle).lifecycle == :active
    :ok = Resources.release(baseline)
    assert {:error, :stale_group} = UpstreamGroups.status(handle)
  end

  @tag :checked_capture_constructor
  test "deadline release/2 releases a real request pin and release/1 keeps its contract" do
    assert_release_deadline_api!()
    {_owner, handle, baseline} = release_deadline_group_fixture()
    d = Lifecycle.deadline(5000)
    assert {:ok, [request]} = Resources.pin_many([handle], self(), :request, d)
    assert %{pins: 2} = UpstreamGroups.status(handle)
    assert :ok = apply(UpstreamGroups, :release, [request, d])
    assert %{pins: 1} = UpstreamGroups.status(handle)
    assert :ok = UpstreamGroups.release(baseline)
    assert {:error, :stale_group} = UpstreamGroups.status(handle)
  end

  @tag :checked_capture_constructor
  test "deadline release/2 rejects expired work without dispatch and reuses one absolute deadline" do
    assert_release_deadline_api!()
    {owner, handle, baseline} = release_deadline_group_fixture()
    {debug, trace} = release_deadline_spy(owner)

    try do
      before = UpstreamGroups.status(handle)
      assert %{pins: 1} = before

      assert {:error, :deadline_exceeded} =
               apply(UpstreamGroups, :release, [baseline, Lifecycle.now() - 1])

      assert ^before = UpstreamGroups.status(handle)
      refute_receive {:release_deadline_dispatch, ^trace, _}, 0
      assert :ok = :sys.suspend(owner, 1000)

      try do
        d = Lifecycle.deadline(50)

        assert {:error, {:deadline_exceeded, :cleanup_pending}} =
                 apply(UpstreamGroups, :release, [baseline, d])

        assert Lifecycle.remaining(d) == 0
        assert {:error, :deadline_exceeded} = apply(UpstreamGroups, :release, [baseline, d])
      after
        assert :ok = :sys.resume(owner, 1000)
      end

      # The first timed-out call was already queued. Its eventual release is
      # real, but the expired retry must never dispatch a second request.
      assert {:error, :stale_group} = UpstreamGroups.status(handle)
      assert_receive {:release_deadline_dispatch, ^trace, ^baseline}, 1000
      refute_receive {:release_deadline_dispatch, ^trace, _}, 0
    after
      if Process.alive?(owner), do: :sys.remove(owner, debug, 1000)
    end
  end

  defp assert_release_deadline_api! do
    assert Code.ensure_loaded?(UpstreamGroups)

    assert function_exported?(UpstreamGroups, :release, 2),
           "missing additive UpstreamGroups.release/2 absolute-deadline API"
  end

  defp release_deadline_group_fixture do
    owner = start_supervised!({UpstreamGroups, instance: self(), limits: %{probe_bytes: 1}})

    assert {:ok, config} =
             UpstreamGroups.compile(%{
               id: "deadline",
               members: [%{id: "a", upstream: "http://127.0.0.1:1"}]
             })

    d = Lifecycle.deadline(5000)
    assert {:ok, handle, preparation} = UpstreamGroups.prepare(owner, config, self(), d)
    assert {:ok, [baseline]} = Resources.pin_many([handle], self(), :baseline, d)
    assert :ok = Resources.release(preparation)
    assert %{pins: 1, lifecycle: :active} = UpstreamGroups.status(handle)
    {owner, handle, baseline}
  end

  defp release_deadline_spy(owner) do
    observer = self()
    trace = make_ref()

    debug = fn state, event, _ ->
      case event do
        {:in, {:"$gen_call", {_caller, _tag}, {:release, pin}}} ->
          send(observer, {:release_deadline_dispatch, trace, pin})

        _ ->
          :ok
      end

      state
    end

    assert :ok = :sys.install(owner, {debug, nil}, 1000)
    {debug, trace}
  end

  defp head_peer do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()
    peer = spawn(fn -> probe_loop(listener, parent) end)

    on_exit(fn ->
      Process.exit(peer, :kill)
      :gen_tcp.close(listener)
    end)

    {"http://127.0.0.1:#{port}", peer}
  end

  defp probe_loop(listener, parent) do
    case :gen_tcp.accept(listener, 2_000) do
      {:ok, socket} ->
        head = read_head(socket)
        assert head =~ "HEAD / HTTP/1.1\r\n"
        send(parent, {:head_probe, self()})
        :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, 2_000)
        :gen_tcp.close(socket)
        probe_loop(listener, parent)

      {:error, :closed} ->
        :ok

      {:error, :timeout} ->
        probe_loop(listener, parent)
    end
  end

  defp read_head(socket, bytes \\ "") do
    if String.contains?(bytes, "\r\n\r\n"),
      do: bytes,
      else:
        (
          {:ok, more} = :gen_tcp.recv(socket, 0, 2_000)
          read_head(socket, bytes <> more)
        )
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(2_000)

    if fun.(),
      do: :ok,
      else:
        (
          assert Lifecycle.remaining(deadline) > 0

          receive do
          after
            2 -> eventually(fun, deadline)
          end
        )
  end
end
