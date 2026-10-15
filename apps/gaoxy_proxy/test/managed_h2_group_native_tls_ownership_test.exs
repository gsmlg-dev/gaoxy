unless Code.ensure_loaded?(Gaoxy.Proxy.ManagedH2FixedFixture) do
  Code.require_file("managed_h2_fixed_endpoint_test.exs", __DIR__)
end

Code.require_file("support/managed_h2_group_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.ManagedH2GroupNativeTLSOwnershipTest do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.{Exchange, HTTP2.Frame, HTTP2.Transport}
  alias Gaoxy.Proxy.GroupEndpoint
  alias Gaoxy.Proxy.ManagedH2GroupFixture, as: G
  alias HTTP.RequestCompletion
  @timeout 5_000

  defmodule ObservedEndpoint do
    def init(options) do
      {observer, options} = Map.pop(options, :observer)
      with {:ok, endpoint} <- GroupEndpoint.init(options), do: {:ok, {endpoint, observer}}
    end

    def resources({endpoint, _}), do: GroupEndpoint.resources(endpoint)

    def call(exchange, {endpoint, observer}) do
      reference = make_ref()
      monitor = Process.monitor(observer)
      {owner, id, token} = exchange.transport_state
      wrong_stream = %{exchange | transport_state: {owner, id + 2, token}}
      wrong_token = %{exchange | transport_state: {owner, id, make_ref()}}
      expired = %{exchange | deadline: Gaoxy.Lifecycle.deadline(0)}

      send(observer, {
        :native_tls_exchange,
        self(),
        reference,
        exchange,
        Exchange.ssl_data(exchange),
        Plug.Conn.get_ssl_data(Exchange.plug_conn(exchange)),
        Transport.operation(wrong_stream, :ssl_data),
        Transport.operation(wrong_token, :ssl_data),
        Transport.operation(expired, :ssl_data)
      })

      proceed =
        try do
          receive do
            {:native_tls_continue, ^reference} -> true
            {:DOWN, ^monitor, :process, ^observer, _} -> false
          after
            5_000 -> false
          end
        after
          Process.demonitor(monitor, [:flush])
        end

      if proceed,
        do: GroupEndpoint.call(exchange, endpoint),
        else: {:error, :test_observer_closed, exchange}
    end
  end

  defmodule OwnerDeadlineEndpoint do
    def init(options) do
      {observer, options} = Map.pop(options, :observer)
      with {:ok, endpoint} <- GroupEndpoint.init(options), do: {:ok, {endpoint, observer}}
    end

    def resources({endpoint, _}), do: GroupEndpoint.resources(endpoint)

    def call(exchange, {_endpoint, observer}) do
      reference = make_ref()
      monitor = Process.monitor(observer)
      send(observer, {:owner_deadline_ready, self(), reference, exchange})

      try do
        receive do
          {:owner_deadline_call, ^reference, extended_deadline} ->
            result = Transport.operation(%{exchange | deadline: extended_deadline}, :ssl_data)
            send(observer, {:owner_deadline_unexpected_return, self(), result})
            {:error, :unexpected_metadata_return, exchange}

          {:DOWN, ^monitor, :process, ^observer, _} ->
            {:error, :test_observer_closed, exchange}
        after
          5_000 -> {:error, :test_release_timeout, exchange}
        end
      after
        Process.demonitor(monitor, [:flush])
      end
    end
  end

  for protocol <- [:http2, :h2c] do
    @tag :tmp_dir
    test "native TLS/h2 to #{protocol} preserves full SSL data without copying it into the group pump",
         %{
           tmp_dir: directory
         } do
      script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
      assert {_, 0} = System.cmd("bash", [script, directory], stderr_to_stdout: true)
      f = G.fixture(unquote(protocol), :http1, ["--manual"])

      assert {:ok, spec} =
               Gaoxy.HTTP.service_spec(
                 id: :native_tls,
                 endpoint: {ObservedEndpoint, %{group: f.group, observer: self()}},
                 protocols: [:http2],
                 transport: :tls,
                 tls: %{
                   certfile: Path.join(directory, "cert.pem"),
                   keyfile: Path.join(directory, "key.pem")
                 },
                 limits: %{max_bytes: f.service_bytes, max_active: 64},
                 http_limits: %{request_timeout: 30_000, write_timeout: 2_000}
               )

      assert {:ok, _} = Gaoxy.add(f.instance, spec)
      [{:native_tls, service, _}] = :ets.lookup(:sys.get_state(f.instance).live, :native_tls)
      gate = :sys.get_state(service).gate
      {:ok, {_, port}} = Gaoxy.info(f.instance, :native_tls).local

      assert {:ok, socket} =
               :ssl.connect(
                 ~c"localhost",
                 port,
                 [
                   :binary,
                   active: false,
                   verify: :verify_peer,
                   cacertfile: Path.join(directory, "ca.pem"),
                   server_name_indication: ~c"localhost",
                   alpn_advertised_protocols: ["h2"]
                 ],
                 @timeout
               )

      on_exit(fn -> :ssl.close(socket) end)
      assert {:ok, "h2"} = :ssl.negotiated_protocol(socket)

      {block, _} =
        HPAX.encode(
          :never_store,
          [
            {":method", "GET"},
            {":scheme", "https"},
            {":authority", "localhost"},
            {":path", "/native-tls?"}
          ],
          HPAX.new(4_096)
        )

      assert :ok =
               :ssl.send(socket, [
                 "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n",
                 Frame.encode(4, 0, 0, ""),
                 Frame.encode(1, 5, 1, block)
               ])

      assert_receive {:native_tls_exchange, worker, reference, exchange, ssl, plug_ssl,
                      {:error, :closed}, {:error, :closed}, {:error, :timeout}},
                     @timeout

      assert exchange.ssl === nil
      assert exchange.secure === true
      assert ssl === plug_ssl
      assert is_binary(ssl[:session_data]) and byte_size(ssl[:session_data]) > 0
      assert :erlang.external_size(ssl) > 0
      {owner, 1, token} = exchange.transport_state
      {_, native} = :sys.get_state(owner)
      assert native.ssl === ssl
      assert native.streams[1].worker === worker
      assert native.streams[1].lease === exchange.lease
      admission = :sys.get_state(gate)
      assert admission.leases[native.lease].pid === owner
      assert admission.leases[native.lease].bytes === native.reserves.connection
      assert admission.leases[exchange.lease].pid === worker
      # A copied real token does not authorize this different caller.
      assert {:error, :closed} =
               GenServer.call(owner, {:h2_operation, 1, token, :ssl_data}, @timeout)

      assert Exchange.ssl_data(exchange) === nil
      joins = for pid <- [owner, native.writer, worker], do: {pid, Process.monitor(pid)}
      send(worker, {:native_tls_continue, reference})

      seen = G.event(f.peer, "request")
      assert seen["target"] === "/native-tls?"
      G.eventually(fn -> G.held_selection(f, "/native-tls?") != nil end)
      {_, held} = G.held_selection(f, "/native-tls?")
      completion = held.completion
      assert %RequestCompletion{} = completion
      assert :sys.get_state(held.guardian).original_request.completion === completion
      G.eventually(fn -> map_size(:sys.get_state(gate).cleanups) === 1 end)
      [{cleanup_token, cleanup}] = Map.to_list(:sys.get_state(gate).cleanups)
      assert cleanup.bytes === 16_478_862
      assert cleanup.lease === exchange.lease
      assert :sys.get_state(service).cleanups[cleanup_token].guardian === held.guardian
      G.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})

      assert %{status: 200, body: ""} =
               response(socket, nil, "", HPAX.new(4_096), 256, Gaoxy.Lifecycle.deadline(@timeout))

      assert :ok = RequestCompletion.await(completion, @timeout)
      # Upstream completion precedes the downstream pump returning. Join that
      # lifecycle before closing the socket, which kills any remaining stream.
      G.eventually(fn -> not Process.alive?(worker) end)

      G.eventually(fn ->
        {_, state} = :sys.get_state(owner)
        not Map.has_key?(state.streams, 1)
      end)

      assert Process.alive?(owner)
      assert Process.alive?(native.writer)
      assert :ok = :ssl.close(socket)

      for {pid, monitor} <- joins do
        assert_receive {:DOWN, ^monitor, :process, ^pid, reason}, @timeout

        if pid === owner,
          do: assert(reason in [:normal, :noproc, :shutdown, {:shutdown, :peer_closed}]),
          else: assert(reason in [:normal, :noproc, :shutdown])
      end

      G.eventually(fn ->
        match?(
          %{active: 0, cleanup_pending: 0, retained_bytes: 0},
          Gaoxy.status(f.instance, :native_tls)
        )
      end)

      assert %{cleanup_failed: nil, retained_high_water: high} =
               Gaoxy.status(f.instance, :native_tls)

      assert high <= f.service_bytes
      assert :ok = Gaoxy.remove(f.instance, :native_tls, @timeout)
      G.clean(f)
      G.no_event(f.peer, "request")
      G.close(f)
    end
  end

  @tag :tmp_dir
  test "queued real SSL operation rejects the original owner deadline after the live watchdog kills its worker",
       %{
         tmp_dir: directory
       } do
    script = Path.expand("../../../scripts/generate-fixtures.sh", __DIR__)
    assert {_, 0} = System.cmd("bash", [script, directory], stderr_to_stdout: true)
    f = G.fixture(:h2c, :http1, ["--manual"])

    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               id: :native_tls,
               endpoint: {OwnerDeadlineEndpoint, %{group: f.group, observer: self()}},
               protocols: [:http2],
               transport: :tls,
               tls: %{
                 certfile: Path.join(directory, "cert.pem"),
                 keyfile: Path.join(directory, "key.pem")
               },
               limits: %{max_bytes: f.service_bytes, max_active: 64},
               http_limits: %{request_timeout: 2_000, write_timeout: 2_000}
             )

    assert {:ok, _} = Gaoxy.add(f.instance, spec)
    [{:native_tls, service, _}] = :ets.lookup(:sys.get_state(f.instance).live, :native_tls)
    gate = :sys.get_state(service).gate
    service_monitor = Process.monitor(service)
    gate_monitor = Process.monitor(gate)
    {:ok, {_, port}} = Gaoxy.info(f.instance, :native_tls).local

    assert {:ok, socket} =
             :ssl.connect(
               ~c"localhost",
               port,
               [
                 :binary,
                 active: false,
                 verify: :verify_peer,
                 cacertfile: Path.join(directory, "ca.pem"),
                 server_name_indication: ~c"localhost",
                 alpn_advertised_protocols: ["h2"]
               ],
               @timeout
             )

    on_exit(fn -> :ssl.close(socket) end)
    assert {:ok, "h2"} = :ssl.negotiated_protocol(socket)

    assert :ok =
             :ssl.send(socket, [
               "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n",
               Frame.encode(4, 0, 0, "")
             ])

    # Acknowledge the real server's SETTINGS before starting the request timer.
    assert {:ok, <<settings_bytes::24, 4, 0, 0::1, 0::31>>} = :ssl.recv(socket, 9, @timeout)
    assert settings_bytes > 0 and settings_bytes <= 1_024
    assert {:ok, settings} = :ssl.recv(socket, settings_bytes, @timeout)
    assert rem(byte_size(settings), 6) === 0

    {block, _} =
      HPAX.encode(
        :never_store,
        [
          {":method", "GET"},
          {":scheme", "https"},
          {":authority", "localhost"},
          {":path", "/owner-deadline"}
        ],
        HPAX.new(4_096)
      )

    assert :ok = :ssl.send(socket, [Frame.encode(4, 1, 0, ""), Frame.encode(1, 5, 1, block)])
    assert_receive {:owner_deadline_ready, worker, reference, exchange}, @timeout
    {owner, 1, token} = exchange.transport_state
    {_, native} = :sys.get_state(owner)
    assert native.settings_ack === true
    assert native.streams[1].worker === worker
    assert native.streams[1].token === token
    assert native.streams[1].lease === exchange.lease
    original_deadline = native.streams[1].deadline
    assert original_deadline === exchange.deadline
    assert Gaoxy.Lifecycle.remaining(original_deadline) > 0
    assert is_binary(native.ssl[:session_data]) and byte_size(native.ssl[:session_data]) > 0
    assert {:trap_exit, true} = Process.info(owner, :trap_exit)
    lease = exchange.lease
    admission = :sys.get_state(gate)
    assert admission.leases[lease].pid === worker
    assert admission.leases[lease].deadline === original_deadline
    assert admission.leases[lease].request_active === true
    watchdog_token = admission.leases[lease].token
    assert is_reference(watchdog_token)
    assert is_reference(admission.leases[lease].timer)
    assert is_integer(Process.read_timer(admission.leases[lease].timer))
    worker_monitor = Process.monitor(worker)
    owner_monitor = Process.monitor(owner)
    writer = native.writer
    writer_monitor = Process.monitor(writer)
    native_worker_monitor = native.streams[1].monitor
    extended_deadline = Gaoxy.Lifecycle.deadline(15_000)
    patterns = [{GenServer, :reply, 2}, {:gen, :reply, 2}, {Gaoxy.Admission, :handle_info, 2}]
    on_exit(fn -> cleanup_owner_deadline_observer(owner, gate, patterns) end)

    try do
      for pattern <- patterns, do: assert(:erlang.trace_pattern(pattern, true, [:local]) === 1)
      assert :erlang.trace(owner, true, [:call, {:tracer, self()}]) === 1
      assert :erlang.trace(gate, true, [:call, {:tracer, self()}]) === 1
      assert :erlang.suspend_process(owner)
      send(worker, {:owner_deadline_call, reference, extended_deadline})

      G.eventually(
        fn -> queued_owner_ssl_calls(owner, worker, token) != [] end,
        original_deadline
      )

      [from] = queued_owner_ssl_calls(owner, worker, token)
      assert {^worker, _} = from
      assert Gaoxy.Lifecycle.remaining(original_deadline) > 0
      assert_receive {:DOWN, ^worker_monitor, :process, ^worker, :killed}, @timeout
      assert Gaoxy.Lifecycle.remaining(original_deadline) === 0
      assert Gaoxy.Lifecycle.remaining(extended_deadline) > 0
      assert Process.alive?(gate)
      assert {:status, :suspended} = Process.info(owner, :status)
      # The original call was observed before expiry. While suspended, the
      # owner still has original worker/token state and receives its real DOWN.
      G.eventually(fn ->
        {:messages, messages} = Process.info(owner, :messages)

        Enum.any?(
          messages,
          &match?({:DOWN, ^native_worker_monitor, :process, ^worker, :killed}, &1)
        )
      end)

      {:messages, messages} = Process.info(owner, :messages)

      call_index =
        Enum.find_index(
          messages,
          &match?(
            {:"$gen_call", ^from, {:h2_operation, 1, ^token, :ssl_data}},
            &1
          )
        )

      down_index =
        Enum.find_index(
          messages,
          &match?(
            {:DOWN, ^native_worker_monitor, :process, ^worker, :killed},
            &1
          )
        )

      assert is_integer(call_index) and is_integer(down_index)
      assert call_index < down_index
      assert [^from] = queued_owner_ssl_calls(owner, worker, token)
      assert :erlang.resume_process(owner)
      # Manual GenServer.reply is observed at both its wrapper and :gen API;
      # the dead caller's alias need not deliver a reply message to anyone.
      assert_receive {:trace, ^owner, :call, {GenServer, :reply, [^from, {:error, :timeout}]}},
                     @timeout

      assert_receive {:trace, ^owner, :call, {:gen, :reply, [^from, {:error, :timeout}]}},
                     @timeout

      G.eventually(fn ->
        {_, state} = :sys.get_state(owner)
        not Map.has_key?(state.streams, 1)
      end)

      delivered = :erlang.trace_delivered(owner)
      assert_receive {:trace_delivered, ^owner, ^delivered}, @timeout
      gate_delivered = :erlang.trace_delivered(gate)
      assert_receive {:trace_delivered, ^gate, ^gate_delivered}, @timeout
      calls = owner_deadline_calls([])
      # The two expected timeout calls were already consumed above. No second
      # reply of any kind, in particular no {:ok,full_ssl}, is permitted.
      extra_replies =
        for {^owner, {module, :reply, [actual_from, result]}} <- calls,
            module in [GenServer, :gen],
            actual_from === from,
            do: result

      assert extra_replies === []

      assert Enum.any?(
               calls,
               &match?(
                 {^gate,
                  {Gaoxy.Admission, :handle_info, [{:expired, ^lease, ^watchdog_token}, _]}},
                 &1
               )
             )

      refute_receive {:owner_deadline_unexpected_return, ^worker, _}, 0
      assert Gaoxy.Lifecycle.remaining(extended_deadline) > 0
      G.eventually(fn -> not Map.has_key?(:sys.get_state(gate).leases, lease) end)
      assert :sys.get_state(gate).cleanups === %{}
      G.no_event(f.peer, "request")
      assert :ok = :ssl.close(socket)

      assert_receive {:DOWN, ^owner_monitor, :process, ^owner, {:shutdown, :peer_closed}},
                     @timeout

      assert_receive {:DOWN, ^writer_monitor, :process, ^writer, :normal}, @timeout

      G.eventually(fn ->
        match?(
          %{active: 0, cleanup_pending: 0, retained_bytes: 0},
          Gaoxy.status(f.instance, :native_tls)
        )
      end)

      assert %{cleanup_failed: nil, retained_high_water: high} =
               Gaoxy.status(f.instance, :native_tls)

      assert high <= f.service_bytes
      assert :ok = Gaoxy.remove(f.instance, :native_tls, @timeout)
      assert_receive {:DOWN, ^service_monitor, :process, ^service, service_reason}, @timeout
      assert service_reason in [:normal, :shutdown]
      assert_receive {:DOWN, ^gate_monitor, :process, ^gate, :killed}, @timeout
      G.clean(f)
      G.no_event(f.peer, "request")
      # Existing joined peer request count must equal only the earlier HEAD
      # health request; an unobserved application request cannot pass close.
      G.close(f)
    after
      cleanup_owner_deadline_observer(owner, gate, patterns)
    end
  end

  defp queued_owner_ssl_calls(owner, worker, token) do
    {:messages, messages} = Process.info(owner, :messages)

    for {:"$gen_call", {^worker, _} = from, {:h2_operation, 1, ^token, :ssl_data}} <- messages,
        do: from
  end

  defp owner_deadline_calls(calls) do
    receive do
      {:trace, pid, :call, mfa} -> owner_deadline_calls([{pid, mfa} | calls])
    after
      0 -> Enum.reverse(calls)
    end
  end

  defp cleanup_owner_deadline_observer(owner, gate, patterns) do
    try do
      :erlang.resume_process(owner)
    catch
      :error, :badarg -> :ok
    end

    for pid <- [owner, gate] do
      try do
        :erlang.trace(pid, false, [:call])
      catch
        :error, :badarg -> :ok
      end
    end

    for pattern <- patterns, do: :erlang.trace_pattern(pattern, false, [:local])
  end

  # This regression expects only an empty200 response; every frame and the
  # entire receive loop retain finite size/count/deadline bounds.
  defp response(_socket, _status, _body, _decoder, 0, _deadline),
    do: flunk("native TLS response exceeded frame bound")

  defp response(socket, status, body, decoder, left, deadline) do
    assert {:ok, <<size::24, type, flags, 0::1, id::31>>} =
             :ssl.recv(socket, 9, Gaoxy.Lifecycle.remaining(deadline))

    assert size <= 16_384
    payload = if size == 0, do: "", else: receive_payload(socket, size, deadline)

    case {type, id} do
      {4, 0} ->
        if flags == 0, do: :ok = :ssl.send(socket, Frame.encode(4, 1, 0, ""))
        response(socket, status, body, decoder, left - 1, deadline)

      {1, 1} ->
        assert Bitwise.band(flags, 4) === 4
        assert {:ok, fields, decoder} = HPAX.decode(payload, decoder)
        {":status", code} = List.keyfind(fields, ":status", 0)
        status = String.to_integer(code)

        if Bitwise.band(flags, 1) == 1,
          do: %{status: status, body: body},
          else: response(socket, status, body, decoder, left - 1, deadline)

      {0, 1} ->
        body = body <> payload
        assert byte_size(body) <= 65_536

        if Bitwise.band(flags, 1) == 1,
          do: %{status: status, body: body},
          else: response(socket, status, body, decoder, left - 1, deadline)

      {8, _} ->
        response(socket, status, body, decoder, left - 1, deadline)

      _ ->
        flunk("unexpected native TLS frame #{inspect({type, flags, id})}")
    end
  end

  defp receive_payload(socket, size, deadline) do
    assert {:ok, payload} = :ssl.recv(socket, size, Gaoxy.Lifecycle.remaining(deadline))
    payload
  end
end
