defmodule Gaoxy.ClientCertificateConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  defmodule Echo do
    def init(_, _), do: {:ok, nil}
    def handle_data(bytes, state), do: {:send, bytes, state}
  end

  defp service(tls) do
    Gaoxy.Config.service(%{
      id: :client_cert,
      transport: :tls,
      handler: Echo,
      tls: Map.merge(%{certfile: "cert.pem", keyfile: "key.pem"}, tls)
    })
  end

  test "peer verification accepts optional and mandatory certificate presence" do
    for required <- [false, true] do
      assert {:ok, %{tls: tls}} =
               service(%{
                 verify: :verify_peer,
                 cacertfile: "ca.pem",
                 fail_if_no_peer_cert: required
               })

      assert tls.verify == :verify_peer
      assert tls.cacertfile == "ca.pem"
      assert tls.fail_if_no_peer_cert == required
    end

    assert {:ok, _} = service(%{verify: :verify_peer, cacertfile: "ca.pem"})
    assert Gaoxy.capabilities().mtls == :supported
  end

  test "invalid verification options never silently disable verification" do
    for options <- [
          %{verify: :invalid},
          %{verify: :verify_peer},
          %{verify: :verify_peer, cacertfile: ""},
          %{verify: :verify_peer, cacertfile: []},
          %{verify: :verify_peer, cacertfile: "ca.pem", fail_if_no_peer_cert: :yes},
          %{cacertfile: "ca.pem"},
          %{fail_if_no_peer_cert: true},
          %{fail_if_no_peer_cert: false},
          %{verify: :verify_none, cacertfile: "ca.pem"}
        ] do
      assert {:error, :invalid_tls_verification} = service(options)
    end
  end

  test "existing server-only TLS remains supported" do
    assert {:ok, _} = service(%{})
    assert {:ok, _} = service(%{verify: :verify_none})
  end

  test "requesting the mTLS capability requires a peer-verifying TLS service" do
    specification = %{
      id: :client_cert,
      transport: :tls,
      handler: Echo,
      capabilities: [:mtls],
      tls: %{
        certfile: "cert.pem",
        keyfile: "key.pem",
        verify: :verify_peer,
        cacertfile: "ca.pem"
      }
    }

    assert {:ok, _} = Gaoxy.Config.service(specification)

    assert {:error, {:unsupported_capability, :mtls}} =
             Gaoxy.Config.service(%{
               specification
               | tls: Map.drop(specification.tls, [:verify, :cacertfile])
             })
  end
end
