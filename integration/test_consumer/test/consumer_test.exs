defmodule GaoxyTestConsumerTest do
  use ExUnit.Case, async: false
  alias HTTP.HTTP2.HPACK

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
