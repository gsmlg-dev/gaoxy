defmodule GaoxyTestH3ConsumerTest do
  use ExUnit.Case, async: false

  @tag timeout: 40_000
  test "explicit optional package serves trusted H3 request and upload from packaged sources" do
    fixture = Gaoxy.Test.open(profile: :http3)

    Gaoxy.Test.expect_once(fixture, :get, "/", fn conn ->
      assert to_string(Plug.Conn.get_http_protocol(conn)) == "HTTP/3"
      Plug.Conn.send_resp(conn, 200, "consumer")
    end)

    Gaoxy.Test.expect_once(fixture, :post, "/echo", fn conn ->
      assert to_string(Plug.Conn.get_http_protocol(conn)) == "HTTP/3"
      {body, conn} = read_body(conn, "")
      Plug.Conn.send_resp(conn, 200, body)
    end)

    info = Gaoxy.Test.info(fixture)
    uri = URI.parse(Gaoxy.Test.url(fixture))
    assert uri.scheme == "https"

    {output, exit} =
      System.cmd(
        System.fetch_env!("GAOXY_QUIC_PYTHON"),
        [Path.expand("peer.py"), "--port", to_string(uri.port), "--ca", info.tls.cacertfile],
        stderr_to_stdout: true
      )

    assert exit == 0, output
    assert output =~ "H3_CONSUMER_PASS cases=2 verified_ca=true protocol=h3"
    assert :ok = Gaoxy.Test.verify!(fixture)
    assert %{status: :ok} = Gaoxy.Test.close(fixture)
    assert {:ok, socket} = :gen_udp.open(uri.port, [:binary, ip: {127, 0, 0, 1}])
    :gen_udp.close(socket)
  end

  test "explicit H3 consumer excludes proxy and client packages" do
    resolved = Enum.map(Mix.Dep.load_and_cache(), & &1.app)
    assert :gaoxy_http3 in resolved
    assert :elixir_quic_http3 in resolved

    for app <- [:gaoxy_proxy, :gaoxy_server, :http_fetch, :http_web_socket, :bandit] do
      refute app in resolved
      assert {:error, :bad_name} = :code.lib_dir(app)
    end
  end

  defp read_body(conn, acc) do
    case Plug.Conn.read_body(conn, length: 1_048_576, read_length: 4_096) do
      {:ok, bytes, conn} -> {acc <> bytes, conn}
      {:more, bytes, conn} -> read_body(conn, acc <> bytes)
    end
  end
end
