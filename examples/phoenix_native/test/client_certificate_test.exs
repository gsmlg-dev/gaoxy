defmodule PhoenixNative.ClientCertificateTest do
  use ExUnit.Case, async: false

  defmodule Socket do
    use Phoenix.Socket

    def connect(_params, socket, %{peer_data: peer_data}) do
      send(
        Application.fetch_env!(:phoenix_native, :client_certificate_observer),
        {:websocket_peer, peer_data.ssl_cert}
      )

      {:ok, socket}
    end

    def id(_socket), do: nil
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix_native
    socket("/identity", Socket, websocket: [connect_info: [:peer_data]], longpoll: false)
    plug(:identity)

    defp identity(conn, _options) do
      certificate = Plug.Conn.get_peer_data(conn).ssl_cert
      body = if certificate, do: Base.encode64(certificate), else: "anonymous"
      Plug.Conn.send_resp(conn, 200, body)
    end
  end

  setup do
    directory =
      Path.join(System.tmp_dir!(), "gaoxy-client-cert-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(directory) end)
    root = Path.expand("../../..", __DIR__)

    assert {_, 0} =
             System.cmd(
               "bash",
               [Path.join(root, "scripts/generate-client-cert-fixtures.sh"), directory],
               stderr_to_stdout: true
             )

    Application.put_env(:phoenix_native, :client_certificate_observer, self())

    on_exit(fn ->
      Application.delete_env(:phoenix_native, :client_certificate_observer)
      Application.delete_env(:phoenix_native, Endpoint)
    end)

    [{:Certificate, certificate, :not_encrypted}] =
      directory |> Path.join("client.pem") |> File.read!() |> :public_key.pem_decode()

    {:ok, directory: directory, certificate: certificate}
  end

  for version <- [:"tlsv1.2", :"tlsv1.3"] do
    @version version
    test "#{version} optional verified certificates reach Phoenix HTTP and WebSocket peer data",
         ctx do
      port = start_endpoint(ctx.directory, @version, false)
      trusted = connect!(port, ctx.directory, @version, :trusted)
      anonymous = connect!(port, ctx.directory, @version, :anonymous)
      assert http(trusted) == Base.encode64(ctx.certificate)
      assert http(anonymous) == "anonymous"
      assert_rejected(port, ctx.directory, @version, :untrusted)

      trusted_websocket = connect!(port, ctx.directory, @version, :trusted)
      assert upgrade(trusted_websocket) =~ "101 Switching Protocols"
      assert_receive {:websocket_peer, certificate}, 2_000
      assert certificate == ctx.certificate
      :ssl.close(trusted_websocket)

      anonymous_websocket = connect!(port, ctx.directory, @version, :anonymous)
      assert upgrade(anonymous_websocket) =~ "101 Switching Protocols"
      assert_receive {:websocket_peer, nil}, 2_000
      :ssl.close(anonymous_websocket)
    end

    test "#{version} required client certificates reject anonymous clients", ctx do
      port = start_endpoint(ctx.directory, @version, true)
      assert_rejected(port, ctx.directory, @version, :anonymous)

      assert http(connect!(port, ctx.directory, @version, :trusted)) ==
               Base.encode64(ctx.certificate)
    end
  end

  defp start_endpoint(directory, version, required) do
    Application.put_env(:phoenix_native, Endpoint,
      adapter: Gaoxy.PhoenixAdapter,
      server: true,
      https: [
        ip: {127, 0, 0, 1},
        port: 0,
        protocols: [:http1],
        certfile: Path.join(directory, "server.pem"),
        keyfile: Path.join(directory, "server-key.pem"),
        verify: :verify_peer,
        cacertfile: Path.join(directory, "ca.pem"),
        fail_if_no_peer_cert: required,
        versions: [version]
      ],
      url: [host: "localhost"],
      websocket_paths: ["/identity/websocket"],
      secret_key_base: String.duplicate("test-client-cert", 8),
      pubsub_server: PhoenixNative.PubSub,
      check_origin: false,
      code_reloader: false,
      debug_errors: false
    )

    start_supervised!(Endpoint)
    {:ok, {{127, 0, 0, 1}, port}} = Endpoint.server_info(:https)
    port
  end

  defp client_options(directory, version, kind) do
    credentials =
      case kind do
        :anonymous ->
          []

        kind ->
          prefix = if kind == :trusted, do: "client", else: "wrong-client"

          [
            certfile: Path.join(directory, prefix <> ".pem"),
            keyfile: Path.join(directory, prefix <> "-key.pem")
          ]
      end

    [
      :binary,
      active: false,
      verify: :verify_peer,
      cacertfile: Path.join(directory, "ca.pem"),
      server_name_indication: ~c"localhost",
      versions: [version]
    ] ++ credentials
  end

  defp connect!(port, directory, version, kind) do
    assert {:ok, socket} =
             :ssl.connect({127, 0, 0, 1}, port, client_options(directory, version, kind), 2_000)

    on_exit(fn -> :ssl.close(socket) end)
    socket
  end

  defp assert_rejected(port, directory, version, kind) do
    case :ssl.connect({127, 0, 0, 1}, port, client_options(directory, version, kind), 2_000) do
      {:error, {:tls_alert, _}} ->
        :ok

      {:ok, socket} ->
        on_exit(fn -> :ssl.close(socket) end)
        :ssl.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
        assert {:error, reason} = :ssl.recv(socket, 0, 2_000)
        assert reason == :closed or match?({:tls_alert, _}, reason)
    end
  end

  defp http(socket) do
    :ok =
      :ssl.send(socket, [
        "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n",
        forged_headers(),
        "\r\n"
      ])

    response = receive_all(socket, "")
    [head, body] = String.split(response, "\r\n\r\n", parts: 2)
    assert head =~ "HTTP/1.1 200"
    body
  end

  defp upgrade(socket) do
    :ok =
      :ssl.send(socket, [
        "GET /identity/websocket?vsn=2.0.0 HTTP/1.1\r\nHost: localhost\r\n",
        "Connection: Upgrade\r\nUpgrade: websocket\r\nSec-WebSocket-Version: 13\r\n",
        "Sec-WebSocket-Key: AAAAAAAAAAAAAAAAAAAAAA==\r\n",
        forged_headers(),
        "\r\n"
      ])

    receive_headers(socket, "")
  end

  defp forged_headers do
    "X-SSL-Client-Cert: forged\r\nX-Forwarded-Client-Cert: forged\r\nSSL-Client-Cert: forged\r\n"
  end

  defp receive_headers(socket, bytes) do
    if String.contains?(bytes, "\r\n\r\n") do
      bytes
    else
      assert {:ok, more} = :ssl.recv(socket, 0, 2_000)
      receive_headers(socket, bytes <> more)
    end
  end

  defp receive_all(socket, bytes) do
    case :ssl.recv(socket, 0, 2_000) do
      {:ok, more} -> receive_all(socket, bytes <> more)
      {:error, :closed} -> bytes
      other -> flunk("TLS response failed: #{inspect(other)}")
    end
  end
end
