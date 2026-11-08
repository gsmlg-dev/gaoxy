defmodule GaoxyTestConsumerTest do
  use ExUnit.Case, async: false
  alias HTTP.HTTP2.HPACK

  defmodule DualStackPlug do
    def init(options), do: options
    def call(conn, _), do: Plug.Conn.send_resp(conn, 200, "dual-stack")
  end

  test "published fixture budgets preserve a complete multilingual request and response" do
    payload = String.duplicate("完整技能文档 — fixture budget\n", 12_000)
    assert byte_size(payload) > 368 * 1_024

    fixture =
      Gaoxy.Test.open(
        limits: %{max_bytes: 8 * 1_024 * 1_024},
        http_limits: %{max_body_bytes: 1_024 * 1_024}
      )

    Gaoxy.Test.expect_once(fixture, :post, "/document", fn conn ->
      {body, conn} = complete_body(conn, [])
      assert body == payload
      Plug.Conn.send_resp(conn, 200, body)
    end)

    assert {:ok, {{_, 200, _}, _, ^payload}} =
             :httpc.request(
               :post,
               {String.to_charlist(Gaoxy.Test.url(fixture, "/document")), [],
                ~c"application/octet-stream", payload},
               [timeout: 5_000],
               body_format: :binary
             )

    assert :ok = Gaoxy.Test.verify!(fixture)
    assert [%{outcome: :ok}] = Gaoxy.Test.requests(fixture).entries
    assert %{status: :ok} = Gaoxy.Test.close(fixture)
  end

  test "published HTTPS explicitly supports dual-stack and IPv6-only with optional client certificates" do
    directory = Application.app_dir(:gaoxy_test, "priv/tls")

    tls = %{
      certfile: Path.join(directory, "cert.pem"),
      keyfile: Path.join(directory, "key.pem"),
      cacertfile: Path.join(directory, "ca.pem"),
      verify: :verify_peer,
      fail_if_no_peer_cert: false
    }

    for v6only <- [false, true] do
      assert {:ok, runtime} =
               Gaoxy.HTTP.start_link(
                 ip: {0, 0, 0, 0, 0, 0, 0, 0},
                 port: 0,
                 transport: :tls,
                 tls: tls,
                 protocols: [:http1],
                 hell_options: [transport_options: [ipv6_v6only: v6only]],
                 plug: {DualStackPlug, []}
               )

      try do
        assert %{local: {:ok, {_, port}}} = Gaoxy.info(runtime, :http)

        options = [
          :binary,
          active: false,
          verify: :verify_peer,
          cacertfile: String.to_charlist(tls.cacertfile),
          server_name_indication: ~c"localhost"
        ]

        assert {:ok, socket} =
                 :ssl.connect({0, 0, 0, 0, 0, 0, 0, 1}, port, [:inet6 | options], 2_000)

        assert_tls_response(socket)

        if v6only do
          assert {:error, :econnrefused} =
                   :ssl.connect({127, 0, 0, 1}, port, [:inet | options], 2_000)
        else
          assert {:ok, socket} =
                   :ssl.connect({127, 0, 0, 1}, port, [:inet | options], 2_000)

          assert_tls_response(socket)
        end
      after
        assert :ok = Gaoxy.stop(runtime, 2_000)
      end
    end
  end

  test "public automatic fixtures serve H1 and verified HTTPS from packaged assets" do
    for profile <- [:http1, :https] do
      fixture = Gaoxy.Test.open(profile: profile)

      Gaoxy.Test.expect_once(fixture, :get, "/hello", fn conn ->
        assert conn.query_string == "value=1"
        Plug.Conn.send_resp(conn, 200, "external consumer")
      end)

      info = Gaoxy.Test.info(fixture)
      assert info.profile == profile
      assert info.ready

      tls =
        if profile == :https do
          assert File.regular?(info.tls.cacertfile)

          [
            ssl: [
              verify: :verify_peer,
              cacertfile: String.to_charlist(info.tls.cacertfile),
              customize_hostname_check: [
                match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
              ]
            ]
          ]
        else
          []
        end

      assert {:ok, {{_, 200, _}, _, "external consumer"}} =
               :httpc.request(
                 :get,
                 {String.to_charlist(Gaoxy.Test.url(fixture, "/hello?value=1")), []},
                 [timeout: 3_000] ++ tls,
                 body_format: :binary
               )

      assert :ok = Gaoxy.Test.verify!(fixture)
      assert %{status: :ok} = Gaoxy.Test.close(fixture)
    end
  end

  test "clean ordinary consumer starts shared HTTP dependencies and excludes H3 and production packages" do
    resolved = Enum.map(Mix.Dep.load_and_cache(), & &1.app)
    started = for {app, _, _} <- Application.started_applications(), do: app
    assert :gaoxy_test in resolved
    assert :gaoxy_test in started

    for app <- [:http_core, :ex_ssl, :elixir_quic] do
      assert app in resolved
      assert app in started
      assert File.dir?(:code.lib_dir(app))
      assert File.dir?(Path.join(Mix.Project.deps_path(), Atom.to_string(app)))
    end

    for app <- [
          :gaoxy_http3,
          :elixir_quic_http3,
          :gaoxy_proxy,
          :gaoxy_server,
          :http_fetch,
          :hpax,
          :http_web_socket
        ] do
      refute app in resolved
      refute app in started
      assert {:error, :bad_name} = :code.lib_dir(app)
      refute File.exists?(Path.join(Mix.Project.deps_path(), Atom.to_string(app)))
    end

    refute Code.ensure_loaded?(Gaoxy.HTTP.HTTP3)
    fixture_children = DynamicSupervisor.which_children(Gaoxy.Test.Supervisor)
    resources = fixture_resources()

    assert_raise Gaoxy.Test.SetupError, ~r/http3|HTTP.3|H3/, fn ->
      Gaoxy.Test.open(profile: :http3)
    end

    assert DynamicSupervisor.which_children(Gaoxy.Test.Supervisor) == fixture_children
    assert fixture_resources() == resources
  end

  test "ordinary consumer serves actual h2c using the public callback and HPACK peer" do
    fixture = Gaoxy.Test.open(profile: :h2c)

    Gaoxy.Test.expect_once(fixture, :get, "/h2", fn conn ->
      assert Plug.Conn.get_http_protocol(conn) == :"HTTP/2"
      Plug.Conn.send_resp(conn, 200, "external h2")
    end)

    uri = URI.parse(Gaoxy.Test.url(fixture))
    {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", uri.port, [:binary, active: false], 2_000)
    on_exit(fn -> :gen_tcp.close(socket) end)

    {_, block} =
      HPACK.encode_headers(
        HPACK.set_max_dynamic_size(HPACK.new_encoder(), 0),
        [{":method", "GET"}, {":scheme", "http"}, {":authority", "localhost"}, {":path", "/h2"}],
        indexing: :never,
        huffman: :never
      )

    :ok =
      :gen_tcp.send(socket, [
        "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n",
        frame(4, 0, 0, ""),
        frame(1, 5, 1, IO.iodata_to_binary(block))
      ])

    assert {"200", "external h2"} =
             receive_h2(socket, HPACK.new_decoder(max_dynamic_size: 4_096), nil, "")

    # END_STREAM can reach the peer before the callback records its completion.
    assert :ok = Gaoxy.Test.verify!(fixture)
    :gen_tcp.close(socket)
  end

  defp receive_h2(socket, decoder, status, body) do
    assert {:ok, <<size::24, type, flags, _::1, stream::31>>} = :gen_tcp.recv(socket, 9, 2_000)
    payload = if size == 0, do: "", else: elem(:gen_tcp.recv(socket, size, 2_000), 1)

    case {type, stream} do
      {4, 0} ->
        if Bitwise.band(flags, 1) == 0, do: :gen_tcp.send(socket, frame(4, 1, 0, ""))
        receive_h2(socket, decoder, status, body)

      {1, 1} ->
        assert {:ok, decoder, fields} = HPACK.decode(decoder, payload)
        status = fields |> List.keyfind(":status", 0) |> elem(1)

        if Bitwise.band(flags, 1) == 1,
          do: {status, body},
          else: receive_h2(socket, decoder, status, body)

      {0, 1} ->
        body = body <> payload

        if Bitwise.band(flags, 1) == 1,
          do: {status, body},
          else: receive_h2(socket, decoder, status, body)

      _ ->
        receive_h2(socket, decoder, status, body)
    end
  end

  defp frame(type, flags, stream, payload),
    do: <<byte_size(payload)::24, type, flags, 0::1, stream::31, payload::binary>>

  defp complete_body(conn, chunks) do
    case Plug.Conn.read_body(conn) do
      {:more, body, conn} -> complete_body(conn, [body | chunks])
      {:ok, body, conn} -> {IO.iodata_to_binary(Enum.reverse([body | chunks])), conn}
    end
  end

  defp assert_tls_response(socket) do
    try do
      assert :ok =
               :ssl.send(socket, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")

      response = tls_response(socket, "", System.monotonic_time(:millisecond) + 2_000)
      assert response =~ "HTTP/1.1 200"
      assert String.ends_with?(response, "dual-stack")
    after
      :ssl.close(socket)
    end
  end

  defp tls_response(socket, bytes, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)
    assert remaining > 0

    case :ssl.recv(socket, 0, remaining) do
      {:ok, chunk} -> tls_response(socket, bytes <> chunk, deadline)
      {:error, :closed} -> bytes
      error -> flunk("TLS response failed: #{inspect(error)}")
    end
  end

  defp fixture_resources do
    Enum.sort(
      for pid <- Process.list(),
          {:dictionary, dictionary} <- [Process.info(pid, :dictionary)],
          {module, :init, 1} <- [Keyword.get(dictionary, :"$initial_call")],
          module in [Gaoxy.Test.Instance, Gaoxy.Test.Server, Gaoxy.Instance],
          do: pid
    )
  end
end
