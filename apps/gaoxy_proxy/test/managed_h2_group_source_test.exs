defmodule Gaoxy.Proxy.ManagedH2GroupSourceTest do
  use ExUnit.Case, async: true

  @envelope Gaoxy.Proxy.ManagedH2Envelope
  @source_keys ~w(target method fields body_mode request_limits max_upload_bytes)a
  @uint64 18_446_744_073_709_551_615

  test "origin-neutral source preserves raw target" do
    input = source()
    assert {:ok, retained} = call(:prepare_group_source, [input])
    assert retained == input
    assert Enum.sort(Map.keys(retained)) == Enum.sort(@source_keys)
    assert retained.fields == [{"X-Trace", "first"}, {"x-trace", "second"}]
    assert :ok == call(:validate_group_source, [retained])
    assert compact_tree?(retained)
  end

  test "source rejects unknown shapes before serialization" do
    for bad <- [
          nil,
          [],
          %{},
          Map.put(source(), :url, "https://other.test/"),
          Map.put(source(), :protocol, :http2),
          Map.put(source(), :__struct__, URI),
          Map.put(source(), :extra, fn -> :never_retained end),
          Map.new(1..2000, &{&1, []})
        ] do
      reject_source(bad)
    end

    for key <- @source_keys, do: reject_source(Map.delete(source(), key))
  end

  test "source validates all fixed scalar ranges" do
    for method <- [:get, :head, :post, :put, :patch, :delete, :options],
        mode <- [:none, :chunked, {:length, 0}, {:length, @uint64}],
        upload <- [1, 65_536] do
      accept_source(%{source() | method: method, body_mode: mode, max_upload_bytes: upload})
    end

    for method <- [:connect, :trace, "GET", nil],
        do: reject_source(%{source() | method: method})

    for mode <- [
          nil,
          self(),
          [],
          {:length, -1},
          {:length, @uint64 + 1},
          {:length, 1.0},
          {:length, "1"},
          {:length, 1, :extra}
        ],
        do: reject_source(%{source() | body_mode: mode})

    for upload <- [0, 65_537, :infinity, nil, 1.0],
        do: reject_source(%{source() | max_upload_bytes: upload})

    for {key, cap} <- source().request_limits do
      for n <- [1, cap],
          do:
            accept_source(%{source() | request_limits: Map.put(source().request_limits, key, n)})

      for n <- [0, cap + 1, nil, 1.0, :infinity],
          do:
            reject_source(%{source() | request_limits: Map.put(source().request_limits, key, n)})

      reject_source(%{source() | request_limits: Map.delete(source().request_limits, key)})
    end

    for limits <- [nil, [], Map.put(source().request_limits, :extra, 1)],
        do: reject_source(%{source() | request_limits: limits})
  end

  test "source rejects malformed target grammar" do
    for target <- [
          nil,
          [],
          "",
          "relative",
          "*",
          "upstream.test:443",
          "https://other.test/",
          "/%",
          "/%0",
          "/%gg",
          "/#fragment",
          "/back\\slash",
          "/has space",
          "/\r\n",
          "/\t",
          <<?/, 0>>,
          <<?/, 127>>,
          <<?/, 128>>,
          "/中文"
        ] do
      reject_source(%{source() | target: target})
    end

    for target <- ["/", "//other.test/a", "///a", "/a%2fb%2F%3F%23", "/a?", "/a??x"] do
      assert accept_source(%{source() | target: target}).target == target
    end
  end

  test "source bounds complete proper fields" do
    for fields <- [
          nil,
          %HTTP.Headers{},
          [{"x", "v"} | :improper],
          ["x"],
          [[[]]],
          [{"x", "v", :extra}],
          [{~c"x", "v"}],
          [{"x", ~c"v"}],
          [{"", "v"}],
          [{"bad name", "v"}],
          [{":path", "/"}],
          [{"x", "\r"}],
          [{"x", "\n"}],
          [{"x", <<0>>}],
          [{"x", <<127>>}],
          List.duplicate({"x", ""}, 257),
          [{"x", :binary.copy("v", 65_536)}]
        ] do
      reject_source(%{source() | fields: fields})
    end

    # These are bounded neutral fields, not selected-member authorization.
    for fields <- [
          [],
          List.duplicate({"x", ""}, 256),
          [{"x", "\t"}],
          [{"host", "other.test"}],
          [{"content-length", "not-a-number"}]
        ] do
      accept_source(%{source() | fields: fields})
    end
  end

  test "logical source bounds are inclusive" do
    target = target(65_536)
    fields = [{"x", :binary.copy("v", 65_535)}]
    assert byte_size(target) + field_bytes(fields) == 131_072
    assert accept_source(%{source() | target: target, fields: fields}).target == target
    accept_source(%{source() | fields: [{:binary.copy("n", 65_536), ""}]})
    reject_source(%{source() | target: target(65_537)})
    reject_source(%{source() | fields: [{:binary.copy("n", 65_537), ""}]})
    assert {:error, :invalid_request} = selected(config(), %{source() | target: target})
  end

  test "backing limits precede compact copies" do
    for {key, value} <- [
          target: target(101),
          name: :binary.copy("n", 100),
          value: :binary.copy("v", 100)
        ] do
      over = slice(value, 65_537)
      assert :binary.referenced_byte_size(over) == 65_537
      reject_source(with_binary(key, over))
    end

    # A maximal individual field backing plus its other leaf exceeds the total.
    for key <- [:name, :value] do
      value = :binary.copy(if(key == :name, do: "n", else: "v"), 100)
      assert compact_tree?(accept_source(with_binary(key, slice(value, 65_535))))
      reject_source(with_binary(key, slice(value, 65_536)))
    end

    names = [
      {slice(:binary.copy("n", 100), 32_768), ""},
      {slice(:binary.copy("m", 100), 32_768), ""}
    ]

    accept_source(%{source() | fields: names})
    [{name, _}, second] = names
    reject_source(%{source() | fields: [{name, "v"}, second]})

    values = [
      {"x", slice(:binary.copy("v", 100), 32_767)},
      {"y", slice(:binary.copy("w", 100), 32_767)}
    ]

    accept_source(%{source() | fields: values})
    reject_source(%{source() | fields: [{"xx", elem(hd(values), 1)}, List.last(values)]})
    accept_source(%{source() | target: slice(target(101), 65_536)})
  end

  test "retained validation rejects noncompact fields" do
    for {key, value} <- [
          target: target(101),
          name: :binary.copy("n", 100),
          value: :binary.copy("v", 100)
        ] do
      retained = slice(value, 4096)
      assert :binary.referenced_byte_size(retained) == 4096
      input = with_binary(key, retained)
      assert {:error, :invalid_group_source} = call(:validate_group_source, [input])
      assert {:error, :invalid_request} = selected(config(), input)
      assert {:ok, compact} = call(:prepare_group_source, [input])
      assert compact == input and compact_tree?(compact)
      assert :ok == call(:validate_group_source, [compact])
      assert {:ok, _} = selected(config(), compact)
    end
  end

  test "maximum complete neutral value fits the existing request slot" do
    fields = [{"x", :binary.copy("v", 65_536 - 256)} | List.duplicate({"x", ""}, 255)]

    input = %{
      source()
      | target: target(65_536),
        fields: fields,
        method: :options,
        body_mode: {:length, @uint64}
    }

    assert length(fields) == 256 and field_bytes(fields) == 65_536
    retained = accept_source(input)
    skeleton = %{input | target: "", fields: []}

    # ETF: binaries add their payload; each pair adds tuple2 + two binary5
    # headers (12); replacing NIL by LIST_EXT/count/NIL adds five bytes.
    expected = :erlang.external_size(skeleton) + 65_536 + 65_536 + 12 * 256 + 5
    key_bytes = fn keys -> Enum.sum(Enum.map(keys, &(3 + byte_size(Atom.to_string(&1))))) end
    # Independent upper bound: version/map, atom keys, empty binary/list,
    # longest method, length tuple/uint64, nested map/four integers and upload.
    wrapper_bound =
      1 + 5 + key_bytes.(@source_keys) + 5 + 1 + (3 + 7) +
        (2 + 3 + 6 + 11) + 5 + key_bytes.(Map.keys(input.request_limits)) + 4 * 5 + 5

    assert :erlang.external_size(skeleton) <= wrapper_bound
    assert :erlang.external_size(retained) == expected
    assert expected <= wrapper_bound + 131_072 + 12 * 256 + 5
    assert wrapper_bound + 131_072 + 12 * 256 + 5 <= 205_337
  end

  test "selected TLS H2 and h2c use their actual origin" do
    for {protocol, origin} <- [
          {:http2, "https://selected.test:444"},
          {:h2c, "http://selected.test:8080"}
        ] do
      cfg = config(protocol, origin)
      assert :ok == call(:validate_config, [cfg])
      assert {:ok, request} = selected(cfg, source())
      assert request.url == origin <> source().target
      assert request.protocol == protocol
      assert request == Map.merge(source(), %{url: origin <> source().target, protocol: protocol})
      assert Enum.sort(Map.keys(request)) == Enum.sort([:url, :protocol | @source_keys])
      assert :ok == call(:validate_request, [request])
      assert compact_tree?(request)
    end

    for bad <- [
          nil,
          [],
          Map.from_struct(config()),
          Map.put(config(), :extra, []),
          %{config() | transport: nil},
          %{config() | client: Gaoxy.Proxy.HTTPFetchClient},
          %{config() | upstream_protocol: :h2c},
          %{config() | upstream_protocol: :http3},
          %{config() | uri: compact_uri("https://user@upstream.test")},
          %{config() | uri: compact_uri("https://upstream.test/path")},
          %{config() | uri: Map.put(config().uri, :extra, [])},
          %{config() | limits: Map.put(config().limits, :extra, 1)},
          %{config() | limits: %{config().limits | max_lifetime: 86_400_001}}
        ] do
      assert {:error, :invalid_request} = selected(bad, source())
    end

    for bad <- [
          nil,
          [],
          Map.put(source(), :url, "https://other.test/"),
          Map.put(source(), :__struct__, URI),
          Map.delete(source(), :fields),
          %{source() | fields: [{"x", "v"} | :improper]},
          %{source() | method: :connect},
          %{source() | max_upload_bytes: :infinity},
          %{source() | target: "https://other.test/"},
          %{source() | request_limits: Map.put(source().request_limits, :extra, 1)}
        ] do
      assert {:error, :invalid_request} = selected(config(), bad)
    end
  end

  test "selected request preserves escapes double slash and empty query" do
    for protocol <- [:http2, :h2c],
        target <- ["/", "/a%2fb%2F?x=%2F", "//other.test/a%2Fb?", "///a", "/a", "/a?", "/a??x"] do
      cfg = config(protocol)
      neutral = accept_source(%{source() | target: target})
      assert {:ok, request} = selected(cfg, neutral)
      assert request.target == target
      assert request.url == raw_origin(cfg) <> target
      assert URI.parse(request.url).host == cfg.uri.host

      assert URI.parse(request.url).query ==
               if(String.contains?(target, "?"),
                 do: target |> String.split("?", parts: 2) |> List.last(),
                 else: nil
               )
    end
  end

  test "selected assembly bounds origin and joined URL" do
    origin = raw_port_origin(8192)
    cfg = config(:http2, origin)
    assert byte_size(raw_origin(cfg)) == 8192
    assert :ok == call(:validate_config, [cfg])
    assert {:ok, request} = selected(cfg, source())
    assert request.url == origin <> source().target
    at_limit = accept_source(%{source() | target: target(65_536 - 8192)})
    assert byte_size(origin) + byte_size(at_limit.target) == 65_536
    assert {:ok, bounded} = selected(cfg, at_limit)
    assert bounded.url == origin <> at_limit.target
    assert byte_size(bounded.url) == 65_536
    assert bounded.target == at_limit.target
    assert :ok == call(:validate_request, [bounded])
    over = config(:http2, raw_port_origin(8193))
    assert :ok == call(:validate_config, [over])
    assert {:error, :invalid_request} = selected(over, source())
    neutral = accept_source(%{source() | target: target(65_536 - 8192 + 1)})
    assert byte_size(origin) + byte_size(neutral.target) == 65_537
    assert {:error, :invalid_request} = selected(cfg, neutral)
  end

  test "selected envelope still rejects forbidden fields" do
    for fields <- [
          [{"host", "other.test"}],
          [{"connection", "close"}],
          [{"keep-alive", "timeout=1"}],
          [{"proxy-connection", "close"}],
          [{"transfer-encoding", "chunked"}],
          [{"upgrade", "websocket"}],
          [{"te", "gzip"}],
          [{"content-length", "not-a-number"}],
          [{"content-length", "3"}, {"content-length", "4"}]
        ] do
      neutral = accept_source(%{source() | fields: fields})
      assert {:error, :invalid_request} = selected(config(), neutral)
    end
  end

  test "selected envelope keeps effective pseudoheader limits" do
    neutral = accept_source(%{source() | fields: List.duplicate({"x", ""}, 251)})
    assert {:ok, _} = selected(config(), neutral)

    for count <- [252, 256] do
      input = accept_source(%{source() | fields: List.duplicate({"x", ""}, count)})
      assert {:error, :invalid_request} = selected(config(), input)
    end

    for limits <- [
          %{source().request_limits | max_headers: 4},
          %{source().request_limits | max_header_bytes: 1}
        ] do
      assert {:error, :invalid_request} =
               selected(config(), accept_source(%{source() | fields: [], request_limits: limits}))
    end

    neutral = accept_source(%{source() | fields: [{"x", :binary.copy("v", 65_535)}]})
    assert {:error, :invalid_request} = selected(config(), neutral)
  end

  test "selected upload limit remains member-specific" do
    cfg = %{config() | limits: %{config().limits | max_chunk_bytes: 1024}}

    for mode <- [:none, :chunked, {:length, 3}] do
      for upload <- [1, 1024] do
        neutral = accept_source(%{source() | body_mode: mode, max_upload_bytes: upload})
        assert {:ok, request} = selected(cfg, neutral)
        assert request.body_mode == mode and request.max_upload_bytes == upload
      end

      assert {:error, :invalid_request} =
               selected(cfg, accept_source(%{source() | body_mode: mode, max_upload_bytes: 1025}))
    end
  end

  test "fixed activation accounting and public preparation remain unchanged" do
    cfg = config(:h2c)
    assert {:ok, request} = selected(cfg, source())
    fixed_source = Map.put(source(), :url, raw_origin(cfg) <> source().target)
    assert {:ok, ^request} = call(:prepare, [cfg, fixed_source])
    contract = Gaoxy.Proxy.ManagedH2Reservation.activation_contract()
    assert contract.reservation_per_request == 9_444_956
    assert contract.components.request_representations.multiplicity == 5
    assert contract.components.fixed_configs.multiplicity == 5
    assert contract.components.checked_policies.multiplicity == 2
    assert Gaoxy.Proxy.ManagedH2Reservation.reservation_bytes([], 1, 1) == 9_444_956
    assert Gaoxy.Proxy.ManagedH2Reservation.worksheet().named_subtotal_per_request == 2_918_508

    assert {:ok, policy, _} =
             Gaoxy.Proxy.ManagedH2Preparation.prepare_policy(%{
               protocol: :h2c,
               origin: raw_origin(cfg),
               connect_address: {127, 0, 0, 1},
               trust: nil
             })

    assert {:ok, prepared, accounting} =
             Gaoxy.Proxy.UpstreamTransports.Options.prepare_request(
               policy,
               %{
                 url: request.url,
                 method: request.method,
                 fields: request.fields,
                 body: nil,
                 trailers: [],
                 timeout: 1,
                 connect_timeout: 1
               }
             )

    assert prepared.url == request.url and prepared.target == request.target
    assert accounting.owned_serialized_payload_bytes == :erlang.external_size(prepared)
    assert accounting.preparation.kind == :request
    assert :erlang.external_size({:ok, prepared, accounting}) <= 205_337
  end

  defp call(function, args), do: apply(@envelope, function, args)
  defp selected(config, source), do: call(:prepare_group_request, [config, source])

  defp reject_source(value) do
    assert {:error, :invalid_group_source} = call(:prepare_group_source, [value])
    assert {:error, :invalid_group_source} = call(:validate_group_source, [value])
  end

  defp accept_source(value) do
    assert {:ok, compact} = call(:prepare_group_source, [value])
    assert compact == value and compact_tree?(compact)
    assert :ok == call(:validate_group_source, [compact])
    compact
  end

  defp source do
    %{
      target: "/a%2Fb?",
      method: :get,
      fields: [{"X-Trace", "first"}, {"x-trace", "second"}],
      body_mode: :none,
      max_upload_bytes: 65_536,
      request_limits: %{
        max_headers: 256,
        max_header_bytes: 65_536,
        max_trailers: 128,
        max_trailer_bytes: 65_536
      }
    }
  end

  defp config(protocol \\ :http2, origin \\ nil) do
    origin =
      origin || if(protocol == :http2, do: "https://upstream.test", else: "http://upstream.test")

    %Gaoxy.Proxy.HTTP{
      uri: compact_uri(origin),
      upstream_protocol: protocol,
      client: Gaoxy.Proxy.ManagedH2Client,
      cacertfile: nil,
      connect_address: nil,
      transport: %{
        provider: Gaoxy.Proxy.UpstreamTransports,
        owner: self(),
        owner_epoch: make_ref(),
        resource: make_ref()
      },
      limits: %{
        max_chunk_bytes: 65_536,
        opening_timeout: 5_000,
        idle_timeout: 60_000,
        write_timeout: 5_000,
        max_lifetime: 30_000
      }
    }
  end

  defp compact_uri(origin) do
    Map.new(Map.to_list(URI.parse(origin)), fn
      {key, value} when is_binary(value) -> {key, :binary.copy(value)}
      pair -> pair
    end)
  end

  defp raw_origin(config), do: config.uri.scheme <> "://" <> config.uri.authority

  defp raw_port_origin(bytes) do
    prefix = "https://upstream.test:"
    prefix <> :binary.copy("0", bytes - byte_size(prefix) - 3) <> "443"
  end

  defp target(bytes), do: :binary.copy("/" <> :binary.copy("a", bytes - 1))

  defp field_bytes(fields),
    do: Enum.sum(Enum.map(fields, fn {n, v} -> byte_size(n) + byte_size(v) end))

  defp with_binary(:target, value), do: %{source() | target: value}
  defp with_binary(:name, value), do: %{source() | fields: [{value, "v"}]}
  defp with_binary(:value, value), do: %{source() | fields: [{"x", value}]}

  defp slice(value, backing_bytes) do
    backing = :binary.copy(value <> :binary.copy("p", backing_bytes - byte_size(value)))
    binary_part(backing, 0, byte_size(value))
  end

  defp compact_tree?(value) when is_binary(value),
    do: :binary.referenced_byte_size(value) == byte_size(value)

  defp compact_tree?(value) when is_map(value),
    do: Enum.all?(Map.to_list(value), fn {k, v} -> compact_tree?(k) and compact_tree?(v) end)

  defp compact_tree?(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.all?(&compact_tree?/1)

  defp compact_tree?(value) when is_list(value), do: Enum.all?(value, &compact_tree?/1)
  defp compact_tree?(_), do: true
end
