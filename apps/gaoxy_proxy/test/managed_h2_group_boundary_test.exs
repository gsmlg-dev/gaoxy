defmodule Gaoxy.Proxy.ManagedH2GroupBoundaryTest do
  use ExUnit.Case, async: true

  @boundary Gaoxy.Proxy.ManagedH2GroupBoundary
  @envelope Gaoxy.Proxy.ManagedH2Envelope
  @selected_keys ~w(id config max_inflight)a
  @context_keys ~w(group instance limits deadline opening_deadline now)a
  @group_keys ~w(provider owner owner_epoch group generation max_url_bytes transports execution_profile)a
  @option_keys ~w(request managed_transport timeout opening_timeout write_timeout deadline opening_deadline)a
  @signed_min -9_223_372_036_854_775_808
  @signed_max 9_223_372_036_854_775_807
  @day 86_400_000

  test "both protocols return only the exact opening envelope and effective limits" do
    for protocol <- [:http2, :h2c] do
      {selected, neutral, checked, context} = fixture(protocol)
      assert {:ok, options, effective} = prepare(selected, neutral, checked, context)
      assert Enum.sort(Map.keys(options)) == Enum.sort(@option_keys)
      assert effective == context.limits
      assert options.managed_transport === checked
      assert options.timeout == 10_000
      assert options.opening_timeout == 2_000
      assert options.write_timeout == 3_000
      assert options.deadline == context.deadline
      assert options.opening_deadline == context.opening_deadline

      assert options.request ==
               Map.merge(neutral, %{
                 protocol: protocol,
                 url: raw_root(selected.config) <> neutral.target,
                 max_upload_bytes: effective.max_chunk_bytes
               })

      assert :ok == @envelope.validate_request(options.request)
      assert compact_tree?(options.request)
    end
  end

  test "effective limits are independently minimized for every endpoint and member key" do
    {selected, neutral, checked, context} = fixture()

    member = %{
      max_chunk_bytes: 2_048,
      opening_timeout: 3_000,
      idle_timeout: 9_000,
      write_timeout: 2_000,
      max_lifetime: 20_000
    }

    endpoint = %{
      max_chunk_bytes: 4_096,
      opening_timeout: 2_000,
      idle_timeout: 10_000,
      write_timeout: 3_000,
      max_lifetime: 10_000
    }

    selected = %{selected | config: %{selected.config | limits: member}}
    context = %{context | limits: endpoint}

    expected = %{
      max_chunk_bytes: 2_048,
      opening_timeout: 2_000,
      idle_timeout: 9_000,
      write_timeout: 2_000,
      max_lifetime: 10_000
    }

    assert {:ok, options, ^expected} = prepare(selected, neutral, checked, context)
    assert options.request.max_upload_bytes == 2_048
    assert options.write_timeout == 2_000
    assert options.deadline == context.deadline
    assert options.opening_deadline == context.opening_deadline
  end

  test "upload reduction preserves smaller original uploads and all other neutral fields" do
    {selected, neutral, checked, context} = fixture()

    for upload <- [1, 1_024, 4_096, 65_536], mode <- [:none, :chunked, {:length, 3}] do
      input = %{neutral | max_upload_bytes: upload, body_mode: mode}
      assert {:ok, options, limits} = prepare(selected, input, checked, context)
      assert options.request.max_upload_bytes == min(upload, limits.max_chunk_bytes)

      assert Map.drop(options.request, [:url, :protocol, :max_upload_bytes]) ==
               Map.delete(input, :max_upload_bytes)
    end
  end

  test "original invalid upload cannot become valid by reduction" do
    {selected, neutral, checked, context} = fixture()

    for upload <- [0, 65_537, :infinity, nil, 1.0] do
      reject(selected, %{neutral | max_upload_bytes: upload}, checked, context)
    end
  end

  test "original neutral requires the exact compact validated source shape" do
    {selected, neutral, checked, context} = fixture()

    for bad <- [
          nil,
          [],
          %{},
          Map.put(neutral, :url, "https://other.test/"),
          Map.put(neutral, :extra, fn -> :not_retained end),
          Map.put(neutral, :__struct__, URI)
        ] do
      reject(selected, bad, checked, context)
    end

    for key <- Map.keys(neutral), do: reject(selected, Map.delete(neutral, key), checked, context)

    for bad <- [
          %{neutral | target: slice(target(101), 4_096)},
          %{neutral | fields: [{slice(:binary.copy("n", 100), 4_096), "v"}]},
          %{neutral | fields: [{"x", slice(:binary.copy("v", 100), 4_096)}]}
        ] do
      assert {:error, :invalid_group_source} = @envelope.validate_group_source(bad)
      reject(selected, bad, checked, context)
    end
  end

  test "neutral finite grammar body lengths and field limits remain enforced" do
    {selected, neutral, checked, context} = fixture()

    for method <- [:get, :head, :post, :put, :patch, :delete, :options],
        mode <- [:none, :chunked, {:length, 0}, {:length, 18_446_744_073_709_551_615}] do
      assert {:ok, _, _} =
               prepare(selected, %{neutral | method: method, body_mode: mode}, checked, context)
    end

    for change <- [
          %{method: :connect},
          %{method: :trace},
          %{method: "GET"},
          %{body_mode: {:length, -1}},
          %{body_mode: {:length, 18_446_744_073_709_551_616}},
          %{body_mode: {:length, 1.0}},
          %{body_mode: {:length, 1, :extra}},
          %{target: "/%gg"},
          %{target: "https://other.test/"},
          %{target: "/bad\r\n"},
          %{fields: [{"x", "v"} | :improper]},
          %{fields: [{"x", <<0>>}]},
          %{fields: List.duplicate({"x", ""}, 257)},
          %{request_limits: Map.put(neutral.request_limits, :extra, 1)}
        ] do
      reject(selected, Map.merge(neutral, change), checked, context)
    end

    for {key, cap} <- neutral.request_limits, bad <- [0, cap + 1, 1.0, nil, :infinity] do
      reject(
        selected,
        %{neutral | request_limits: Map.put(neutral.request_limits, key, bad)},
        checked,
        context
      )
    end
  end

  test "selected effective pseudoheaders and content length validation are preserved" do
    {selected, neutral, checked, context} = fixture()

    assert {:ok, _, _} =
             prepare(
               selected,
               %{neutral | fields: List.duplicate({"x", ""}, 251)},
               checked,
               context
             )

    assert {:ok, options, _} =
             prepare(
               selected,
               %{
                 neutral
                 | fields: [{"Content-Length", "3"}, {"x", "a"}, {"x", "b"}],
                   body_mode: {:length, 3}
               },
               checked,
               context
             )

    assert options.request.fields == [{"Content-Length", "3"}, {"x", "a"}, {"x", "b"}]

    for fields <- [
          List.duplicate({"x", ""}, 252),
          [{"host", "other.test"}],
          [{"connection", "close"}],
          [{"te", "gzip"}],
          [{"content-length", "bad"}],
          [{"content-length", "3"}, {"content-length", "4"}],
          [{"x", :binary.copy("v", 65_535)}]
        ] do
      reject(selected, %{neutral | fields: fields}, checked, context)
    end

    for request_limits <- [
          %{neutral.request_limits | max_headers: 4},
          %{neutral.request_limits | max_header_bytes: 1}
        ] do
      reject(selected, %{neutral | fields: [], request_limits: request_limits}, checked, context)
    end
  end

  test "selected is exactly the compact owner checkout member without expanded health state" do
    {selected, neutral, checked, context} = fixture()

    for bad <- [
          nil,
          [],
          %{},
          selected.config,
          Map.put(selected, :health, :healthy),
          Map.put(selected, :extra, fn -> :not_retained end),
          Map.put(selected, :__struct__, Gaoxy.Proxy.HTTP)
        ] do
      reject(bad, neutral, checked, context)
    end

    for key <- @selected_keys, do: reject(Map.delete(selected, key), neutral, checked, context)

    for id <- ["a", :binary.copy("i", 128)], count <- [1, 1_024] do
      assert {:ok, _, _} =
               prepare(%{selected | id: id, max_inflight: count}, neutral, checked, context)
    end

    for id <- ["", :binary.copy("i", 129), slice(:binary.copy("i", 100), 4_096), nil, 1] do
      reject(%{selected | id: id}, neutral, checked, context)
    end

    for count <- [0, 1_025, 1.0, nil, :infinity] do
      reject(%{selected | max_inflight: count}, neutral, checked, context)
    end
  end

  test "selected config must satisfy the supported exact fixed managed H2 schema" do
    {selected, neutral, checked, context} = fixture()

    for config <- [
          nil,
          [],
          Map.from_struct(selected.config),
          Map.put(selected.config, :extra, []),
          %{selected.config | client: Gaoxy.Proxy.HTTPFetchClient},
          %{selected.config | transport: nil},
          %{selected.config | upstream_protocol: :http1},
          %{selected.config | upstream_protocol: :h2c},
          %{selected.config | uri: compact_uri("https://user@upstream.test")},
          %{selected.config | uri: compact_uri("https://upstream.test/path")},
          %{selected.config | cacertfile: "/tmp/ca"},
          %{selected.config | connect_address: {127, 0, 0, 1}}
        ] do
      reject(%{selected | config: config}, neutral, checked, context)
    end
  end

  test "context accepts only the six declared keys and a PID-shaped instance" do
    {selected, neutral, checked, context} = fixture()
    assert Enum.sort(Map.keys(context)) == Enum.sort(@context_keys)

    for bad <- [
          nil,
          [],
          %{},
          Map.put(context, :authority, make_ref()),
          Map.put(context, :extra, fn -> :not_retained end),
          Map.put(context, :__struct__, URI)
        ] do
      reject(selected, neutral, checked, bad)
    end

    for key <- @context_keys, do: reject(selected, neutral, checked, Map.delete(context, key))

    for instance <- [nil, make_ref(), :instance, 1] do
      reject(selected, neutral, checked, %{context | instance: instance})
    end
  end

  test "group handle has an exact finite H2 profile and identity shell" do
    {selected, neutral, checked, context} = fixture()
    group = context.group
    assert Enum.sort(Map.keys(group)) == Enum.sort(@group_keys)

    for bad <- [nil, [], %{}, Map.put(group, :extra, []), Map.put(group, :__struct__, URI)] do
      reject(selected, neutral, checked, %{context | group: bad})
    end

    for key <- @group_keys,
        do: reject(selected, neutral, checked, %{context | group: Map.delete(group, key)})

    for change <- [
          %{provider: Gaoxy.Proxy.UpstreamTransports},
          %{owner: make_ref()},
          %{owner_epoch: self()},
          %{generation: nil},
          %{execution_profile: :managed_h1},
          %{execution_profile: "managed_h2"},
          %{group: ""},
          %{group: :group},
          %{group: :binary.copy("g", 129)},
          %{group: slice(:binary.copy("g", 100), 4_096)},
          %{max_url_bytes: 0},
          %{max_url_bytes: 8_193},
          %{max_url_bytes: 1.0},
          %{max_url_bytes: :infinity}
        ] do
      reject(selected, neutral, checked, %{context | group: Map.merge(group, change)})
    end

    for id <- ["g", :binary.copy("g", 128)] do
      assert {:ok, _, _} =
               prepare(selected, neutral, checked, %{context | group: %{group | group: id}})
    end
  end

  test "transport membership is exact and all handles in the proper manifest are validated" do
    {selected, neutral, checked, context} = fixture()
    transport = selected.config.transport

    for transports <- [
          nil,
          [],
          [transport | :improper],
          [transport, transport],
          [transport, nil],
          [transport, Map.put(transport, :extra, [])],
          [transport, %{transport | provider: Gaoxy.Proxy.UpstreamGroups}],
          [transport, %{transport | owner: make_ref()}],
          [transport, %{transport | owner_epoch: nil}],
          [transport, %{transport | resource: self()}],
          [%{transport | resource: make_ref()}]
        ] do
      reject(selected, neutral, checked, %{
        context
        | group: %{context.group | transports: transports}
      })
    end

    for key <- Map.keys(transport) do
      bad = Map.delete(transport, key)

      reject(selected, neutral, checked, %{
        context
        | group: %{context.group | transports: [transport, bad]}
      })
    end

    changed = %{
      selected
      | config: %{selected.config | transport: %{transport | owner_epoch: make_ref()}}
    }

    reject(changed, neutral, checked, context)
  end

  test "both unique supplied orders are accepted without authority inference or sorting" do
    {selected, neutral, checked, context} = fixture()
    first = selected.config.transport
    second = transport()

    for transports <- [[first, second], [second, first]] do
      group = %{context.group | transports: transports}
      assert {:ok, options, _} = prepare(selected, neutral, checked, %{context | group: group})
      assert options.managed_transport === checked
      assert options.request.url == raw_root(selected.config) <> neutral.target
      assert group.transports === transports
    end
  end

  test "maximal proper group manifest remains subject to complete flattened resource caps" do
    {selected, neutral, checked, context} = fixture()
    transports = [selected.config.transport | Enum.map(1..31, fn _ -> transport() end)]
    group = %{context.group | group: :binary.copy("g", 128), transports: transports}
    flattened = [group | transports]
    assert length(flattened) == 33
    assert :erlang.external_size(flattened) <= 65_536
    assert {:ok, ^flattened} = Gaoxy.HTTP.Resources.validate(flattened)
    assert {:ok, _, _} = prepare(selected, neutral, checked, %{context | group: group})

    reject(selected, neutral, checked, %{
      context
      | group: %{group | transports: transports ++ [transport()]}
    })
  end

  test "checked client requires exact supported public policy scope and fetch options" do
    {selected, neutral, checked, context} = fixture()

    for bad <- [
          nil,
          [],
          %{},
          Map.put(checked, :extra, []),
          %{checked | transport_scope: nil},
          %{checked | transport_scope: Map.put(checked.transport_scope, :extra, [])},
          %{checked | policy: Map.put(checked.policy, :extra, [])},
          %{checked | fetch_options: checked.fetch_options ++ [redirect: :manual]},
          %{checked | fetch_options: [{:http_version, :http2} | :improper]}
        ] do
      reject(selected, neutral, bad, context)
    end

    for key <- Map.keys(checked), do: reject(selected, neutral, Map.delete(checked, key), context)

    for key <- Keyword.keys(checked.fetch_options) do
      reject(
        selected,
        neutral,
        %{checked | fetch_options: Keyword.delete(checked.fetch_options, key)},
        context
      )
    end
  end

  test "policy protocol and normalized authority must match the selected endpoint" do
    for protocol <- [:http2, :h2c] do
      {selected, neutral, checked, context} = fixture(protocol)
      scheme = if protocol == :http2, do: "https", else: "http"
      port = if protocol == :http2, do: 443, else: 80
      raw = scheme <> "://UPSTREAM.test:000" <> Integer.to_string(port)
      selected = %{selected | config: %{selected.config | uri: compact_uri(raw)}}
      assert {:ok, options, _} = prepare(selected, neutral, checked, context)
      assert options.request.url == raw <> neutral.target

      for origin <- [scheme <> "://other.test", scheme <> "://upstream.test:444"] do
        mismatch = checked_client(protocol, origin)
        assert :ok == @envelope.validate_checked_client(mismatch, protocol)
        reject(selected, neutral, mismatch, context)
      end

      other = if protocol == :http2, do: :h2c, else: :http2
      reject(selected, neutral, checked_client(other), context)
    end
  end

  test "raw root escape case leading slashes and present empty query survive assembly" do
    for protocol <- [:http2, :h2c],
        raw_target <- [
          "/",
          "/a%2fb%2F?x=%2f%2F",
          "//other.test/a%2Fb?",
          "///a",
          "/a",
          "/a?",
          "/a??x"
        ] do
      {selected, neutral, checked, context} = fixture(protocol)

      assert {:ok, options, _} =
               prepare(selected, %{neutral | target: raw_target}, checked, context)

      assert options.request.target == raw_target
      assert options.request.url == raw_root(selected.config) <> raw_target
      assert URI.parse(options.request.url).host == selected.config.uri.host

      query =
        if String.contains?(raw_target, "?"),
          do: raw_target |> String.split("?", parts: 2) |> List.last(),
          else: nil

      assert URI.parse(options.request.url).query == query
    end
  end

  test "selected root must fit the advertised group bound independently of normalized authority" do
    {selected, neutral, checked, context} = fixture()
    size = byte_size(raw_root(selected.config))

    assert {:ok, _, _} =
             prepare(selected, neutral, checked, %{
               context
               | group: %{context.group | max_url_bytes: size}
             })

    reject(selected, neutral, checked, %{
      context
      | group: %{context.group | max_url_bytes: size - 1}
    })

    raw = raw_port_origin(8_192)
    selected = %{selected | config: %{selected.config | uri: compact_uri(raw)}}
    assert {:ok, options, _} = prepare(selected, neutral, checked, context)
    assert options.request.url == raw <> neutral.target

    reject(selected, neutral, checked, %{context | group: %{context.group | max_url_bytes: 8_191}})

    over = %{selected | config: %{selected.config | uri: compact_uri(raw_port_origin(8_193))}}
    assert :ok == @envelope.validate_config(over.config)
    reject(over, neutral, checked, context)
  end

  test "advertised and actual root plus target bounds are inclusive and coupled" do
    {selected, neutral, checked, context} = fixture()
    at_limit = %{neutral | target: target(65_536 - 8_192)}
    assert {:ok, short, _} = prepare(selected, at_limit, checked, context)
    assert byte_size(short.request.url) < 65_536
    reject(selected, %{neutral | target: target(65_536 - 8_192 + 1)}, checked, context)
    raw = raw_port_origin(8_192)
    selected = %{selected | config: %{selected.config | uri: compact_uri(raw)}}
    assert {:ok, full, _} = prepare(selected, at_limit, checked, context)
    assert byte_size(full.request.url) == 65_536
    assert full.request.url == raw <> at_limit.target
    reject(selected, %{neutral | target: target(65_536 - 8_192 + 1)}, checked, context)
  end

  test "endpoint and member limits have exactly five finite bounded integer values" do
    {selected, neutral, checked, context} = fixture()

    for key <- Map.keys(context.limits) do
      cap = if key == :max_chunk_bytes, do: 65_536, else: @day

      for value <- [1, cap] do
        limits = Map.put(context.limits, key, value)
        assert {:ok, _, _} = prepare(selected, neutral, checked, %{context | limits: limits})
        member = %{selected | config: %{selected.config | limits: limits}}
        assert {:ok, _, _} = prepare(member, neutral, checked, context)
      end

      for value <- [0, cap + 1, nil, 1.0, :infinity] do
        limits = Map.put(context.limits, key, value)
        reject(selected, neutral, checked, %{context | limits: limits})

        reject(
          %{selected | config: %{selected.config | limits: limits}},
          neutral,
          checked,
          context
        )
      end

      limits = Map.delete(context.limits, key)
      reject(selected, neutral, checked, %{context | limits: limits})
      reject(%{selected | config: %{selected.config | limits: limits}}, neutral, checked, context)
    end

    for limits <- [nil, [], Map.put(context.limits, :extra, 1)] do
      reject(selected, neutral, checked, %{context | limits: limits})
      reject(%{selected | config: %{selected.config | limits: limits}}, neutral, checked, context)
    end
  end

  test "remaining absolute budgets are finite inclusive and never renewed by preparation" do
    {selected, neutral, checked, context} = fixture()

    for {now, total, opening} <- [
          {0, 1, 1},
          {-100_000, @day, @day},
          {@signed_min, @day, 1},
          {@signed_max - 1_001, 1, 1}
        ] do
      input = %{context | now: now, deadline: now + total, opening_deadline: now + opening}
      assert {:ok, options, _} = prepare(selected, neutral, checked, input)
      assert options.timeout == total
      assert options.opening_timeout == opening
      assert options.deadline == input.deadline
      assert options.opening_deadline == input.opening_deadline
    end

    input = %{context | now: 11_999, deadline: 12_000, opening_deadline: 12_000}

    assert {:ok, %{timeout: 1, opening_timeout: 1, deadline: 12_000, opening_deadline: 12_000}, _} =
             prepare(selected, neutral, checked, input)
  end

  test "invalid expired reversed overflowed and cleanup-headroom deadlines reject" do
    {selected, neutral, checked, context} = fixture()

    for key <- [:now, :deadline, :opening_deadline],
        value <- [nil, 1.0, :infinity, @signed_min - 1, @signed_max + 1] do
      reject(selected, neutral, checked, Map.put(context, key, value))
    end

    for change <- [
          %{deadline: context.now},
          %{deadline: context.now - 1},
          %{opening_deadline: context.now},
          %{opening_deadline: context.now - 1},
          %{opening_deadline: context.deadline + 1},
          %{deadline: context.now + @day + 1},
          %{deadline: context.now + @day + 1, opening_deadline: context.now + @day + 1},
          %{now: @signed_min, deadline: @signed_max - 1_000, opening_deadline: @signed_min + 1},
          %{
            now: @signed_max - 1_000,
            deadline: @signed_max - 999,
            opening_deadline: @signed_max - 999
          },
          %{now: @signed_max - 1, deadline: @signed_max, opening_deadline: @signed_max}
        ] do
      reject(selected, neutral, checked, Map.merge(context, change))
    end
  end

  test "enabled accounting preserves preparation coherence and rejects a foreign transport" do
    assert :ok === apply(@boundary, :activation, [])
    {selected, neutral, checked, context} = fixture()
    assert {:ok, _, _} = prepare(selected, neutral, checked, context)

    foreign = %{
      selected
      | config: %{
          selected.config
          | transport: %{selected.config.transport | resource: make_ref()}
        }
    }

    reject(foreign, neutral, checked, context)
    assert :ok === apply(@boundary, :activation, [])
  end

  defp prepare(selected, neutral, checked, context),
    do: apply(@boundary, :prepare, [selected, neutral, checked, context])

  defp reject(selected, neutral, checked, context),
    do: assert({:error, :invalid_group_opening} == prepare(selected, neutral, checked, context))

  defp fixture(protocol \\ :http2) do
    transport = transport()

    config = %Gaoxy.Proxy.HTTP{
      uri: compact_uri(origin(protocol)),
      upstream_protocol: protocol,
      client: Gaoxy.Proxy.ManagedH2Client,
      cacertfile: nil,
      connect_address: nil,
      transport: transport,
      limits: limits()
    }

    selected = %{id: "member", config: config, max_inflight: 1}

    neutral = %{
      target: "/a%2Fb?",
      method: :post,
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

    group = %{
      provider: Gaoxy.Proxy.UpstreamGroups,
      owner: self(),
      owner_epoch: make_ref(),
      group: "group",
      generation: make_ref(),
      max_url_bytes: 8_192,
      transports: [transport],
      execution_profile: :managed_h2
    }

    context = %{
      group: group,
      instance: self(),
      limits: %{limits() | max_chunk_bytes: 4_096},
      now: 10_000,
      deadline: 20_000,
      opening_deadline: 12_000
    }

    {selected, neutral, checked_client(protocol), context}
  end

  defp limits,
    do: %{
      max_chunk_bytes: 65_536,
      opening_timeout: 5_000,
      idle_timeout: 60_000,
      write_timeout: 3_000,
      max_lifetime: 30_000
    }

  # Supported public handle shells establish pure coherence, not live authority.
  defp transport,
    do: %{
      provider: Gaoxy.Proxy.UpstreamTransports,
      owner: self(),
      owner_epoch: make_ref(),
      resource: make_ref()
    }

  defp origin(:http2), do: "https://upstream.test"
  defp origin(:h2c), do: "http://upstream.test"

  defp checked_client(protocol, origin \\ nil) do
    {:ok, policy, _} =
      Gaoxy.Proxy.ManagedH2Preparation.prepare_policy(%{
        protocol: protocol,
        origin: origin || origin(protocol),
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

  defp compact_uri(origin) do
    Map.new(Map.to_list(URI.parse(origin)), fn
      {key, value} when is_binary(value) -> {key, :binary.copy(value)}
      pair -> pair
    end)
  end

  defp raw_root(config), do: config.uri.scheme <> "://" <> config.uri.authority

  defp raw_port_origin(bytes) do
    prefix = "https://upstream.test:"
    :binary.copy(prefix <> :binary.copy("0", bytes - byte_size(prefix) - 3) <> "443")
  end

  defp target(bytes), do: :binary.copy("/" <> :binary.copy("a", bytes - 1))

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
