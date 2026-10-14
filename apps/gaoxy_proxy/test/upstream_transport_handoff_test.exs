defmodule Gaoxy.Proxy.UpstreamTransportHandoffTest do
  use ExUnit.Case, async: true

  alias Gaoxy.HTTP.Resources
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports

  @tag :handoff_auth
  test "an authentic old holder delegates after natural closure and guardian uses its own pin" do
    {source, peer, peer_monitor} = completion_peer()
    f = fixture(source)
    creators = owned_monitors(f.owner)
    assert map_size(f.handle) == 4
    assert map_size(f.pin) == 8
    assert :ok = Resources.release(f.baseline)
    assert :ok = Resources.release(f.preparation)

    assert {:error, :resource_admission_closed} =
             Transports.validate_endpoint(f.handle, identity(f), f.deadline)

    assert {:error, :resource_admission_closed} =
             call(f.native, fn ->
               Resources.pin_many([f.handle], self(), :request, f.deadline)
             end)

    assert {:ok, %{resources: 1, pins: 1, request_tokens: 0}} = Transports.status(f.owner)

    assert {:error, :invalid_resource_pin} =
             call(f.guardian, fn ->
               Transports.checkout(f.handle, [f.pin], self(), f.deadline)
             end)

    assert {:ok, child} = delegate(f)
    assert child.holder == f.guardian
    assert child.handles == [f.handle]
    assert child.kind == :request
    assert map_size(child) == 8
    refute child.ref == f.pin.ref

    assert {:ok, promise, completion, token} =
             call(f.guardian, fn ->
               with {:ok, client, token} <-
                      Transports.checkout(f.handle, [child], self(), f.deadline) do
                 promise =
                   HTTP.fetch(
                     f.source.origin <> "/old?generation=1",
                     Keyword.merge(client.fetch_options,
                       transport_scope: client.transport_scope,
                       timeout: 3000,
                       connect_timeout: 1000
                     )
                   )

                 completion = HTTP.Promise.completion(promise)
                 :ok = Transports.bind_completion(f.handle, token, completion)
                 {:ok, promise, completion, token}
               end
             end)

    assert_receive {:peer_request, ^peer, head}, 3000
    assert String.starts_with?(head, "GET /old?generation=1 HTTP/1.1\r\n")

    assert {:error, :cleanup_pending} =
             call(f.guardian, fn -> Transports.finish(f.handle, token) end)

    assert {:ok, %{request_tokens: 1}} = Transports.status(f.owner)
    send(peer, :respond)

    assert {200, "old", ^completion, :ok, :ok} =
             call(f.guardian, fn ->
               %HTTP.Response{status: status, stream: stream} = HTTP.Promise.await(promise, 2000)
               bytes = read_stream(stream)
               original = HTTP.Promise.completion(promise)
               joined = HTTP.RequestCompletion.await(completion, 2000)
               finished = Transports.finish(f.handle, token)
               {status, bytes, original, joined, finished}
             end)

    assert :ok = call(f.native, fn -> Resources.release(f.pin) end)
    assert {:ok, %{resources: 1, pins: 1, request_tokens: 0}} = Transports.status(f.owner)
    assert :ok = call(f.guardian, fn -> Resources.release(child) end)
    assert_receive {:peer_eof, ^peer, {:error, :closed}}, 3000
    assert_receive {:DOWN, ^peer_monitor, :process, ^peer, :normal}, 3000
    eventually(fn -> zero?(f.owner) end)
    join_monitors(creators)
    stop_actor(f.native)
    stop_actor(f.guardian)
  end

  @tag :handoff_auth
  test "the stored holder alone authorizes even when another caller acquired its pin" do
    f = fixture()
    assert {:ok, [pin]} = Resources.pin_many([f.handle], f.native, :request, f.deadline)

    denied(
      f,
      fn ->
        delegate_api(f.handle, pin, f.guardian, identity(f), make_ref(), f.deadline)
      end,
      {:error, :unauthorized}
    )

    assert {:ok, child} = delegate(f, pin: pin)
    assert child.holder == f.guardian
    assert :ok = Resources.release(pin)
    assert :ok = call(f.guardian, fn -> Resources.release(child) end)
  end

  @tag :handoff_auth
  test "another actor and a forged public holder cannot impersonate the stored holder" do
    f = fixture()
    intruder = actor()

    denied(
      f,
      fn ->
        call(intruder, fn ->
          delegate_api(f.handle, f.pin, f.guardian, identity(f), make_ref(), f.deadline)
        end)
      end,
      {:error, :unauthorized}
    )

    denied(
      f,
      fn ->
        call(intruder, fn ->
          delegate_api(
            f.handle,
            %{f.pin | holder: self()},
            f.guardian,
            identity(f),
            make_ref(),
            f.deadline
          )
        end)
      end,
      {:error, :invalid_resource_pin}
    )

    assert {:ok, _} = delegate(f)
  end

  @tag :handoff_auth
  test "expanded forged and stale pins cannot consume the authentic source right" do
    f = fixture()

    assert {:ok, [stale]} =
             call(f.native, fn ->
               Resources.pin_many([f.handle], self(), :request, f.deadline)
             end)

    assert :ok = call(f.native, fn -> Resources.release(stale) end)

    for pin <- [
          Map.put(f.pin, :extra, true),
          %{f.pin | ref: make_ref()},
          %{f.pin | operation: make_ref()},
          %{f.pin | owner: f.guardian},
          %{f.pin | owner_epoch: make_ref()},
          %{f.pin | handles: [%{f.handle | resource: make_ref()}]},
          stale
        ] do
      denied(f, fn -> delegate(f, pin: pin) end, {:error, :invalid_resource_pin})
    end

    assert {:ok, _} = delegate(f)
  end

  @tag :handoff_auth
  test "delegation requires exact live four field handle membership" do
    f = fixture()

    for handle <- [
          Map.put(f.handle, :extra, true),
          %{f.handle | resource: make_ref()},
          %{f.handle | owner_epoch: make_ref()},
          %{f.handle | owner: f.guardian}
        ] do
      denied(f, fn -> delegate(f, handle: handle) end, {:error, :invalid_resource})
    end

    assert {:ok, second, preparation} =
             Transports.prepare(f.owner, source(), self(), f.deadline)

    denied(f, fn -> delegate(f, handle: second) end, {:error, :invalid_resource_pin})
    assert :ok = Resources.release(preparation)
    eventually(fn -> match?({:ok, %{resources: 1}}, Transports.status(f.owner)) end)
    assert {:ok, _} = delegate(f)
  end

  @tag :handoff_auth
  test "baseline and preparation pins cannot derive request rights" do
    f = fixture()

    for kind <- [:baseline, :preparation] do
      assert {:ok, [pin]} =
               call(f.native, fn -> Resources.pin_many([f.handle], self(), kind, f.deadline) end)

      denied(f, fn -> delegate(f, pin: pin) end, {:error, :invalid_resource_pin})
      assert :ok = call(f.native, fn -> Resources.release(pin) end)
    end

    assert {:ok, _} = delegate(f)
  end

  @tag :handoff_auth
  test "identity must have exactly three fields with a strict root H1 URI" do
    f = fixture()

    for malformed <-
          [
            Map.put(identity(f), :extra, true),
            Map.delete(identity(f), :instance),
            %{identity(f) | instance: nil},
            %{identity(f) | upstream_protocol: :http2},
            %{identity(f) | upstream_protocol: :http3},
            %{identity(f) | origin: ~c"http://example.test"}
          ] ++
            Enum.map(
              [
                "",
                "ftp://example.test",
                "http://",
                "http://example.test:0",
                "http://example.test:65536",
                "http://example.test:abc",
                "http://user:password@example.test",
                "http://example.test/path",
                "http://example.test/?",
                "http://example.test/?q=1",
                "http://example.test/#",
                "http://example.test/\\path",
                "http://example.test/\r\n",
                <<"http://example.test/", 255>>
              ],
              &%{identity(f) | origin: &1}
            ) do
      denied(f, fn -> delegate(f, identity: malformed) end, {:error, :invalid_transport_endpoint})
    end

    assert {:ok, _} = delegate(f)
  end

  @tag :handoff_auth
  test "a different instance scheme host or port preserves prepared policy and source right" do
    f = fixture()
    other_instance = actor()

    for endpoint <- [
          %{identity(f) | instance: other_instance},
          %{identity(f) | origin: "https://example.test"},
          %{identity(f) | origin: "http://another.test"},
          %{identity(f) | origin: "http://example.test:81"}
        ] do
      denied(f, fn -> delegate(f, identity: endpoint) end, {:error, :transport_endpoint_mismatch})
    end

    assert {:ok, _} = delegate(f)
  end

  @tag :handoff_auth
  test "guardian must be live and distinct from the authentic native holder" do
    f = fixture()
    dead = actor()
    stop_actor(dead)
    denied(f, fn -> delegate(f, guardian: f.native) end, {:error, :invalid_resource_pin})

    denied(
      f,
      fn -> delegate(f, guardian: dead) end,
      {:error, {:deadline_exceeded, :cleanup_pending}}
    )

    assert {:ok, _} = delegate(f)
  end

  @tag :handoff_auth
  test "derived guardian pins cannot form a delegation chain" do
    f = fixture()
    another = actor()
    assert {:ok, child} = delegate(f)

    denied(
      f,
      fn ->
        call(f.guardian, fn ->
          delegate_api(f.handle, child, another, identity(f), make_ref(), f.deadline)
        end)
      end,
      {:error, :invalid_resource_pin}
    )
  end

  @tag :handoff_lifecycle
  test "one source resource grants once with live idempotence but no released replay" do
    f = fixture()
    operation = make_ref()
    assert {:ok, child} = delegate(f, operation: operation)
    before = :sys.get_state(f.owner)
    assert {:ok, ^child} = delegate(f, operation: operation)
    assert :sys.get_state(f.owner) == before

    denied(f, fn -> delegate(f) end, {:error, :invalid_resource_pin})
    another = actor()

    denied(
      f,
      fn -> delegate(f, operation: operation, guardian: another) end,
      {:error, :invalid_resource_pin}
    )

    assert :ok = call(f.guardian, fn -> Resources.release(child) end)

    denied(f, fn -> delegate(f, operation: operation) end, {:error, :invalid_resource_pin})
    assert :ok = call(f.native, fn -> Resources.release(f.pin) end)
  end

  @tag :handoff_lifecycle
  test "source release leaves independent guardian ownership until guardian release" do
    {source, peer, peer_monitor} = completion_peer()
    f = fixture(source)
    creators = owned_monitors(f.owner)
    assert :ok = Resources.release(f.preparation)
    assert :ok = Resources.release(f.baseline)
    assert {:ok, child} = delegate(f)
    assert :ok = call(f.native, fn -> Resources.release(f.pin) end)
    assert {:ok, %{resources: 1, pins: 1}} = Transports.status(f.owner)

    assert {:ok, promise, completion, token} =
             call(f.guardian, fn ->
               with {:ok, client, token} <-
                      Transports.checkout(f.handle, [child], self(), f.deadline) do
                 promise =
                   HTTP.fetch(
                     f.source.origin <> "/child",
                     Keyword.merge(client.fetch_options,
                       transport_scope: client.transport_scope,
                       timeout: 3000,
                       connect_timeout: 1000
                     )
                   )

                 completion = HTTP.Promise.completion(promise)
                 :ok = Transports.bind_completion(f.handle, token, completion)
                 {:ok, promise, completion, token}
               end
             end)

    assert_receive {:peer_request, ^peer, head}, 3000
    assert String.starts_with?(head, "GET /child HTTP/1.1\r\n")

    assert {:error, :cleanup_pending} =
             call(f.guardian, fn -> Transports.finish(f.handle, token) end)

    assert {:ok, %{resources: 1, pins: 1, request_tokens: 1}} = Transports.status(f.owner)
    send(peer, :respond)

    assert {200, "old", ^completion, :ok} =
             call(f.guardian, fn ->
               %HTTP.Response{status: status, stream: stream} = HTTP.Promise.await(promise, 2000)
               bytes = read_stream(stream)
               original = HTTP.Promise.completion(promise)
               joined = HTTP.RequestCompletion.await(completion, 2000)
               {status, bytes, original, joined}
             end)

    assert :ok = call(f.guardian, fn -> Transports.finish(f.handle, token) end)
    assert :ok = call(f.guardian, fn -> Resources.release(child) end)
    assert_receive {:peer_eof, ^peer, {:error, :closed}}, 3000
    assert_receive {:DOWN, ^peer_monitor, :process, ^peer, :normal}, 3000
    eventually(fn -> zero?(f.owner) end)
    join_monitors(creators)
    stop_actor(f.native)
    stop_actor(f.guardian)
  end

  @tag :handoff_lifecycle
  test "expired and extended deadlines cannot grant beyond the stored source admission" do
    f = fixture()

    for d <- [System.monotonic_time(:millisecond) - 1, f.deadline + 1, nil, :infinity] do
      denied(
        f,
        fn -> delegate(f, deadline: d) end,
        {:error, {:deadline_exceeded, :cleanup_pending}}
      )
    end

    assert {:ok, _} = delegate(f)
  end

  @tag :handoff_lifecycle
  test "a full pin ledger rejects without consuming the source grant" do
    f = fixture(source(), %{limits() | max_pins: 3})
    denied(f, fn -> delegate(f) end, {:error, {:capacity, :pins}})
    assert :ok = Resources.release(f.preparation)
    assert {:ok, child} = delegate(f)
    assert {:ok, %{pins: 3}} = Transports.status(f.owner)
    assert :ok = call(f.guardian, fn -> Resources.release(child) end)
  end

  @tag :handoff_lifecycle
  test "100 admitted derive release cycles restore the exact baseline ledger" do
    f = fixture()
    assert :ok = Resources.release(f.preparation)
    assert :ok = call(f.native, fn -> Resources.release(f.pin) end)
    before = :sys.get_state(f.owner)
    status = Transports.status(f.owner)

    for _ <- 1..100 do
      assert {:ok, [pin]} =
               call(f.native, fn ->
                 Resources.pin_many([f.handle], self(), :request, f.deadline)
               end)

      assert {:ok, child} = delegate(f, pin: pin)
      assert :ok = call(f.native, fn -> Resources.release(pin) end)
      assert :ok = call(f.guardian, fn -> Resources.release(child) end)
      assert Transports.status(f.owner) == status
      assert :sys.get_state(f.owner) == before
    end
  end

  @tag :handoff_lifecycle
  test "guardian death after grant releases its independently monitored hold" do
    f = fixture()
    assert :ok = Resources.release(f.preparation)
    before = :sys.get_state(f.owner)
    assert {:ok, before_status} = Transports.status(f.owner)
    assert {:ok, child} = delegate(f)
    granted = :sys.get_state(f.owner)
    used_source = granted.pins[f.pin.ref]

    marker_bytes =
      :erlang.external_size(used_source) - :erlang.external_size(before.pins[f.pin.ref])

    assert marker_bytes > 0
    assert used_source.delegations[f.handle.resource].ref == child.ref
    expected = %{before | pins: Map.put(before.pins, f.pin.ref, used_source)}

    expected_status = %{
      before_status
      | owned_serialized_payload_bytes:
          before_status.owned_serialized_payload_bytes + marker_bytes
    }

    stop_actor(f.guardian)
    eventually(fn -> :sys.get_state(f.owner) == expected end)
    assert {:ok, ^expected_status} = Transports.status(f.owner)
    refute Map.has_key?(expected.pins, child.ref)
    assert expected.tokens == %{}
    another = actor()
    denied(f, fn -> delegate(f, guardian: another) end, {:error, :invalid_resource_pin})
    assert :ok = call(f.native, fn -> Resources.release(f.pin) end)
    baseline = %{before | pins: Map.delete(before.pins, f.pin.ref)}
    assert :sys.get_state(f.owner) == baseline

    assert {:ok, %{pins: 1, request_tokens: 0, owned_serialized_payload_bytes: bytes}} =
             Transports.status(f.owner)

    assert bytes ==
             before_status.owned_serialized_payload_bytes -
               :erlang.external_size(before.pins[f.pin.ref])
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "the full serialized source marker and child delta fits at the exact byte boundary" do
    f = fixture()
    assert {:ok, [second]} = request_pin(f)
    before = :sys.get_state(f.owner)
    assert {:ok, before_status} = Transports.status(f.owner)
    assert {:ok, measured_child} = delegate(f)
    granted = :sys.get_state(f.owner)
    assert {:ok, granted_status} = Transports.status(f.owner)

    delta =
      :erlang.external_size(granted.pins[f.pin.ref]) -
        :erlang.external_size(before.pins[f.pin.ref]) +
        :erlang.external_size(granted.pins[measured_child.ref])

    assert granted_status.owned_serialized_payload_bytes ==
             before_status.owned_serialized_payload_bytes + delta

    assert :ok = call(f.guardian, fn -> Resources.release(measured_child) end)
    assert :ok = call(f.native, fn -> Resources.release(f.pin) end)
    assert {:ok, [fresh]} = request_pin(f)
    f = %{f | pin: fresh}
    assert {:ok, refreshed_status} = Transports.status(f.owner)
    assert refreshed_status == before_status
    exact = refreshed_status.owned_serialized_payload_bytes + delta
    set_limit(f.owner, :max_owned_payload_bytes, exact - 1)
    denied(f, fn -> delegate(f) end, {:error, {:capacity, :owned_payload}})
    set_limit(f.owner, :max_owned_payload_bytes, exact)
    assert {:ok, child} = delegate(f)
    assert {:ok, %{owned_serialized_payload_bytes: ^exact}} = Transports.status(f.owner)
    denied(f, fn -> delegate(f, pin: second) end, {:error, {:capacity, :owned_payload}})
    assert :ok = call(f.guardian, fn -> Resources.release(child) end)
    assert :ok = call(f.native, fn -> Resources.release(f.pin) end)
    assert {:ok, retry} = delegate(f, pin: second)
    assert :ok = call(f.guardian, fn -> Resources.release(retry) end)
    assert :ok = call(f.native, fn -> Resources.release(second) end)
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "exact pin slots reject atomically and leave a second source available for retry" do
    f = fixture()
    assert {:ok, [second]} = request_pin(f)
    assert {:ok, %{pins: slots}} = Transports.status(f.owner)
    set_limit(f.owner, :max_pins, slots + 1)
    assert {:ok, child} = delegate(f)
    denied(f, fn -> delegate(f, pin: second) end, {:error, {:capacity, :pins}})
    assert :ok = call(f.guardian, fn -> Resources.release(child) end)
    assert {:ok, retry} = delegate(f, pin: second)
    assert :ok = call(f.guardian, fn -> Resources.release(retry) end)
    assert :ok = call(f.native, fn -> Resources.release(second) end)
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "oversized expanded and retained input is rejected before contacting any owner" do
    f = fixture()
    observer = observer()
    handle = %{f.handle | owner: observer}
    pin = %{f.pin | owner: observer, handles: [handle]}
    root = "http://" <> String.duplicate("a", 100)
    retained = binary_part(root <> String.duplicate("x", 65_536), 0, byte_size(root))
    assert :binary.referenced_byte_size(retained) > 65_536

    for endpoint <- [
          %{identity(f) | origin: "http://" <> String.duplicate("a", 65_536)},
          %{identity(f) | origin: retained},
          Map.put(identity(f), :extra, String.duplicate("x", 65_536))
        ] do
      denied(
        f,
        fn ->
          call(f.native, fn ->
            delegate_api(handle, pin, f.guardian, endpoint, make_ref(), f.deadline)
          end)
        end,
        {:error, :invalid_transport_endpoint}
      )
    end

    for invalid_pin <- [
          Map.put(pin, :extra, String.duplicate("x", 65_536)),
          %{pin | handles: List.duplicate(handle, 65)}
        ] do
      denied(
        f,
        fn ->
          call(f.native, fn ->
            delegate_api(handle, invalid_pin, f.guardian, identity(f), make_ref(), f.deadline)
          end)
        end,
        {:error, :invalid_resource_pin}
      )
    end

    denied(
      f,
      fn ->
        call(f.native, fn ->
          delegate_api(
            Map.put(handle, :extra, String.duplicate("x", 65_536)),
            pin,
            f.guardian,
            identity(f),
            make_ref(),
            f.deadline
          )
        end)
      end,
      {:error, :invalid_resource}
    )

    assert :ok = call(observer, fn -> :ok end)
    refute_receive {:owner_contact, ^observer, _}, 0
    assert {:ok, _} = delegate(f)
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "an owner-held queued call expires without a grant and permits a later valid attempt" do
    f = fixture()
    before = :sys.get_state(f.owner)
    operation = make_ref()
    barrier = admission_barrier(f.owner, operation)
    d = System.monotonic_time(:millisecond) + 200
    reply = begin_delegate(f, operation: operation, deadline: d)
    owner = f.owner
    assert_receive {:admission_held, ^owner, ^operation}, 1000
    assert {:error, {:deadline_exceeded, :cleanup_pending}} = await_call(f.native, reply)
    send(owner, {:continue_admission, barrier})
    assert :sys.get_state(owner) == before
    assert {:ok, _} = delegate(f)
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "a grant delivered after D is canceled by the native original operation" do
    f = fixture()
    operation = make_ref()
    barrier = admission_barrier(f.owner, operation)
    d = System.monotonic_time(:millisecond) + 600
    reply = begin_delegate(f, operation: operation, deadline: d)
    owner = f.owner
    native = f.native
    assert_receive {:admission_held, ^owner, ^operation}, 1000
    suspend_actor(native)
    send(owner, {:continue_admission, barrier})

    eventually(
      fn -> match?({:ok, %{pins: 4}}, Transports.status(owner)) end,
      System.monotonic_time(:millisecond) + 400
    )

    granted = :sys.get_state(owner)
    marker = granted.pins[f.pin.ref].delegations[f.handle.resource]
    assert granted.pins[marker.ref].public.operation == operation
    await_deadline(d)
    resume_actor(native)
    assert {:error, {:deadline_exceeded, :cleanup_pending}} = await_call(native, reply)
    eventually(fn -> not Map.has_key?(:sys.get_state(owner).pins, marker.ref) end)
    assert :sys.get_state(owner).pins[f.pin.ref].delegations[f.handle.resource] == marker
    denied(f, fn -> delegate(f) end, {:error, :invalid_resource_pin})
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "guardian death before queued admission creates no grant or consumed marker" do
    f = fixture()
    before = :sys.get_state(f.owner)
    operation = make_ref()
    barrier = admission_barrier(f.owner, operation)
    reply = begin_delegate(f, operation: operation)
    owner = f.owner
    assert_receive {:admission_held, ^owner, ^operation}, 1000
    stop_actor(f.guardian)
    send(owner, {:continue_admission, barrier})
    assert {:error, {:deadline_exceeded, :cleanup_pending}} = await_call(f.native, reply)
    assert :sys.get_state(owner) == before
    assert {:ok, _} = delegate(f, guardian: actor())
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "native death before a queued reply joins its monitoring guardian without a leaked grant" do
    f = fixture()
    guardian = actor(f.native)
    operation = make_ref()
    barrier = admission_barrier(f.owner, operation)
    _reply = begin_delegate(f, operation: operation, guardian: guardian)
    owner = f.owner
    native = f.native
    assert_receive {:admission_held, ^owner, ^operation}, 1000
    guardian_monitor = Process.monitor(guardian)
    native_monitor = Process.monitor(native)
    Process.exit(native, :kill)
    assert_receive {:DOWN, ^native_monitor, :process, ^native, :killed}, 1000
    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, 1000
    send(owner, {:continue_admission, barrier})

    eventually(fn ->
      state = :sys.get_state(owner)

      not Map.has_key?(state.pins, f.pin.ref) and map_size(state.pins) == 2 and
        state.tokens == %{}
    end)

    assert {:ok, %{pins: 2, request_tokens: 0}} = Transports.status(owner)
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "native death after transfer removes only the source and its charged markers" do
    f = fixture()
    before = :sys.get_state(f.owner)
    assert {:ok, child} = delegate(f)
    child_hold = :sys.get_state(f.owner).pins[child.ref]
    stop_actor(f.native)

    expected = %{
      before
      | pins: before.pins |> Map.delete(f.pin.ref) |> Map.put(child.ref, child_hold)
    }

    eventually(fn -> :sys.get_state(f.owner) == expected end)
    assert Process.alive?(f.guardian)
    assert :ok = call(f.guardian, fn -> Resources.release(child) end)
    assert :sys.get_state(f.owner) == %{before | pins: Map.delete(before.pins, f.pin.ref)}
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "native death after an unpublished grant joins its monitoring guardian and both pin holds" do
    f = fixture()
    guardian = actor(f.native)
    before = :sys.get_state(f.owner)
    operation = make_ref()
    barrier = admission_barrier(f.owner, operation)
    _reply = begin_delegate(f, operation: operation, guardian: guardian)
    owner = f.owner
    native = f.native
    assert_receive {:admission_held, ^owner, ^operation}, 1000
    suspend_actor(native)
    send(owner, {:continue_admission, barrier})
    eventually(fn -> match?({:ok, %{pins: 4}}, Transports.status(owner)) end)
    marker = :sys.get_state(owner).pins[f.pin.ref].delegations[f.handle.resource]
    assert :sys.get_state(owner).pins[marker.ref].public.holder == guardian
    native_monitor = Process.monitor(native)
    guardian_monitor = Process.monitor(guardian)
    Process.exit(native, :kill)
    assert_receive {:DOWN, ^native_monitor, :process, ^native, :killed}, 1000
    assert_receive {:DOWN, ^guardian_monitor, :process, ^guardian, :normal}, 1000
    expected = %{before | pins: Map.delete(before.pins, f.pin.ref)}
    eventually(fn -> :sys.get_state(owner) == expected end)
    assert {:ok, %{pins: 2, request_tokens: 0}} = Transports.status(owner)
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "cancel authenticates the original acquirer and repeated cancel release orders are idempotent" do
    for order <- [:cancel_first, :release_first] do
      f = fixture()
      operation = make_ref()
      assert {:ok, child} = delegate(f, operation: operation)
      before = :sys.get_state(f.owner)
      assert :ok = Transports.cancel(f.owner, operation)
      assert {:ok, _} = Transports.status(f.owner)
      assert :sys.get_state(f.owner) == before

      assert {:ok, %{pins: 3, request_tokens: 0}} =
               call(f.native, fn ->
                 if order == :cancel_first do
                   :ok = Transports.cancel(f.owner, operation)
                   :ok = Resources.release(child)
                 else
                   :ok = Resources.release(child)
                   :ok = Transports.cancel(f.owner, operation)
                 end

                 :ok = Transports.cancel(f.owner, operation)
                 :ok = Resources.release(child)
                 Transports.status(f.owner)
               end)

      assert :sys.get_state(f.owner).pins[f.pin.ref].delegations[f.handle.resource].ref ==
               child.ref

      denied(f, fn -> delegate(f, operation: operation) end, {:error, :invalid_resource_pin})
      assert :ok = call(f.native, fn -> Resources.release(f.pin) end)
    end
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "owner retirement synchronously denies grant and checkout before any custodian ACK" do
    f = fixture()
    assert {:ok, child} = delegate(f)
    entry = :sys.get_state(f.owner).records[f.handle.resource]
    barrier = retirement_barrier(entry.custodian)
    creators = owned_monitors(f.owner)
    assert {:ok, status} = Transports.status(f.owner)
    set_limit(f.owner, :max_owned_payload_bytes, status.owned_serialized_payload_bytes)
    assert {:ok, receipt} = Transports.retire(f.owner, f.deadline)
    custodian = entry.custodian
    assert_receive {:retirement_held, ^custodian}, 1000
    state = :sys.get_state(f.owner)
    assert state.records[f.handle.resource].retirement_requested
    assert state.records[f.handle.resource].lifecycle == :active
    assert {:ok, %{pins: 0, request_tokens: 0, resources: 1}} = Transports.status(f.owner)
    denied_while_retiring(f, fn -> delegate(f) end, {:error, :retiring})

    denied_while_retiring(
      f,
      fn ->
        call(f.guardian, fn ->
          Transports.checkout(f.handle, [child], self(), f.deadline)
        end)
      end,
      {:error, :retiring}
    )

    send(custodian, {:continue_retirement, barrier})
    assert :ok = Transports.await_retirement(receipt, f.deadline)
    assert zero?(f.owner)
    join_monitors(creators)
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "resource retirement is charged and denies new work before ACK at a saturated budget" do
    {source, peer, peer_monitor} = completion_peer()
    f = fixture(source)
    creators = owned_monitors(f.owner)

    assert {:ok, client, token, promise, completion} =
             call(f.native, fn ->
               with {:ok, client, token} <-
                      Transports.checkout(f.handle, [f.pin], self(), f.deadline) do
                 promise = fetch(client, f.source.origin <> "/uncertain")
                 {:ok, client, token, promise, HTTP.Promise.completion(promise)}
               end
             end)

    assert client.policy.origin == source.origin
    assert_receive {:peer_request, ^peer, head}, 3000
    assert String.starts_with?(head, "GET /uncertain HTTP/1.1\r\n")
    state = :sys.get_state(f.owner)
    entry = state.records[f.handle.resource]
    assert entry.retirement_requested == false
    assert entry.payload.retirement_requested == false
    assert entry.payload_bytes == :erlang.external_size(entry.payload)

    assert entry.payload_bytes >=
             :erlang.external_size(%{entry.payload | retirement_requested: true})

    barrier = retirement_barrier(entry.custodian)
    assert {:ok, status} = Transports.status(f.owner)
    set_limit(f.owner, :max_owned_payload_bytes, status.owned_serialized_payload_bytes)

    assert {:error, :cleanup_unconfirmed} =
             call(f.native, fn -> Transports.finish(f.handle, token) end)

    custodian = entry.custodian
    assert_receive {:retirement_held, ^custodian}, 1000
    requested = :sys.get_state(f.owner)
    assert requested.records[f.handle.resource].retirement_requested
    assert requested.records[f.handle.resource].payload_bytes == entry.payload_bytes
    assert requested.tokens[token].completion == nil

    assert {:ok, %{owned_serialized_payload_bytes: bytes, request_tokens: 1}} =
             Transports.status(f.owner)

    assert bytes == status.owned_serialized_payload_bytes
    denied(f, fn -> delegate(f) end, {:error, :resource_unavailable})

    denied(
      f,
      fn ->
        call(f.native, fn ->
          Transports.checkout(f.handle, [f.pin], self(), f.deadline)
        end)
      end,
      {:error, :resource_unavailable}
    )

    assert :ok = call(f.native, fn -> Transports.bind_completion(f.handle, token, completion) end)

    assert {:error, :cleanup_pending} =
             call(f.native, fn -> Transports.finish(f.handle, token) end)

    send(peer, :respond)
    assert {200, "old", ^completion, :ok} = consume(f.native, promise, completion)
    assert :ok = call(f.native, fn -> Transports.finish(f.handle, token) end)
    send(custodian, {:continue_retirement, barrier})
    assert_receive {:peer_eof, ^peer, {:error, :closed}}, 3000
    assert_receive {:DOWN, ^peer_monitor, :process, ^peer, :normal}, 3000
    eventually(fn -> zero?(f.owner) end)
    join_monitors(creators)
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "instance death overrides a live source before the custodian retirement ACK" do
    f = fixture()
    assert {:ok, child} = delegate(f)
    entry = :sys.get_state(f.owner).records[f.handle.resource]
    barrier = retirement_barrier(entry.custodian)
    creators = owned_monitors(f.owner)
    instance_monitor = Process.monitor(f.instance)
    owner_monitor = Process.monitor(f.owner)
    instance = f.instance
    owner = f.owner
    Process.exit(instance, :kill)
    assert_receive {:DOWN, ^instance_monitor, :process, ^instance, :killed}, 1000
    custodian = entry.custodian
    assert_receive {:retirement_held, ^custodian}, 1000
    assert :sys.get_state(owner).records[f.handle.resource].retirement_requested
    assert {:ok, %{pins: 0, request_tokens: 0, resources: 1}} = Transports.status(owner)
    denied_while_retiring(f, fn -> delegate(f) end, {:error, :retiring})

    denied_while_retiring(
      f,
      fn ->
        call(f.guardian, fn ->
          Transports.checkout(f.handle, [child], self(), f.deadline)
        end)
      end,
      {:error, :retiring}
    )

    send(custodian, {:continue_retirement, barrier})
    join_monitors(creators)
    assert_receive {:DOWN, ^owner_monitor, :process, ^owner, :normal}, 4000

    assert :ok =
             cleanup_fixture(f.embedding, fn ->
               refute Process.alive?(instance)
               refute Process.alive?(owner)
               refute Process.alive?(custodian)
               :ok
             end)
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "short retirement D stays non-success after late zero ledger and physical EOF" do
    {source, peer, peer_monitor} = completion_peer()
    f = fixture(source)

    assert {:ok, promise, completion, token} =
             call(f.native, fn ->
               with {:ok, client, token} <-
                      Transports.checkout(f.handle, [f.pin], self(), f.deadline) do
                 promise = fetch(client, f.source.origin <> "/short-retirement")
                 completion = HTTP.Promise.completion(promise)
                 :ok = Transports.bind_completion(f.handle, token, completion)
                 {:ok, promise, completion, token}
               end
             end)

    assert_receive {:peer_request, ^peer, _head}, 3000
    send(peer, :respond)
    assert {200, "old", ^completion, :ok} = consume(f.native, promise, completion)
    assert :ok = call(f.native, fn -> Transports.finish(f.handle, token) end)
    entry = :sys.get_state(f.owner).records[f.handle.resource]
    creators = owned_monitors(f.owner)
    barrier = retirement_barrier(entry.custodian)
    d = System.monotonic_time(:millisecond) + 100
    assert {:ok, receipt} = Transports.retire(f.owner, d)
    custodian = entry.custodian
    assert_receive {:retirement_held, ^custodian}, 1000

    assert {:error, {:deadline_exceeded, :cleanup_pending}} =
             Transports.await_retirement(receipt, f.deadline)

    assert {:ok, %{resources: 1, reserved_connections: 2}} = Transports.status(f.owner)
    send(custodian, {:continue_retirement, barrier})
    assert_receive {:peer_eof, ^peer, {:error, :closed}}, 3000
    assert_receive {:DOWN, ^peer_monitor, :process, ^peer, :normal}, 3000
    eventually(fn -> zero?(f.owner) end)
    join_monitors(creators)

    assert {:error, {:deadline_exceeded, :cleanup_pending}} =
             Transports.await_retirement(receipt, f.deadline)

    assert :ok =
             cleanup_fixture(f.embedding, fn ->
               monitors = Enum.map([f.instance, f.owner], &{&1, Process.monitor(&1)})

               assert {:error, {:deadline_exceeded, :cleanup_pending}} =
                        Gaoxy.stop(f.instance, 3000)

               join_monitors(monitors)
               :ok
             end)
  end

  @tag handoff_lifecycle: true, handoff_step2: true
  test "a 64 handle source owns at most 64 charged markers and leaves no history after release" do
    f =
      fixture(source(), %{
        max_resources: 64,
        max_pins: 512,
        max_request_tokens: 8,
        max_owned_payload_bytes: 2_097_152
      })

    prepared =
      for _ <- 1..63 do
        assert {:ok, handle, pins} = Transports.prepare(f.owner, source(), self(), f.deadline)
        {handle, pins}
      end

    handles = [f.handle | Enum.map(prepared, &elem(&1, 0))]
    assert {:ok, baseline} = Resources.pin_many(handles, self(), :baseline, f.deadline)
    assert :ok = Resources.release(f.baseline)
    assert :ok = Resources.release(f.preparation)
    for {_, pins} <- prepared, do: assert(:ok = Resources.release(pins))
    assert :ok = call(f.native, fn -> Resources.release(f.pin) end)
    before = :sys.get_state(f.owner)
    before_status = Transports.status(f.owner)
    creators = owned_monitors(f.owner)

    assert {:ok, [batch]} =
             call(f.native, fn -> Resources.pin_many(handles, self(), :request, f.deadline) end)

    children =
      for handle <- handles do
        assert {:ok, child} = delegate(f, handle: handle, pin: batch)
        child
      end

    used = :sys.get_state(f.owner).pins[batch.ref]
    assert map_size(used.delegations) == 64
    assert MapSet.new(Map.keys(used.delegations)) == MapSet.new(Enum.map(handles, & &1.resource))
    assert {:ok, %{pins: 192, request_tokens: 0}} = Transports.status(f.owner)
    assert :ok = call(f.native, fn -> Resources.release(batch) end)
    assert {:ok, %{pins: 128, request_tokens: 0}} = Transports.status(f.owner)
    assert :ok = call(f.guardian, fn -> Resources.release(children) end)
    assert :sys.get_state(f.owner) == before
    assert Transports.status(f.owner) == before_status
    assert :ok = Resources.release(baseline)
    eventually(fn -> zero?(f.owner) end)
    join_monitors(creators)
  end

  defp request_pin(f),
    do: call(f.native, fn -> Resources.pin_many([f.handle], self(), :request, f.deadline) end)

  defp set_limit(owner, key, value),
    do:
      :sys.replace_state(owner, fn state ->
        %{state | limits: Map.put(state.limits, key, value)}
      end)

  defp denied_while_retiring(f, attempt, expected) do
    before = Map.drop(:sys.get_state(f.owner), [:request_timer, :retirement_timer])
    assert attempt.() == expected
    assert Map.drop(:sys.get_state(f.owner), [:request_timer, :retirement_timer]) == before
  end

  defp begin_delegate(f, options) do
    operation = Keyword.fetch!(options, :operation)
    guardian = Keyword.get(options, :guardian, f.guardian)
    d = Keyword.get(options, :deadline, f.deadline)
    ref = make_ref()

    send(
      f.native,
      {:call, self(), ref,
       fn ->
         delegate_api(f.handle, f.pin, guardian, identity(f), operation, d)
       end}
    )

    ref
  end

  defp await_call(actor, ref) do
    receive do
      {:actor_reply, ^actor, ^ref, result} -> result
    after
      4000 -> flunk("queued actor reply exceeded finite deadline")
    end
  end

  defp admission_barrier(owner, operation) do
    parent = self()
    barrier = make_ref()

    :ok =
      :sys.install(
        owner,
        {fn seen, event, _ ->
           case event do
             {:in, {:"$gen_call", _, {:delegate_request_pin, _, _, _, _, _, ^operation, _}}}
             when not seen ->
               send(parent, {:admission_held, self(), operation})

               receive do
                 {:continue_admission, ^barrier} -> :ok
               after
                 4000 -> raise "test-owned admission barrier exceeded finite deadline"
               end

               true

             _ ->
               seen
           end
         end, false}
      )

    on_exit(fn -> send(owner, {:continue_admission, barrier}) end)
    barrier
  end

  defp retirement_barrier(custodian) do
    parent = self()
    barrier = make_ref()

    :ok =
      :sys.install(
        custodian,
        {fn seen, event, _ ->
           retirement =
             case event do
               {:in, {:retire, _}} -> true
               {:in, {:retire, _, _, _}} -> true
               _ -> false
             end

           if retirement and not seen do
             send(parent, {:retirement_held, self()})

             receive do
               {:continue_retirement, ^barrier} -> :ok
             after
               4000 -> raise "test-owned retirement barrier exceeded finite deadline"
             end
           end

           seen or retirement
         end, false}
      )

    on_exit(fn -> send(custodian, {:continue_retirement, barrier}) end)
    barrier
  end

  defp suspend_actor(actor) do
    :erlang.suspend_process(actor)
    on_exit(fn -> resume_actor(actor) end)
  end

  defp resume_actor(actor) do
    if Process.info(actor, :status) == {:status, :suspended}, do: :erlang.resume_process(actor)
    :ok
  end

  defp await_deadline(d) do
    receive do
    after
      max(d - System.monotonic_time(:millisecond) + 1, 0) -> :ok
    end
  end

  defp observer do
    parent = self()
    pid = spawn(fn -> observer_loop(parent) end)
    on_exit(fn -> stop_actor(pid) end)
    pid
  end

  defp observer_loop(parent) do
    receive do
      {:call, caller, ref, operation} ->
        send(caller, {:actor_reply, self(), ref, actor_result(operation)})
        observer_loop(parent)

      :stop ->
        :ok

      message ->
        send(parent, {:owner_contact, self(), message})
        observer_loop(parent)
    after
      30_000 -> exit(:observer_idle_deadline)
    end
  end

  defp fetch(client, url),
    do:
      HTTP.fetch(
        url,
        Keyword.merge(client.fetch_options,
          transport_scope: client.transport_scope,
          timeout: 3000,
          connect_timeout: 1000
        )
      )

  defp consume(actor, promise, completion),
    do:
      call(actor, fn ->
        %HTTP.Response{status: status, stream: stream} = HTTP.Promise.await(promise, 2000)
        bytes = read_stream(stream)
        original = HTTP.Promise.completion(promise)
        joined = HTTP.RequestCompletion.await(completion, 2000)
        {status, bytes, original, joined}
      end)

  defp cleanup_fixture(embedding, operation),
    do: actor_call(embedding, :cleanup, operation, 20_000)

  defp delegate(f, options \\ []) do
    handle = Keyword.get(options, :handle, f.handle)
    pin = Keyword.get(options, :pin, f.pin)
    guardian = Keyword.get(options, :guardian, f.guardian)
    endpoint = Keyword.get(options, :identity, identity(f))
    operation = Keyword.get(options, :operation, make_ref())
    d = Keyword.get(options, :deadline, f.deadline)
    call(f.native, fn -> delegate_api(handle, pin, guardian, endpoint, operation, d) end)
  end

  defp delegate_api(handle, pin, guardian, endpoint, operation, d),
    do: apply(Transports, :delegate_request_pin, [handle, pin, guardian, endpoint, operation, d])

  defp denied(f, attempt, expected) do
    before = :sys.get_state(f.owner)
    status = Transports.status(f.owner)
    assert attempt.() == expected
    assert :sys.get_state(f.owner) == before
    assert Transports.status(f.owner) == status
  end

  defp fixture(policy \\ source(), owner_limits \\ limits()) do
    embedding = actor()

    {instance, owner} =
      call(embedding, fn ->
        {:ok, instance} = Gaoxy.start_link()
        Process.unlink(instance)
        {:ok, owner} = Transports.start_link(instance: instance, limits: owner_limits)
        Process.unlink(owner)
        {instance, owner}
      end)

    on_exit(fn ->
      assert :ok =
               cleanup_fixture(
                 embedding,
                 fn ->
                   actors = owned_monitors(owner)
                   assert {:ok, receipt} = Transports.retire(owner, deadline())
                   assert :ok = Transports.await_retirement(receipt, deadline())
                   join_monitors(actors)

                   monitors = Enum.map([instance, owner], &{&1, Process.monitor(&1)})
                   assert :ok = Gaoxy.stop(instance, 3000)
                   join_monitors(monitors)
                   :ok
                 end
               )
    end)

    d = deadline()
    assert {:ok, handle, preparation} = Transports.prepare(owner, policy, self(), d)
    assert {:ok, baseline} = Resources.pin_many([handle], self(), :baseline, d)
    native = actor()
    guardian = actor()

    assert {:ok, [pin]} =
             call(native, fn -> Resources.pin_many([handle], self(), :request, d) end)

    %{
      instance: instance,
      owner: owner,
      embedding: embedding,
      handle: handle,
      preparation: preparation,
      baseline: baseline,
      native: native,
      guardian: guardian,
      pin: pin,
      source: policy,
      deadline: d
    }
  end

  defp actor(native \\ nil) do
    pid =
      spawn(fn ->
        monitor = if is_pid(native), do: Process.monitor(native), else: nil
        actor_loop(false, monitor)
      end)

    on_exit(fn -> stop_actor(pid) end)
    pid
  end

  defp actor_loop(completed, native_monitor) do
    receive do
      {:call, caller, ref, operation} ->
        result = actor_result(operation)
        send(caller, {:actor_reply, self(), ref, result})
        actor_loop(completed, native_monitor)

      {:cleanup, caller, ref, operation} ->
        result = if completed, do: :ok, else: actor_result(operation)
        send(caller, {:actor_reply, self(), ref, result})
        actor_loop(completed or result == :ok, native_monitor)

      {:DOWN, ^native_monitor, :process, _, _} when is_reference(native_monitor) ->
        :ok

      :stop ->
        :ok
    after
      30_000 -> exit(:actor_idle_deadline)
    end
  end

  defp actor_result(operation) do
    try do
      operation.()
    rescue
      e in UndefinedFunctionError -> {:error, {:missing_api, e.module, e.function, e.arity}}
      e -> {:actor_error, e, __STACKTRACE__}
    catch
      kind, reason -> {:actor_error, kind, reason}
    end
  end

  defp call(actor, operation, timeout \\ 4000),
    do: actor_call(actor, :call, operation, timeout)

  defp actor_call(actor, tag, operation, timeout) do
    ref = make_ref()
    monitor = Process.monitor(actor)
    send(actor, {tag, self(), ref, operation})

    try do
      receive do
        {:actor_reply, ^actor, ^ref, result} -> result
        {:DOWN, ^monitor, :process, ^actor, reason} -> flunk("actor died: #{inspect(reason)}")
      after
        timeout -> flunk("actor call exceeded finite deadline")
      end
    after
      Process.demonitor(monitor, [:flush])
    end
  end

  defp stop_actor(actor) do
    monitor = Process.monitor(actor)
    send(actor, :stop)

    receive do
      {:DOWN, ^monitor, :process, ^actor, reason} -> assert reason in [:normal, :noproc]
    after
      4000 -> flunk("test actor did not join")
    end
  end

  defp owned_monitors(owner) do
    state = :sys.get_state(owner)

    actors =
      Enum.flat_map(state.records, fn {_, entry} ->
        [entry.custodian | Map.keys(entry.helpers)]
      end) ++
        Enum.flat_map(state.tokens, fn
          {_, %{abort_helper: {pid, _}}} -> [pid]
          _ -> []
        end)

    Enum.map(Enum.uniq(actors), &{&1, Process.monitor(&1)})
  end

  defp join_monitors(monitors) do
    for {actor, monitor} <- monitors do
      receive do
        {:DOWN, ^monitor, :process, ^actor, reason} -> assert reason in [:normal, :noproc]
      after
        4000 -> flunk("owned actor did not join")
      end
    end
  end

  defp completion_peer do
    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}, reuseaddr: true])

    {:ok, {_, port}} = :inet.sockname(listener)
    parent = self()

    {peer, monitor} =
      spawn_monitor(fn ->
        case :gen_tcp.accept(listener, 10_000) do
          {:ok, socket} ->
            try do
              head = recv_head(socket, System.monotonic_time(:millisecond) + 3000)
              send(parent, {:peer_request, self(), head})

              receive do
                :respond ->
                  :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\nold")
                  send(parent, {:peer_eof, self(), :gen_tcp.recv(socket, 0, 4000)})

                :stop ->
                  :ok
              after
                5000 -> exit(:peer_response_deadline)
              end
            after
              :gen_tcp.close(socket)
            end

          {:error, :closed} ->
            :ok

          {:error, reason} ->
            exit({:peer_accept_failed, reason})
        end
      end)

    on_exit(fn ->
      :gen_tcp.close(listener)
      stop_actor(peer)
    end)

    {%{origin: "http://127.0.0.1:#{port}", connect_address: {127, 0, 0, 1}, trust: nil}, peer,
     monitor}
  end

  defp recv_head(socket, d, acc \\ "") do
    cond do
      byte_size(acc) > 65_536 ->
        raise "peer head exceeds finite cap"

      String.contains?(acc, "\r\n\r\n") ->
        acc

      true ->
        {:ok, bytes} = :gen_tcp.recv(socket, 0, max(d - System.monotonic_time(:millisecond), 1))
        recv_head(socket, d, acc <> bytes)
    end
  end

  defp read_stream(stream, chunks \\ []) do
    send(stream, {:read_chunk, self(), :ack})

    receive do
      {:stream_chunk, ^stream, bytes, ack} ->
        send(stream, {:stream_chunk_ack, ack})
        read_stream(stream, [bytes | chunks])

      {:stream_end, ^stream} ->
        IO.iodata_to_binary(Enum.reverse(chunks))

      {:stream_error, ^stream, reason} ->
        flunk("public stream failed: #{inspect(reason)}")
    after
      2000 -> flunk("public stream exceeded finite deadline")
    end
  end

  defp eventually(predicate, d \\ deadline()) do
    if predicate.() do
      :ok
    else
      assert System.monotonic_time(:millisecond) < d, "ledger did not settle before deadline"

      receive do
      after
        5 -> eventually(predicate, d)
      end
    end
  end

  defp zero?(owner),
    do:
      match?(
        {:ok,
         %{
           resources: 0,
           pins: 0,
           request_tokens: 0,
           helpers: 0,
           reserved_connections: 0,
           owned_serialized_payload_bytes: 0
         }},
        Transports.status(owner)
      )

  defp identity(f),
    do: %{origin: f.source.origin, upstream_protocol: :http1, instance: f.instance}

  defp source,
    do: %{origin: "http://example.test", connect_address: {127, 0, 0, 1}, trust: nil}

  defp limits,
    do: %{max_resources: 2, max_pins: 8, max_request_tokens: 8, max_owned_payload_bytes: 131_072}

  defp deadline, do: System.monotonic_time(:millisecond) + 15_000
end
