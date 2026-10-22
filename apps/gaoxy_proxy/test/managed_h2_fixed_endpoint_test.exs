Code.require_file("support/managed_h2_fixed_fixture.exs", __DIR__)

defmodule Gaoxy.Proxy.ManagedH2FixedEndpointTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Proxy.ManagedH2FixedFixture, as: F
  alias Gaoxy.Proxy.UpstreamTransports, as: Transports
  alias HTTP.HTTP2.HPACK
  @moduletag :capture_log

  for protocol <- [:http2, :h2c], {pad, status} <- [{65_458, 200}, {65_459, 502}] do
    @wire_protocol protocol
    @wire_pad pad
    @wire_status status
    test "http1 -> #{protocol} complete H1 wire #{pad + 78} bytes returns #{status} before committing any excess head" do
      f = F.fixture(@wire_protocol, :http1, ["--manual"])
      socket = F.connect(f)
      :ok = F.send_request(f, socket, "GET", "/hold/wire-head", [{"connection", "close"}])
      seen = F.event(f.peer, "request")

      F.eventually(fn ->
        match?(
          [%{completion: %HTTP.RequestCompletion{}}],
          Map.values(:sys.get_state(f.owner).tokens)
        )
      end)

      [held] = Map.values(:sys.get_state(f.owner).tokens)
      completion = held.completion
      guardian = held.guardian
      monitor = Process.monitor(guardian)
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)

      fields = [
        ["content-length", "0"],
        ["x-pad", :binary.copy("a", @wire_pad)],
        ["x", "b"],
        ["y", "c"]
      ]

      logical =
        Enum.reduce(fields, 0, fn [name, value], acc ->
          acc + byte_size(name) + byte_size(value)
        end)

      assert logical == @wire_pad + 24
      assert logical + 4 * length(fields) + 2 == @wire_pad + 42

      complete_head =
        IO.iodata_to_binary([
          "HTTP/1.1 200 OK\r\nconnection: close\r\n",
          Enum.map(fields, fn [name, value] -> [name, ": ", value, "\r\n"] end),
          "\r\n"
        ])

      assert byte_size(complete_head) == @wire_pad + 78
      F.command(f.peer, seen, "respond", %{"fields" => fields})
      wire = F.until_closed(socket)

      if @wire_status == 200 do
        assert byte_size(wire) == 65_536
        assert wire == complete_head
      else
        # The only committed head is the bounded empty upstream failure. An
        # oversized 200 prefix or second response cannot satisfy this equality.
        assert wire ==
                 "HTTP/1.1 502 Bad Gateway\r\nconnection: close\r\ncontent-length: 0\r\n\r\n"
      end

      assert :ok = HTTP.RequestCompletion.await(completion, 5_000)
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 5_000
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      F.close(f)
    end
  end

  for protocol <- [:http2, :h2c],
      {failure, status, phrase, limits, malformed} <- [
        {:malformed_chunk, 400, "Bad Request", %{}, "Z\r\n"},
        {:body_limit, 413, "Request Entity Too Large", %{max_body_bytes: 4},
         "5\r\nabcde\r\n0\r\n\r\n"},
        {:trailer_count, 431, "Request Header Fields Too Large", %{max_trailers: 1},
         "0\r\nX-Check: first\r\nX-Check: second\r\n\r\n"},
        {:trailer_bytes, 431, "Request Header Fields Too Large", %{max_trailer_bytes: 8},
         "0\r\nX-Check: x\r\n\r\n"}
      ] do
    @local_protocol protocol
    @local_failure failure
    @local_status status
    @local_phrase phrase
    @local_limits limits
    @local_malformed malformed
    @tag :local_request_status
    test "http1 -> #{protocol} native #{failure} preserves #{status} with upstream final head withheld" do
      f = F.fixture(@local_protocol, :http1, ["--manual"], %{http_limits: @local_limits})
      socket = F.connect(f)
      target = "/hold/local-#{@local_failure}"

      :ok =
        F.send_request(
          f,
          socket,
          "POST",
          target,
          [{"transfer-encoding", "chunked"}, {"trailer", "x-check"}],
          false
        )

      seen = F.event(f.peer, "request")
      assert seen["target"] == target
      assert seen["connection"] == 1

      assert Enum.filter(seen["headers"], fn [name, _] -> String.starts_with?(name, ":") end) ==
               [
                 [":method", "POST"],
                 [":scheme", if(@local_protocol == :http2, do: "https", else: "http")],
                 [":authority", "localhost:#{f.ready["port"]}"],
                 [":path", target]
               ]

      refute Enum.any?(seen["headers"], fn [name, _] ->
               name in ["trailer", "transfer-encoding"]
             end)

      F.eventually(fn ->
        match?(
          [%{completion: %HTTP.RequestCompletion{}}],
          Map.values(:sys.get_state(f.owner).tokens)
        )
      end)

      [held] = Map.values(:sys.get_state(f.owner).tokens)
      guardian = held.guardian
      completion = held.completion
      state = :sys.get_state(guardian)
      assert state.client.completion(state.original_request) == completion
      assert state.submitted_url == f.origin <> target
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(completion, 0)
      assert {:ok, %{request_tokens: 1, pins: 3, helpers: 0}} = Transports.status(f.owner)
      assert %{cleanup_pending: 1, retained_bytes: retained} = Gaoxy.status(f.instance, :http)
      assert retained >= 9_444_956
      monitor = Process.monitor(guardian)

      # The real peer's manual mode withholds every final response. These bytes
      # exercise the native parser and public service limits, not a fake error.
      :ok = :gen_tcp.send(socket, @local_malformed)

      assert F.until_closed(socket) ==
               "HTTP/1.1 #{@local_status} #{@local_phrase}\r\nconnection: close\r\ncontent-length: 0\r\n\r\n"

      assert :ok = HTTP.RequestCompletion.await(completion, 5_000)
      assert :ok = HTTP.RequestCompletion.await(completion, 0)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, :normal}, 5_000
      F.no_event(f.peer, "upload")
      F.no_event(f.peer, "upload_end")
      F.no_event(f.peer, "upload_trailers")
      F.no_event(f.peer, "request")
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      F.close(f)
    end
  end

  for downstream <- [:http1, :http2], protocol <- [:http2, :h2c] do
    @downstream downstream
    @protocol protocol
    test "#{downstream} -> #{protocol} exact escaped targets duplicate fields raw gzip manual redirect and sequential reuse" do
      f = F.fixture(@protocol, @downstream)

      for {target, expected} <- [{"/a%2Fb?q=%2F", "/a%2Fb?q=%2F"}, {"/empty?", "/empty?"}] do
        assert %{status: 200, body: ^expected} =
                 F.request(f, "GET", target, [
                   {"x-trace", "first"},
                   {"x-trace", "second"},
                   {"x-forwarded-for", "spoofed"}
                 ])

        seen = F.event(f.peer, "request")
        assert seen["target"] == target
        assert seen["connection"] == 1

        assert Enum.filter(seen["headers"], &(hd(&1) == "x-trace")) == [
                 ["x-trace", "first"],
                 ["x-trace", "second"]
               ]

        assert [":authority", "localhost:#{f.ready["port"]}"] in seen["headers"]
        refute Enum.any?(seen["headers"], &(List.last(&1) == "spoofed"))
      end

      if @protocol == :http2,
        do: assert(%{"alpn" => "h2", "sni" => "localhost"} = F.event(f.peer, "tls"))

      assert %{status: 200, headers: fields, body: compressed} = F.request(f, "GET", "/gzip")
      assert :zlib.gunzip(compressed) == "raw-compression"
      assert {"content-encoding", "gzip"} in fields
      assert {"content-length", Integer.to_string(byte_size(compressed))} in fields
      assert F.event(f.peer, "request")["connection"] == 1
      assert %{status: 302, headers: fields, body: "redirect"} = F.request(f, "GET", "/redirect")
      assert {"location", "http://unfollowed.invalid/never"} in fields
      assert F.event(f.peer, "request")["connection"] == 1
      F.no_event(f.peer, "request")
      F.close(f)
    end

    test "#{downstream} -> #{protocol} streamed bytes response trailers and bodyless framing" do
      f = F.fixture(@protocol, @downstream)
      bytes = "managed-h2-stream:" <> String.duplicate("s", 65_536)
      assert %{status: 200, body: ^bytes} = F.request(f, "GET", "/stream")
      F.event(f.peer, "request")

      assert %{
               status: 200,
               body: "trailers",
               trailers: [{"x-check", "first"}, {"x-check", "second"}],
               headers: fields
             } = F.request(f, "GET", "/trailers")

      assert Enum.filter(fields, &(elem(&1, 0) == "set-cookie")) == [
               {"set-cookie", "one=1"},
               {"set-cookie", "two=2"}
             ]

      F.event(f.peer, "request")

      for code <- [204, 205, 304] do
        assert %{status: ^code, body: ""} = F.request(f, "GET", "/#{code}")
        F.event(f.peer, "request")
      end

      assert %{status: 200, body: "", headers: fields} = F.request(f, "HEAD", "/head")
      assert {"content-length", "5"} in fields
      F.event(f.peer, "request")
      F.close(f)
    end

    test "#{downstream} -> #{protocol} original binding precedes producer bytes and actual PID preserves raw Content-Length" do
      f = F.fixture(@protocol, @downstream)
      socket = F.connect(f)

      :ok =
        F.send_request(
          f,
          socket,
          "POST",
          "/echo?raw=%2F",
          [{"content-length", "6"}, {"x-trace", "first"}],
          false
        )

      :ok = F.send_body(f, socket, "abc", false)
      seen = F.event(f.peer, "request")
      assert ["content-length", "6"] in seen["headers"]
      assert %{"total_bytes" => 3} = F.upload_through(f.peer, seen, "abc")
      F.no_event(f.peer, "upload_end")
      [held] = :sys.get_state(f.owner).tokens |> Map.values()
      state = :sys.get_state(held.guardian)
      assert %HTTP.RequestCompletion{} = held.completion
      assert held.completion == state.client.completion(state.original_request)
      assert state.managed_path == true
      assert state.managed_transport == nil
      assert state.request_options == nil
      assert state.selector == nil
      assert state.awaiting_transport == nil
      assert state.submitted_url == f.origin <> "/echo?raw=%2F"
      assert :binary.referenced_byte_size(state.submitted_url) == byte_size(state.submitted_url)
      assert Enum.sort(Map.keys(state.request)) == [:completion, :promise, :resolved, :stream]
      assert {:error, :cleanup_pending} = HTTP.RequestCompletion.await(held.completion, 0)
      :ok = F.send_body(f, socket, "def", true)
      assert %{"total_bytes" => 6} = F.upload_through(f.peer, seen, "abcdef", 3)
      connection = seen["connection"]
      stream = seen["stream"]

      assert %{"connection" => ^connection, "stream" => ^stream, "total_bytes" => 6} =
               F.event(f.peer, "upload_end")

      assert %{status: 200, body: "abcdef"} = F.response(f, socket)
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      assert :ok = HTTP.RequestCompletion.await(held.completion, 0)
      F.close(f)
    end

    test "#{downstream} -> #{protocol} early final response finishes an incomplete upload without replay" do
      f = F.fixture(@protocol, @downstream)
      socket = F.connect(f)
      :ok = F.send_request(f, socket, "POST", "/early", [{"content-length", "1000000"}], false)
      assert %{status: 413, body: "early-final"} = F.response(f, socket)
      assert %{"target" => "/early"} = F.event(f.peer, "request")
      F.no_event(f.peer, "upload")
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      assert %{status: 200, body: "/healthy"} = F.request(f, "GET", "/healthy")
      assert %{"target" => "/healthy"} = F.event(f.peer, "request")
      F.no_event(f.peer, "request")
      F.close(f)
    end

    test "#{downstream} -> #{protocol} simultaneous requests multiplex one connection and reset preserves healthy sibling" do
      f = F.fixture(@protocol, @downstream, ["--manual"])
      {first, one, guardian, completion} = F.hold(f, "/hold/one")
      second = F.connect(f)
      :ok = F.send_request(f, second, "GET", "/hold/two")
      two = F.event(f.peer, "request")
      assert one["connection"] == two["connection"]
      refute one["stream"] == two["stream"]
      F.command(f.peer, one, "reset")
      assert %{status: 502} = F.response(f, first)
      monitor = Process.monitor(guardian)
      assert :ok = HTTP.RequestCompletion.await(completion, 5_000)
      assert_receive {:DOWN, ^monitor, :process, ^guardian, reason}, 5_000
      assert reason in [:normal, :noproc]

      F.command(f.peer, two, "respond", %{
        "body64" => Base.encode64("healthy"),
        "fields" => [["content-length", "7"]]
      })

      assert %{status: 200, body: "healthy"} = F.response(f, second)
      :ok = :gen_tcp.close(first)
      :ok = :gen_tcp.close(second)
      F.clean(f)
      F.close(f)
    end
  end

  for downstream <- [:http1, :http2], protocol <- [:http2, :h2c] do
    @trailer_downstream downstream
    @trailer_protocol protocol
    test "#{downstream} -> #{protocol} safe duplicate request trailers reach the peer in order" do
      f = F.fixture(@trailer_protocol, @trailer_downstream)
      socket = F.connect(f)

      fields =
        [{"trailer", "x-check"}] ++
          if(@trailer_downstream == :http1, do: [{"transfer-encoding", "chunked"}], else: [])

      :ok = F.send_request(f, socket, "POST", "/echo", fields, false)

      if @trailer_downstream == :http1 do
        :ok = :gen_tcp.send(socket, "4\r\nwire\r\n0\r\nX-Check: first\r\nX-Check: second\r\n\r\n")
      else
        :ok = F.send_body(f, socket, "wire", false)

        {_, block} =
          HPACK.encode_headers(HPACK.new_encoder(), [{"x-check", "first"}, {"x-check", "second"}],
            indexing: :never,
            huffman: :never
          )

        :ok = :gen_tcp.send(socket, Gaoxy.HTTP.HTTP2.Frame.encode(1, 5, 1, block))
      end

      assert %{"target" => "/echo"} = F.event(f.peer, "request")

      assert %{"fields" => [["x-check", "first"], ["x-check", "second"]]} =
               F.event(f.peer, "upload_trailers")

      assert %{"total_bytes" => 4} = F.event(f.peer, "upload_end")
      assert %{status: 200, body: "wire"} = F.response(f, socket)
      :ok = :gen_tcp.close(socket)
      F.clean(f)
      F.close(f)
    end
  end

  test "C2 R32 P0 refuses the33rd simultaneous request without hidden pending Fetch or replay" do
    f = F.fixture(:h2c, :http1, ["--manual"])
    held = for index <- 1..32, do: F.hold(f, "/hold/#{index}")
    assert {:ok, %{request_tokens: 32}} = Transports.status(f.owner)
    assert %{cleanup_pending: 32, retained_bytes: bytes} = Gaoxy.status(f.instance, :http)
    assert bytes >= 302_238_592
    socket = F.connect(f)
    :ok = F.send_request(f, socket, "GET", "/refused33")
    assert %{status: 503} = F.response(f, socket)
    :ok = :gen_tcp.close(socket)
    F.no_event(f.peer, "request")
    assert {:ok, %{request_tokens: 32}} = Transports.status(f.owner)
    assert Enum.all?(held, fn {_, seen, _, _} -> seen["connection"] in [1, 2] end)

    assert held
           |> Enum.map(fn {_, seen, _, _} -> {seen["connection"], seen["stream"]} end)
           |> Enum.uniq()
           |> length() == 32

    for {socket, seen, _, completion} <- held do
      F.command(f.peer, seen, "respond", %{"fields" => [["content-length", "0"]]})
      assert %{status: 200, body: ""} = F.response(f, socket)
      :ok = :gen_tcp.close(socket)
      assert :ok = HTTP.RequestCompletion.await(completion, 5_000)
    end

    F.clean(f)
    F.close(f)
  end

  test "fixed managed H2 initialization is pure and protocol/scheme mismatches dedicated H2 and managed H3 reject" do
    alias Gaoxy.Proxy.HTTP, as: ProxyHTTP
    handle = %{provider: Transports, owner: self(), owner_epoch: make_ref(), resource: make_ref()}

    for {protocol, origin} <- [{:http2, "https://localhost"}, {:h2c, "http://localhost"}] do
      assert {:ok, config} =
               ProxyHTTP.init(%{upstream: origin, upstream_protocol: protocol, transport: handle})

      assert config.client == Gaoxy.Proxy.ManagedH2Client
      assert config.cacertfile == nil
      assert config.connect_address == nil
      assert {:ok, ^config} = ProxyHTTP.init(config)
      assert [^handle] = ProxyHTTP.resources(config)
      assert {:message_queue_len, 0} = Process.info(self(), :message_queue_len)

      for change <- [
            %{cacertfile: "/tmp/trust.pem"},
            %{connect_address: {127, 0, 0, 1}},
            %{max_chunk_bytes: 65_537},
            %{opening_timeout: 86_400_001},
            %{idle_timeout: :infinity},
            %{extra: true}
          ] do
        assert {:error, :invalid_http_proxy_options} =
                 ProxyHTTP.init(
                   Map.merge(
                     %{upstream: origin, upstream_protocol: protocol, transport: handle},
                     change
                   )
                 )
      end
    end

    for options <- [
          %{upstream: "http://localhost", upstream_protocol: :http2, transport: handle},
          %{upstream: "https://localhost", upstream_protocol: :h2c, transport: handle},
          %{upstream: "https://localhost", upstream_protocol: :http2},
          %{upstream: "http://localhost", upstream_protocol: :h2c},
          %{upstream: "https://localhost", upstream_protocol: :http3, transport: handle}
        ] do
      assert {:error, :invalid_http_proxy_options} = ProxyHTTP.init(options)
    end
  end
end
