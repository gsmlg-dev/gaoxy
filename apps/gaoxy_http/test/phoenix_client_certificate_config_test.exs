defmodule Gaoxy.PhoenixClientCertificateConfigTest do
  use ExUnit.Case, async: true

  defmodule Endpoint do
    def init(options), do: options
    def call(conn, _), do: Plug.Conn.send_resp(conn, 200, "ok")
  end

  test "Phoenix HTTPS forwards verified optional client-certificate options to the service" do
    assert [%{start: {Gaoxy.HTTP.ListenerSet, :start_link, [options]}}] =
             Gaoxy.PhoenixAdapter.child_specs(Endpoint,
               https: [
                 port: 0,
                 certfile: "cert.pem",
                 keyfile: "key.pem",
                 verify: :verify_peer,
                 cacertfile: "ca.pem",
                 fail_if_no_peer_cert: false,
                 versions: [:"tlsv1.3", :"tlsv1.2"]
               ]
             )

    assert {:ok, [%{tls: tls}]} = Gaoxy.HTTP.ListenerSet.planned_services(options[:plan])
    assert tls.verify == :verify_peer
    assert tls.cacertfile == "ca.pem"
    assert tls.fail_if_no_peer_cert == false
    assert tls.versions == [:"tlsv1.3", :"tlsv1.2"]
  end

  test "Phoenix HTTPS fails invalid peer-verification combinations before binding" do
    assert_raise ArgumentError, ~r/invalid_tls_verification/, fn ->
      [%{start: {Gaoxy.HTTP.ListenerSet, :start_link, [options]}}] =
        Gaoxy.PhoenixAdapter.child_specs(Endpoint,
          https: [port: 0, certfile: "cert.pem", keyfile: "key.pem", verify: :verify_peer]
        )

      case Gaoxy.HTTP.ListenerSet.preflight(options[:plan]) do
        {:error, reason} -> raise ArgumentError, inspect(reason)
      end
    end
  end
end
