defmodule Gaoxy.HTTP.ResourceBudgetH2Test do
  use ExUnit.Case, async: false
  alias Gaoxy.HTTP.{Exchange, Response}
  alias Gaoxy.HTTP.HTTP2.{Frame, Limits}
  alias HTTP.HTTP2.HPACK
  @timeout 3_000

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      send(owner, {:budget_h2, self(), exchange.transport_state, exchange.gate, exchange.lease})

      receive do
        {:terminal_hold, hook} ->
          {:ok, final} = Response.send_resp(exchange, 200, [], "/terminal")
          worker = self()
          lease = final.lease

          :ok =
            :sys.install(
              final.gate,
              {hook,
               fn previous, event, _ ->
                 case event do
                   {:in, {:"$gen_call", {^worker, _}, {:repartition_until, ^lease, _, _, _}}} ->
                     send(owner, {:terminal_pending, worker, final.gate, hook})

                     receive do
                       {:release_terminal, ^hook} -> :ok
                     after
                       2_000 -> raise "terminal test barrier expired"
                     end

                   _ ->
                     :ok
                 end

                 previous
               end, nil}
            )

          {:ok, final}

        :read_hold ->
          {:more, bytes, exchange} = Exchange.read_body_step(exchange, 128, 1_000)
          send(owner, {:held_body, self(), bytes, :binary.referenced_byte_size(bytes)})

          receive do
            :continue -> echo(exchange, bytes)
          after
            Gaoxy.Lifecycle.remaining(exchange.deadline) -> {:error, :timeout, exchange}
          end

        :respond ->
          if exchange.request.path == "/upload",
            do: echo(exchange, ""),
            else: Response.send_resp(exchange, 200, [], exchange.request.path)
      after
        Gaoxy.Lifecycle.remaining(exchange.deadline) -> {:error, :timeout, exchange}
      end
    end

    defp echo(exchange, result) do
      case Exchange.read_body_step(exchange, 16_384, 1_000) do
        {:more, bytes, next} -> echo(next, result <> bytes)
        {:ok, bytes, next} -> Response.send_resp(next, 200, [], result <> bytes)
        {:pending, next} -> echo(next, result)
        {:error, reason, next} -> {:error, reason, next}
      end
    end
  end

  test "one H2 connection owns overlapping streams independently and releases completed work" do
    server = server()
    socket = connect(server)
    send_headers(socket, 1, "/first")
    assert_receive {:budget_h2, first, {owner, 1, _}, _, _}, @timeout
    send_headers(socket, 3, "/second")
    assert_receive {:budget_h2, second, {^owner, 3, _}, _, _}, @timeout
    assert first != second

    assert %{active_connections: 1, active_requests: 2, active_h2_streams: 2} =
             Gaoxy.resource_budget(server)

    send(first, :respond)
    assert response(socket, 1) == {"200", "/first"}
    await(server, &(&1.active_requests == 1 and &1.active_h2_streams == 1))
    assert Process.alive?(second)
    send(second, :respond)
    assert response(socket, 3) == {"200", "/second"}
    await(server, &(&1.active_requests == 0 and &1.active_h2_streams == 0))
    assert %{active: 2} = Gaoxy.status(server, :http)
    close(server, socket)
  end

  test "definite pre-reserve expiry retires its attempt and reuses the same connection slot" do
    server = server(h2_limits: %{max_streams: 1})
    socket = connect(server)
    send_headers(socket, 1, "/first")
    assert_receive {:budget_h2, first, {owner, 1, _}, gate, _}, @timeout
    {_, initial} = :sys.get_state(owner)
    template = initial.streams[1]
    send(first, :respond)
    assert response(socket, 1) == {"200", "/first"}
    await(server, &(&1.active_requests == 0 and &1.active_h2_streams == 0))
    token = make_ref()

    # Install the exact queued-start checkpoint with an elapsed deadline. The
    # actual connection owns the public async request and receives its genuine
    # Admission response alias; no forged receipt or timeout-as-proof is used.
    :sys.replace_state(owner, fn {transport, state} ->
      limit = Gaoxy.Lifecycle.now() - 1

      stream = %{
        template
        | id: 3,
          token: token,
          worker: nil,
          monitor: nil,
          lease: nil,
          startup: nil,
          deadline: limit
      }

      {:ok, {:native_http2_worker_v1, protocol_bytes, bytes}} =
        Gaoxy.HTTP.HTTP2.WorkerAccounting.reservation(state, stream)

      accounting = %{
        retained_bytes: bytes - state.reserves.stream,
        temporary_bytes: state.reserves.stream,
        transport_bytes: bytes
      }

      request =
        Gaoxy.Admission.spawn_request(
          gate,
          state.lease,
          token,
          accounting,
          limit,
          {Gaoxy.HTTP.HTTP2.Stream, :run, [owner, 3, token, gate, protocol_bytes, limit]},
          [kind: :h2_stream, memberships: %{h2_stream: {state.lease, 3}, request: token}],
          :phase_receipt
        )

      startup = %{
        request: request,
        timer: Process.send_after(owner, {:h2_worker_start_timeout, 3, token}, 0),
        token: token,
        parent_lease: state.lease,
        protocol_bytes: protocol_bytes,
        bytes: bytes,
        deadline: limit
      }

      {transport,
       %{state | streams: %{3 => %{stream | startup: startup}}, starting: 3, highest: 3}}
    end)

    assert {3, 0, 3, <<7::32>>} = recv_frame(socket)

    await(server, fn budget ->
      {_, state} = :sys.get_state(owner)

      budget.active_requests == 0 and budget.active_h2_streams == 0 and
        state.streams == %{} and state.retiring_streams == %{} and state.retirement_timer == nil
    end)

    refute_receive {:budget_h2, _, {^owner, 3, _}, _, _}, 0
    send_headers(socket, 5, "/after-expiry")
    assert_receive {:budget_h2, next, {^owner, 5, _}, ^gate, _}, @timeout
    send(next, :respond)
    assert response(socket, 5) == {"200", "/after-expiry"}
    close(server, socket)
  end

  test "peer close cancels unfinished streams and releases parent-owned quota and buffers" do
    server = server()
    socket = connect(server)
    send_headers(socket, 1, "/live")
    assert_receive {:budget_h2, first, {owner, 1, _}, _, _}, @timeout
    send_headers(socket, 3, "/upload", false)
    assert_receive {:budget_h2, second, {^owner, 3, _}, _, _}, @timeout
    :ok = :gen_tcp.send(socket, Frame.encode(0, 0, 3, :binary.copy("p", 1_024)))

    await(server, fn _ ->
      {_, state} = :sys.get_state(owner)
      byte_size(state.streams[3].input) == 1_024
    end)

    first_monitor = Process.monitor(first)
    second_monitor = Process.monitor(second)
    :ok = :gen_tcp.close(socket)
    assert_receive {:DOWN, ^first_monitor, :process, ^first, :killed}, @timeout
    assert_receive {:DOWN, ^second_monitor, :process, ^second, :killed}, @timeout

    await(
      server,
      &(&1.usage == 0 and &1.active_connections == 0 and &1.active_requests == 0 and
          &1.active_h2_streams == 0)
    )
  end

  test "peer close after END_STREAM joins final bookkeeping before worker termination" do
    server = server()
    socket = connect(server)
    send_headers(socket, 1, "/terminal")
    assert_receive {:budget_h2, worker, {owner, 1, _}, gate, _}, @timeout
    hook = make_ref()
    on_exit(fn -> send(gate, {:release_terminal, hook}) end)
    monitor = Process.monitor(worker)
    :erlang.trace_pattern({Gaoxy.HTTP.HTTP2.Connection, :close, 1}, true, [:local])
    :erlang.trace(owner, true, [:call])

    on_exit(fn ->
      :erlang.trace_pattern({Gaoxy.HTTP.HTTP2.Connection, :close, 1}, false, [:local])
    end)

    send(worker, {:terminal_hold, hook})
    assert response(socket, 1) == {"200", "/terminal"}
    assert_receive {:terminal_pending, ^worker, ^gate, ^hook}, @timeout
    :ok = :gen_tcp.close(socket)

    assert_receive {:trace, ^owner, :call, {Gaoxy.HTTP.HTTP2.Connection, :close, [closing]}},
                   @timeout

    assert closing.streams[1].local_closed and closing.streams[1].eof
    assert closing.streams[1].write == nil
    assert Process.alive?(worker)
    send(gate, {:release_terminal, hook})
    assert_receive {:DOWN, ^monitor, :process, ^worker, :normal}, @timeout
    await(server, &(&1.usage == 0 and &1.active_requests == 0 and &1.active_h2_streams == 0))
  end

  test "TCP receive floor follows effective buffer and retained slices detach before handoff" do
    server = server(h2_limits: %{control_turn: 1})
    socket = connect(server)
    send_headers(socket, 1, "/upload", false)
    assert_receive {:budget_h2, worker, {owner, 1, _}, gate, _}, @timeout
    {transport, state} = :sys.get_state(owner)
    assert {:ok, [buffer: delivery]} = Hell.Socket.getopts(transport, [:buffer])
    assert delivery > 0 and delivery <= Limits.receive_buffer()
    assert state.reserves.receive == 2 * state.limits.max_buffer_bytes + 8 * delivery
    assert state.reserves.connection == 4 * state.limits.max_buffer_bytes + 8 * delivery
    assert state.reserves.connection < Limits.reservation(state.limits, state.h2).connection

    body = :binary.copy("b", 5_000)
    # Ignored extension, DATA and a partial next frame share a wire write. A
    # one-frame parser turn exercises carry retention through local messages.
    next = IO.iodata_to_binary(Frame.encode(0, 1, 1, "end"))
    <<partial::binary-size(5), rest::binary>> = next

    :ok =
      :gen_tcp.send(socket, [
        Frame.encode(99, 0, 0, :binary.copy("x", 5_000)),
        Frame.encode(0, 0, 1, body),
        partial
      ])

    await(server, fn _ ->
      {_, current} = :sys.get_state(owner)
      current.buffer == partial and current.streams[1].input == body
    end)

    {_, state} = :sys.get_state(owner)
    assert :binary.referenced_byte_size(state.buffer) == byte_size(partial)
    assert :binary.referenced_byte_size(state.streams[1].input) == byte_size(body)
    send(worker, :read_hold)
    assert_receive {:held_body, ^worker, held, 128}, @timeout
    assert held == :binary.copy("b", 128)
    {_, state} = :sys.get_state(owner)
    assert state.streams[1].delivered_wire == 128
    assert :binary.referenced_byte_size(state.streams[1].input) == 4_872
    lease = :sys.get_state(gate).leases[state.lease]
    assert lease.accounting.temporary_bytes >= state.reserves.receive

    assert lease.accounting.retained_bytes >=
             :erlang.external_size(Map.drop(state, [:decode_reservation])) + 128

    :ok = :gen_tcp.send(socket, rest)
    send(worker, :continue)
    assert response(socket, 1) == {"200", body <> "end"}

    {_, block} =
      HPACK.encode_headers(
        HPACK.new_encoder(),
        fields("/continued") ++ [{"x-long", :binary.copy("h", 5_000)}],
        indexing: :never,
        huffman: :never
      )

    <<first::binary-size(2_000), last::binary>> = block

    :ok =
      :gen_tcp.send(socket, [
        Frame.encode(99, 0, 0, :binary.copy("x", 5_000)),
        Frame.encode(1, 1, 3, first)
      ])

    await(server, fn _ ->
      {_, current} = :sys.get_state(owner)
      current.continuation != nil and current.continuation.block == first
    end)

    {_, continued} = :sys.get_state(owner)
    assert :binary.referenced_byte_size(continued.continuation.block) == byte_size(first)
    :ok = :gen_tcp.send(socket, Frame.encode(9, 4, 3, last))
    assert_receive {:budget_h2, headers_worker, {^owner, 3, _}, ^gate, _}, @timeout
    send(headers_worker, :respond)
    assert response(socket, 3) == {"200", "/continued"}
    # A partial-only delivery takes the decoder's :more path. Model a native
    # slice backed by one complete driver buffer, with no preceding full frame.
    carry = <<12_000::24, 99, 0, 0::32>> <> :binary.copy("c", 4_000)
    backed = carry <> :binary.copy("x", Limits.receive_buffer() - byte_size(carry))
    backed = :binary.copy(backed)
    slice = binary_part(backed, 0, byte_size(carry))
    assert :binary.referenced_byte_size(slice) == Limits.receive_buffer()

    :sys.replace_state(owner, fn {transport, current} ->
      {:continue, next} = Gaoxy.HTTP.HTTP2.Connection.data(slice, transport, current)
      {transport, next}
    end)

    {_, partial_only} = :sys.get_state(owner)
    assert partial_only.buffer == carry
    assert :binary.referenced_byte_size(partial_only.buffer) == byte_size(carry)
    close(server, socket)
  end

  test "drain completion preserves receive floor and rejects growth beyond funded total" do
    server = server()
    socket = connect(server)
    send_headers(socket, 1, "/live")
    assert_receive {:budget_h2, worker, {owner, 1, _}, gate, _}, @timeout
    {_, original} = :sys.get_state(owner)
    :ok = Gaoxy.Admission.drain(gate, Gaoxy.Lifecycle.deadline(@timeout))
    assert {7, 0, 0, _} = recv_frame(socket)
    # A legal partial extension frame occupies receive carry during drain.
    partial = <<16_000::24, 99, 0, 0::32>> <> :binary.copy("p", 8_000)
    :ok = :gen_tcp.send(socket, partial)

    await(server, fn _ ->
      {_, current} = :sys.get_state(owner)
      current.buffer == partial
    end)

    {_, state} = :sys.get_state(owner)
    accounting = :sys.get_state(gate).leases[state.lease].accounting
    assert state.accounted_bytes == original.funded_floor
    assert accounting.temporary_bytes >= state.reserves.receive
    assert accounting.retained_bytes + accounting.temporary_bytes == state.accounted_bytes
    observer = self()

    :sys.replace_state(owner, fn {transport, current} ->
      too_large = %{
        accounting
        | retained_bytes: accounting.retained_bytes + current.reserves.completion + 1,
          transport_bytes: accounting.transport_bytes + current.reserves.completion + 1
      }

      result =
        Gaoxy.Admission.update_until(
          gate,
          current.lease,
          too_large,
          make_ref(),
          Gaoxy.Lifecycle.deadline(50)
        )

      send(observer, {:beyond_funding, result})
      {transport, current}
    end)

    assert_receive {:beyond_funding, {:error, :draining}}
    assert Process.alive?(worker)
    send(worker, :respond)
    assert response(socket, 1) == {"200", "/live"}
    close(server, socket)
  end

  test "HPACK insertion and indexed reuse retain actual decoder state without a decode high water" do
    server = server()
    socket = connect(server)
    fields = fields("/indexed") ++ [{"x-budget", String.duplicate("a", 3_000)}]

    {encoder, block} =
      HPACK.encode_headers(HPACK.new_encoder(), fields, indexing: :incremental, huffman: :never)

    :ok = :gen_tcp.send(socket, Frame.encode(1, 5, 1, block))
    assert_receive {:budget_h2, first, {owner, 1, _}, gate, _}, @timeout
    send(first, :respond)
    assert response(socket, 1) == {"200", "/indexed"}
    await(server, &(&1.active_requests == 0 and &1.active_h2_streams == 0))
    {_, state} = :sys.get_state(owner)
    assert state.decode_reservation == 0
    lease = :sys.get_state(gate).leases[state.lease]

    assert lease.accounting.retained_bytes + lease.accounting.temporary_bytes ==
             max(state.funded_floor, lease.accounting.retained_bytes + state.reserves.receive)

    assert lease.accounting.temporary_bytes >= state.reserves.receive

    assert lease.accounting.retained_bytes >= :erlang.external_size(state.decoder)
    assert lease.bytes < 20_000_000
    decode_peak = Limits.decode_reservation(state.h2, byte_size(block))
    assert decode_peak > lease.accounting.retained_bytes
    {_, indexed} = HPACK.encode_headers(encoder, fields, indexing: :incremental, huffman: :never)
    assert byte_size(indexed) < byte_size(block)
    :ok = :gen_tcp.send(socket, Frame.encode(1, 5, 3, indexed))
    assert_receive {:budget_h2, second, {^owner, 3, _}, ^gate, _}, @timeout
    send(second, :respond)
    assert response(socket, 3) == {"200", "/indexed"}
    await(server, &(&1.active_requests == 0 and &1.active_h2_streams == 0))
    {_, after_indexed} = :sys.get_state(owner)
    assert after_indexed.decode_reservation == 0
    assert %{rejected: 0} = Gaoxy.status(server, :http)
    close(server, socket)
  end

  test "request quota refuses only its stream and preserves HPACK indexing and its live sibling" do
    server = server(limits: %{max_requests: 1})
    socket = connect(server)
    send_headers(socket, 1, "/live")
    assert_receive {:budget_h2, first, {owner, 1, _}, _, _}, @timeout
    fields = fields("/indexed") ++ [{"x-budget", "refused-table-entry"}]

    {encoder, block} =
      HPACK.encode_headers(HPACK.new_encoder(), fields, indexing: :incremental, huffman: :never)

    :ok = :gen_tcp.send(socket, Frame.encode(1, 5, 3, block))
    assert {3, 0, 3, <<7::32>>} = recv_frame(socket)
    assert Process.alive?(first)

    assert %{active_connections: 1, active_requests: 1, active_h2_streams: 1} =
             Gaoxy.resource_budget(server)

    send(first, :respond)
    assert response(socket, 1) == {"200", "/live"}
    await(server, &(&1.active_requests == 0 and &1.active_h2_streams == 0))
    {_, indexed} = HPACK.encode_headers(encoder, fields, indexing: :incremental, huffman: :never)
    assert byte_size(indexed) < byte_size(block)
    :ok = :gen_tcp.send(socket, Frame.encode(1, 5, 5, indexed))
    assert_receive {:budget_h2, second, {^owner, 5, _}, _, _}, @timeout
    send(second, :respond)
    assert response(socket, 5) == {"200", "/indexed"}
    close(server, socket)
  end

  test "overlapping H2 uploads retain request and stream memberships until their own completion" do
    server = server()
    socket = connect(server)
    for id <- [1, 3], do: send_headers(socket, id, "/upload", false, [{"content-length", "4"}])
    assert_receive {:budget_h2, first, {owner, 1, _}, _, _}, @timeout
    assert_receive {:budget_h2, second, {^owner, 3, _}, _, _}, @timeout

    assert %{active_connections: 1, active_requests: 2, active_h2_streams: 2} =
             Gaoxy.resource_budget(server)

    :ok = :gen_tcp.send(socket, [Frame.encode(0, 1, 1, "abcd"), Frame.encode(0, 1, 3, "efgh")])
    send(first, :respond)
    assert response(socket, 1) == {"200", "abcd"}
    assert Process.alive?(second)
    send(second, :respond)
    assert response(socket, 3) == {"200", "efgh"}
    close(server, socket)
  end

  test "unfunded valid HPACK decode closes with connection overload before dispatch" do
    server = server(resource_budget: %{soft_limit: 32 * 1_048_576, hard_limit: 64 * 1_048_576})
    socket = connect(server)
    fields = fields("/unfunded") ++ [{"x-pad", String.duplicate("a", 8_000)}]

    {_, block} =
      HPACK.encode_headers(HPACK.new_encoder(), fields, indexing: :never, huffman: :never)

    assert {:ok, _, ^fields} = HPACK.decode(HPACK.new_decoder(), block)
    python = Path.expand("../../../.audit/h2peer/bin/python", __DIR__)

    script =
      "import base64,sys; from hpack import Decoder; h=dict(Decoder().decode(base64.b64decode(sys.argv[1]))); assert h[':path']=='/unfunded' and h['x-pad']=='a'*8000; print('VALID')"

    assert {"VALID\n", 0} =
             System.cmd(python, ["-c", script, Base.encode64(block)], stderr_to_stdout: true)

    assert Limits.decode_reservation(%{table_size: 4_096}, byte_size(block)) > 64 * 1_048_576
    :ok = :gen_tcp.send(socket, Frame.encode(1, 5, 1, block))
    assert {7, 0, 0, <<_::1, 0::31, 11::32>>} = recv_frame(socket)
    refute_receive {:budget_h2, _, _, _, _}, 0
    close(server, socket)
  end

  defp server(extra \\ []) do
    {budget, extra} = Keyword.pop(extra, :resource_budget)

    {:ok, spec} =
      Gaoxy.HTTP.service_spec(
        Keyword.merge(
          [
            endpoint: {Endpoint, self()},
            protocols: [:http2],
            h2c: :prior_knowledge,
            http_limits: %{request_timeout: @timeout}
          ],
          extra
        )
      )

    options = if budget, do: [services: [spec], resource_budget: budget], else: [services: [spec]]
    {:ok, server} = Gaoxy.start_link(options)
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    server
  end

  defp connect(server) do
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")])
    assert {4, 0, 0, _} = recv_frame(socket, false)
    assert {4, 1, 0, ""} = recv_frame(socket, false)
    :ok = :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
    socket
  end

  defp fields(path),
    do: [
      {":method", if(path == "/upload", do: "POST", else: "GET")},
      {":scheme", "http"},
      {":authority", "localhost"},
      {":path", path}
    ]

  defp send_headers(socket, id, path, ended \\ true, extra \\ []) do
    {_, block} =
      HPACK.encode_headers(HPACK.new_encoder(), fields(path) ++ extra,
        indexing: :never,
        huffman: :never
      )

    :ok = :gen_tcp.send(socket, Frame.encode(1, if(ended, do: 5, else: 4), id, block))
  end

  defp recv_frame(socket, controls \\ true) do
    assert {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @timeout)
    bytes = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, @timeout), 1)

    if controls and type == 4 do
      unless Frame.flag?(flags, 1), do: :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
      recv_frame(socket, controls)
    else
      {type, flags, id, bytes}
    end
  end

  defp response(socket, stream, status \\ nil, body \\ "", decoder \\ HPACK.new_decoder()) do
    case recv_frame(socket) do
      {1, flags, ^stream, bytes} ->
        assert Frame.flag?(flags, 4)
        {:ok, decoder, fields} = HPACK.decode(decoder, bytes)
        {":status", status} = List.keyfind(fields, ":status", 0)

        if Frame.flag?(flags, 1),
          do: {status, body},
          else: response(socket, stream, status, body, decoder)

      {0, flags, ^stream, bytes} ->
        if Frame.flag?(flags, 1),
          do: {status, body <> bytes},
          else: response(socket, stream, status, body <> bytes, decoder)

      {8, _, _, _} ->
        response(socket, stream, status, body, decoder)

      other ->
        flunk("unexpected H2 frame: #{inspect(other)}")
    end
  end

  defp close(server, socket) do
    :gen_tcp.close(socket)

    await(
      server,
      &(&1.active_connections == 0 and &1.active_requests == 0 and &1.active_h2_streams == 0 and
          &1.usage == 0)
    )
  end

  defp await(server, predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)
    status = Gaoxy.resource_budget(server)

    unless predicate.(status) do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)
      Process.sleep(1)
      await(server, predicate, deadline)
    end
  end
end
