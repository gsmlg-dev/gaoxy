defmodule Gaoxy.Proxy.ManagedH2EnvelopeTest do
  use ExUnit.Case, async: true

  @envelope Gaoxy.Proxy.ManagedH2Envelope
  @preparation Gaoxy.Proxy.ManagedH2Preparation
  @request_keys [
    :protocol,
    :url,
    :target,
    :method,
    :fields,
    :body_mode,
    :request_limits,
    :max_upload_bytes
  ]

  test "pre-Session envelope preserves raw Content-Length, duplicate order and empty query" do
    for protocol <- [:http2, :h2c], position <- [0, 1, 2], supplied_type <- [false, true] do
      raw = [{"X-Trace", "first"}, {"x-trace", "second"}]
      raw = List.insert_at(raw, position, {"Content-Length", "3"})
      raw = if supplied_type, do: raw ++ [{"Content-Type", "text/plain"}], else: raw
      source = %{source(protocol) | fields: raw}
      assert {:ok, envelope} = call(:prepare, [config(protocol), source])
      assert Enum.sort(Map.keys(envelope)) == Enum.sort(@request_keys)
      assert envelope == Map.put(source, :protocol, protocol)
      assert envelope.target == "/a%2Fb?"
      assert envelope.fields == raw
      assert :ok == call(:validate_request, [envelope])
      assert compact_tree?(envelope)
      assert :erlang.external_size(envelope) <= 205_337
    end
  end

  test "source and envelope schemas reject aliases, omissions, forged structs and arbitrary payloads" do
    for bad <- [
          nil,
          [],
          %{},
          Map.delete(source(), :url),
          Map.put(source(), :exchange, :forbidden),
          Map.put(source(), :protocol, :http2),
          Map.put(source(), :headers, []),
          Map.put(source(), :__struct__, URI),
          Map.new(1..2000, &{&1, []})
        ] do
      reject(:prepare, [config(), bad])
    end

    request = Map.put(source(), :protocol, :http2)

    for bad <- [
          nil,
          [],
          Map.delete(request, :target),
          Map.put(request, :path, "/"),
          Map.put(request, :body, self()),
          Map.put(request, :__struct__, URI)
        ] do
      reject(:validate_request, [bad])
    end

    for protocol <- [:http1, :http3, nil, "http2"] do
      reject(:validate_request, [%{request | protocol: protocol}])
    end
  end

  test "methods and body modes have finite enums and unsigned64 lengths" do
    for method <- [:get, :head, :post, :put, :patch, :delete, :options],
        mode <- [:none, :chunked, {:length, 0}, {:length, 18_446_744_073_709_551_615}] do
      source = %{source() | method: method, body_mode: mode, fields: []}
      assert {:ok, _} = call(:prepare, [config(), source])
    end

    for mode <- [
          nil,
          self(),
          [],
          {:length, -1},
          {:length, 18_446_744_073_709_551_616},
          {:length, 1.0},
          {:length, 1, :extra},
          {:length, "3"}
        ] do
      reject(:prepare, [config(), %{source() | body_mode: mode}])
    end

    for method <- [:connect, :trace, "POST", nil] do
      reject(:prepare, [config(), %{source() | method: method}])
    end
  end

  test "exact effective limits and upload bounds reject malformed or expanded maps" do
    for bytes <- [1, 65_536] do
      assert {:ok, _} = call(:prepare, [config(), %{source() | max_upload_bytes: bytes}])
    end

    for bytes <- [0, 65_537, :infinity, 1.0, nil] do
      reject(:prepare, [config(), %{source() | max_upload_bytes: bytes}])
    end

    for key <- Map.keys(source().request_limits) do
      cap = Map.fetch!(source().request_limits, key)

      for value <- [0, cap + 1, nil, 1.0] do
        limits = Map.put(source().request_limits, key, value)
        reject(:prepare, [config(), %{source() | request_limits: limits}])
      end

      reject(:prepare, [
        config(),
        %{source() | request_limits: Map.delete(source().request_limits, key)}
      ])
    end

    reject(:prepare, [
      config(),
      %{source() | request_limits: Map.put(source().request_limits, :unknown, 1)}
    ])

    reject(:prepare, [
      config(),
      %{source() | request_limits: %{source().request_limits | max_headers: 1}}
    ])
  end

  test "submitted origin and raw target must agree including present empty query" do
    for {url, target} <- [
          {"https://upstream.test/", "/"},
          {"https://upstream.test/a%2Fb", "/a%2Fb"},
          {"https://upstream.test/a%2Fb?", "/a%2Fb?"},
          {"https://upstream.test/a?x=%2F", "/a?x=%2F"}
        ] do
      assert {:ok, %{url: ^url, target: ^target}} =
               call(:prepare, [config(), %{source() | url: url, target: target}])
    end

    for change <- [
          %{target: "/a/b?"},
          %{target: "/a%2Fb"},
          %{target: "https://upstream.test/a%2Fb?"},
          %{url: "https://other.test/a%2Fb?"},
          %{url: "http://upstream.test/a%2Fb?"},
          %{url: "https://upstream.test:444/a%2Fb?"},
          %{url: "https://user@upstream.test/a%2Fb?"},
          %{url: "https://upstream.test/a%2Fb?#fragment"},
          %{url: "https://upstream.test/%gg"},
          %{url: "https://upstream.test:443junk/a%2Fb?"},
          %{target: "/bad\r\n"}
        ] do
      reject(:prepare, [config(), Map.merge(source(), change)])
    end
  end

  test "feasible exact URL bound uses finite raw port text with a small target" do
    prefix = "https://upstream.test:"
    suffix = "443/a%2Fb?"

    url =
      :binary.copy(
        prefix <> :binary.copy("0", 65_536 - byte_size(prefix) - byte_size(suffix)) <> suffix
      )

    assert byte_size(url) == 65_536
    assert {:ok, %{url: ^url}} = call(:prepare, [config(), %{source() | url: url}])

    reject(:prepare, [
      config(),
      %{
        source()
        | url:
            prefix <>
              "0" <> binary_part(url, byte_size(prefix), byte_size(url) - byte_size(prefix))
      }
    ])

    # Raw target at its ceiling cannot fit the effective pseudo/default head.
    for bytes <- [65_536, 65_537] do
      target = "/" <> :binary.copy("a", bytes - 1)

      reject(:prepare, [
        config(),
        %{source() | url: "https://upstream.test" <> target, target: target}
      ])
    end
  end

  test "source pair grammar rejects improper lists, nonbinary leaves and forbidden fields" do
    for fields <- [
          [{"x", "v"} | :improper],
          [{"x", "v", "extra"}],
          ["x"],
          [[[]]],
          [{~c"x", "v"}],
          [{"x", ~c"v"}],
          [{"", "v"}],
          [{"bad name", "v"}],
          [{"x", "\r"}],
          [{"x", <<0>>}],
          [{"x", <<127>>}],
          [{":path", "/"}],
          [{"host", "other.test"}],
          [{"connection", "close"}],
          [{"content-length", "18446744073709551616"}],
          [{"content-length", "3"}, {"content-length", "4"}],
          %HTTP.Headers{}
        ] do
      reject(:prepare, [config(), %{source() | fields: fields}])
    end
  end

  test "effective native count includes four pseudo fields and generated user-agent" do
    raw = List.duplicate({"x", ""}, 251)
    assert {:ok, _} = call(:prepare, [config(), %{source() | fields: raw, body_mode: :none}])

    for count <- [252, 256, 257] do
      reject(:prepare, [
        config(),
        %{source() | fields: List.duplicate({"x", ""}, count), body_mode: :none}
      ])
    end

    for bytes <- [65_536, 65_537] do
      reject(:prepare, [config(), %{source() | fields: [{"x", :binary.copy("v", bytes - 1)}]}])
    end
  end

  test "URL, target and fields backing is checked before copying and admissible slices compact" do
    target = "/" <> :binary.copy("a", 100)
    bounded_source = %{source() | url: "https://upstream.test" <> target, target: target}

    for key <- [:url, :target] do
      value = Map.fetch!(bounded_source, key)
      over = slice(value, 65_537)
      assert :binary.referenced_byte_size(over) == 65_537
      reject(:prepare, [config(), Map.put(bounded_source, key, over)])
    end

    over = slice(:binary.copy("v", 100), 65_537)
    reject(:prepare, [config(), %{source() | fields: [{"x", over}]}])

    parts = [
      {"x", slice(:binary.copy("v", 100), 32_768)},
      {"y", slice(:binary.copy("v", 100), 32_768)}
    ]

    reject(:prepare, [config(), %{source() | fields: parts}])

    valid = %{
      source()
      | url: slice(source().url, 4096),
        target: slice(source().target, 4096),
        fields: [{"x", slice(:binary.copy("v", 100), 4096)}]
    }

    assert {:ok, result} = call(:prepare, [config(), valid])
    assert compact_tree?(result)
  end

  test "compiled config is an exact canonical HTTP struct and handle" do
    for protocol <- [:http2, :h2c] do
      assert :ok == call(:validate_config, [config(protocol)])
    end

    for bad <- [
          nil,
          [],
          Map.from_struct(config()),
          Map.put(config(), :extra, []),
          %{config() | transport: nil},
          %{config() | client: Gaoxy.Proxy.HTTPFetchClient},
          %{config() | cacertfile: "/tmp/ca"},
          %{config() | connect_address: {127, 0, 0, 1}},
          %{config() | upstream_protocol: :http3},
          %{config() | upstream_protocol: :h2c},
          %{config() | uri: Map.put(config().uri, :extra, [])},
          %{config() | uri: Map.from_struct(config().uri)},
          %{config() | uri: %{config().uri | path: "/"}},
          %{config() | uri: %{config().uri | userinfo: "user"}},
          %{config() | uri: %{config().uri | query: ""}},
          %{config() | uri: %{config().uri | fragment: ""}},
          %{config() | uri: %{config().uri | authority: "other.test"}}
        ] do
      reject(:validate_config, [bad])
    end

    for key <- Map.keys(config().transport) do
      reject(:validate_config, [%{config() | transport: Map.delete(config().transport, key)}])
    end

    for change <- [
          %{provider: :bad},
          %{owner: make_ref()},
          %{owner_epoch: self()},
          %{resource: 1},
          %{extra: :bad}
        ] do
      reject(:validate_config, [%{config() | transport: Map.merge(config().transport, change)}])
    end
  end

  test "canonical config URI validates numeric authorities, ports and finite host bounds" do
    for origin <- [
          "https://127.0.0.1",
          "https://[::1]",
          "https://upstream.test:1",
          "https://upstream.test:65535",
          "https://" <> :binary.copy("a", 253)
        ] do
      assert :ok == call(:validate_config, [%{config() | uri: compact_uri(origin)}])
    end

    for origin <- [
          "https://",
          "https://upstream.test:0",
          "https://upstream.test:65536",
          "https://upstream.test:443junk",
          "https://" <> :binary.copy("a", 254),
          "https://exa mple.test",
          "https://upstream.test/nonroot"
        ] do
      reject(:validate_config, [%{config() | uri: URI.parse(origin)}])
    end

    reject(:validate_config, [
      %{config() | uri: %{config().uri | host: slice(:binary.copy("a", 100), 65_537)}}
    ])
  end

  test "fixed config five limits retain bounded integer timeouts and chunk size" do
    for key <- Map.keys(config().limits) do
      cap = if key == :max_chunk_bytes, do: 65_536, else: 86_400_000

      for value <- [1, cap] do
        assert :ok ==
                 call(:validate_config, [
                   %{config() | limits: Map.put(config().limits, key, value)}
                 ])
      end

      for value <- [0, cap + 1, :infinity, 1.0] do
        reject(:validate_config, [%{config() | limits: Map.put(config().limits, key, value)}])
      end

      reject(:validate_config, [%{config() | limits: Map.delete(config().limits, key)}])
    end

    reject(:validate_config, [%{config() | limits: Map.put(config().limits, :extra, 1)}])
  end

  test "checked client uses only exact public options and matching prepared H2 policy" do
    for protocol <- [:http2, :h2c] do
      assert :ok == call(:validate_checked_client, [checked_client(protocol), protocol])
      other = if protocol == :http2, do: :h2c, else: :http2
      reject(:validate_checked_client, [checked_client(protocol), other])
    end

    client = checked_client()

    for bad <- [
          nil,
          [],
          Map.delete(client, :policy),
          Map.put(client, :extra, []),
          %{client | transport_scope: nil},
          %{client | fetch_options: client.fetch_options ++ [redirect: :manual]},
          %{client | fetch_options: client.fetch_options ++ [ssl: []]},
          %{client | fetch_options: [http_version: :http2] ++ [:bad]},
          %{client | fetch_options: [{:http_version, :http2} | :improper]},
          %{client | policy: Map.put(client.policy, :extra, [])},
          %{client | policy: %{client.policy | port: 444}}
        ] do
      reject(:validate_checked_client, [bad, :http2])
    end

    for key <- Keyword.keys(client.fetch_options) do
      reject(:validate_checked_client, [
        %{client | fetch_options: Keyword.delete(client.fetch_options, key)},
        :http2
      ])

      reject(:validate_checked_client, [
        %{client | fetch_options: Keyword.put(client.fetch_options, key, :invalid)},
        :http2
      ])
    end
  end

  test "trailer policy has exactly four keys, compact lowercase token lists and finite maxima" do
    assert :ok == call(:validate_trailer_policy, [trailer_policy()])
    allowed = Enum.map(1..128, &"x-#{&1}")
    dropped = Enum.map(1..265, &"drop-#{&1}")

    assert :ok ==
             call(:validate_trailer_policy, [
               %{trailer_policy() | allowed: allowed, dropped: dropped}
             ])

    for change <- [
          %{allowed: allowed ++ ["over"]},
          %{dropped: dropped ++ ["over"]},
          %{allowed: ["x" | :improper]},
          %{dropped: [["x"]]},
          %{allowed: ["X"]},
          %{allowed: ["bad name"]},
          %{allowed: [""]},
          %{allowed: ["content-length"]},
          %{allowed: [slice(:binary.copy("x", 100), 65_643)]},
          %{max_count: 0},
          %{max_count: 129},
          %{max_bytes: 0},
          %{max_bytes: 65_537}
        ] do
      reject(:validate_trailer_policy, [Map.merge(trailer_policy(), change)])
    end

    reject(:validate_trailer_policy, [Map.put(trailer_policy(), :extra, [])])
    reject(:validate_trailer_policy, [Map.delete(trailer_policy(), :dropped)])
  end

  test "complete trailer policy fits its payload and external constructor ceilings" do
    allowed =
      Enum.map(1..128, fn index ->
        name = "allowed-#{index}"
        name <> :binary.copy("a", 100 - byte_size(name))
      end)

    short_dropped = Enum.map(1..264, &"drop-#{&1}")
    remaining = 65_642 - 128 * 100 - Enum.sum(Enum.map(short_dropped, &byte_size/1))
    dropped = [:binary.copy("b", remaining) | short_dropped]
    value = %{trailer_policy() | allowed: allowed, dropped: dropped}
    assert Enum.sum(Enum.map(allowed ++ dropped, &byte_size/1)) == 65_642
    assert :erlang.external_size(value) <= 67_689
    assert :ok == call(:validate_trailer_policy, [value])
    reject(:validate_trailer_policy, [%{value | dropped: ["b" <> hd(dropped) | tl(dropped)]}])
  end

  test "Response extraction preserves ordered duplicate initial fields and only bounded head" do
    for status <- [200, 599],
        type <- [:basic, :cors, :error, :opaque],
        {body, stream} <- [{nil, nil}, {"", nil}, {nil, self()}, {"", self()}, {self(), self()}] do
      response = %{response() | status: status, type: type, body: body, stream: stream}

      assert {:ok, %{status: ^status, fields: fields, stream: ^stream} = result} =
               call(:validate_response, [response, source().url])

      assert map_size(result) == 3
      assert fields == response.headers.headers
      assert compact_tree?(fields)
    end
  end

  test "Response and Headers reject forged or expanded wrappers and nonstreamed bodies" do
    for bad <- [
          nil,
          [],
          Map.from_struct(response()),
          Map.put(response(), :extra, []),
          %{response() | status: 199},
          %{response() | status: 600},
          %{response() | status: 200.0},
          %{response() | http_version: :h2c},
          %{response() | http_version: :http1},
          %{response() | body: "buffered"},
          %{response() | body: self(), stream: nil},
          %{response() | body: self(), stream: :erlang.list_to_pid(~c"<0.1.0>")},
          %{response() | stream: make_ref()},
          %{response() | headers: []},
          %{response() | headers: Map.put(response().headers, :extra, [])},
          %{response() | headers: Map.from_struct(response().headers)},
          %{response() | trailers: %HTTP.Headers{headers: [{"x", "v"}]}},
          %{response() | trailers: Map.put(%HTTP.Headers{}, :extra, [])}
        ] do
      reject(:validate_response, [bad, source().url])
    end

    for key <- [:ok, :body_used, :redirected], value <- [nil, 1, "true"] do
      reject(:validate_response, [Map.put(response(), key, value), source().url])
    end

    for value <- [nil, "basic", :unknown] do
      reject(:validate_response, [%{response() | type: value}, source().url])
    end
  end

  test "metadata status text and submitted-derived URI validate logical and backing bounds" do
    assert {:ok, _} =
             call(:validate_response, [
               %{response() | status_text: :binary.copy("a", 64)},
               source().url
             ])

    for value <- [:binary.copy("a", 65), ~c"OK"] do
      reject(:validate_response, [%{response() | status_text: value}, source().url])
    end

    assert {:ok, _} = call(:validate_response, [%{response() | url: nil}, source().url])

    for uri <- [
          URI.parse("https://other.test/a%2Fb?"),
          URI.parse("https://upstream.test/a/b?"),
          URI.parse("https://upstream.test/a%2Fb"),
          Map.put(response().url, :extra, []),
          Map.from_struct(response().url),
          %{response().url | query: slice(:binary.copy("a", 100), 65_537)}
        ] do
      reject(:validate_response, [%{response() | url: uri}, source().url])
    end

    submitted = "https://upstream.test/" <> :binary.copy("a", 100)

    reject(:validate_response, [
      %{response() | url: URI.parse(submitted)},
      slice(submitted, 65_537)
    ])
  end

  test "native normalized response URI matches submitted fields and normalizes only an empty root" do
    for url <- [
          "http://upstream.test/a%2Fb?",
          "https://upstream.test:444/a%2Fb?x=%2F",
          "https://upstream.test",
          "https://upstream.test?",
          "https://upstream.test/"
        ] do
      submitted = URI.parse(url)

      normalized = %{
        submitted
        | authority: nil,
          path: if(submitted.path in [nil, ""], do: "/", else: submitted.path)
      }

      assert {:ok, %{status: 200, fields: fields, stream: nil}} =
               call(:validate_response, [%{response() | url: normalized}, url])

      assert fields == response().headers.headers
      assert {:ok, _} = call(:validate_response, [%{response() | url: submitted}, url])
    end
  end

  test "normalized response URI rejects every mismatched field and forged public wrapper" do
    url = source().url
    normalized = %{URI.parse(url) | authority: nil}

    for uri <- [
          %{normalized | scheme: "http"},
          %{normalized | host: "attacker.invalid"},
          %{normalized | port: 444},
          %{normalized | path: "/a/b"},
          %{normalized | path: nil},
          %{normalized | query: nil},
          %{normalized | query: "attacker"},
          %{normalized | userinfo: "attacker"},
          %{normalized | fragment: "attacker"},
          %{normalized | authority: "attacker.invalid"},
          %{normalized | authority: "upstream.test:443"},
          Map.put(normalized, :extra, []),
          Map.delete(normalized, :port),
          Map.from_struct(normalized)
        ] do
      reject(:validate_response, [%{response() | url: uri}, url])
    end

    root = "https://upstream.test"
    reject(:validate_response, [%{response() | url: %{URI.parse(root) | authority: nil}}, root])
  end

  test "normalized URI preflights equal-valued source backing before complete serialization" do
    host = :binary.copy("h", 100)
    path = "/" <> :binary.copy("p", 99)
    query = :binary.copy("q", 100)
    url = :binary.copy("https://" <> host <> path <> "?" <> query)
    normalized = %{URI.parse(url) | authority: nil}

    assert {:ok, _} = call(:validate_response, [%{response() | url: normalized}, url])

    for key <- [:host, :path, :query] do
      retained = slice(Map.fetch!(normalized, key), 65_537)
      assert :binary.referenced_byte_size(retained) == 65_537
      assert Map.put(normalized, key, retained) == normalized
      reject(:validate_response, [%{response() | url: Map.put(normalized, key, retained)}, url])
    end

    aggregate =
      Enum.reduce([:host, :path, :query], normalized, fn key, uri ->
        Map.put(uri, key, slice(Map.fetch!(uri, key), 65_536))
      end)

    assert aggregate == normalized

    assert Enum.sum(
             Enum.map(
               [aggregate.host, aggregate.path, aggregate.query],
               &:binary.referenced_byte_size/1
             )
           ) > 132_096

    reject(:validate_response, [%{response() | url: aggregate}, url])
  end

  test "initial heads enforce exact count and bytes before normalization or backing copy" do
    for fields <- [List.duplicate({"x", ""}, 256), [{"x", :binary.copy("v", 65_535)}]] do
      assert {:ok, %{fields: ^fields}} =
               call(:validate_response, [
                 %{response() | headers: %HTTP.Headers{headers: fields}},
                 source().url
               ])
    end

    for fields <- [
          List.duplicate({"x", ""}, 257),
          [{"x", :binary.copy("v", 65_536)}],
          [{"x", slice(:binary.copy("v", 100), 65_537)}],
          [{"x", "v"} | :improper],
          [{"x", :bad}],
          [{"x", "\n"}],
          [{"bad name", "v"}]
        ] do
      reject(:validate_response, [
        %{response() | headers: %HTTP.Headers{headers: fields}},
        source().url
      ])
    end
  end

  test "informational block count and aggregate field count have independent ceilings" do
    # Even empty values cost one name byte plus32 overhead:2,048 such fields
    # cannot simultaneously satisfy the65,536-byte cap. Use the feasible max.
    assert 2048 * 33 > 65_536
    assert 1985 * 33 <= 65_536
    info = List.duplicate({103, %HTTP.Headers{headers: List.duplicate({"x", ""}, 15)}}, 127)
    info = info ++ [{103, %HTTP.Headers{headers: List.duplicate({"x", ""}, 80)}}]

    assert {:ok, _} =
             call(:validate_response, [%{response() | informational: info}, source().url])

    for bad <- [
          info ++ [{103, %HTTP.Headers{}}],
          [{99, %HTTP.Headers{}}],
          [{200, %HTTP.Headers{}}],
          [{103, %HTTP.Headers{}} | :improper],
          [{103, []}],
          [{103, Map.put(%HTTP.Headers{}, :extra, [])}],
          List.duplicate({103, %HTTP.Headers{headers: List.duplicate({"x", ""}, 16)}}, 128),
          [
            {103, %HTTP.Headers{headers: List.duplicate({"x", ""}, 17)}}
            | List.duplicate({103, %HTTP.Headers{headers: List.duplicate({"x", ""}, 16)}}, 127)
          ]
        ] do
      reject(:validate_response, [%{response() | informational: bad}, source().url])
    end
  end

  test "informational aggregate bytes includes per-field32 overhead and source backing" do
    fields = [{"x", :binary.copy("v", 65_503)}]
    assert 1 + 65_503 + 32 == 65_536

    assert {:ok, _} =
             call(:validate_response, [
               %{response() | informational: [{103, %HTTP.Headers{headers: fields}}]},
               source().url
             ])

    for fields <- [
          [{"x", :binary.copy("v", 65_504)}],
          [{"x", slice(:binary.copy("v", 100), 65_537)}]
        ] do
      reject(:validate_response, [
        %{response() | informational: [{103, %HTTP.Headers{headers: fields}}]},
        source().url
      ])
    end
  end

  defp call(function, args), do: apply(@envelope, function, args)

  defp compact_uri(origin) do
    Map.new(Map.to_list(URI.parse(origin)), fn
      {key, value} when is_binary(value) -> {key, :binary.copy(value)}
      pair -> pair
    end)
  end

  defp reject(function, args) do
    assert {:error, reason} = call(function, args)
    assert is_atom(reason)
  end

  defp config(protocol \\ :http2) do
    %Gaoxy.Proxy.HTTP{
      uri:
        URI.parse(
          if(protocol == :http2, do: "https://upstream.test", else: "http://upstream.test")
        ),
      cacertfile: nil,
      connect_address: nil,
      transport: %{
        provider: Gaoxy.Proxy.UpstreamTransports,
        owner: self(),
        owner_epoch: make_ref(),
        resource: make_ref()
      },
      upstream_protocol: protocol,
      client: Gaoxy.Proxy.ManagedH2Client,
      limits: %{
        max_chunk_bytes: 65_536,
        opening_timeout: 5_000,
        idle_timeout: 60_000,
        write_timeout: 5_000,
        max_lifetime: 30_000
      }
    }
  end

  defp source(protocol \\ :http2) do
    %{
      url:
        if(protocol == :http2,
          do: "https://upstream.test/a%2Fb?",
          else: "http://upstream.test/a%2Fb?"
        ),
      target: "/a%2Fb?",
      method: :post,
      fields: [{"content-length", "3"}, {"x-trace", "first"}, {"x-trace", "second"}],
      body_mode: {:length, 3},
      max_upload_bytes: 65_536,
      request_limits: %{
        max_headers: 256,
        max_header_bytes: 65_536,
        max_trailers: 128,
        max_trailer_bytes: 65_536
      }
    }
  end

  defp checked_client(protocol \\ :http2) do
    {:ok, policy, _} =
      @preparation.prepare_policy(%{
        protocol: protocol,
        origin: if(protocol == :http2, do: "https://upstream.test", else: "http://upstream.test"),
        connect_address: {127, 0, 0, 1},
        trust: if(protocol == :http2, do: [<<48, 3, 2, 1, 1>>], else: nil)
      })

    %{
      policy: policy,
      transport_scope: struct(HTTP.ManagedTransport),
      fetch_options: [
        http_version: protocol,
        tls_backend: :ssl,
        http2_profile: :native_v1,
        http2_reuse: true,
        redirect: :manual,
        request_mode: :proxy,
        decode_body: false,
        stream_response: true,
        telemetry: false
      ]
    }
  end

  defp trailer_policy,
    do: %{allowed: ["x-trace"], dropped: ["connection"], max_count: 128, max_bytes: 65_536}

  defp response do
    %HTTP.Response{
      status: 200,
      status_text: "OK",
      ok: true,
      headers: %HTTP.Headers{headers: [{"x-trace", "first"}, {"x-trace", "second"}]},
      body: nil,
      body_used: false,
      url: URI.parse(source().url),
      redirected: false,
      type: :basic,
      stream: nil,
      http_version: :http2,
      informational: [],
      trailers: %HTTP.Headers{}
    }
  end

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
