defmodule Gaoxy.HTTP2IntegrationTest do
  use ExUnit.Case, async: true
  alias Gaoxy.HTTP.Response
  alias Gaoxy.HTTP.HTTP2.Frame
  @timeout 3_000

  defmodule Endpoint do
    def init(options), do: {:ok, options}

    def call(exchange, options) do
      case exchange.request.path do
        "/buffer" ->
          Response.send_resp(exchange, 200, [{"set-cookie", "one=1"}, {"set-cookie", "two=2"}], [
            :binary.copy("a", 16_384),
            [[], [?b], <<>>]
          ])

        "/fixed" ->
          with {:ok, next} <- Response.send_chunked(exchange, 200, [{"content-length", "16384"}]),
               {:ok, next} <- chunk(next, [:binary.copy("a", 16_384), [[], <<>>]]),
               do: Response.finish(next)

        path when path in ["/head", "/204", "/205", "/304"] ->
          {status, headers} =
            case path do
              "/head" -> {200, [{"content-length", "42"}]}
              "/204" -> {204, []}
              "/205" -> {205, []}
              "/304" -> {304, [{"content-length", "123"}]}
            end

          with {:ok, next} <- Response.send_chunked(exchange, status, headers),
               {:ok, next} <- chunk(next, "ignored"),
               do: Response.finish(next)

        "/file" ->
          Response.send_file(exchange, 200, [], options[:file], 7, 16_385)

        "/inform" ->
          with :ok <- Response.inform(exchange, 103, [{"link", "</asset>; rel=preload"}]),
               do: Response.send_resp(exchange, 200, [], "hello")

        "/probe" ->
          result =
            case options[:probe_kind] do
              :headers -> Response.send_resp(exchange, 200, options[:fields], "unsafe")
              :trailers -> Response.send_chunked(exchange, 200, options[:fields])
            end

          send(options[:owner], {:probe_result, result})
          Response.send_resp(exchange, 200, [], "safe")

        _ ->
          Response.send_resp(exchange, 200, [], Keyword.get(options, :label, "local"))
      end
    end

    defp chunk(exchange, data) do
      case Response.chunk(exchange, data) do
        :ok -> {:ok, exchange}
        result -> result
      end
    end
  end

  defmodule ProxyEndpoint do
    def init({url, owner}) do
      with {:ok, config} <- Gaoxy.Proxy.HTTP.init(%{upstream: url, max_lifetime: 4_000}),
           do: {:ok, {config, owner}}
    end

    def call(exchange, {config, owner}) do
      if exchange.request.path == "/local" do
        Response.send_resp(exchange, 200, [], "local")
      else
        send(owner, {:proxy_worker, exchange.request.path, self()})
        Gaoxy.Proxy.HTTP.call(exchange, config)
      end
    end
  end

  for protocol <- [:http1, :http2] do
    @protocol protocol
    @tag :tmp_dir
    test "#{protocol} preserves shared response semantics and exact window-sized iodata", %{
      tmp_dir: dir
    } do
      file = Path.join(dir, "payload")
      File.write!(file, "prefix-" <> :binary.copy("f", 16_385) <> "suffix")
      server = server(@protocol, {Endpoint, [file: file]})

      for {method, path, status, body, length} <- [
            {"GET", "/buffer", 200, :binary.copy("a", 16_384) <> "b", "16385"},
            {"GET", "/fixed", 200, :binary.copy("a", 16_384), "16384"},
            {"HEAD", "/head", 200, "", "42"},
            {"GET", "/204", 204, "", nil},
            {"GET", "/205", 205, "", "0"},
            {"GET", "/304", 304, "", "123"},
            {"GET", "/file", 200, :binary.copy("f", 16_385), "16385"},
            {"GET", "/inform", 200, "hello", "5"}
          ] do
        result = request(server, @protocol, method, path)
        assert result.status == status, path
        assert result.body == body, path

        assert List.keyfind(result.headers, "content-length", 0) ==
                 if(length, do: {"content-length", length}, else: nil),
               path

        if path == "/buffer" do
          assert Enum.filter(result.headers, &(elem(&1, 0) == "set-cookie")) == [
                   {"set-cookie", "one=1"},
                   {"set-cookie", "two=2"}
                 ]
        end

        if path == "/inform",
          do: assert([{103, [{"link", "</asset>; rel=preload"}]}] = result.inform)
      end
    end
  end

  test "H2 rejects application pseudoheaders before committing a response" do
    server =
      server(
        :http2,
        {Endpoint, [owner: self(), probe_kind: :headers, fields: [{":status", "599"}]]}
      )

    socket = connect(server, :http2)
    headers(socket, 1, "GET", "/probe", true)
    assert_receive {:probe_result, {:error, _}}, @timeout
    assert response(socket, 1).body == "safe"
  end

  test "H2 validates prohibited and malformed trailer declarations before committing a response" do
    for declaration <- ["content-length", "connection", "x-one,", "x one"] do
      server =
        server(
          :http2,
          {Endpoint, [owner: self(), probe_kind: :trailers, fields: [{"trailer", declaration}]]}
        )

      socket = connect(server, :http2)
      headers(socket, 1, "GET", "/probe", true)
      assert_receive {:probe_result, {:error, _}}, @timeout
      assert response(socket, 1).body == "safe"
      :gen_tcp.close(socket)
      assert :ok = Gaoxy.stop(server, @timeout)
    end
  end

  test "H2 uploads and ordered duplicate trailers cross the dedicated H1 proxy and clean up" do
    {url, peer} =
      peer(fn socket ->
        head = h1_head(socket)
        assert head =~ "POST /upload?x=%2F HTTP/1.1"
        assert String.downcase(head) =~ "trailer: x-check"
        assert "upload" = h1_chunk(socket)
        assert "0\r\nx-check: one\r\nx-check: two\r\n\r\n" = h1_until(socket, "\r\n\r\n")

        :ok =
          :gen_tcp.send(
            socket,
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nTrailer: x-check\r\n\r\n4\r\nbody\r\n0\r\nx-check: first\r\nx-check: last\r\n\r\n"
          )

        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = server(:http2, {ProxyEndpoint, {url, self()}})
    socket = connect(server, :http2)
    headers(socket, 1, "POST", "/upload?x=%2F", false, [{"trailer", "x-check"}])
    :ok = :gen_tcp.send(socket, Frame.encode(0, 0, 1, "upload"))

    {block, _} =
      HPAX.encode(:never_store, [{"x-check", "one"}, {"x-check", "two"}], HPAX.new(4_096))

    :ok = :gen_tcp.send(socket, Frame.encode(1, 5, 1, block))
    result = response(socket, 1)
    assert result.status == 200
    assert result.body == "body"
    assert result.trailers == [{"x-check", "first"}, {"x-check", "last"}]
    refute List.keymember?(result.headers, "transfer-encoding", 0)
    assert_peer(peer)
    await_status(server, &(&1.cleanup_pending == 0 and &1.active == 2))
  end

  test "an early H1 final response stops H2 upload while another stream remains usable" do
    {url, peer} =
      peer(fn socket ->
        _ = h1_head(socket)
        :ok = :gen_tcp.send(socket, "HTTP/1.1 413 Content Too Large\r\nContent-Length: 0\r\n\r\n")
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = server(:http2, {ProxyEndpoint, {url, self()}})
    socket = connect(server, :http2)
    headers(socket, 1, "POST", "/early", false, [{"content-length", "1000000"}])
    assert response(socket, 1).status == 413
    assert_peer(peer)
    await_status(server, &(&1.cleanup_pending == 0 and &1.active == 2))
    headers(socket, 3, "GET", "/local", true)
    assert response(socket, 3).body == "local"
  end

  test "an ended H2 GET opens no upstream upload stream" do
    {url, peer} =
      peer(fn socket ->
        head = h1_head(socket)
        refute String.downcase(head) =~ "transfer-encoding:"
        :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = server(:http2, {ProxyEndpoint, {url, self()}})
    socket = connect(server, :http2)
    headers(socket, 1, "GET", "/empty", true)
    assert response(socket, 1).body == "ok"
    assert_peer(peer)
    await_status(server, &(&1.cleanup_pending == 0 and &1.active == 2))
  end

  test "reset during an upstream wait cancels its guardian without closing a live sibling" do
    owner = self()

    {url, peer} =
      peer(fn socket ->
        _ = h1_head(socket)
        send(owner, {:upstream_waiting, self()})
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = server(:http2, {ProxyEndpoint, {url, self()}})
    socket = connect(server, :http2)
    headers(socket, 1, "GET", "/wait", true)
    assert_receive {:proxy_worker, "/wait", worker}, @timeout
    assert_receive {:upstream_waiting, ^peer}, @timeout
    assert Gaoxy.status(server, :http).cleanup_pending == 1
    monitor = Process.monitor(worker)
    :ok = :gen_tcp.send(socket, Frame.encode(3, 0, 1, <<8::32>>))
    assert_receive {:DOWN, ^monitor, :process, ^worker, _}, @timeout
    assert_peer(peer)
    await_status(server, &(&1.cleanup_pending == 0 and &1.active == 2))
    headers(socket, 3, "GET", "/local", true)
    assert response(socket, 3).body == "local"
  end

  test "a downstream H2 disconnect closes an idle H1 response and clears every reservation" do
    owner = self()

    {url, peer} =
      peer(fn socket ->
        _ = h1_head(socket)
        :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n")
        send(owner, {:upstream_waiting, self()})
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    server = server(:http2, {ProxyEndpoint, {url, self()}})
    socket = connect(server, :http2)
    headers(socket, 1, "GET", "/events", true)
    assert_receive {:upstream_waiting, ^peer}, @timeout
    await_status(server, &(&1.cleanup_pending == 1))
    :ok = :gen_tcp.close(socket)
    assert_peer(peer)
    await_status(server, &(&1.active == 0 and &1.retained_bytes == 0 and &1.cleanup_pending == 0))
  end

  test "repeated H2 route activation retains an old proxy guardian and a stable connection" do
    owner = self()

    {url, peer} =
      peer(fn socket ->
        assert h1_head(socket) =~ "GET /old HTTP/1.1"
        send(owner, {:old_generation_upstream, self()})

        receive do
          :release -> :ok
        after
          @timeout -> flunk("old generation peer was not released")
        end

        :ok = :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\nold")
        assert {:error, :closed} = :gen_tcp.recv(socket, 0, @timeout)
      end)

    store =
      start_supervised!(
        {Gaoxy.HTTP.Generation, routes: [%{target: {ProxyEndpoint, {url, self()}}}]}
      )

    server = server(:http2, {Gaoxy.HTTP.Generation, store})
    before = Gaoxy.info(server, :http)
    socket = connect(server, :http2)
    headers(socket, 1, "GET", "/old", true)
    assert_receive {:old_generation_upstream, ^peer}, @timeout
    assert Gaoxy.status(server, :http).cleanup_pending == 1

    for iteration <- 1..20 do
      label = "generation-#{iteration}"

      assert {:ok, _} =
               Gaoxy.HTTP.Generation.reload(store, [%{target: {Endpoint, [label: label]}}])

      assert Gaoxy.info(server, :http).local == before.local
      id = 2 * iteration + 1
      headers(socket, id, "GET", "/new", true)
      assert response(socket, id).body == label
      assert Gaoxy.status(server, :http).cleanup_pending == 1
    end

    assert {:ok, generation, router} = Gaoxy.HTTP.Generation.snapshot(store)
    assert {:error, _} = Gaoxy.HTTP.Generation.reload(store, [%{target: {System, []}}])
    assert {:ok, ^generation, ^router} = Gaoxy.HTTP.Generation.snapshot(store)
    send(peer, :release)
    assert response(socket, 1).body == "old"
    assert_peer(peer)
    await_status(server, &(&1.cleanup_pending == 0 and &1.active == 2))
    headers(socket, 43, "GET", "/new", true)
    assert response(socket, 43).body == "generation-20"
  end

  defp server(protocol, endpoint) do
    options = [
      endpoint: endpoint,
      http_limits: %{request_timeout: 5_000, write_timeout: 1_000},
      limits: %{max_bytes: 536_870_912, max_active: 128}
    ]

    options =
      if protocol == :http2,
        do: options ++ [protocols: [:http2], h2c: :prior_knowledge],
        else: options

    {:ok, server} = Gaoxy.HTTP.start_link(options)
    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server, @timeout) end)
    server
  end

  defp connect(server, protocol) do
    {:ok, {ip, port}} = Gaoxy.info(server, :http).local
    {:ok, socket} = :gen_tcp.connect(ip, port, [:binary, active: false], @timeout)
    on_exit(fn -> :gen_tcp.close(socket) end)

    if protocol == :http2,
      do: :gen_tcp.send(socket, ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", Frame.encode(4, 0, 0, "")])

    socket
  end

  defp request(server, protocol, method, path) do
    socket = connect(server, protocol)

    result =
      if protocol == :http2 do
        headers(socket, 1, method, path, true)
        response(socket, 1)
      else
        :ok =
          :gen_tcp.send(
            socket,
            "#{method} #{path} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
          )

        h1_response(socket, [])
      end

    :gen_tcp.close(socket)
    await_status(server, &(&1.active == 0 and &1.retained_bytes == 0))
    result
  end

  defp headers(socket, id, method, path, ended, fields \\ []) do
    {block, _} =
      HPAX.encode(
        :never_store,
        [{":method", method}, {":scheme", "http"}, {":authority", "localhost"}, {":path", path}] ++
          fields,
        HPAX.new(4_096)
      )

    :ok = :gen_tcp.send(socket, Frame.encode(1, if(ended, do: 5, else: 4), id, block))
  end

  defp response(
         socket,
         id,
         result \\ %{status: nil, headers: [], body: "", trailers: [], inform: []},
         block \\ "",
         decoder \\ HPAX.new(4_096)
       ) do
    {type, flags, stream, payload} = recv_frame(socket)

    cond do
      type == 4 and flags == 0 ->
        :ok = :gen_tcp.send(socket, Frame.encode(4, 1, 0, ""))
        response(socket, id, result, block, decoder)

      type in [1, 9] and stream == id ->
        block = block <> payload

        if Bitwise.band(flags, 4) == 0 do
          response(socket, id, result, block, decoder)
        else
          {:ok, fields, decoder} = HPAX.decode(block, decoder)
          status = List.keyfind(fields, ":status", 0)

          result =
            case status do
              {_, value} ->
                code = String.to_integer(value)
                fields = List.keydelete(fields, ":status", 0)

                if code < 200,
                  do: %{result | inform: result.inform ++ [{code, fields}]},
                  else: %{result | status: code, headers: fields}

              nil ->
                %{result | trailers: fields}
            end

          if Bitwise.band(flags, 1) == 1,
            do: result,
            else: response(socket, id, result, "", decoder)
        end

      type == 0 and stream == id ->
        result = %{result | body: result.body <> payload}

        if Bitwise.band(flags, 1) == 1,
          do: result,
          else: response(socket, id, result, block, decoder)

      type == 7 ->
        flunk("unexpected GOAWAY: #{inspect(payload)}")

      type == 3 and stream == id ->
        flunk("unexpected reset: #{inspect(payload)}")

      true ->
        response(socket, id, result, block, decoder)
    end
  end

  defp recv_frame(socket) do
    {:ok, <<size::24, type, flags, _::1, id::31>>} = :gen_tcp.recv(socket, 9, @timeout)
    payload = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, @timeout), 1)
    {type, flags, id, payload}
  end

  defp h1_response(socket, informational) do
    [status | fields] =
      h1_head(socket) |> String.trim_trailing("\r\n\r\n") |> String.split("\r\n")

    [_, code, _] = String.split(status, " ", parts: 3)
    code = String.to_integer(code)

    fields =
      Enum.map(fields, fn field ->
        [name, value] = String.split(field, ":", parts: 2)
        {String.downcase(name), String.trim_leading(value)}
      end)

    if code < 200,
      do: h1_response(socket, informational ++ [{code, fields}]),
      else: %{status: code, headers: fields, body: until_closed(socket), inform: informational}
  end

  defp h1_head(socket), do: h1_until(socket, "\r\n\r\n")

  defp h1_until(socket, delimiter, bytes \\ "") do
    if String.ends_with?(bytes, delimiter),
      do: bytes,
      else:
        (
          {:ok, byte} = :gen_tcp.recv(socket, 1, @timeout)
          h1_until(socket, delimiter, bytes <> byte)
        )
  end

  defp h1_chunk(socket) do
    size = h1_until(socket, "\r\n") |> String.trim_trailing("\r\n") |> String.to_integer(16)
    {:ok, bytes} = :gen_tcp.recv(socket, size + 2, @timeout)
    <<body::binary-size(size), "\r\n">> = bytes
    body
  end

  defp until_closed(socket, body \\ "") do
    case :gen_tcp.recv(socket, 0, @timeout) do
      {:ok, bytes} -> until_closed(socket, body <> bytes)
      {:error, :closed} -> body
    end
  end

  defp peer(fun) do
    {:ok, listener} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_, port}} = :inet.sockname(listener)
    owner = self()

    pid =
      spawn(fn ->
        try do
          {:ok, socket} = :gen_tcp.accept(listener, @timeout)

          try do
            fun.(socket)
            send(owner, {:peer_done, self()})
          after
            :gen_tcp.close(socket)
          end
        rescue
          error ->
            send(owner, {:peer_error, self(), Exception.format(:error, error, __STACKTRACE__)})
        after
          :gen_tcp.close(listener)
        end
      end)

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :kill)
      :gen_tcp.close(listener)
    end)

    {"http://127.0.0.1:#{port}", pid}
  end

  defp assert_peer(pid) do
    receive do
      {:peer_done, ^pid} -> :ok
      {:peer_error, ^pid, error} -> flunk(error)
    after
      @timeout -> flunk("upstream peer did not finish")
    end
  end

  defp await_status(server, predicate, deadline \\ nil) do
    deadline = deadline || Gaoxy.Lifecycle.deadline(@timeout)
    status = Gaoxy.status(server, :http)

    if not predicate.(status) do
      assert Gaoxy.Lifecycle.remaining(deadline) > 0, inspect(status)

      receive do
      after
        1 -> await_status(server, predicate, deadline)
      end
    else
      assert status.cleanup_failed == nil
    end
  end
end
