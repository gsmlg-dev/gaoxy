defmodule Gaoxy.HTTP2NetworkTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Exchange, Response}

  defmodule Endpoint do
    def init(options), do: {:ok, options}

    def call(exchange, options) do
      case exchange.request.path do
        "/identity-hold" ->
          send(options[:owner], {:identity, self(), exchange.transport_state})

          receive do
            :release -> Response.send_resp(exchange, 200, [], "released")
          after
            1_000 -> {:error, :timeout, exchange}
          end

        path when path in ["/queued", "/blocked"] ->
          if options[:owner],
            do: send(options[:owner], {:response_started, path, self(), exchange.transport_state})

          Response.send_resp(exchange, 200, [], path)

        "/fragmented" ->
          send(options[:owner], {:fragmented, self()})

          value =
            String.duplicate(
              "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
              450
            )

          Response.send_resp(exchange, 200, [{"x-large", value}], "fragmented")

        "/hold" ->
          send(options[:owner], {:held, self()})

          receive do
            :release -> Response.send_resp(exchange, 200, [], "released")
          after
            1_000 -> {:error, :timeout, exchange}
          end

        "/echo" ->
          case read(exchange, "") do
            {:ok, body, exchange} ->
              Response.send_resp(exchange, 200, [{"x-protocol", "h2"}], body)

            {:error, reason, exchange} ->
              {:error, reason, exchange}
          end

        "/large-credit" ->
          case Exchange.read_body_step(exchange, 65_536, 500) do
            {:ok, bytes, next} -> Response.send_resp(next, 200, [], bytes)
            {:more, bytes, next} -> Response.send_resp(next, 200, [], bytes)
            {:error, reason, next} -> {:error, reason, next}
          end

        "/poll" ->
          send(options[:owner], {:polling, self()})
          started = System.monotonic_time(:millisecond)
          result = Exchange.poll_connection(exchange, 180)
          send(options[:owner], {:polled, result, System.monotonic_time(:millisecond) - started})

          case result do
            {:pending, next} -> Response.send_resp(next, 200, [], "polled")
            {:error, reason, next} -> {:error, reason, next}
          end

        "/stream" ->
          with {:ok, exchange} <- Response.send_chunked(exchange, 200, [{"trailer", "x-check"}]),
               {:ok, exchange} <- Response.chunk(exchange, "one"),
               {:ok, exchange} <- Response.chunk(exchange, "two"),
               {:ok, exchange} <- Response.finish(exchange, [{"x-check", "value"}]),
               do: {:ok, exchange}

        _ ->
          Response.send_resp(exchange, 200, [], exchange.request.path)
      end
    end

    defp read(exchange, body) do
      case Exchange.read_body(exchange, 4, 500) do
        {:ok, bytes, exchange} -> {:ok, body <> bytes, exchange}
        {:more, bytes, exchange} -> read(exchange, body <> bytes)
        {:error, reason} -> {:error, reason, exchange}
      end
    end
  end

  test "prior knowledge is explicit and rejects the insufficient core byte budget" do
    assert {:error, :http2_byte_budget} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               protocols: [:http2],
               h2c: :prior_knowledge
             )

    assert {:error, :invalid_http_protocols} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               protocols: [:http2, :http1],
               h2c: :prior_knowledge
             )
  end

  test "two concurrent streams preserve bodies and response semantics" do
    {socket, _} = connect()
    send_headers(socket, 1, "/echo", false, [{"content-length", "6"}])
    send_headers(socket, 3, "/other", true)
    :ok = :gen_tcp.send(socket, frame(0, 1, 1, "abcdef"))
    results = responses(socket, [1, 3])
    assert results[1].body == "abcdef"
    assert results[3].body == "/other"
    assert {":status", "200"} in results[1].headers

    refute Enum.any?(results[1].headers, fn {name, _} ->
             name in ["connection", "transfer-encoding"]
           end)
  end

  test "a stalled endpoint does not block a sibling and reset terminates only its worker" do
    {socket, _} = connect(owner: self())
    send_headers(socket, 1, "/hold", true)
    assert_receive {:held, worker}, 1_000
    monitor = Process.monitor(worker)
    send_headers(socket, 3, "/live", true)
    assert responses(socket, [3])[3].body == "/live"
    :ok = :gen_tcp.send(socket, frame(3, 0, 1, <<8::32>>))
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, 1_000
    send_headers(socket, 5, "/again", true)
    assert responses(socket, [5])[5].body == "/again"
  end

  test "zero stream write window leaves a ready sibling and control traffic live" do
    {socket, _} = connect()
    :ok = :gen_tcp.send(socket, frame(4, 0, 0, <<4::16, 0::32>>))
    send_headers(socket, 1, "/blocked", true)
    send_headers(socket, 3, "/ready", true)
    :ok = :gen_tcp.send(socket, frame(8, 0, 3, <<0::1, 32::31>>))
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "12345678"))
    assert responses(socket, [3])[3].body == "/ready"
    :ok = :gen_tcp.send(socket, frame(8, 0, 1, <<0::1, 32::31>>))
    assert responses(socket, [1])[1].body == "/blocked"
  end

  test "response trailers terminate streaming without H1 chunk framing" do
    {socket, _} = connect()
    send_headers(socket, 1, "/stream", true)
    result = responses(socket, [1])[1]
    assert result.body == "onetwo"
    assert {"x-check", "value"} in result.headers
    refute {"transfer-encoding", "chunked"} in result.headers
  end

  test "continuation exclusivity is a connection error" do
    {socket, _} = connect()
    :ok = :gen_tcp.send(socket, frame(1, 0, 1, <<0x82>>))
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "12345678"))
    assert goaway(socket) == 1
  end

  @tag :idle_window
  test "WINDOW_UPDATE on an idle stream is a connection error even with a zero increment" do
    for increment <- [0, 1] do
      {socket, _} = connect()
      :ok = :gen_tcp.send(socket, frame(8, 0, 1, <<increment::32>>))
      assert goaway(socket) == 1
    end
  end

  @tag :priority_length
  test "malformed PRIORITY length resets its stream while the exact sibling survives" do
    {socket, _} = connect(owner: self())
    send_headers(socket, 1, "/hold", true)
    assert_receive {:held, _}, 1_000
    :ok = :gen_tcp.send(socket, frame(2, 0, 1, "x"))
    assert_reset(socket, 1, 6)
    send_headers(socket, 3, "/sibling", true)
    assert responses(socket, [3])[3].body == "/sibling"
  end

  test "a closed stream consumes HPACK changes before resetting and a sibling can use them" do
    {socket, server} = connect()
    send_headers(socket, 1, "/first", true)
    assert responses(socket, [1])[1].body == "/first"
    await_stream_completion(server, Gaoxy.Lifecycle.deadline(1_000))

    {closed_block, encoder} = HPAX.encode(:store, [{"x-context", "kept"}], HPAX.new(4_096))
    :ok = :gen_tcp.send(socket, frame(1, 5, 1, closed_block))
    assert {3, _, 1, <<5::32>>} = recv_frame(socket)

    {next_block, _} =
      HPAX.encode(
        :no_store,
        [
          {":method", "GET"},
          {":scheme", "http"},
          {":authority", "localhost"},
          {":path", "/sibling"},
          {"x-context", "kept"}
        ],
        encoder
      )

    :ok = :gen_tcp.send(socket, frame(1, 5, 3, next_block))
    assert responses(socket, [3])[3].body == "/sibling"
  end

  test "an oversized first compressed fragment is rejected before CONTINUATION arrives" do
    {socket, _} = connect(h2_limits: %{max_header_block: 64, frame_timeout: 250})
    :ok = :gen_tcp.send(socket, frame(1, 0, 1, :binary.copy(<<0>>, 65)))
    assert goaway(socket) == 11
  end

  test "body credit above the H2 transport window is clamped while preserving the payload" do
    {socket, _} = connect(http_limits: %{max_read_chunk: 65_536, max_buffer_bytes: 131_072})
    send_headers(socket, 1, "/large-credit", false, [{"content-length", "5"}])
    :ok = :gen_tcp.send(socket, frame(0, 1, 1, "hello"))
    assert responses(socket, [1])[1].body == "hello"
  end

  test "a finite connection poll waits without delaying another stream or control frames" do
    {socket, _} = connect(owner: self())
    send_headers(socket, 1, "/poll", true)
    assert_receive {:polling, _}, 1_000
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "pollping"))
    assert_ping(socket, "pollping")
    send_headers(socket, 3, "/live", true)
    assert responses(socket, [3])[3].body == "/live"
    assert_receive {:polled, {:pending, _}, elapsed}, 1_000
    assert elapsed >= 150
    assert elapsed < 800
    assert responses(socket, [1])[1].body == "polled"
  end

  test "a self-dependent HEADERS priority still updates HPACK before its stream error" do
    {socket, _} = connect()

    {block, encoder} =
      HPAX.encode(
        :store,
        [
          {":method", "GET"},
          {":scheme", "http"},
          {":authority", "localhost"},
          {":path", "/rejected"},
          {"x-context", "kept"}
        ],
        HPAX.new(4_096)
      )

    :ok = :gen_tcp.send(socket, frame(1, 37, 1, [<<0::1, 1::31, 0>>, block]))
    assert_reset(socket, 1, 1)

    {next, _} =
      HPAX.encode(
        :no_store,
        [
          {":method", "GET"},
          {":scheme", "http"},
          {":authority", "localhost"},
          {":path", "/sibling"},
          {"x-context", "kept"}
        ],
        encoder
      )

    :ok = :gen_tcp.send(socket, frame(1, 5, 3, next))
    assert responses(socket, [3])[3].body == "/sibling"
  end

  test "body demand emits H2 Continue once before the peer uploads" do
    {socket, _} = connect()
    send_headers(socket, 1, "/echo", false, [{"content-length", "5"}, {"expect", "100-continue"}])
    assert_status(socket, 1, "100")
    :ok = :gen_tcp.send(socket, frame(0, 1, 1, "hello"))
    result = responses(socket, [1])[1]
    assert result.body == "hello"
    assert Enum.filter(result.headers, &(elem(&1, 0) == ":status")) == [{":status", "200"}]
  end

  test "pause refuses new streams while admitted work and PING continue on the existing connection" do
    {socket, server} = connect(owner: self())
    local = Gaoxy.info(server, :http).local
    send_headers(socket, 1, "/hold", true)
    assert_receive {:held, worker}, 1_000
    assert Gaoxy.info(server, :http).pause == :unbind_rebind
    assert :ok = Gaoxy.pause(server, :http)
    assert Gaoxy.info(server, :http).local == :error
    {:ok, {ip, port}} = local
    assert {:error, :econnrefused} = :gen_tcp.connect(ip, port, [:binary, active: false], 100)
    send_headers(socket, 3, "/refused", true)
    assert_reset(socket, 3, 7)
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "pausedok"))
    assert_ping(socket, "pausedok")
    send(worker, :release)
    assert responses(socket, [1])[1].body == "released"
    assert :ok = Gaoxy.resume(server, :http)
    assert {:ok, {^ip, resumed_port}} = Gaoxy.info(server, :http).local

    assert {:ok, resumed_socket} =
             :gen_tcp.connect(ip, resumed_port, [:binary, active: false], 100)

    :gen_tcp.close(resumed_socket)
    send_headers(socket, 5, "/resumed", true)
    assert responses(socket, [5])[5].body == "/resumed"
  end

  test "drain emits GOAWAY and finishes admitted work before its single service deadline" do
    {socket, server} = connect(owner: self())
    send_headers(socket, 1, "/hold", true)
    assert_receive {:held, worker}, 1_000
    task = Task.async(fn -> Gaoxy.stop(server, 500) end)
    assert_goaway(socket, 1, 0)
    send(worker, :release)
    assert responses(socket, [1])[1].body == "released"
    assert :ok = Task.await(task, 1_000)
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1_000)
  end

  test "reset removes a response waiting behind another writer operation and preserves its sibling" do
    {socket, server} = connect(owner: self())
    send_headers(socket, 1, "/identity-hold", true)
    assert_receive {:identity, worker, {owner, 1, _token}}, 1_000
    writer = writer_for(owner, worker)
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "queuebar"))
    assert_ping(socket, "queuebar")
    await_h2(owner, fn state -> state.inflight == nil and :queue.is_empty(state.output) end)
    assert :erlang.suspend_process(writer)
    on_exit(fn -> resume_writer(writer) end)

    send_headers(socket, 3, "/blocked", true)
    assert_receive {:response_started, "/blocked", _, {^owner, 3, _}}, 1_000
    await_h2(owner, fn state -> match?({_, {:headers, 3, _}}, state.inflight) end)
    send_headers(socket, 5, "/queued", true)
    assert_receive {:response_started, "/queued", queued, {^owner, 5, _}}, 1_000
    await_h2(owner, fn state -> :queue.len(state.output) > 0 end)
    monitor = Process.monitor(queued)
    :ok = :gen_tcp.send(socket, frame(3, 0, 5, <<8::32>>))
    assert_receive {:DOWN, ^monitor, :process, ^queued, _}, 1_000
    assert :erlang.resume_process(writer)
    result = responses(socket, [3])
    assert result[3].body == "/blocked"
    refute Map.has_key?(result, 5), inspect(result)
    send(worker, :release)
    assert responses(socket, [1])[1].body == "released"
    await_stream_completion(server, Gaoxy.Lifecycle.deadline(1_000))
  end

  test "reset preserves END_HEADERS for a header block already handed to the writer" do
    {socket, _server} = connect(owner: self())
    send_headers(socket, 1, "/identity-hold", true)
    assert_receive {:identity, worker, {owner, 1, _}}, 1_000
    writer = writer_for(owner, worker)
    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "fragment"))
    assert_ping(socket, "fragment")
    await_h2(owner, fn state -> state.inflight == nil and :queue.is_empty(state.output) end)
    assert :erlang.suspend_process(writer)
    on_exit(fn -> resume_writer(writer) end)
    send_headers(socket, 3, "/fragmented", true)
    assert_receive {:fragmented, fragmented}, 1_000
    await_h2(owner, fn state -> state.inflight != nil and :queue.len(state.output) > 0 end)
    monitor = Process.monitor(fragmented)
    :ok = :gen_tcp.send(socket, frame(3, 0, 3, <<8::32>>))
    assert_receive {:DOWN, ^monitor, :process, ^fragmented, _}, 1_000
    assert :erlang.resume_process(writer)
    assert {1, 0, 3, first} = recv_frame(socket)
    assert {9, 4, 3, last} = recv_frame(socket)
    assert {:ok, fields, _} = HPAX.decode(first <> last, HPAX.new(4_096))

    value =
      String.duplicate("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", 450)

    assert {"x-large", value} in fields
    send_headers(socket, 5, "/live-after-fragment", true)
    result = responses(socket, [5])
    assert result[5].body == "/live-after-fragment"
    refute Map.has_key?(result, 3), inspect(result)
    send(worker, :release)
    assert responses(socket, [1])[1].body == "released"
  end

  test "writer crash closes the owner and its admitted worker without affecting the listener" do
    {socket, server} = connect(owner: self())
    send_headers(socket, 1, "/identity-hold", true)
    assert_receive {:identity, worker, {owner, 1, _}}, 1_000
    writer = writer_for(owner, worker)
    monitors = for pid <- [owner, worker, writer], do: {pid, Process.monitor(pid)}
    Process.exit(writer, :kill)

    for {pid, monitor} <- monitors,
        do: assert_receive({:DOWN, ^monitor, :process, ^pid, _}, 1_000)

    until_closed(socket)
    await_restored(server)
    assert Gaoxy.info(server, :http).mode == :ready
  end

  test "owner crash closes its writer and stream and stale operations cannot commit a response" do
    {socket, server} = connect(owner: self())
    send_headers(socket, 1, "/identity-hold", true)
    assert_receive {:identity, worker, {owner, 1, token}}, 1_000

    assert {:error, :closed} =
             GenServer.call(owner, {:h2_operation, 1, token, {:head, 200, [], true}})

    :ok = :gen_tcp.send(socket, frame(6, 0, 0, "stalecal"))
    assert_ping(socket, "stalecal")
    writer = writer_for(owner, worker)
    monitors = for pid <- [owner, worker, writer], do: {pid, Process.monitor(pid)}
    Process.exit(owner, :kill)

    for {pid, monitor} <- monitors,
        do: assert_receive({:DOWN, ^monitor, :process, ^pid, _}, 1_000)

    until_closed(socket)
    await_restored(server)
    assert Gaoxy.info(server, :http).mode == :ready
  end

  @tag :tmp_dir
  test "independent Python h2 qualifies TCP and TLS ALPN with cross-process writes", %{
    tmp_dir: dir
  } do
    root = Path.expand("../../..", __DIR__)
    python = Path.join(root, ".audit/h2peer/bin/python")

    assert File.exists?(python),
           "install the pinned independent peer from test/support/h2-requirements.txt"

    assert {_, 0} =
             System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir],
               stderr_to_stdout: true
             )

    for mode <- [:tcp, :tls] do
      options = [
        endpoint: {Endpoint, []},
        protocols: [:http2],
        limits: %{max_bytes: 536_870_912, max_active: 128},
        http_limits: %{request_timeout: 10_000}
      ]

      options =
        if mode == :tcp,
          do: Keyword.put(options, :h2c, :prior_knowledge),
          else:
            options ++
              [
                transport: :tls,
                tls: %{certfile: Path.join(dir, "cert.pem"), keyfile: Path.join(dir, "key.pem")}
              ]

      {:ok, server} = Gaoxy.HTTP.start_link(options)
      on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
      {:ok, {_, port}} = Gaoxy.info(server, :http).local

      assert {output, 0} =
               System.cmd(
                 python,
                 [
                   Path.join(__DIR__, "support/h2_peer.py"),
                   Integer.to_string(port),
                   if(mode == :tcp, do: "tcp", else: "tls"),
                   Path.join(dir, "ca.pem")
                 ],
                 stderr_to_stdout: true
               )

      assert output =~ "PASS independent Python h2"
    end
  end

  defp connect(options \\ []) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {Endpoint, Keyword.drop(options, [:http_limits, :h2_limits])},
        protocols: [:http2],
        h2c: :prior_knowledge,
        limits: %{max_bytes: 536_870_912, max_active: 128},
        http_limits:
          Map.merge(%{request_timeout: 2_000}, Keyword.get(options, :http_limits, %{})),
        h2_limits: Keyword.get(options, :h2_limits, %{})
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
    on_exit(fn -> :gen_tcp.close(socket) end)
    :ok = :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", frame(4, 0, 0, "")])
    {socket, server}
  end

  defp send_headers(socket, id, path, ended, extra \\ []) do
    fields =
      [
        {":method", if(path == "/echo", do: "POST", else: "GET")},
        {":scheme", "http"},
        {":authority", "localhost"},
        {":path", path}
      ] ++ extra

    {bytes, _} = HPAX.encode(:never_store, fields, HPAX.new(4_096))
    :ok = :gen_tcp.send(socket, frame(1, if(ended, do: 5, else: 4), id, bytes))
  end

  defp frame(type, flags, id, bytes) do
    [<<IO.iodata_length(bytes)::24, type, flags, 0::1, id::31>>, bytes]
  end

  defp recv_frame(socket) do
    {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, 2_000)
    payload = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, 2_000), 1)
    {type, flags, id, payload}
  end

  defp responses(socket, pending, result \\ %{}) do
    if pending == [] do
      result
    else
      {type, flags, id, payload} = recv_frame(socket)
      current = Map.get(result, id, %{body: "", headers: []})

      current =
        case type do
          1 ->
            {:ok, fields, _} = HPAX.decode(payload, HPAX.new(4_096))
            %{current | headers: current.headers ++ fields}

          0 ->
            %{current | body: current.body <> payload}

          4 when flags == 0 ->
            :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
            current

          _ ->
            current
        end

      done = type in [0, 1] and Bitwise.band(flags, 1) == 1

      responses(
        socket,
        if(done, do: List.delete(pending, id), else: pending),
        Map.put(result, id, current)
      )
    end
  end

  defp goaway(socket) do
    case recv_frame(socket) do
      {7, _, 0, <<_::32, code::32, _::binary>>} ->
        code

      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        goaway(socket)

      _ ->
        goaway(socket)
    end
  end

  defp assert_ping(socket, payload) do
    case recv_frame(socket) do
      {6, 1, 0, ^payload} ->
        :ok

      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        assert_ping(socket, payload)

      {4, 1, 0, ""} ->
        assert_ping(socket, payload)

      other ->
        flunk("expected PING progress during poll, got #{inspect(other)}")
    end
  end

  defp assert_status(socket, id, status) do
    case recv_frame(socket) do
      {1, 4, ^id, payload} ->
        assert {:ok, [{":status", ^status}], _} = HPAX.decode(payload, HPAX.new(4_096))

      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        assert_status(socket, id, status)

      {4, 1, 0, ""} ->
        assert_status(socket, id, status)

      other ->
        flunk("expected informational status, got #{inspect(other)}")
    end
  end

  defp assert_reset(socket, id, code) do
    case recv_frame(socket) do
      {3, _, ^id, <<^code::32>>} ->
        :ok

      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        assert_reset(socket, id, code)

      {4, 1, 0, ""} ->
        assert_reset(socket, id, code)

      other ->
        flunk("expected stream reset, got #{inspect(other)}")
    end
  end

  defp assert_goaway(socket, last, code) do
    case recv_frame(socket) do
      {7, _, 0, <<^last::32, ^code::32, _::binary>>} ->
        :ok

      {4, 0, 0, _} ->
        :ok = :gen_tcp.send(socket, frame(4, 1, 0, ""))
        assert_goaway(socket, last, code)

      {4, 1, 0, ""} ->
        assert_goaway(socket, last, code)

      other ->
        flunk("expected GOAWAY, got #{inspect(other)}")
    end
  end

  defp await_stream_completion(server, deadline) do
    status = Gaoxy.status(server, :http)

    if status.active != 2 do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

      receive do
      after
        1 -> await_stream_completion(server, deadline)
      end
    end
  end

  defp resume_writer(writer) do
    :erlang.resume_process(writer)
  rescue
    ArgumentError -> :ok
  end

  defp writer_for(owner, worker) do
    [writer] =
      for {_, pid, _, _} <- Supervisor.which_children(Gaoxy.HTTP.Tasks),
          pid != worker,
          is_pid(pid),
          {:links, links} <- [Process.info(pid, :links)],
          owner in links,
          do: pid

    writer
  end

  defp await_h2(owner, predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(1_000)
    {_, state} = :sys.get_state(owner)

    unless predicate.(state) do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        1 -> await_h2(owner, predicate, deadline)
      end
    end
  end

  defp until_closed(socket) do
    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, _} -> until_closed(socket)
      {:error, :closed} -> :ok
    end
  end

  defp await_restored(server, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(1_000)
    status = Gaoxy.status(server, :http)

    unless match?(%{active: 0, retained_bytes: 0, cleanup_pending: 0}, status) do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

      receive do
      after
        1 -> await_restored(server, deadline)
      end
    end
  end
end
