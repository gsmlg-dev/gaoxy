defmodule Gaoxy.Test.HelperTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Test.{Response, SSE, WebSocket}
  @timeout 15_000

  @sse_peer ~S"""
  import asyncio, http.client, socket, ssl, sys, time
  profile, port, ca = sys.argv[1], int(sys.argv[2]), sys.argv[3]
  initial, later = b"data: initial\n\n", b"data: later\n\n"
  def observe(body, flags):
      if initial in body and "initial" not in flags:
          flags.add("initial")
          print("SSE_READY", flush=True)
      if later in body and "later" not in flags:
          flags.add("later")
          print("SSE_NEXT", flush=True)
  if profile in ("http1", "https"):
      context = ssl.create_default_context(cafile=ca) if profile == "https" else None
      conn = (http.client.HTTPSConnection("127.0.0.1", port, context=context, timeout=12)
              if context else http.client.HTTPConnection("127.0.0.1", port, timeout=12))
      try:
          conn.request("GET", "/persistent")
          response = conn.getresponse()
          assert response.status == 200 and response.getheader("content-type").startswith("text/event-stream")
          body, flags = b"", set()
          while True:
              data = response.read(1)
              if not data:
                  break
              body += data
              observe(body, flags)
          assert flags == {"initial", "later"}, body
      finally:
          conn.close()
  elif profile in ("h2c", "http2"):
      import h2.config, h2.connection, h2.events
      wire = socket.create_connection(("127.0.0.1", port), timeout=12)
      if profile == "http2":
          context = ssl.create_default_context(cafile=ca)
          context.set_alpn_protocols(["h2"])
          wire = context.wrap_socket(wire, server_hostname="localhost")
          assert wire.selected_alpn_protocol() == "h2"
      conn = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=True))
      conn.initiate_connection()
      conn.send_headers(1, [(b":method", b"GET"), (b":scheme", b"https" if profile == "http2" else b"http"),
          (b":authority", b"localhost"), (b":path", b"/persistent")], end_stream=True)
      wire.sendall(conn.data_to_send())
      body, flags, ended, headers = b"", set(), False, False
      deadline = time.monotonic() + 12
      while not ended:
          assert time.monotonic() < deadline
          packet = wire.recv(65536)
          if not packet:
              assert flags == {"initial", "later"}, body
              break
          for event in conn.receive_data(packet):
              if isinstance(event, h2.events.ResponseReceived):
                  assert dict(event.headers)[b":status"] == b"200"
                  headers = True
              elif isinstance(event, h2.events.DataReceived):
                  body += event.data
                  conn.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                  observe(body, flags)
              elif isinstance(event, (h2.events.StreamEnded, h2.events.ConnectionTerminated)):
                  ended = True
              elif isinstance(event, h2.events.StreamReset):
                  raise AssertionError(event)
          pending = conn.data_to_send()
          if pending:
              wire.sendall(pending)
      assert headers and flags == {"initial", "later"}, body
      wire.close()
  else:
      from aioquic.asyncio import connect
      from aioquic.asyncio.protocol import QuicConnectionProtocol
      from aioquic.h3.connection import H3Connection
      from aioquic.h3.events import DataReceived, HeadersReceived
      from aioquic.quic.configuration import QuicConfiguration
      from aioquic.quic.events import ProtocolNegotiated, ConnectionTerminated, StreamReset
      class Peer(QuicConnectionProtocol):
          def __init__(self, *args, **kwargs):
              super().__init__(*args, **kwargs)
              self.http = H3Connection(self._quic)
              self.body, self.flags, self.ended, self.headers = b"", set(), asyncio.Event(), False
              self.alpn = None
          def quic_event_received(self, event):
              if isinstance(event, ProtocolNegotiated):
                  self.alpn = event.alpn_protocol
              elif isinstance(event, ConnectionTerminated):
                  self.ended.set()
              elif isinstance(event, StreamReset):
                  raise AssertionError(event)
              for current in self.http.handle_event(event):
                  if isinstance(current, HeadersReceived):
                      assert dict(current.headers)[b":status"] == b"200"
                      self.headers = True
                  elif isinstance(current, DataReceived):
                      self.body += current.data
                      observe(self.body, self.flags)
                  if isinstance(current, (HeadersReceived, DataReceived)) and current.stream_ended:
                      self.ended.set()
      async def run():
          config = QuicConfiguration(is_client=True, alpn_protocols=["h3"], idle_timeout=12)
          config.server_name = "localhost"
          config.load_verify_locations(ca)
          async with connect("127.0.0.1", port, configuration=config, create_protocol=Peer) as peer:
              assert peer.alpn == "h3"
              peer.http.send_headers(0, [(b":method", b"GET"), (b":scheme", b"https"),
                  (b":authority", b"localhost"), (b":path", b"/persistent")], end_stream=True)
              peer.transmit()
              await asyncio.wait_for(peer.ended.wait(), 12)
              assert peer.headers and peer.flags == {"initial", "later"}, peer.body
      asyncio.run(run())
  print("PASS persistent " + profile, flush=True)
  """

  for profile <- [:http1, :https, :h2c, :http2, :http3] do
    @profile profile
    @tag timeout: 25_000
    test "#{profile}: persistent SSE establishes, sends and cancels through observed barriers" do
      fixture = Gaoxy.Test.open(mode: :manual, profile: @profile, timeout: 4_000)
      on_exit(fn -> close_if_alive(fixture) end)
      info = Gaoxy.Test.info(fixture)
      fixture_id = info.fixture_id

      Gaoxy.Test.expect_once(fixture, :get, "/persistent", fn conn ->
        SSE.open(conn, ["initial"], timeout: 15_000)
      end)

      peer = peer(info)

      assert_receive {:gaoxy_test_event, ^fixture_id, request_id,
                      %{type: :sse_established, session: session}},
                     @timeout

      output = await_output(peer, "SSE_READY", "", deadline())
      assert :ok = Gaoxy.Test.verify!(fixture)
      assert :ok = SSE.send_event(session, "later")
      output = await_output(peer, "SSE_NEXT", output, deadline())

      assert_receive {:gaoxy_test_event, ^fixture_id, ^request_id,
                      %{type: :sse_event, event: "later"}},
                     @timeout

      assert %{status: :ok} = Gaoxy.Test.close(fixture)

      assert_receive {:gaoxy_test_event, ^fixture_id, ^request_id,
                      %{type: :session_cancelled, reason: :fixture_close}},
                     @timeout

      assert await_exit(peer, output, deadline()) =~ "PASS persistent #{@profile}"
      assert_unavailable(info)
    end
  end

  test "helper failure before SSE establishment remains a callback failure" do
    fixture = Gaoxy.Test.open(mode: :manual)
    on_exit(fn -> close_if_alive(fixture) end)

    Gaoxy.Test.expect_once(fixture, :get, "/invalid", fn conn ->
      SSE.open(conn, [%{data: "value", id: "invalid\nfield"}])
    end)

    socket = request(fixture, "/invalid")
    _wire = receive_all(socket, "")
    assert_raise ArgumentError, ~r/SSE id/, fn -> Gaoxy.Test.verify!(fixture) end
    assert %{status: :error, failures: [%{type: :callback}]} = Gaoxy.Test.close(fixture)
    refute Enum.any?(events(fixture), &(&1.type == :sse_established))
  end

  test "persistent SSE total timeout is a failure even after establishment" do
    fixture = Gaoxy.Test.open(mode: :manual)
    on_exit(fn -> close_if_alive(fixture) end)
    Gaoxy.Test.expect_once(fixture, :get, "/timeout", &SSE.open(&1, ["ready"], timeout: 100))
    socket = request(fixture, "/timeout")
    assert receive_all(socket, "") =~ "data: ready"
    assert_raise RuntimeError, ~r/exceeded its timeout/, fn -> Gaoxy.Test.verify!(fixture) end
    assert %{status: :error} = Gaoxy.Test.close(fixture)
  end

  test "queued SSE events and finish cannot bypass the absolute session deadline" do
    fixture = Gaoxy.Test.open(mode: :manual)
    on_exit(fn -> close_if_alive(fixture) end)
    fixture_id = Gaoxy.Test.info(fixture).fixture_id
    Gaoxy.Test.expect_once(fixture, :get, "/deadline", &SSE.open(&1, [], timeout: 200))
    socket = request(fixture, "/deadline")

    assert_receive {:gaoxy_test_event, ^fixture_id, _,
                    %{type: :sse_established, session: session}},
                   1_000

    true = :erlang.suspend_process(session)

    try do
      SSE.send_event(session, "expired")
      SSE.finish(session)
      token = make_ref()
      Process.send_after(self(), token, 250)
      assert_receive ^token, 1_000
    after
      :erlang.resume_process(session)
    end

    refute receive_all(socket, "") =~ "data: expired"
    assert_raise RuntimeError, ~r/exceeded its timeout/, fn -> Gaoxy.Test.verify!(fixture) end
    assert %{status: :error} = Gaoxy.Test.close(fixture)
  end

  test "SSE can finish normally through an event-driven request-process handle" do
    fixture = Gaoxy.Test.open(mode: :manual)
    on_exit(fn -> close_if_alive(fixture) end)
    fixture_id = Gaoxy.Test.info(fixture).fixture_id
    Gaoxy.Test.expect_once(fixture, :get, "/finish", &SSE.open(&1, ["ready"]))
    socket = request(fixture, "/finish")

    assert_receive {:gaoxy_test_event, ^fixture_id, request_id,
                    %{type: :sse_established, session: session}},
                   @timeout

    assert :ok = SSE.finish(session)
    assert receive_all(socket, "") =~ "data: ready"

    assert_receive {:gaoxy_test_event, ^fixture_id, ^request_id, %{type: :stream_complete}},
                   @timeout

    assert :ok = Gaoxy.Test.verify_and_close!(fixture)
  end

  test "H1 WebSocket echoes, pushes, observes and controls close after a real handshake" do
    fixture = Gaoxy.Test.open(mode: :manual)
    on_exit(fn -> close_if_alive(fixture) end)
    info = Gaoxy.Test.info(fixture)
    fixture_id = info.fixture_id
    Gaoxy.Test.expect_once(fixture, :get, "/socket", &WebSocket.upgrade/1)
    socket = websocket(fixture)

    assert_receive {:gaoxy_test_event, ^fixture_id, request_id,
                    %{type: :websocket_established, session: session}},
                   @timeout

    assert :ok = :gen_tcp.send(socket, masked(1, "hello"))
    assert frame(socket) == {1, "hello"}

    assert_receive {:gaoxy_test_event, ^fixture_id, ^request_id,
                    %{type: :websocket_received, opcode: :text, payload: "hello"}},
                   @timeout

    assert :ok = WebSocket.send(session, :binary, "push")
    assert frame(socket) == {2, "push"}
    assert :ok = WebSocket.close(session, 1000, "bye")
    assert frame(socket) == {8, <<1000::16, "bye">>}
    assert :ok = :gen_tcp.send(socket, masked(8, <<1000::16>>))
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 3_000)

    assert_receive {:gaoxy_test_event, ^fixture_id, ^request_id,
                    %{type: :websocket_closed, reason: :normal}},
                   @timeout

    assert :ok = Gaoxy.Test.verify_and_close!(fixture)
    assert_unavailable(info)
  end

  test "established WebSocket cancels at finalization and closes accepted socket" do
    fixture = Gaoxy.Test.open(mode: :manual, timeout: 3_000)
    on_exit(fn -> close_if_alive(fixture) end)
    info = Gaoxy.Test.info(fixture)
    fixture_id = info.fixture_id
    Gaoxy.Test.expect_once(fixture, :get, "/socket", &WebSocket.upgrade(&1, echo: false))
    socket = websocket(fixture)

    assert_receive {:gaoxy_test_event, ^fixture_id, request_id, %{type: :websocket_established}},
                   @timeout

    closer = Task.async(fn -> Gaoxy.Test.close(fixture) end)
    assert frame(socket) == {8, <<1001::16, "fixture closed">>}
    assert :ok = :gen_tcp.send(socket, masked(8, <<1001::16>>))
    assert %{status: :ok} = Task.await(closer, 5_000)

    assert_receive {:gaoxy_test_event, ^fixture_id, ^request_id,
                    %{type: :session_cancelled, reason: :fixture_close}},
                   @timeout

    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 3_000)
    assert_unavailable(info)
  end

  test "WebSocket lifetime expiry cannot pass when its termination callback is skipped" do
    fixture = Gaoxy.Test.open(mode: :manual)
    on_exit(fn -> close_if_alive(fixture) end)
    fixture_id = Gaoxy.Test.info(fixture).fixture_id
    Gaoxy.Test.expect_once(fixture, :get, "/socket", &WebSocket.upgrade(&1, max_lifetime: 200))
    socket = websocket(fixture)

    assert_receive {:gaoxy_test_event, ^fixture_id, _,
                    %{type: :websocket_established, session: session}},
                   1_000

    monitor = Process.monitor(session)
    assert_receive {:DOWN, ^monitor, :process, ^session, _}, 2_000
    _wire = receive_all(socket, "")
    await_session_cleanup(fixture, deadline())

    assert_raise Gaoxy.Test.VerificationError, fn -> Gaoxy.Test.verify!(fixture) end

    assert %{status: :error, failures: [%{type: :session_terminated}]} =
             Gaoxy.Test.close(fixture)
  end

  test "WebSocket bare TCP EOF remains a session failure" do
    fixture = Gaoxy.Test.open(mode: :manual)
    on_exit(fn -> close_if_alive(fixture) end)
    fixture_id = Gaoxy.Test.info(fixture).fixture_id
    Gaoxy.Test.expect_once(fixture, :get, "/socket", &WebSocket.upgrade/1)
    socket = websocket(fixture)

    assert_receive {:gaoxy_test_event, ^fixture_id, _,
                    %{type: :websocket_established, session: session}},
                   1_000

    monitor = Process.monitor(session)
    :ok = :gen_tcp.close(socket)
    assert_receive {:DOWN, ^monitor, :process, ^session, _}, 2_000
    await_session_cleanup(fixture, deadline())
    assert catch_exit(Gaoxy.Test.verify!(fixture)) == :remote

    assert %{status: :error, failures: [%{type: :callback, reason: :remote}]} =
             Gaoxy.Test.close(fixture)
  end

  test "WebSocket peer close frame is distinguished from bare EOF" do
    fixture = Gaoxy.Test.open(mode: :manual)
    on_exit(fn -> close_if_alive(fixture) end)
    Gaoxy.Test.expect_once(fixture, :get, "/socket", &WebSocket.upgrade/1)
    socket = websocket(fixture)
    :ok = :gen_tcp.send(socket, masked(8, <<1000::16>>))
    assert frame(socket) == {8, <<1000::16>>}
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 3_000)
    assert :ok = Gaoxy.Test.verify_and_close!(fixture)
  end

  test "failed WebSocket handshake cannot acquire persistent-session exemption" do
    fixture = Gaoxy.Test.open(mode: :manual)
    on_exit(fn -> close_if_alive(fixture) end)
    Gaoxy.Test.expect_once(fixture, :get, "/invalid", &WebSocket.upgrade/1)
    socket = request(fixture, "/invalid")
    assert receive_all(socket, "") =~ "500"
    assert %{status: :error} = Gaoxy.Test.close(fixture)
    refute Enum.any?(events(fixture), &(&1.type == :websocket_established))
  end

  test "redirect helper sends location and status through the public Plug adapter" do
    fixture = Gaoxy.Test.open(mode: :manual)
    on_exit(fn -> close_if_alive(fixture) end)
    Gaoxy.Test.expect_once(fixture, :get, "/redirect", &Response.redirect(&1, "/target", 307))
    response = fixture |> request("/redirect") |> receive_all("")
    assert response =~ "HTTP/1.1 307"
    assert response =~ "location: /target\r\n"
    assert :ok = Gaoxy.Test.verify_and_close!(fixture)
  end

  defp peer(info) do
    root = Path.expand("../../..", __DIR__)
    python = System.get_env("GAOXY_QUIC_PYTHON") || Path.join(root, ".audit/h2peer/bin/python")
    assert File.regular?(python), "independent peer Python is unavailable: #{python}"
    [%{port: port}] = info.endpoints

    port =
      Port.open({:spawn_executable, String.to_charlist(python)}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: [
          "-u",
          "-c",
          @sse_peer,
          Atom.to_string(info.profile),
          to_string(port),
          if(info.tls, do: info.tls.cacertfile, else: "-")
        ]
      ])

    on_exit(fn ->
      try do
        Port.close(port)
      rescue
        ArgumentError -> :ok
      end
    end)

    port
  end

  defp request(fixture, path) do
    [%{ip: ip, port: port}] = Gaoxy.Test.info(fixture).endpoints
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 2_000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "GET #{path} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
      )

    socket
  end

  defp websocket(fixture) do
    [%{ip: ip, port: port}] = Gaoxy.Test.info(fixture).endpoints
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 2_000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    :ok =
      :gen_tcp.send(
        socket,
        "GET /socket HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
      )

    headers = receive_headers(socket, "", System.monotonic_time(:millisecond) + 3_000)
    assert headers =~ "HTTP/1.1 101"
    assert String.downcase(headers) =~ "sec-websocket-accept: s3pplmbitxaq9kygzzhzrbk+xoo="
    socket
  end

  defp receive_headers(socket, bytes, deadline) do
    if String.ends_with?(bytes, "\r\n\r\n") do
      bytes
    else
      assert {:ok, packet} =
               :gen_tcp.recv(socket, 0, max(deadline - System.monotonic_time(:millisecond), 0))

      receive_headers(socket, bytes <> packet, deadline)
    end
  end

  defp masked(opcode, payload) do
    mask = <<1, 2, 3, 4>>

    encoded =
      payload
      |> :binary.bin_to_list()
      |> Enum.with_index()
      |> Enum.map(fn {byte, index} -> Bitwise.bxor(byte, :binary.at(mask, rem(index, 4))) end)
      |> :binary.list_to_bin()

    <<Bitwise.bor(0x80, opcode), Bitwise.bor(0x80, byte_size(payload)), mask::binary,
      encoded::binary>>
  end

  defp frame(socket) do
    assert {:ok, <<first, size>>} = :gen_tcp.recv(socket, 2, 3_000)
    assert size < 126
    assert {:ok, payload} = :gen_tcp.recv(socket, size, 3_000)
    {Bitwise.band(first, 0x0F), payload}
  end

  defp receive_all(socket, body) do
    case :gen_tcp.recv(socket, 0, 4_000) do
      {:ok, bytes} -> receive_all(socket, body <> bytes)
      {:error, :closed} -> body
      {:error, :econnreset} -> body
      other -> flunk("response read failed: #{inspect(other)}")
    end
  end

  defp events(fixture), do: Enum.flat_map(Gaoxy.Test.requests(fixture).entries, & &1.events)
  defp deadline, do: System.monotonic_time(:millisecond) + @timeout

  defp await_session_cleanup(fixture, deadline) do
    if map_size(:sys.get_state(fixture.pid).sessions) > 0 do
      assert System.monotonic_time(:millisecond) < deadline
      await_session_cleanup(fixture, deadline)
    end
  end

  defp await_output(port, marker, output, deadline) do
    if String.contains?(output, marker) do
      output
    else
      receive do
        {^port, {:data, data}} ->
          await_output(port, marker, output <> data, deadline)

        {^port, {:exit_status, status}} ->
          flunk("peer exited #{status} before barrier:\n#{output}")
      after
        max(0, deadline - System.monotonic_time(:millisecond)) ->
          flunk("peer barrier timeout:\n#{output}")
      end
    end
  end

  defp await_exit(port, output, deadline) do
    receive do
      {^port, {:data, data}} ->
        await_exit(port, output <> data, deadline)

      {^port, {:exit_status, status}} ->
        assert status == 0, output
        output
    after
      max(0, deadline - System.monotonic_time(:millisecond)) -> flunk("peer timeout:\n#{output}")
    end
  end

  defp assert_unavailable(%{profile: :http3, endpoints: [%{ip: ip, port: port}]}) do
    assert {:ok, socket} = :gen_udp.open(port, [:binary, ip: ip, active: false])
    :gen_udp.close(socket)
  end

  defp assert_unavailable(%{endpoints: [%{ip: ip, port: port}]}) do
    assert {:error, :econnrefused} = :gen_tcp.connect(ip, port, [:binary, active: false], 200)
  end

  defp close_if_alive(fixture) do
    if Process.alive?(fixture.pid), do: Gaoxy.Test.close(fixture)
  end
end
