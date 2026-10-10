defmodule Gaoxy.Proxy.DestinationPolicyTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Proxy.DestinationPolicy

  test "authentication and a nonempty explicit destination policy are required" do
    for options <- [
          %{},
          %{authenticate: &auth/1},
          %{rules: [rule()]},
          %{authenticate: &auth/1, rules: []}
        ] do
      assert {:error, :invalid_destination_policy} = DestinationPolicy.init(options)
    end

    policy = policy()
    assert {:error, :authentication_required} = DestinationPolicy.authenticate(policy, [])

    assert {:error, :authentication_required} =
             DestinationPolicy.authenticate(policy, [{"proxy-authorization", "bad"}])

    assert {:error, :authentication_required} =
             DestinationPolicy.authenticate(policy, [
               {"proxy-authorization", "Bearer secret"},
               {"Proxy-Authorization", "Bearer secret"}
             ])

    assert {:ok, "operator"} =
             DestinationPolicy.authenticate(policy, [{"proxy-authorization", "Bearer secret"}])
  end

  test "principal, authority, port, operation and method are checked before resolution" do
    policy = policy()
    assert {:ok, authorization} = DestinationPolicy.authorize(policy, "operator", context())
    assert authorization.host == "example.test"

    for change <- [
          %{host: "other.test"},
          %{port: 22},
          %{operation: :connect},
          %{method: "DELETE"},
          %{host: "fe80::1%eth0"}
        ] do
      assert {:error, :destination_denied} =
               DestinationPolicy.authorize(policy, "operator", Map.merge(context(), change))
    end

    assert {:error, :destination_denied} = DestinationPolicy.authorize(policy, "other", context())
  end

  test "every resolved address is checked and mixed answers fail closed" do
    assert {:ok, authorization} = DestinationPolicy.authorize(policy(), "operator", context())
    assert {:ok, {8, 8, 8, 8}} = DestinationPolicy.pin(authorization, [{8, 8, 8, 8}])

    for address <- [
          {0, 0, 0, 0},
          {10, 0, 0, 1},
          {100, 100, 100, 200},
          {127, 0, 0, 1},
          {169, 254, 169, 254},
          {172, 16, 0, 1},
          {192, 168, 1, 1},
          {224, 0, 0, 1},
          {255, 255, 255, 255},
          {0, 0, 0, 0, 0, 0, 0, 1},
          {0xFC00, 0, 0, 0, 0, 0, 0, 1},
          {0xFE80, 0, 0, 0, 0, 0, 0, 1},
          {0xFF02, 0, 0, 0, 0, 0, 0, 1},
          {0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 1}
        ] do
      assert {:error, :destination_denied} = DestinationPolicy.pin(authorization, [address])

      assert {:error, :destination_denied} =
               DestinationPolicy.pin(authorization, [{8, 8, 8, 8}, address])
    end

    assert {:error, :destination_denied} = DestinationPolicy.pin(authorization, [])
    assert {:error, :destination_denied} = DestinationPolicy.pin(authorization, [{256, 1, 1, 1}])
  end

  test "a reserved address needs an explicit narrow CIDR exception and mapped IPv6 is normalized" do
    rule = %{rule() | cidrs: ["127.0.0.1/32"], allow_reserved: true}
    assert {:ok, authorization} = DestinationPolicy.authorize(policy(rule), "operator", context())

    assert {:ok, {127, 0, 0, 1}} =
             DestinationPolicy.pin(authorization, [{0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 1}])

    assert {:error, :destination_denied} = DestinationPolicy.pin(authorization, [{127, 0, 0, 2}])

    assert {:error, :invalid_destination_policy} =
             DestinationPolicy.init(%{
               authenticate: &auth/1,
               rules: [%{rule | cidrs: ["0.0.0.0/0"]}]
             })
  end

  test "IPv6 public candidates require an applicable explicit CIDR rule" do
    rule = %{rule() | cidrs: ["2001:4860::/32"]}
    assert {:ok, authorization} = DestinationPolicy.authorize(policy(rule), "operator", context())
    address = {0x2001, 0x4860, 0, 0, 0, 0, 0x8888, 1}
    assert {:ok, ^address} = DestinationPolicy.pin(authorization, [address])
    assert {:error, :destination_denied} = DestinationPolicy.pin(authorization, [{8, 8, 8, 8}])
  end

  test "numeric destinations are revalidated at connection time without a DNS lookup" do
    rule = %{rule() | hosts: ["127.0.0.1"], cidrs: ["127.0.0.1/32"], allow_reserved: true}

    assert {:ok, authorization} =
             DestinationPolicy.authorize(policy(rule), "operator", %{
               context()
               | host: "127.0.0.1"
             })

    assert {:ok, {127, 0, 0, 1}} =
             DestinationPolicy.resolve(authorization, Gaoxy.Lifecycle.deadline(1_000))

    assert {:error, :deadline_exceeded} =
             DestinationPolicy.resolve(authorization, Gaoxy.Lifecycle.now())
  end

  test "IPv6 site-local destinations and mixed answers need an explicit narrow exception" do
    rule = %{rule() | cidrs: ["::/0"]}
    assert {:ok, authorization} = DestinationPolicy.authorize(policy(rule), "operator", context())
    address = {0xFEC0, 0, 0, 0, 0, 0, 0, 1}
    assert {:error, :destination_denied} = DestinationPolicy.pin(authorization, [address])

    assert {:error, :destination_denied} =
             DestinationPolicy.pin(authorization, [{0x2001, 0x4860, 0, 0, 0, 0, 0, 1}, address])

    assert {:ok, exception} =
             DestinationPolicy.authorize(
               policy(%{rule | cidrs: ["fec0::1/128"], allow_reserved: true}),
               "operator",
               context()
             )

    assert {:ok, ^address} = DestinationPolicy.pin(exception, [address])
  end

  test "management destination denies override every matching allow rule" do
    assert {:ok, policy} =
             DestinationPolicy.init(%{
               authenticate: &auth/1,
               rules: [rule()],
               deny_cidrs: ["8.8.8.8/32"]
             })

    assert {:ok, authorization} = DestinationPolicy.authorize(policy, "operator", context())
    assert {:error, :destination_denied} = DestinationPolicy.pin(authorization, [{8, 8, 8, 8}])

    assert {:error, :destination_denied} =
             DestinationPolicy.pin(authorization, [{9, 9, 9, 9}, {8, 8, 8, 8}])

    assert {:ok, {9, 9, 9, 9}} = DestinationPolicy.pin(authorization, [{9, 9, 9, 9}])
  end

  defp auth("Bearer secret"), do: {:ok, "operator"}
  defp auth(_), do: :error
  defp context, do: %{host: "EXAMPLE.TEST", port: 80, operation: :forward, method: "GET"}

  defp rule,
    do: %{
      principals: ["operator"],
      hosts: ["example.test"],
      ports: [80],
      operations: [:forward],
      methods: ["GET"],
      cidrs: ["0.0.0.0/0"],
      allow_reserved: false
    }

  defp policy(rule \\ rule()) do
    assert {:ok, policy} = DestinationPolicy.init(%{authenticate: &auth/1, rules: [rule]})
    policy
  end
end
