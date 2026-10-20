defmodule Gaoxy.HTTP2IndependentReviewTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Exchange, Response}
  alias Gaoxy.HTTP.HTTP2.{Frame, Headers}
  @timeout 2_000

  defmodule Endpoint do
    def init(options), do: {:ok, options}

    def call(exchange, owner) do
      case exchange.request.path do
        "/hold" ->
          send(owner, {:review_owner, self(), exchange.transport_state})

          receive do
            :release -> Response.send_resp(exchange, 200, [], "released")
          after
            2_000 -> {:error, :timeout, exchange}
          end

        "/inform-after-final" ->
          {:ok, next} = Response.send_chunked(exchange, 200, [])
          send(owner, {:review_inform, Response.inform(next, 103, [])})
          Response.finish(next)

        "/trailers-before-ready" ->
          complete = Exchange.body_complete?(exchange)
          {:ok, "", next} = Exchange.read_body_step(exchange, 16, 500)
          send(owner, {:review_trailers, complete, Exchange.request_trailers(next)})
          Response.send_resp(next, 200, [], "read")

        "/response-header-limit" ->
          fields = for n <- 1..4, do: {"x-#{n}", "v"}
          result = Response.send_resp(exchange, 200, fields, "unsafe")
          send(owner, {:review_header_limit, result})

          case result do
            {:ok, next} -> {:ok, next}
            {:error, _} -> Response.send_resp(exchange, 200, [], "safe")
          end

        "/response-header-bytes" ->
          result =
            Response.send_resp(exchange, 200, [{"x", String.duplicate("v", 144)}], "unsafe")

          send(owner, {:review_header_bytes, result})

          case result do
            {:ok, next} -> {:ok, next}
            {:error, _} -> Response.send_resp(exchange, 200, [], "safe")
          end

        "/negative-window" ->
          {:ok, next} = Response.send_chunked(exchange, 200, [])
          {:ok, next} = Response.chunk(next, "abc")
          send(owner, {:review_window, self(), next.transport_state})

          receive do
            :release ->
              with {:ok, next} <- Response.chunk(next, "later"), do: Response.finish(next)
          after
            2_000 -> {:error, :timeout, next}
          end

        _ ->
          Response.send_resp(exchange, 200, [], "sibling")
      end
    end
  end

  test "informational headers cannot follow a committed final response" do
    {socket, _server} = connect()
    send_headers(socket, 1, "/inform-after-final", true)
    assert_receive {:review_inform, {:error, :invalid_response_state}}, @timeout
    assert %{status: "200", informational: []} = response(socket, 1)
    send_headers(socket, 3, "/sibling", true)
    assert response(socket, 3).body == "sibling"
  end

  test "terminal trailers buffered before worker admission still require final body consumption" do
    {socket, _server} = connect()
    # Establish decoding capacity before deliberately suspending Admission.
    send_headers(socket, 1, "/hold", true, [{"x-precharge", String.duplicate("a", 128)}])
    assert_receive {:review_owner, held, {owner, 1, _}}, @timeout
    {_socket, state} = :sys.get_state(owner)
    gate = state.gate
    :ok = :sys.suspend(gate)
    on_exit(fn -> safe_resume(gate) end)

    send_headers(socket, 3, "/trailers-before-ready", false, [{"trailer", "x-check"}])
    trailers = [{"x-check", "first"}, {"x-check", "last"}]
    {block, _} = HPAX.encode(:never_store, trailers, HPAX.new(4_096))
    :ok = :gen_tcp.send(socket, Frame.encode(1, 5, 3, block))

    await_owner(owner, fn state ->
      match?(%{eof: true, lease: nil, trailers: ^trailers}, state.streams[3])
    end)

    :ok = :sys.resume(gate)
    assert_receive {:review_trailers, false, ^trailers}, @timeout
    assert response(socket, 3).body == "read"
    send(held, :release)
    assert response(socket, 1).body == "released"
  end

  test "generated status and framing fields stay inside the configured response header count" do
    {socket, _server} = connect(%{max_headers: 5})
    send_headers(socket, 1, "/response-header-limit", true)
    assert_receive {:review_header_limit, {:error, :invalid_response_headers}}, @timeout
    result = response(socket, 1)
    assert result.body == "safe"
    assert length(result.fields) <= 5
  end

  test "generated status and framing fields stay inside the configured response header bytes" do
    {socket, _server} = connect(%{max_header_bytes: 256})
    send_headers(socket, 1, "/response-header-bytes", true)
    assert_receive {:review_header_bytes, {:error, :invalid_response_headers}}, @timeout
    result = response(socket, 1)
    assert result.body == "safe"
    assert Headers.bytes(result.fields) <= 256
  end

  test "a WINDOW_UPDATE on a never-opened stream is a connection protocol error" do
    {socket, _server} = connect()
    send_headers(socket, 1, "/hold", true)
    assert_receive {:review_owner, held, {_owner, 1, _}}, @timeout
    :ok = :gen_tcp.send(socket, Frame.encode(8, 0, 3, <<7::32>>))
    # A WINDOW_UPDATE for a never-opened stream is a connection error.
    assert_goaway(socket, 1)
    monitor = Process.monitor(held)
    assert_receive {:DOWN, ^monitor, :process, ^held, _}, @timeout
  end

  test "a negative SETTINGS send window preserves a credited sibling's progress" do
    {socket, _server} = connect()
    send_headers(socket, 1, "/negative-window", true)
    assert_receive {:review_window, worker, {owner, 1, _}}, @timeout
    assert_data(socket, 1, "abc")
    :ok = :gen_tcp.send(socket, Frame.encode(4, 0, 0, <<4::16, 0::32>>))
    await_owner(owner, &(&1.streams[1].send_window == -3))
    send_headers(socket, 3, "/sibling", true)
    :ok = :gen_tcp.send(socket, Frame.encode(8, 0, 3, <<7::32>>))
    assert response(socket, 3).body == "sibling"
    :ok = :gen_tcp.send(socket, Frame.encode(8, 0, 1, <<8::32>>))
    send(worker, :release)
    assert response(socket, 1).body == "later"
  end

  test "the advertised maximum frame fits the validated ingress carry budget" do
    assert {:error, _} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, self()},
               protocols: [:http2],
               h2c: :prior_knowledge,
               limits: %{max_bytes: 536_870_912, max_active: 128},
               h2_limits: %{max_frame: 65_535}
             )

    {socket, _server} = connect(%{max_buffer_bytes: 131_072}, %{max_frame: 65_535})
    send_headers(socket, 1, "/hold", true)
    assert_receive {:review_owner, held, _}, @timeout
    :ok = :gen_tcp.send(socket, Frame.encode(255, 0, 0, :binary.copy("u", 65_535)))
    send_headers(socket, 3, "/sibling", true)
    assert response(socket, 3).body == "sibling"
    send(held, :release)
    assert response(socket, 1).body == "released"
  end

  test "a queued response head retains its original absolute stream deadline" do
    {socket, _server} = connect(%{request_timeout: 1_000})
    send_headers(socket, 1, "/hold", true)
    assert_receive {:review_owner, held, {owner, 1, _}}, @timeout
    await_owner(owner, &(&1.writer_ready and &1.inflight == nil and :queue.is_empty(&1.output)))
    {_socket, state} = :sys.get_state(owner)
    writer = state.writer
    original_deadline = state.streams[1].deadline
    assert :erlang.suspend_process(writer)
    on_exit(fn -> safe_resume_writer(writer) end)
    send(held, :release)
    await_owner(owner, &match?({_, {:headers, 1, _}}, &1.inflight))
    {:messages, messages} = Process.info(writer, :messages)

    assert [{:h2_write, ^owner, _, _, deadline}] =
             Enum.filter(messages, &match?({:h2_write, _, _, _, _}, &1))

    assert deadline <= original_deadline
    assert :erlang.resume_process(writer)
    assert response(socket, 1).body == "released"
  end

  defp connect(http_limits \\ %{}, h2_limits \\ %{}) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {Endpoint, self()},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: 536_870_912, max_active: 128},
        http_limits: Map.merge(%{request_timeout: 5_000}, http_limits),
        h2_limits: h2_limits
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")])
    {socket, server}
  end

  defp send_headers(socket, id, path, ended, extra \\ []) do
    fields =
      [{":method", "GET"}, {":scheme", "http"}, {":authority", "localhost"}, {":path", path}] ++
        extra

    {block, _} = HPAX.encode(:never_store, fields, HPAX.new(4_096))
    :ok = :gen_tcp.send(socket, Frame.encode(1, if(ended, do: 5, else: 4), id, block))
  end

  defp response(
         socket,
         id,
         result \\ %{status: nil, fields: [], informational: [], body: ""},
         block \\ "",
         decoder \\ HPAX.new(4_096)
       ) do
    case recv_frame(socket) do
      {type, flags, ^id, bytes} when type in [1, 9] ->
        block = block <> bytes

        if Frame.flag?(flags, 4) do
          {:ok, fields, decoder} = HPAX.decode(block, decoder)
          {":status", status} = List.keyfind(fields, ":status", 0)

          next =
            if String.to_integer(status) < 200,
              do: %{result | informational: result.informational ++ [status]},
              else: %{result | status: status, fields: fields}

          if Frame.flag?(flags, 1), do: next, else: response(socket, id, next, "", decoder)
        else
          response(socket, id, result, block, decoder)
        end

      {0, flags, ^id, bytes} ->
        next = %{result | body: result.body <> bytes}
        if Frame.flag?(flags, 1), do: next, else: response(socket, id, next, block, decoder)

      {4, flags, 0, _} ->
        unless Frame.flag?(flags, 1), do: :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        response(socket, id, result, block, decoder)

      _ ->
        response(socket, id, result, block, decoder)
    end
  end

  defp recv_frame(socket) do
    {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @timeout)
    bytes = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, @timeout), 1)
    {type, flags, id, bytes}
  end

  defp assert_goaway(socket, code) do
    case recv_frame(socket) do
      {7, _, 0, <<_::32, ^code::32, _::binary>>} ->
        :ok

      {4, flags, 0, _} ->
        unless Frame.flag?(flags, 1), do: :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        assert_goaway(socket, code)

      _ ->
        assert_goaway(socket, code)
    end
  end

  defp assert_data(socket, id, bytes) do
    case recv_frame(socket) do
      {0, _, ^id, ^bytes} ->
        :ok

      {4, flags, 0, _} ->
        unless Frame.flag?(flags, 1), do: :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        assert_data(socket, id, bytes)

      _ ->
        assert_data(socket, id, bytes)
    end
  end

  defp await_owner(owner, predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)
    {_socket, state} = :sys.get_state(owner, @timeout)

    unless predicate.(state) do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        1 -> await_owner(owner, predicate, deadline)
      end
    end
  end

  defp safe_resume(gate) do
    if Process.alive?(gate), do: :sys.resume(gate, 100)
  catch
    :exit, _ -> :ok
  end

  defp safe_resume_writer(writer) do
    if Process.alive?(writer), do: :erlang.resume_process(writer)
  rescue
    ArgumentError -> :ok
  end
end
