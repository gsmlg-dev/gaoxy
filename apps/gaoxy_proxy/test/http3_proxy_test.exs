defmodule Gaoxy.Proxy.HTTP3ProxyTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Proxy.{HTTP, HTTPFetchClient, HTTP3SessionClient, UpstreamGroups}

  @moduletag :tmp_dir

  setup %{tmp_dir: directory} do
    ca = Path.join(directory, "ca.pem")
    File.write!(ca, "fixture trust file; configuration checks regular files only")
    {:ok, ca: ca}
  end

  test "default and explicit H1 preserve the dedicated client and upload default" do
    options = %{upstream: "http://localhost:1234"}
    assert {:ok, default} = HTTP.init(options)
    assert {:ok, explicit} = HTTP.init(Map.put(options, :upstream_protocol, :http1))
    assert default == explicit
    assert default.client == HTTPFetchClient
    assert default.upstream_protocol == :http1
    assert default.limits.max_chunk_bytes == 65_536
    assert {:ok, ^default} = HTTP.init(default)
  end

  test "explicit HTTPS H3 selects the Session client and bounds upload chunks", %{ca: ca} do
    assert {:ok, config} = HTTP.init(h3(ca))
    assert config.client == HTTP3SessionClient
    assert config.upstream_protocol == :http3
    assert config.limits.max_chunk_bytes == 16_384
    assert {:ok, ^config} = HTTP.init(config)

    assert {:ok, smaller} = HTTP.init(Map.put(h3(ca), :max_chunk_bytes, 3))
    assert smaller.limits.max_chunk_bytes == 3

    assert {:error, :invalid_http_proxy_options} =
             HTTP.init(Map.put(h3(ca), :max_chunk_bytes, 16_385))
  end

  test "H3 requires fixed HTTPS and explicit regular trust without dial overrides", %{ca: ca} do
    for options <- [
          Map.put(h3(ca), :upstream, "http://localhost:443"),
          Map.delete(h3(ca), :cacertfile),
          Map.put(h3(ca), :cacertfile, nil),
          Map.put(h3(ca), :cacertfile, Path.dirname(ca)),
          Map.put(h3(ca), :cacertfile, ca <> ".missing"),
          Map.put(h3(ca), :connect_address, {127, 0, 0, 1}),
          Map.put(h3(ca), :connect_address, "127.0.0.1"),
          Map.put(h3(ca), :tls, verify: :verify_none),
          Map.put(h3(ca), :server_name_indication, "other.test")
        ] do
      assert {:error, :invalid_http_proxy_options} = HTTP.init(options), inspect(options)
    end
  end

  test "protocol and client cannot be injected through options or a compiled struct", %{ca: ca} do
    for options <- [
          Map.put(h3(ca), :upstream_protocol, :http2),
          Map.put(h3(ca), :upstream_protocol, "http3"),
          Map.put(h3(ca), :client, HTTPFetchClient),
          Map.put(h3(ca), :client, __MODULE__),
          Map.put(h3(ca), :transport, __MODULE__)
        ] do
      assert {:error, :invalid_http_proxy_options} = HTTP.init(options)
    end

    assert {:ok, config} = HTTP.init(h3(ca))

    for forged <- [
          Map.put(config, :client, HTTPFetchClient),
          Map.put(config, :client, __MODULE__),
          Map.put(config, :upstream_protocol, :http1),
          Map.put(config, :connect_address, {127, 0, 0, 1}),
          Map.put(config, :cacertfile, nil),
          Map.put(config, :limits, %{config.limits | max_chunk_bytes: 16_385})
        ] do
      assert {:error, :invalid_http_proxy_options} = HTTP.init(forged)
    end
  end

  test "group compilation rejects H3 maps and precompiled H3 members", %{ca: ca} do
    member = Map.merge(h3(ca), %{id: "a"})

    assert {:error, :invalid_upstream_group} =
             UpstreamGroups.compile(%{id: "api", members: [member]})

    assert {:ok, group} =
             UpstreamGroups.compile(%{
               id: "api",
               members: [%{id: "a", upstream: "http://localhost:1234"}]
             })

    assert {:ok, h3_config} = HTTP.init(h3(ca))
    [compiled_member] = group.members
    forged = %{group | members: [%{compiled_member | config: h3_config}]}
    assert {:error, :invalid_upstream_group} = UpstreamGroups.compile(forged)
  end

  defp h3(ca),
    do: %{upstream: "https://localhost:443", upstream_protocol: :http3, cacertfile: ca}
end
