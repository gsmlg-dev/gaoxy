defmodule Gaoxy.PhoenixAdapterTest do
  use ExUnit.Case, async: true

  defmodule Endpoint do
    def init(opts), do: opts
    def call(conn, _opts), do: Plug.Conn.send_resp(conn, 200, "phoenix")
  end

  test "one Endpoint child owns configured HTTP and HTTPS services" do
    config = [
      otp_app: :gaoxy_http,
      http: [ip: {127, 0, 0, 1}, port: 0],
      https: [ip: {127, 0, 0, 1}, port: 0, certfile: "cert.pem", keyfile: "key.pem"]
    ]

    assert [%{start: {Gaoxy, :start_link, [[name: name, services: services]]}}] =
             Gaoxy.PhoenixAdapter.child_specs(Endpoint, config)

    assert is_atom(name)

    assert Enum.map(services, & &1.id) == [
             Module.concat(Endpoint, HTTP),
             Module.concat(Endpoint, HTTPS)
           ]

    assert Enum.map(services, & &1.transport) == [:tcp, :tls]
    assert {:error, :not_running} = Gaoxy.PhoenixAdapter.server_info(Endpoint, :http)
  end

  test "gateway-owned Endpoint configuration starts no duplicate listener" do
    assert [] =
             Gaoxy.PhoenixAdapter.child_specs(Endpoint,
               otp_app: :gaoxy_http,
               server: false,
               http: [port: 4000]
             )
  end

  test "unknown listener options fail before child creation" do
    assert_raise ArgumentError, fn ->
      Gaoxy.PhoenixAdapter.child_specs(Endpoint,
        otp_app: :gaoxy_http,
        http: [port: 0, unsupported: true]
      )
    end
  end
end
