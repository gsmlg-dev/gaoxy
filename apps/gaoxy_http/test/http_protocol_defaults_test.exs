defmodule Gaoxy.HTTP.ProtocolDefaultsTest do
  use ExUnit.Case, async: true

  defmodule Endpoint do
    def init(options), do: {:ok, options}
    def call(exchange, _options), do: Gaoxy.HTTP.Response.send_resp(exchange, 200, [], "default")
  end

  defmodule FixturePlug do
    def init(options), do: options
    def call(conn, _options), do: Plug.Conn.send_resp(conn, 200, "default")
  end

  @tls %{certfile: "cert.pem", keyfile: "key.pem"}

  test "HTTPS prefers H2 and supplies its omitted byte budget" do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []}, transport: :tls, tls: @tls)

    assert spec.handler_options.protocols == [:http2, :http1]
    assert spec.tls.alpn == ["h2", "http/1.1"]
    assert spec.limits.max_bytes == 268_435_456
    assert spec.handler_options.h2c == :disabled
  end

  test "plain HTTP keeps H1 and the core byte budget" do
    assert {:ok, spec} = Gaoxy.HTTP.service_spec(endpoint: {Endpoint, []})
    assert spec.handler_options.protocols == [:http1]
    assert spec.limits.max_bytes == 1_048_576
  end

  test "explicit H1 HTTPS retains its protocol and budget" do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               transport: :tls,
               tls: @tls,
               protocols: [:http1]
             )

    assert spec.handler_options.protocols == [:http1]
    assert spec.tls.alpn == ["http/1.1"]
    assert spec.limits.max_bytes == 1_048_576
  end

  test "explicit prior knowledge h2c gets an omitted H2 budget" do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               protocols: [:http2],
               h2c: :prior_knowledge
             )

    assert spec.handler_options.protocols == [:http2]
    assert spec.handler_options.h2c == :prior_knowledge
    assert spec.limits.max_bytes == 268_435_456
  end

  test "H2 defaults preserve supplied limit fields and insufficient-budget rejection" do
    assert {:ok, spec} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               transport: :tls,
               tls: @tls,
               limits: %{max_active: 7, max_bytes: 536_870_912}
             )

    assert spec.limits.max_active == 7
    assert spec.limits.max_bytes == 536_870_912

    assert {:error, :http2_byte_budget} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               transport: :tls,
               tls: @tls,
               limits: %{max_bytes: 1_048_576}
             )

    assert {:error, :http2_byte_budget} =
             Gaoxy.HTTP.service_spec(
               endpoint: {Endpoint, []},
               transport: :tls,
               tls: @tls,
               limits: %{max_active: 2}
             )
  end

  test "Phoenix delegates omitted HTTPS protocols while plain HTTP keeps H1" do
    assert [%{start: {Gaoxy, :start_link, [[name: _, services: [http, https]]]}}] =
             Gaoxy.PhoenixAdapter.child_specs(FixturePlug,
               http: [port: 0],
               https: [port: 0, certfile: "cert.pem", keyfile: "key.pem"]
             )

    assert http.handler_options.protocols == [:http1]
    assert https.handler_options.protocols == [:http2, :http1]
    assert https.tls.alpn == ["h2", "http/1.1"]
    assert https.limits.max_bytes == 268_435_456
  end

  @tag :tmp_dir
  test "default HTTPS negotiates H2 and serves a request", %{tmp_dir: dir} do
    {server, port} = tls_server(dir, [])
    socket = tls_client(dir, port, alpn_advertised_protocols: ["h2", "http/1.1"])
    assert {:ok, "h2"} = :ssl.negotiated_protocol(socket)

    {head, _} =
      HPAX.encode(
        :never_store,
        [{":method", "GET"}, {":scheme", "https"}, {":authority", "localhost"}, {":path", "/"}],
        HPAX.new(0)
      )

    :ok =
      :ssl.send(
        socket,
        ["PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n", h2_frame(4, 0, 0, ""), h2_frame(1, 5, 1, head)]
      )

    assert {"200", "default"} = h2_response(socket, nil, "", 12)
    :ok = :ssl.close(socket)
    assert :ok = Gaoxy.stop(server)
  end

  @tag :tmp_dir
  test "default HTTPS retains H1 negotiation, no-ALPN fallback and explicit H1", %{tmp_dir: dir} do
    for {server_options, client_options, negotiated} <- [
          {[], [alpn_advertised_protocols: ["http/1.1"]], {:ok, "http/1.1"}},
          {[], [], {:error, :protocol_not_negotiated}},
          {[protocols: [:http1]], [alpn_advertised_protocols: ["h2", "http/1.1"]],
           {:ok, "http/1.1"}}
        ] do
      {server, port} = tls_server(dir, server_options)
      socket = tls_client(dir, port, client_options)
      assert :ssl.negotiated_protocol(socket) == negotiated
      :ok = :ssl.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
      response = h1_response(socket, "")
      assert response =~ "HTTP/1.1 200 OK\r\n"
      assert String.ends_with?(response, "default")
      :ok = :ssl.close(socket)
      assert :ok = Gaoxy.stop(server)
    end
  end

  defp tls_server(dir, options) do
    unless File.exists?(Path.join(dir, "cert.pem")) do
      root = Path.expand("../../..", __DIR__)

      assert {_, 0} =
               System.cmd("bash", [Path.join(root, "scripts/generate-fixtures.sh"), dir],
                 stderr_to_stdout: true
               )
    end

    assert {:ok, server} =
             Gaoxy.HTTP.start_link(
               [
                 endpoint: {Endpoint, []},
                 transport: :tls,
                 tls: %{certfile: Path.join(dir, "cert.pem"), keyfile: Path.join(dir, "key.pem")}
               ] ++ options
             )

    on_exit(fn -> if Process.alive?(server), do: Gaoxy.stop(server) end)
    assert {:ok, {_, port}} = Gaoxy.info(server, :http).local
    {server, port}
  end

  defp tls_client(dir, port, options) do
    assert {:ok, socket} =
             :ssl.connect(
               ~c"localhost",
               port,
               [
                 :binary,
                 active: false,
                 verify: :verify_peer,
                 cacertfile: String.to_charlist(Path.join(dir, "ca.pem")),
                 server_name_indication: ~c"localhost"
               ] ++ options,
               2_000
             )

    on_exit(fn -> :ssl.close(socket) end)
    socket
  end

  defp h1_response(socket, bytes) do
    case :ssl.recv(socket, 0, 2_000) do
      {:ok, more} -> h1_response(socket, bytes <> more)
      {:error, :closed} -> bytes
      other -> flunk("unexpected H1 response: #{inspect(other)}")
    end
  end

  defp h2_frame(type, flags, id, bytes),
    do: [<<IO.iodata_length(bytes)::24, type, flags, 0::1, id::31>>, bytes]

  defp h2_response(_socket, _status, _body, 0), do: flunk("H2 response did not finish")

  defp h2_response(socket, status, body, left) do
    assert {:ok, <<size::24, type, flags, _::1, id::31>>} = :ssl.recv(socket, 9, 2_000)
    payload = if size == 0, do: "", else: elem(:ssl.recv(socket, size, 2_000), 1)

    {status, body} =
      case {type, id} do
        {1, 1} ->
          assert {:ok, fields, _} = HPAX.decode(payload, HPAX.new(0))
          {List.keyfind(fields, ":status", 0) |> elem(1), body}

        {0, 1} ->
          {status, body <> payload}

        _ ->
          {status, body}
      end

    if id == 1 and type in [0, 1] and Bitwise.band(flags, 1) == 1,
      do: {status, body},
      else: h2_response(socket, status, body, left - 1)
  end
end
