defmodule Gaoxy.PhoenixAdapterTest do
  use ExUnit.Case, async: true
  @moduletag :unit

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

    assert [%{start: {Gaoxy.HTTP.ListenerSet, :start_link, [options]}}] =
             Gaoxy.PhoenixAdapter.child_specs(Endpoint, config)

    assert is_atom(options[:instance_name])
    assert plan = options[:plan]

    assert plan.service_ids == %{
             http: Module.concat(Endpoint, HTTP),
             https: Module.concat(Endpoint, HTTPS)
           }

    assert Keyword.keys(plan.listeners) == [:http, :https]
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
