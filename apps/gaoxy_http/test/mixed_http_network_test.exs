defmodule Gaoxy.HTTP.MixedHTTPNetworkTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.{Exchange, Response}
  alias Gaoxy.HTTP.HTTP2.Frame
  @timeout 2_000
  @preface "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

  defmodule Endpoint do
    def init(owner), do: {:ok, owner}

    def call(exchange, owner) do
      {:ok, body, exchange} = read(exchange, "")
      request = exchange.request
      send(owner, {:mixed_request, request.version, request.path, body})

      Response.send_resp(
        exchange,
        200,
        [{"x-native-version", Atom.to_string(request.version)}],
        request.path <> ":" <> body
      )
    end

    defp read(exchange, bytes) do
      case Exchange.read_body(exchange, 16_384, 1_000) do
        {:ok, more, next} -> {:ok, bytes <> more, next}
        {:more, more, next} -> read(next, bytes <> more)
      end
    end
  end

  defmodule PhoenixEndpoint do
    def init(options), do: options

    def call(conn, _) do
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      conn
      |> Plug.Conn.put_resp_header(
        "x-native-version",
        Atom.to_string(conn.private.gaoxy_http_version)
      )
      |> Plug.Conn.send_resp(200, conn.request_path <> ":" <> body)
    end
  end

  test "explicit H1 and independent H2 coexist on one port with exact-once bytes" do
    {server, ip, port} = server()
    assert ip == {127, 0, 0, 1}
    run_peer(port)

    for {version, path, body} <- [
          {:"HTTP/1.1", "/h1-first", "h1-body"},
          {:"HTTP/1.1", "/h1-pipeline", ""},
          {:"HTTP/1.1", "/h1-second", ""},
          {:"HTTP/2", "/h2-first", "h2-body"},
          {:"HTTP/2", "/h2-second", ""}
        ] do
      assert_receive {:mixed_request, ^version, ^path, ^body}, @timeout
    end

    refute_receive {:mixed_request, _, _, _}, 20
    await_empty(server)
  end

  test "Phoenix HTTP options run both protocols through one native listener" do
    [child] =
      Gaoxy.PhoenixAdapter.child_specs(PhoenixEndpoint,
        http: [port: 0, protocols: [:http2, :http1], h2c: :prior_knowledge]
      )

    server = start_supervised!(child)
    assert [service] = Gaoxy.services(server)
    assert {:ok, {_, port}} = Gaoxy.info(server, service).local
    run_peer(port)
    await_empty(server, service)
  end

  test "each fragmented preface boundary preserves coalesced H2 request bytes" do
    {server, ip, port} = server()

    for split <- 1..23 do
      socket = connect(ip, port)
      <<prefix::binary-size(^split), rest::binary>> = @preface
      :ok = :gen_tcp.send(socket, prefix)
      # No H2 frame is emitted before a complete preface, even for PRI.
      assert {:error, :timeout} = :gen_tcp.recv(socket, 0, 5)
      :ok = :gen_tcp.send(socket, [rest, Frame.encode(4, 0, 0, ""), headers(1, "/split")])
      assert h2_response(socket) == "/split:"
      assert_receive {:mixed_request, :"HTTP/2", "/split", ""}, @timeout
      :gen_tcp.close(socket)
    end

    refute_receive {:mixed_request, _, _, _}, 20
    await_empty(server)
  end

  test "PRI method mismatch chooses H1 and pipelined bytes stay on H1" do
    {server, ip, port} = server()
    socket = connect(ip, port)
    :ok = :gen_tcp.send(socket, "PRI")
    assert {:error, :timeout} = :gen_tcp.recv(socket, 0, 10)

    :ok =
      :gen_tcp.send(
        socket,
        " /first HTTP/1.1\r\nHost: localhost\r\n\r\n" <>
          "GET /last HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
      )

    bytes = all(socket)
    assert String.starts_with?(bytes, "HTTP/1.1 200 OK\r\n")
    assert length(:binary.matches(bytes, "HTTP/1.1 200 OK\r\n")) == 2
    assert bytes =~ "/first:"
    assert bytes =~ "/last:"
    assert_receive {:mixed_request, :"HTTP/1.1", "/first", ""}
    assert_receive {:mixed_request, :"HTTP/1.1", "/last", ""}
    refute_receive {:mixed_request, _, _, _}, 20
    await_empty(server)
  end

  test "a selected H2 parser error closes without invoking H1" do
    {server, ip, port} = server()
    socket = connect(ip, port)
    :ok = :gen_tcp.send(socket, [@preface, Frame.encode(6, 0, 0, "12345678")])
    bytes = all(socket)
    refute bytes =~ "HTTP/1.1"
    refute_receive {:mixed_request, _, _, _}, 20
    await_empty(server)
  end

  test "undecided close and drain reclaim the single connection lease" do
    {server, ip, port} = server()
    first = connect(ip, port)
    :ok = :gen_tcp.send(first, "PRI")
    await_status(server, &match?(%{active: 1, retained_bytes: 3}, &1))
    :ok = :gen_tcp.close(first)
    await_empty(server)

    second = connect(ip, port)
    :ok = :gen_tcp.send(second, "PRI")
    await_status(server, &match?(%{active: 1, retained_bytes: 3}, &1))
    assert :ok = Gaoxy.remove(server, :http, @timeout)
    assert {:error, :closed} = :gen_tcp.recv(second, 0, @timeout)
    assert [] = Gaoxy.services(server)
    refute_receive {:mixed_request, _, _, _}, 20
  end

  test "the first byte starts a fixed detector deadline while an empty connection stays idle" do
    {server, ip, port} =
      server(http_limits: %{header_timeout: 1_000}, h2_limits: %{frame_timeout: 300})

    socket = connect(ip, port)
    await_status(server, &match?(%{active: 1, retained_bytes: 0}, &1))
    {owner, idle} = connection_state(server)
    assert idle.phase == :detecting
    assert idle.first_input == nil
    assert idle.detector_timer == nil
    assert {:error, :timeout} = :gen_tcp.recv(socket, 0, 10)

    :ok = :gen_tcp.send(socket, "P")
    await_status(server, &match?(%{active: 1, retained_bytes: 1}, &1))
    {_socket, first} = :sys.get_state(owner, @timeout)
    assert first.detector_deadline == first.first_input + 300
    :ok = :gen_tcp.send(socket, "RI")
    await_status(server, &match?(%{active: 1, retained_bytes: 3}, &1))
    {_socket, next} = :sys.get_state(owner, @timeout)
    assert next.detector_deadline == first.detector_deadline
    assert next.detector_timer == first.detector_timer
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
    await_empty(server)
    refute_receive {:mixed_request, _, _, _}, 20
  end

  defp server(options \\ []) do
    {:ok, server} =
      Gaoxy.HTTP.start_link(
        endpoint: {Endpoint, self()},
        protocols: [:http2, :http1],
        h2c: :prior_knowledge,
        http_limits: Keyword.get(options, :http_limits, %{}),
        h2_limits: Keyword.get(options, :h2_limits, %{})
      )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {server, ip, port}
  end

  defp connect(ip, port) do
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)
    socket
  end

  defp run_peer(port) do
    python =
      System.get_env("GAOXY_QUIC_PYTHON") ||
        Path.expand("../../../.audit/h2peer/bin/python", __DIR__)

    {output, code} =
      System.cmd(python, [Path.join(__DIR__, "support/mixed_http_peer.py"), to_string(port)],
        stderr_to_stdout: true
      )

    assert code == 0, output

    assert %{
             "status" => "PASS",
             "h1_requests" => 3,
             "h2_streams" => 2,
             "protocols" => ["HTTP/1.1", "HTTP/2"],
             "simultaneous" => true
           } = JSON.decode!(output)
  end

  defp headers(id, path) do
    {block, _} =
      HPAX.encode(
        :never_store,
        [{":method", "GET"}, {":scheme", "http"}, {":authority", "localhost"}, {":path", path}],
        HPAX.new(4_096)
      )

    Frame.encode(1, 5, id, block)
  end

  defp h2_response(socket, body \\ "", decoder \\ HPAX.new(4_096)) do
    {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @timeout)
    payload = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, @timeout), 1)

    case {type, id} do
      {4, 0} ->
        unless Frame.flag?(flags, 1), do: :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        h2_response(socket, body, decoder)

      {1, 1} ->
        {:ok, fields, decoder} = HPAX.decode(payload, decoder)
        assert {":status", "200"} in fields
        assert {"x-native-version", "HTTP/2"} in fields
        if Frame.flag?(flags, 1), do: body, else: h2_response(socket, body, decoder)

      {0, 1} ->
        body = body <> payload
        if Frame.flag?(flags, 1), do: body, else: h2_response(socket, body, decoder)

      other ->
        flunk("unexpected H2 frame #{inspect(other)}")
    end
  end

  defp all(socket, bytes \\ "") do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, more} -> all(socket, bytes <> more)
      {:error, :closed} -> bytes
      other -> flunk("connection did not close: #{inspect(other)}")
    end
  end

  defp await_empty(server, service \\ :http, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)

    case Gaoxy.status(server, service) do
      %{active: 0, retained_bytes: 0, cleanup_pending: 0} ->
        :ok

      _ ->
        assert Gaoxy.Lifecycle.remaining(deadline) > 0

        receive do
        after
          1 -> await_empty(server, service, deadline)
        end
    end
  end

  defp await_status(server, predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)
    status = Gaoxy.status(server, :http)

    unless predicate.(status) do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0

      receive do
      after
        1 -> await_status(server, predicate, deadline)
      end
    end
  end

  defp connection_state(server) do
    instance = :sys.get_state(server, @timeout)
    [{:http, service, _generation}] = :ets.lookup(instance.live, :http)
    %{gate: gate} = :sys.get_state(service, @timeout)
    [{_lease, %{pid: owner}}] = Map.to_list(:sys.get_state(gate, @timeout).leases)
    {_socket, state} = :sys.get_state(owner, @timeout)
    {owner, state}
  end
end
