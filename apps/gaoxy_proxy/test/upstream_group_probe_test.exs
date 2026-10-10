defmodule Gaoxy.Proxy.UpstreamGroupProbeTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Proxy.UpstreamGroups
  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Lifecycle
  @timeout 3_000

  test "unknown is excluded; three failed real HEAD probes remove and two successes restore" do
    {url, peer} = peer()
    owner = start_supervised!({UpstreamGroups, instance: self()})
    {handle, preparation} = prepare(owner, url)
    {:ok, pins} = Resources.pin_many([handle], self(), :request, Lifecycle.deadline(@timeout))
    assert_receive {:probe_head, ^peer, head}, @timeout
    assert head =~ "HEAD /health?ready=1 HTTP/1.1\r\n"
    assert hd(UpstreamGroups.status(handle).members).health == :unknown

    assert {:error, :unavailable} =
             UpstreamGroups.checkout(handle, pins, self(), %{}, Lifecycle.deadline(@timeout))

    send(peer, {:status, 200})
    await_health(handle, :healthy)

    for index <- 1..3 do
      assert_receive {:probe_head, ^peer, _}, @timeout
      send(peer, {:status, 503})
      assert_receive {:probe_closed, ^peer}, @timeout
      eventually(fn -> not hd(UpstreamGroups.status(handle).members).probe end)

      assert hd(UpstreamGroups.status(handle).members).health ==
               if(index == 3, do: :unhealthy, else: :healthy)
    end

    assert {:error, :unavailable} =
             UpstreamGroups.checkout(handle, pins, self(), %{}, Lifecycle.deadline(@timeout))

    assert_receive {:probe_head, ^peer, _}, @timeout
    send(peer, {:status, 200})
    assert_receive {:probe_closed, ^peer}, @timeout
    eventually(fn -> not hd(UpstreamGroups.status(handle).members).probe end)
    assert hd(UpstreamGroups.status(handle).members).health == :unhealthy
    assert_receive {:probe_head, ^peer, _}, @timeout
    send(peer, {:status, 200})
    await_health(handle, :healthy)
    :ok = Resources.release(pins)
    :ok = Resources.release(preparation)
  end

  test "freshness expires while the next real probe waits and does not overlap" do
    {url, peer} = peer()
    owner = start_supervised!({UpstreamGroups, instance: self()})
    {handle, preparation} = prepare(owner, url, %{interval: 50, stale_after: 60})
    assert_receive {:probe_head, ^peer, _}, @timeout
    send(peer, {:status, 200})
    await_health(handle, :healthy)
    assert_receive {:probe_head, ^peer, _}, @timeout
    eventually(fn -> hd(UpstreamGroups.status(handle).members).stale end)
    assert UpstreamGroups.status(handle).probes == 1
    {:ok, pins} = Resources.pin_many([handle], self(), :request, Lifecycle.deadline(@timeout))

    assert {:error, :unavailable} =
             UpstreamGroups.checkout(handle, pins, self(), %{}, Lifecycle.deadline(@timeout))

    refute_receive {:probe_head, ^peer, _}, 30
    send(peer, {:status, 200})
    eventually(fn -> not hd(UpstreamGroups.status(handle).members).stale end)
    :ok = Resources.release(pins)
    :ok = Resources.release(preparation)
  end

  test "a probe retains its reservation after response until its guardian confirms public cleanup" do
    {url, peer} = peer()
    owner = start_supervised!({UpstreamGroups, instance: self()})
    {handle, preparation} = prepare(owner, url, %{interval: 1_000, stale_after: 2_000})
    assert_receive {:probe_head, ^peer, _}, @timeout
    probe = probe(owner)
    state = :sys.get_state(probe)
    assert %HTTP.RequestCompletion{} = completion = state.request.completion
    :ok = :sys.suspend(probe)

    try do
      send(peer, {:status, 200})
      assert :ok = HTTP.RequestCompletion.await(completion, @timeout)
      assert UpstreamGroups.status(handle).probes == 1
      assert UpstreamGroups.status(handle).probe_bytes > 0
      assert hd(UpstreamGroups.status(handle).members).health == :unknown
      :ok = :sys.resume(probe)
      await_health(handle, :healthy)
      eventually(fn -> UpstreamGroups.status(handle).probes == 0 end)
      assert UpstreamGroups.status(handle).probe_bytes == 0
    after
      if Process.alive?(probe), do: :sys.resume(probe)
    end

    :ok = Resources.release(preparation)
  end

  test "separate probe slot and byte budgets prevent side effects; instance death cancels the one held probe" do
    {a_url, a} = peer()
    {b_url, b} = peer()

    instance =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    on_exit(fn -> if Process.alive?(instance), do: Process.exit(instance, :kill) end)
    owner = start_supervised!({UpstreamGroups, instance: instance, limits: %{max_probes: 1}})

    {:ok, config} =
      UpstreamGroups.compile(%{
        id: "api",
        members: [%{id: "a", upstream: a_url}, %{id: "b", upstream: b_url}]
      })

    {:ok, handle, preparation} =
      UpstreamGroups.prepare(owner, config, self(), Lifecycle.deadline(@timeout))

    assert_receive {:probe_head, first, _}, @timeout
    assert first in [a, b]
    assert UpstreamGroups.status(handle).probes == 1
    refute_receive {:probe_head, _, _}, 30
    guardian = probe(owner)
    monitor = Process.monitor(guardian)
    Process.exit(instance, :kill)
    send(first, :await_close)
    assert_receive {:probe_closed, ^first}, @timeout
    assert_receive {:DOWN, ^monitor, :process, ^guardian, _}, @timeout
    eventually(fn -> UpstreamGroups.status(handle).probes == 0 end)
    :ok = Resources.release(preparation)

    denied =
      start_supervised!({UpstreamGroups, instance: self(), limits: %{probe_bytes: 1}},
        id: :denied
      )

    {:ok, _, pin} = UpstreamGroups.prepare(denied, config, self(), Lifecycle.deadline(@timeout))
    refute_receive {:probe_head, _, _}, 60
    :ok = Resources.release(pin)
  end

  test "a real HEAD opening timeout closes its peer and enables a later bounded probe" do
    {url, peer} = peer()
    owner = start_supervised!({UpstreamGroups, instance: self()})
    {handle, preparation} = prepare(owner, url, %{timeout: 80, interval: 50})
    assert_receive {:probe_head, ^peer, _}, @timeout
    send(peer, :await_close)
    assert_receive {:probe_closed, ^peer}, @timeout
    assert_receive {:probe_head, ^peer, _}, @timeout
    send(peer, {:status, 200})
    await_health(handle, :healthy)
    :ok = Resources.release(preparation)
  end

  defp prepare(owner, url, policy \\ %{}) do
    health =
      Map.merge(
        %{path: "/health?ready=1", interval: 50, timeout: 500, stale_after: 1_000, jitter: 0},
        policy
      )

    {:ok, config} =
      UpstreamGroups.compile(%{id: "api", members: [%{id: "one", upstream: url}], health: health})

    {:ok, handle, pin} =
      UpstreamGroups.prepare(owner, config, self(), Lifecycle.deadline(@timeout))

    {handle, pin}
  end

  defp await_health(handle, health),
    do: eventually(fn -> hd(UpstreamGroups.status(handle).members).health == health end)

  defp probe(owner) do
    Enum.find_value(DynamicSupervisor.which_children(Gaoxy.Proxy.ProbeSupervisor), fn
      {_, pid, _, [Gaoxy.Proxy.UpstreamGroups.Probe]} ->
        try do
          if :sys.get_state(pid).owner == owner, do: pid
        catch
          :exit, _ -> nil
        end

      _ ->
        nil
    end) || flunk("probe guardian missing")
  end

  defp peer do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()
    pid = spawn(fn -> loop(listener, parent) end)

    on_exit(fn ->
      :gen_tcp.close(listener)
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    {"http://127.0.0.1:#{port}", pid}
  end

  defp loop(listener, parent) do
    case :gen_tcp.accept(listener, @timeout) do
      {:ok, socket} ->
        send(parent, {:probe_head, self(), head(socket)})

        receive do
          {:status, status} ->
            :ok =
              :gen_tcp.send(socket, "HTTP/1.1 #{status} Response\r\nContent-Length: 0\r\n\r\n")

          :await_close ->
            :ok
        after
          @timeout -> flunk("HEAD peer response barrier expired")
        end

        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
        :gen_tcp.close(socket)
        send(parent, {:probe_closed, self()})
        loop(listener, parent)

      {:error, :closed} ->
        :ok

      {:error, :timeout} ->
        loop(listener, parent)
    end
  end

  defp head(socket, bytes \\ "") do
    if String.contains?(bytes, "\r\n\r\n"),
      do: bytes,
      else:
        (
          assert {:ok, more} = :gen_tcp.recv(socket, 0, @timeout)
          head(socket, bytes <> more)
        )
  end

  defp eventually(fun, deadline \\ nil) do
    deadline = deadline || Lifecycle.deadline(@timeout)

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
