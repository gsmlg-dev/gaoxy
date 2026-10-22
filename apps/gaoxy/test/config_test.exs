defmodule Gaoxy.ConfigTest do
  use ExUnit.Case, async: true
  @moduletag :unit

  defmodule Stream do
    def init(_, _), do: {:ok, ""}
    def handle_data(data, state), do: {:send, data, state}
  end

  def service(extra \\ %{}), do: Map.merge(%{id: "echo", transport: :tcp, handler: Stream}, extra)

  test "pure validation returns a finite immutable plan" do
    assert {:ok, %{services: [%{id: "echo", port: 0, limits: %{max_active: 64}}]}} =
             Gaoxy.Config.validate(services: [service()])
  end

  test "unknown options, duplicate identities and conflicting socket ownership fail" do
    assert {:error, {:unknown_options, [:typo]}} = Gaoxy.Config.validate(typo: true)

    assert {:error, {:duplicate_service, "echo"}} =
             Gaoxy.Config.validate(services: [service(), service()])

    assert {:error, {:binding_conflict, "other", "echo"}} =
             Gaoxy.Config.validate(
               services: [service(%{port: 4000}), service(%{id: "other", port: 4000})]
             )

    assert {:error, _} =
             Gaoxy.Config.validate(services: [service(%{limits: %{max_active: :infinity}})])
  end

  test "explicit unsupported providers and capabilities never fall back" do
    assert {:error, {:unsupported_capability, :ex_ssl}} =
             Gaoxy.Config.validate(
               services: [service(%{transport: :tls, tls: %{provider: :ex_ssl}})]
             )

    # Optional engines may be installed by another umbrella application.
    if Code.ensure_loaded?(Quic) do
      assert {:error, :invalid_alpn} =
               Gaoxy.Config.validate(services: [service(%{transport: :quic})])
    else
      assert {:error, {:unsupported_capability, :quic}} =
               Gaoxy.Config.validate(services: [service(%{transport: :quic})])
    end

    assert {:error, {:unsupported_capability, :http3}} =
             Gaoxy.Config.validate(services: [service(%{capabilities: [:http3]})])
  end

  test "IPv6 broadcast and scope-free IPv6 multicast are rejected" do
    assert {:error, {:unsupported_capability, :ipv6_broadcast}} =
             Gaoxy.Config.validate(
               services: [
                 service(%{transport: :udp, mode: :broadcast, ip: {0, 0, 0, 0, 0, 0, 0, 0}})
               ]
             )

    assert {:error, _} =
             Gaoxy.Config.validate(
               services: [
                 service(%{
                   transport: :udp,
                   mode: :multicast,
                   ip: {0, 0, 0, 0, 0, 0, 0, 0},
                   udp: %{memberships: [{{0xFF02, 0, 0, 0, 0, 0, 0, 42}, :any}]}
                 })
               ]
             )
  end
end
