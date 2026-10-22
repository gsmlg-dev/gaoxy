defmodule Gaoxy.Test.ProtocolTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Test.{Response, SSE, Server}
  @timeout 15_000

  @peer ~S"""
  import asyncio, http.client, socket, ssl, sys, time
  profile, port, ca = sys.argv[1], int(sys.argv[2]), sys.argv[3]
  body = b"fixture upload " * 2000
  expected = {"/echo": body, "/fast": b"fast", "/stream": b"onetwo",
              "/events": b"event: update\nid: 7\ndata: first\ndata: second\n\ndata: last\n\n",
              "/hold": b"released"}
  def context(alpn):
      ctx = ssl.create_default_context(cafile=ca)
      ctx.set_alpn_protocols(alpn)
      return ctx
  def done():
      print("PASS independent " + profile, flush=True)
  if profile in ("http1", "https"):
      if profile == "https":
          for hostname in ("localhost", "127.0.0.1"):
              with socket.create_connection(("127.0.0.1", port), timeout=5) as raw:
                  with context(["http/1.1"]).wrap_socket(raw, server_hostname=hostname) as tls:
                      assert tls.selected_alpn_protocol() == "http/1.1"
      for path in ("/echo", "/fast", "/stream", "/events"):
          conn = (http.client.HTTPSConnection("127.0.0.1", port, context=context(["http/1.1"]), timeout=5)
                  if profile == "https" else http.client.HTTPConnection("127.0.0.1", port, timeout=5))
          try:
              conn.request("POST" if path == "/echo" else "GET", path,
                           body=body if path == "/echo" else None)
              response = conn.getresponse()
              assert response.version == 11 and response.status == 200
              assert response.read() == expected[path], path
          finally:
              conn.close()
      done()
  elif profile in ("h2c", "http2", "count-h2c", "count-http2"):
      import h2.config, h2.connection, h2.events
      counting = profile.startswith("count-")
      secure = profile.endswith("http2")
      wire = socket.create_connection(("127.0.0.1", port), timeout=5)
      if secure:
          wire = context(["h2"]).wrap_socket(wire, server_hostname="localhost")
          assert wire.selected_alpn_protocol() == "h2"
      wire.settimeout(5)
      conn = h2.connection.H2Connection(config=h2.config.H2Configuration(client_side=True, header_encoding="utf-8"))
      conn.initiate_connection()
      paths = ["/once", "/once"] if counting else ["/hold", "/fast", "/echo", "/stream", "/events"]
      results = {}
      for index, path in enumerate(paths):
          sid = index * 2 + 1
          conn.send_headers(sid, [(":method", "POST" if path == "/echo" else "GET"),
              (":scheme", "https" if secure else "http"), (":authority", "localhost"), (":path", path)],
              end_stream=path != "/echo")
          if path == "/echo":
              for offset in range(0, len(body), 16000):
                  conn.send_data(sid, body[offset:offset + 16000], end_stream=offset + 16000 >= len(body))
          results[sid] = {"body": b"", "status": None, "ended": False, "path": path}
      wire.sendall(conn.data_to_send())
      deadline = time.monotonic() + 12
      fast = False
      while not all(value["ended"] for value in results.values()):
          assert time.monotonic() < deadline, results
          packet = wire.recv(65536)
          assert packet, "early H2 EOF"
          for event in conn.receive_data(packet):
              assert not isinstance(event, (h2.events.StreamReset, h2.events.ConnectionTerminated)), event
              sid = getattr(event, "stream_id", None)
              if sid not in results:
                  continue
              if isinstance(event, h2.events.ResponseReceived):
                  results[sid]["status"] = dict(event.headers)[":status"]
              elif isinstance(event, h2.events.DataReceived):
                  results[sid]["body"] += event.data
                  conn.acknowledge_received_data(event.flow_controlled_length, sid)
              elif isinstance(event, h2.events.StreamEnded):
                  results[sid]["ended"] = True
          if not counting and results[3]["ended"] and not fast:
              assert not results[1]["ended"], "held stream ended before its barrier"
              print("FAST_READY", flush=True)
              fast = True
          pending = conn.data_to_send()
          if pending:
              wire.sendall(pending)
      if counting:
          assert sorted(value["status"] for value in results.values()) == ["200", "500"], results
          assert sum(value["body"] == b"once" for value in results.values()) == 1
      else:
          assert fast
          for value in results.values():
              assert value["status"] == "200" and value["body"] == expected[value["path"]], value
      conn.close_connection()
      wire.sendall(conn.data_to_send())
      wire.close()
      done()
  else:
      from aioquic.asyncio import connect
      from aioquic.asyncio.protocol import QuicConnectionProtocol
      from aioquic.h3.connection import H3Connection
      from aioquic.h3.events import DataReceived, HeadersReceived
      from aioquic.quic.configuration import QuicConfiguration
      from aioquic.quic.events import ProtocolNegotiated, StreamReset, ConnectionTerminated
      class Peer(QuicConnectionProtocol):
          def __init__(self, *args, **kwargs):
              super().__init__(*args, **kwargs)
              self.http = H3Connection(self._quic)
              self.results, self.changed, self.alpn = {}, asyncio.Event(), None
          def quic_event_received(self, event):
              if isinstance(event, ProtocolNegotiated):
                  self.alpn = event.alpn_protocol
              if isinstance(event, StreamReset):
                  raise AssertionError(event)
              if isinstance(event, ConnectionTerminated) and not all(value["ended"] for value in self.results.values()):
                  raise AssertionError(event)
              for current in self.http.handle_event(event):
                  if isinstance(current, (HeadersReceived, DataReceived)):
                      result = self.results[current.stream_id]
                      if isinstance(current, HeadersReceived):
                          result["status"] = dict(current.headers)[b":status"]
                      else:
                          result["body"] += current.data
                      result["ended"] = current.stream_ended
              self.changed.set()
          def request(self, path):
              sid = self._quic.get_next_available_stream_id()
              self.results[sid] = {"path": path, "status": None, "body": b"", "ended": False}
              self.http.send_headers(sid, [(b":method", b"POST" if path == "/echo" else b"GET"),
                  (b":scheme", b"https"), (b":authority", b"localhost"), (b":path", path.encode())],
                  end_stream=path != "/echo")
              if path == "/echo":
                  self.http.send_data(sid, body, end_stream=True)
              self.transmit()
              return sid
          async def until(self, predicate):
              async with asyncio.timeout(12):
                  while not predicate():
                      self.changed.clear()
                      await self.changed.wait()
      async def run():
          config = QuicConfiguration(is_client=True, alpn_protocols=["h3"], idle_timeout=15)
          config.server_name = "localhost"
          config.load_verify_locations(ca)
          async with connect("127.0.0.1", port, configuration=config, create_protocol=Peer) as peer:
              assert peer.alpn == "h3"
              held = peer.request("/hold")
              fast = peer.request("/fast")
              for path in ("/echo", "/stream", "/events"):
                  peer.request(path)
              await peer.until(lambda: peer.results[fast]["ended"])
              assert not peer.results[held]["ended"]
              print("FAST_READY", flush=True)
              await peer.until(lambda: all(value["ended"] for value in peer.results.values()))
              for value in peer.results.values():
                  assert value["status"] == b"200" and value["body"] == expected[value["path"]], value
              await asyncio.wait_for(peer.ping(), 5)
      asyncio.run(run())
      done()
  """

  for profile <- [:http1, :https, :h2c, :http2, :http3] do
    @profile profile
    @tag timeout: 25_000
    test "#{profile}: trusted independent requests, bodies, finite streams and SSE" do
      fixture = Gaoxy.Test.open(mode: :manual, profile: @profile, timeout: 3_000)
      info = Gaoxy.Test.info(fixture)
      on_exit(fn -> close_if_alive(fixture) end)
      assert info.ready and info.profile == @profile
      assert info.capabilities.streaming and info.capabilities.sse
      assert info.capabilities.websocket == websocket_profile?(@profile)
      assert URI.parse(Gaoxy.Test.url(fixture)).port > 0
      owner = self()

      Gaoxy.Test.expect_once(fixture, :post, "/echo", fn conn ->
        assert Plug.Conn.get_http_protocol(conn) == protocol(@profile)
        {body, conn} = read_body(conn)
        Response.send(conn, 200, body)
      end)

      Gaoxy.Test.expect_once(fixture, :get, "/fast", &Response.send(&1, 200, "fast"))
      Gaoxy.Test.expect_once(fixture, :get, "/stream", &Response.stream(&1, 200, ["one", "two"]))

      Gaoxy.Test.expect_once(fixture, :get, "/events", fn conn ->
        SSE.stream(conn, [%{event: "update", id: "7", data: "first\nsecond"}, "last"])
      end)

      if multiplexed_profile?(@profile) do
        Gaoxy.Test.expect_once(fixture, :get, "/hold", fn conn ->
          send(owner, {:protocol_held, self()})

          receive do
            :release -> Response.send(conn, 200, "released")
          after
            12_000 -> raise "protocol isolation barrier expired"
          end
        end)
      end

      peer = peer(info, Atom.to_string(@profile))

      output =
        if multiplexed_profile?(@profile) do
          assert_receive {:protocol_held, held}, @timeout
          output = await_output(peer, "FAST_READY", "", deadline())
          send(held, :release)
          output
        else
          ""
        end

      assert await_exit(peer, output, deadline()) =~ "PASS independent #{@profile}"
      assert :ok = Gaoxy.Test.verify!(fixture)
      entries = Gaoxy.Test.requests(fixture).entries
      assert Enum.all?(entries, &(&1.protocol == protocol(@profile)))
      fixture_id = info.fixture_id
      stream_id = Enum.find(entries, &(&1.path == "/stream")).id

      assert_receive {:gaoxy_test_event, ^fixture_id, ^stream_id,
                      %{type: :stream_headers, status: 200}}

      assert_receive {:gaoxy_test_event, ^fixture_id, ^stream_id, %{type: :stream_complete}}

      sse = Enum.find(entries, &(&1.path == "/events"))
      assert Enum.count(sse.events, &(&1.type == :sse_event)) == 2
      assert %{status: :ok} = Gaoxy.Test.close(fixture)
      assert_unavailable(info)
    end

    @tag timeout: 15_000
    test "#{profile}: abrupt coordinator death closes the listener and accepted sockets" do
      fixture = Gaoxy.Test.open(mode: :manual, profile: @profile, timeout: 1_000)
      info = Gaoxy.Test.info(fixture)
      monitor = Process.monitor(fixture.pid)

      if @profile != :http3 do
        [%{ip: ip, port: port}] = info.endpoints
        {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], 1_000)
        Process.exit(fixture.pid, :kill)
        assert_receive {:DOWN, ^monitor, :process, _, :killed}, 2_000
        {reason, bytes} = drain_socket(socket, "", System.monotonic_time(:millisecond) + 5_000)
        assert reason in [:closed, :econnreset]
        assert bytes == "" or (tls_profile?(@profile) and tls_alerts?(bytes))
        :gen_tcp.close(socket)
      else
        Process.exit(fixture.pid, :kill)
        assert_receive {:DOWN, ^monitor, :process, _, :killed}, 2_000
      end

      await_unavailable(info, System.monotonic_time(:millisecond) + 7_000)
      assert_raise Gaoxy.Test.UnavailableError, fn -> Gaoxy.Test.verify!(fixture) end
    end
  end

  for profile <- [:h2c, :http2] do
    @profile profile
    test "#{profile}: competing exact-once streams execute only one callback" do
      fixture = Gaoxy.Test.open(mode: :manual, profile: @profile, timeout: 3_000)
      info = Gaoxy.Test.info(fixture)
      on_exit(fn -> close_if_alive(fixture) end)
      owner = self()

      Gaoxy.Test.expect_once(fixture, :get, "/once", fn conn ->
        send(owner, :protocol_once)
        Response.send(conn, 200, "once")
      end)

      peer = peer(info, "count-#{@profile}")
      assert await_exit(peer, "", deadline()) =~ "PASS independent count-#{@profile}"
      assert_receive :protocol_once
      refute_received :protocol_once
      assert %{status: :error, failures: failures} = Gaoxy.Test.close(fixture)
      assert Enum.any?(failures, &(&1.type == :excessive))
      assert_unavailable(info)
    end
  end

  test "unsupported profiles fail before creating a server process" do
    assert {:error, {:unsupported_profile, :invalid}} =
             Server.start_link(self(), profile: :invalid, fixture_id: make_ref())
  end

  defp peer(info, mode) do
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
          @peer,
          mode,
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

  defp read_body(conn, body \\ "") do
    case Plug.Conn.read_body(conn) do
      {:ok, bytes, conn} -> {body <> bytes, conn}
      {:more, bytes, conn} -> read_body(conn, body <> bytes)
    end
  end

  defp protocol(profile) when profile in [:http1, :https], do: :"HTTP/1.1"
  defp protocol(profile) when profile in [:h2c, :http2], do: :"HTTP/2"
  defp protocol(:http3), do: :"HTTP/3"
  defp websocket_profile?(profile), do: profile in [:http1, :https]
  defp multiplexed_profile?(profile), do: profile in [:h2c, :http2, :http3]
  defp tls_profile?(profile), do: profile in [:https, :http2]
  defp deadline, do: System.monotonic_time(:millisecond) + @timeout

  defp drain_socket(socket, bytes, deadline) do
    case :gen_tcp.recv(socket, 0, max(deadline - System.monotonic_time(:millisecond), 0)) do
      {:ok, packet} -> drain_socket(socket, bytes <> packet, deadline)
      {:error, reason} -> {reason, bytes}
    end
  end

  defp tls_alerts?(""), do: true

  defp tls_alerts?(<<21, 3, _minor, length::16, _alert::binary-size(length), rest::binary>>),
    do: tls_alerts?(rest)

  defp tls_alerts?(_), do: false

  defp assert_unavailable(info), do: assert(listener_unavailable?(info))

  defp await_unavailable(info, deadline) do
    if not listener_unavailable?(info) do
      assert System.monotonic_time(:millisecond) < deadline, "listener survived coordinator death"

      receive do
      after
        10 -> await_unavailable(info, deadline)
      end
    end
  end

  defp listener_unavailable?(%{profile: :http3, endpoints: [%{ip: ip, port: port}]}) do
    case :gen_udp.open(port, [:binary, ip: ip, active: false]) do
      {:ok, socket} ->
        :gen_udp.close(socket)
        true

      {:error, :eaddrinuse} ->
        false

      error ->
        flunk("UDP cleanup probe: #{inspect(error)}")
    end
  end

  defp listener_unavailable?(%{endpoints: [%{ip: ip, port: port}]}) do
    case :gen_tcp.connect(ip, port, [:binary, active: false], 200) do
      {:error, :econnrefused} ->
        true

      {:error, :econnreset} ->
        false

      {:ok, socket} ->
        :gen_tcp.close(socket)
        false

      error ->
        flunk("TCP cleanup probe: #{inspect(error)}")
    end
  end

  defp close_if_alive(fixture) do
    if Process.alive?(fixture.pid), do: Gaoxy.Test.close(fixture)
  end
end
