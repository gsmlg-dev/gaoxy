defmodule Gaoxy.Proxy.UpstreamTransports.OptionsTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Proxy.ManagedH1Preparation, as: Preparation
  alias Gaoxy.Proxy.UpstreamTransports.Options

  test "requires every finite owner budget and preserves accepted limits" do
    assert {:ok, accepted} = Options.normalize_limits(limits())
    assert accepted == limits()

    maximum = %{
      max_resources: 64,
      max_pins: 4096,
      max_request_tokens: 2048,
      max_owned_payload_bytes: 67_108_864
    }

    assert {:ok, ^maximum} = Options.normalize_limits(maximum)

    for {key, cap} <- maximum, value <- [0, -1, 1.0, :infinity, nil, cap + 1] do
      assert {:error, :invalid_limits} = Options.normalize_limits(Map.put(limits(), key, value))
    end
  end

  test "rejects missing, unknown, duplicate and arbitrary owner options" do
    for source <- [
          %{},
          nil,
          Map.delete(limits(), :max_pins),
          Map.put(limits(), :max_pending, 0),
          Map.put(limits(), :ssl, fn -> :bad end),
          Map.to_list(limits()),
          [{:max_resources, 1}, {:max_resources, 2} | Map.to_list(limits())],
          Map.new(1..2000, &{&1, []})
        ] do
      assert {:error, :invalid_limits} = Options.normalize_limits(source)
    end
  end

  test "matches existing immutable H1 preparation and labels owned serialized payload" do
    for source <- [policy_source(), tls_source(["opaque DER bytes"])] do
      {:ok, expected, preparation} = Preparation.prepare_policy(source)
      assert {:ok, ^expected, accounting} = Options.prepare_policy(source)

      assert accounting == %{
               owned_serialized_payload_bytes: :erlang.external_size(expected),
               preparation: preparation
             }

      assert expected.open_options[:http_version] == :http1
      assert expected.open_options[:max_connections] == 2
      assert expected.open_options[:max_requests] == 32
      assert expected.open_options[:max_pending] == 0
      assert expected.open_options[:idle_timeout] == 30_000
      assert compact_tree?(expected)
    end
  end

  test "rejects raw policy options, duplicate fields, SSL callbacks and mutable trust" do
    for source <- [
          Map.put(policy_source(), :http_version, :http2),
          Map.put(policy_source(), :http_version, :http3),
          Map.put(policy_source(), :ssl, verify_fun: fn _, _, _ -> :bad end),
          Map.put(policy_source(), :socket_opts, []),
          Map.put(policy_source(), :options, []),
          Map.put(policy_source(), :cacertfile, "never-read.pem"),
          [{:origin, "http://other.test"} | Map.to_list(policy_source())]
        ] do
      assert {:error, :invalid_policy} = Options.prepare_policy(source)
    end

    for trust <- [nil, [], "never-read.pem", {:file, "never-read.pem"}, fn -> :bad end] do
      assert {:error, :invalid_trust} = Options.prepare_policy(tls_source(trust))
    end

    assert {:error, :invalid_policy} =
             Options.prepare_policy(%{policy_source() | connect_address: "127.0.0.1"})
  end

  test "preserves compact request, ordered fields and empty query without policy mutation" do
    {:ok, policy, _} = Options.prepare_policy(policy_source())
    {:ok, expected, preparation} = Preparation.prepare_request(policy, request_source())
    assert {:ok, ^expected, accounting} = Options.prepare_request(policy, request_source())

    assert accounting == %{
             owned_serialized_payload_bytes: :erlang.external_size(expected),
             preparation: preparation
           }

    assert expected.target == "/upload?"
    assert expected.fields == [{"X-Repeat", "first"}, {"x-repeat", "second"}]
    assert {:ok, ^policy, _} = Options.prepare_policy(policy_source())
    assert compact_tree?(expected)
  end

  test "rejects request protocol, authority, address, trust and identity overrides" do
    {:ok, policy, _} = Options.prepare_policy(policy_source())

    for {key, value} <- [
          http_version: :http2,
          http_version: :http3,
          connect_address: {127, 0, 0, 2},
          authority: "other.test",
          trust: ["new trust"],
          ssl: [],
          transport: self(),
          options: [],
          timeout_callback: fn -> :bad end
        ] do
      assert {:error, :invalid_request} =
               Options.prepare_request(policy, Map.put(request_source(), key, value))
    end

    assert {:error, :invalid_request} =
             Options.prepare_request(policy, [{:timeout, 1} | Map.to_list(request_source())])

    for url <- ["https://example.test/", "http://other.test/", "http://example.test:81/"] do
      assert {:error, :origin_mismatch} =
               Options.prepare_request(policy, %{request_source() | url: url})
    end

    h2 = %{policy | open_options: Keyword.put(policy.open_options, :http_version, :http2)}
    assert {:error, :invalid_policy} = Options.prepare_request(h2, request_source())
  end

  test "bounds trust and source backing before compact construction" do
    cert = slice(:binary.copy("d", 80))
    assert :binary.referenced_byte_size(cert) == 8192
    assert {:ok, policy, _} = Options.prepare_policy(tls_source([cert]))
    assert policy.open_options[:ssl][:cacerts] == [cert]
    assert compact_tree?(policy)

    assert {:error, :source_backing_limit} =
             Options.prepare_policy(tls_source([slice(:binary.copy("d", 80), 65_537)]))

    assert {:error, :trust_limit} =
             Options.prepare_policy(tls_source(List.duplicate("d", 129)))

    assert {:error, :trust_limit} =
             Options.prepare_policy(tls_source([:binary.copy("d", 65_537)]))

    assert {:error, :source_backing_limit} =
             Options.prepare_policy(
               tls_source(List.duplicate(slice(:binary.copy("d", 80), 16_384), 65))
             )

    {:ok, policy, _} = Options.prepare_policy(policy_source())
    value = slice(:binary.copy("v", 80))

    assert {:ok, prepared, _} =
             Options.prepare_request(policy, %{request_source() | fields: [{"x", value}]})

    assert compact_tree?(prepared)

    assert {:error, :source_backing_limit} =
             Options.prepare_request(policy, %{
               request_source()
               | fields: [{"x", slice(:binary.copy("v", 80), 65_537)}]
             })
  end

  test "validation and preparation do not change caller links or send messages" do
    {:links, links} = Process.info(self(), :links)
    assert {:ok, _, _} = Options.prepare_policy(policy_source())
    assert {:error, :invalid_limits} = Options.normalize_limits(%{limits() | max_resources: 65})

    assert {:error, :invalid_policy} =
             Options.prepare_policy(Map.put(policy_source(), :options, []))

    assert Process.info(self(), :links) == {:links, links}
    refute_receive _message, 0
  end

  defp limits do
    %{max_resources: 2, max_pins: 8, max_request_tokens: 64, max_owned_payload_bytes: 131_072}
  end

  defp policy_source do
    %{origin: "http://example.test", connect_address: {127, 0, 0, 1}, trust: nil}
  end

  defp tls_source(trust), do: %{policy_source() | origin: "https://example.test", trust: trust}

  defp request_source do
    %{
      url: "http://example.test/upload?",
      method: :post,
      fields: [{"X-Repeat", "first"}, {"x-repeat", "second"}],
      body: nil,
      trailers: [],
      timeout: 1000,
      connect_timeout: 500
    }
  end

  defp slice(value, bytes \\ 8192) do
    parent = :binary.copy(value <> :binary.copy("p", bytes - byte_size(value)))
    binary_part(parent, 0, byte_size(value))
  end

  defp compact_tree?(value) when is_binary(value),
    do: :binary.referenced_byte_size(value) == byte_size(value)

  defp compact_tree?(value) when is_map(value),
    do:
      :maps.fold(
        fn key, value, acc -> acc and compact_tree?(key) and compact_tree?(value) end,
        true,
        value
      )

  defp compact_tree?(value) when is_tuple(value),
    do: Enum.all?(Tuple.to_list(value), &compact_tree?/1)

  defp compact_tree?(value) when is_list(value), do: Enum.all?(value, &compact_tree?/1)
  defp compact_tree?(_), do: true
end
