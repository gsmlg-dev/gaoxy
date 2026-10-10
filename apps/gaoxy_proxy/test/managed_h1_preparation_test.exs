defmodule Gaoxy.Proxy.ManagedH1PreparationTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Proxy.ManagedH1Preparation, as: Preparation

  test "builds fixed numeric-pinned H1 options without opening a scope" do
    assert {:ok, policy, manifest} =
             Preparation.prepare_policy(%{
               origin: "http://example.test",
               connect_address: {127, 0, 0, 1},
               trust: nil
             })

    assert %Preparation.Policy{
             origin: "http://example.test",
             scheme: :http,
             host: "example.test",
             port: 80,
             connect_address: {127, 0, 0, 1}
           } = policy

    assert [
             origin: "http://example.test",
             connect_address: {127, 0, 0, 1},
             http_version: :http1,
             tls_backend: :ssl,
             http2_profile: :native_v1,
             max_requests: 32,
             max_connections: 2,
             max_pending: 0,
             idle_timeout: 30_000,
             ssl: [],
             socket_opts: [
               buffer: 8192,
               recbuf: 8192,
               sndbuf: 8192,
               nodelay: true,
               send_timeout: 30_000,
               send_timeout_close: true
             ]
           ] = policy.open_options

    assert %{kind: :policy, source: %{backing_bytes: 19}} = manifest
  end

  test "accepts bounded origins, default ports and numeric IPv6 dialing" do
    for origin <- ["http://example.test", "http://example.test/", "https://EXAMPLE.test:443"] do
      trust = if String.starts_with?(origin, "https"), do: ["opaque"], else: nil

      assert {:ok, _, _} =
               Preparation.prepare_policy(%{policy_source() | origin: origin, trust: trust})
    end

    assert {:ok, %Preparation.Policy{host: "::1", port: 65535}, _} =
             Preparation.prepare_policy(%{
               policy_source()
               | origin: "http://[::1]:65535",
                 connect_address: {0, 0, 0, 0, 0, 0, 0, 1}
             })

    assert {:ok, _, _} =
             Preparation.prepare_policy(%{policy_source() | origin: "http://example.test:1"})

    host = :binary.copy("a", 253)

    assert {:ok, _, _} =
             Preparation.prepare_policy(%{policy_source() | origin: "http://" <> host})

    assert {:error, :invalid_url} =
             Preparation.prepare_policy(%{policy_source() | origin: "http://" <> host <> "a"})
  end

  test "rejects unsupported policy trees, source options and origin text" do
    for value <- [
          %{},
          URI.parse("http://example.test"),
          [],
          "http://example.test",
          Map.put(policy_source(), :ssl, []),
          Map.delete(policy_source(), :trust),
          Map.new(1..2000, &{&1, []})
        ] do
      assert {:error, :invalid_policy} = Preparation.prepare_policy(value)
    end

    for origin <- [
          "http://user:secret@example.test",
          "http://example.test#",
          "http://example.test?",
          "http://example.test/nonroot",
          "ftp://example.test",
          "http://example.test:0",
          "http://example.test:65536",
          "http://example.test:%",
          "http://example.test/%2",
          "http://example.test/%gg",
          "http://exa mple.test",
          "http://example.test\\",
          "http://example.test\n",
          "http://exämple.test",
          "",
          :binary.copy("a", 65_536),
          :binary.copy("a", 65_537),
          ~c"http://example.test"
        ] do
      assert {:error, :invalid_url} =
               Preparation.prepare_policy(%{policy_source() | origin: origin})
    end

    for address <- [
          nil,
          "127.0.0.1",
          [127, 0, 0, 1],
          {256, 0, 0, 1},
          {-1, 0, 0, 1},
          {1, 2, 3},
          {0, 0, 0, 0, 0, 0, 0, 65_536},
          {1, 2, 3, :bad}
        ] do
      assert {:error, :invalid_policy} =
               Preparation.prepare_policy(%{policy_source() | connect_address: address})
    end
  end

  test "uses explicit opaque HTTPS trust and fixed SSL values" do
    assert {:ok, policy, _} =
             Preparation.prepare_policy(tls_source(["-----BEGIN CERTIFICATE-----"]))

    assert [
             verify: :verify_peer,
             depth: 4,
             versions: [:"tlsv1.3", :"tlsv1.2"],
             cacerts: ["-----BEGIN CERTIFICATE-----"],
             server_name_indication: ~c"example.test"
           ] =
             policy.open_options[:ssl]

    for trust <- [
          nil,
          [],
          "file.pem",
          ~c"file.pem",
          %{cacertfile: "file.pem"},
          [cacertfile: "file.pem"],
          [fn -> :bad end],
          [""],
          ["valid" | :bad]
        ] do
      assert {:error, :invalid_trust} = Preparation.prepare_policy(tls_source(trust))
    end

    assert {:error, :invalid_trust} =
             Preparation.prepare_policy(%{policy_source() | trust: ["opaque"]})
  end

  test "enforces trust count, per-leaf, aggregate and final ETF independently" do
    assert {:ok, _, _} = Preparation.prepare_policy(tls_source(List.duplicate("x", 128)))

    assert {:error, :trust_limit} =
             Preparation.prepare_policy(tls_source(List.duplicate("x", 129)))

    cert = :binary.copy("x", 65_536)
    assert {:ok, _, _} = Preparation.prepare_policy(tls_source([cert]))
    assert {:error, :trust_limit} = Preparation.prepare_policy(tls_source([cert <> "x"]))
    assert {:ok, _, _} = Preparation.prepare_policy(tls_source(List.duplicate(cert, 15)))

    assert {:error, :policy_limit} =
             Preparation.prepare_policy(tls_source(List.duplicate(cert, 16)))

    assert {:error, :trust_limit} =
             Preparation.prepare_policy(tls_source(List.duplicate(cert, 16) ++ ["x"]))
  end

  test "checks trust and origin backing before compact copies" do
    huge = :binary.copy("x", 65_537)
    cert = binary_part(huge, 20, 80)
    assert :binary.referenced_byte_size(cert) == 65_537
    assert {:error, :source_backing_limit} = Preparation.prepare_policy(tls_source([cert]))
    parent = :binary.copy("x", 16_384)
    cert = binary_part(parent, 20, 80)

    assert {:error, :source_backing_limit} =
             Preparation.prepare_policy(tls_source(List.duplicate(cert, 65)))

    origin = "http://" <> :binary.copy("a", 80) <> ".test"
    huge = :binary.copy(origin <> :binary.copy("x", 65_537 - byte_size(origin)))
    origin = binary_part(huge, 0, byte_size(origin))
    assert :binary.referenced_byte_size(origin) == 65_537

    assert {:error, :source_backing_limit} =
             Preparation.prepare_policy(%{policy_source() | origin: origin})
  end

  test "preserves ordered fields, escaping and a present empty query" do
    assert {:ok, prepared, _} = Preparation.prepare_request(policy(), request())

    assert %Preparation.Request{
             url: "http://example.test/upload?",
             target: "/upload?",
             method: :post,
             fields: [{"X-Repeat", "first"}, {"x-repeat", "second"}],
             body: nil,
             trailers: [],
             timeout: 1_000,
             connect_timeout: 500
           } = prepared

    for {url, target} <- [
          {"http://example.test", "/"},
          {"http://EXAMPLE.test:80/%2f?a=2&a=1", "/%2f?a=2&a=1"}
        ] do
      assert {:ok, %Preparation.Request{url: ^url, target: ^target}, _} =
               Preparation.prepare_request(policy(), %{request() | url: url})
    end
  end

  test "permits PID uploads and ordered duplicate declared trailers" do
    source = %{
      request()
      | body: self(),
        fields: [{"Trailer", "x-end"}],
        trailers: [{"X-End", "one"}, {"x-end", "two"}]
    }

    assert {:ok, %Preparation.Request{body: pid, trailers: [{"X-End", "one"}, {"x-end", "two"}]},
            _} =
             Preparation.prepare_request(policy(), source)

    assert pid == self()
  end

  test "validates canonical policy grammar and consistency without provenance" do
    canonical = policy()

    assert {:ok, _, _} =
             Preparation.prepare_request(
               struct(Preparation.Policy, Map.from_struct(canonical)),
               request()
             )

    for modified <- [
          %{canonical | host: "other.test"},
          %{canonical | scheme: :https},
          %{canonical | port: 81},
          %{canonical | open_options: List.duplicate([], 50_000)},
          %{canonical | open_options: Keyword.put(canonical.open_options, :max_requests, 33)},
          Map.put(canonical, :extra, :bad),
          Map.from_struct(canonical),
          nil
        ] do
      assert {:error, :invalid_policy} = Preparation.prepare_request(modified, request())
    end
  end

  test "enforces URL and target plus field byte boundaries separately" do
    prefix = "http://example.test/"
    url = prefix <> :binary.copy("a", 65_536 - byte_size(prefix))
    url = :binary.copy(url)

    assert {:ok, _, _} =
             Preparation.prepare_request(policy(), %{request() | url: url, fields: []})

    assert {:error, :invalid_url} =
             Preparation.prepare_request(policy(), %{request() | url: url <> "a", fields: []})

    source = %{
      request()
      | url: "http://example.test/",
        fields: [{"x", :binary.copy("v", 65_502)}]
    }

    assert {:ok, _, _} = Preparation.prepare_request(policy(), source)

    assert {:error, :request_limit} =
             Preparation.prepare_request(policy(), %{
               source
               | fields: [{"x", :binary.copy("v", 65_503)}]
             })

    assert {:error, :request_limit} =
             Preparation.prepare_request(policy(), %{source | url: "http://example.test/?"})
  end

  test "enforces field and trailer counts without visiting excess content" do
    fields = List.duplicate({"x", ""}, 256)
    assert {:ok, _, _} = Preparation.prepare_request(policy(), %{request() | fields: fields})

    assert {:error, :request_limit} =
             Preparation.prepare_request(policy(), %{request() | fields: fields ++ [{"x", ""}]})

    huge_tail = List.duplicate([], 50_000)

    assert {:error, :request_limit} =
             Preparation.prepare_request(policy(), %{request() | fields: fields ++ [huge_tail]})

    trailers = List.duplicate({"x", ""}, 128)
    source = %{request() | body: self(), fields: [{"trailer", "x"}], trailers: trailers}
    assert {:ok, _, _} = Preparation.prepare_request(policy(), source)

    assert {:error, :trailer_limit} =
             Preparation.prepare_request(policy(), %{source | trailers: trailers ++ [{"x", ""}]})

    assert {:error, :trailer_limit} =
             Preparation.prepare_request(policy(), %{source | trailers: trailers ++ [huge_tail]})

    assert {:error, :trust_limit} =
             Preparation.prepare_policy(tls_source(List.duplicate("x", 128) ++ [huge_tail]))
  end

  test "enforces exact trailer wire bytes" do
    source = %{
      request()
      | body: self(),
        fields: [{"trailer", "x"}],
        trailers: [{"x", :binary.copy("v", 65_529)}]
    }

    assert {:ok, _, _} = Preparation.prepare_request(policy(), source)

    assert {:error, :trailer_limit} =
             Preparation.prepare_request(policy(), %{
               source
               | trailers: [{"x", :binary.copy("v", 65_530)}]
             })
  end

  test "admits only the method enum, nil or PID body and finite timeout integers" do
    for method <- [:get, :head, :post, :put, :delete, :patch, :options],
        body <- [nil, self()],
        timeout <- [1, 86_400_000] do
      assert {:ok, _, _} =
               Preparation.prepare_request(policy(), %{
                 request()
                 | method: method,
                   body: body,
                   timeout: timeout,
                   connect_timeout: timeout
               })
    end

    for change <- [
          %{method: "GET"},
          %{method: :connect},
          %{method: :trace},
          %{body: ""},
          %{body: ["buffered"]},
          %{body: fn -> :bad end},
          %{timeout: :infinity},
          %{timeout: 0},
          %{timeout: 86_400_001},
          %{timeout: 1.0},
          %{connect_timeout: 0},
          %{connect_timeout: 86_400_001}
        ] do
      assert {:error, :invalid_request} =
               Preparation.prepare_request(policy(), Map.merge(request(), change))
    end
  end

  test "rejects unsupported source maps, malformed pairs and improper lists" do
    for source <- [
          nil,
          [],
          Map.put(request(), :content_type, "secret"),
          Map.put(request(), :duplex, :half),
          Map.put(request(), :options, []),
          Map.delete(request(), :timeout),
          Map.new(1..2000, &{&1, []})
        ] do
      assert {:error, :invalid_request} = Preparation.prepare_request(policy(), source)
    end

    for fields <- [
          [{"x", ~c"value"}],
          [{~c"x", "value"}],
          ["x"],
          [{"x", "v", "extra"}],
          [{"x", "v"} | :improper],
          %HTTP.Headers{headers: []},
          [[[]]]
        ] do
      assert {:error, :invalid_fields} =
               Preparation.prepare_request(policy(), %{request() | fields: fields})
    end

    for trailers <- [[{"x", "v"} | :improper], [[[]]], [{"x", :bad}]] do
      assert {:error, :invalid_trailers} =
               Preparation.prepare_request(policy(), %{
                 request()
                 | body: self(),
                   trailers: trailers
               })
    end
  end

  test "rejects mismatched origin, URI input and invalid URL octets" do
    for url <- [
          "http://other.test/upload?",
          "https://example.test/upload?",
          "http://example.test:81/"
        ] do
      assert {:error, :origin_mismatch} =
               Preparation.prepare_request(policy(), %{request() | url: url})
    end

    for url <- [
          URI.parse(request().url),
          ~c"http://example.test",
          "http://user:secret@example.test/",
          "http://example.test/#secret",
          "http://example.test/%",
          "http://example.test/%zz",
          "http://example.test/a b",
          "http://example.test/\r",
          "http://example.test/\\",
          "http://example.test/é"
        ] do
      assert {:error, :invalid_url} =
               Preparation.prepare_request(policy(), %{request() | url: url})
    end

    {:ok, ipv6, _} =
      Preparation.prepare_policy(%{
        policy_source()
        | origin: "http://[::1]",
          connect_address: {0, 0, 0, 0, 0, 0, 0, 1}
      })

    assert {:ok, %Preparation.Request{target: "/?x=%2f&x=1"}, _} =
             Preparation.prepare_request(ipv6, %{request() | url: "http://[::1]:80/?x=%2f&x=1"})
  end

  test "checks field tokens and binary values without changing duplicates" do
    for fields <- [
          [{"", "v"}],
          [{"bad name", "v"}],
          [{"ümlaut", "v"}],
          [{"x", "\r"}],
          [{"x", "\n"}],
          [{"x", <<0>>}],
          [{"x", <<127>>}]
        ] do
      assert {:error, :invalid_fields} =
               Preparation.prepare_request(policy(), %{request() | fields: fields})
    end

    value = <<9, 32, 128, 255>>

    assert {:ok, %Preparation.Request{fields: [{"x", ^value}]}, _} =
             Preparation.prepare_request(policy(), %{request() | fields: [{"x", value}]})
  end

  test "checks declarations, static and Connection-nominated forbidden trailers" do
    for {fields, trailers} <- [
          {[], [{"x", "v"}]},
          {[{"trailer", "x"}], [{"bad name", "v"}]},
          {[{"trailer", "content-length"}], [{"content-length", "1"}]},
          {[{"trailer", "authorization"}], [{"authorization", "secret"}]},
          {[{"trailer", "x"}, {"connection", "x"}], [{"x", "v"}]},
          {[{"trailer", "x"}], [{"x", "bad\n"}]},
          {[{"trailer", ""}], []},
          {[{"trailer", "x,"}], []},
          {[{"trailer", ",x"}], []},
          {[{"connection", "close,,x"}], []},
          {[{"trailer", "bad name"}], []}
        ] do
      assert {:error, :invalid_trailers} =
               Preparation.prepare_request(
                 policy(),
                 %{request() | body: self(), fields: fields, trailers: trailers}
               )
    end

    assert {:error, :invalid_trailers} =
             Preparation.prepare_request(
               policy(),
               %{request() | fields: [{"trailer", "x"}], trailers: [{"x", "v"}]}
             )

    assert {:ok, _, _} =
             Preparation.prepare_request(
               policy(),
               %{
                 request()
                 | body: self(),
                   fields: [{"trailer", " \tx , X\t "}],
                   trailers: [{"x", "v"}]
               }
             )
  end

  test "bounds declaration token counts across all fields in each class" do
    tokens = Enum.join(List.duplicate("x", 128), ",")

    for name <- ["trailer", "connection"] do
      assert {:ok, _, _} =
               Preparation.prepare_request(
                 policy(),
                 %{request() | fields: [{name, tokens}]}
               )

      for fields <- [[{name, tokens <> ",x"}], [{name, tokens}, {name, "x"}]] do
        assert {:error, :invalid_trailers} =
                 Preparation.prepare_request(policy(), %{request() | fields: fields})
      end
    end
  end

  test "copies every retained bounded slice and records old-source plus new-owned backing" do
    value = shared_slice(:binary.copy("v", 80))
    assert :binary.referenced_byte_size(value) == 8192
    source = %{request() | fields: [{"x", value}]}

    assert {:ok, %Preparation.Request{fields: [{"x", owned}]} = output, manifest} =
             Preparation.prepare_request(policy(), source)

    assert owned == value
    assert :binary.referenced_byte_size(owned) == 80
    assert manifest.source.backing_bytes == byte_size(source.url) + 1 + 8192

    assert manifest.transient.source_plus_owned_backing_upper ==
             manifest.source.backing_bytes + manifest.owned.backing_bytes

    assert compact_tree?(output)

    origin = shared_slice("https://" <> :binary.copy("a", 80) <> ".test")
    cert = shared_slice(:binary.copy("d", 80))
    assert :binary.referenced_byte_size(origin) == 8192
    assert :binary.referenced_byte_size(cert) == 8192

    assert {:ok, tls, manifest} =
             Preparation.prepare_policy(%{policy_source() | origin: origin, trust: [cert]})

    assert compact_tree?(tls)
    assert manifest.source.backing_bytes == 2 * 8192

    url = shared_slice("http://example.test/" <> :binary.copy("a", 80) <> "?")
    name = shared_slice(:binary.copy("n", 80))
    trailer_name = shared_slice(:binary.copy("t", 80))

    for input <- [url, name, trailer_name] do
      assert :binary.referenced_byte_size(input) == 8192
    end

    source = %{
      request()
      | url: url,
        body: self(),
        fields: [{name, value}, {"trailer", trailer_name}],
        trailers: [{trailer_name, value}]
    }

    assert {:ok, output, _} = Preparation.prepare_request(policy(), source)
    assert compact_tree?(output)
    assert output.url == url
    assert output.fields == source.fields
    assert output.trailers == source.trailers
  end

  test "rejects oversized parents and aggregate backing despite small logical leaves" do
    value = shared_slice(:binary.copy("v", 80), 65_537)
    assert :binary.referenced_byte_size(value) == 65_537

    assert {:error, :source_backing_limit} =
             Preparation.prepare_request(policy(), %{request() | fields: [{"x", value}]})

    url = shared_slice("http://example.test/" <> :binary.copy("a", 80), 65_537)

    assert {:error, :source_backing_limit} =
             Preparation.prepare_request(policy(), %{request() | url: url})

    value = shared_slice(:binary.copy("v", 80))
    fields = List.duplicate({"x", value}, 9)

    assert {:error, :source_backing_limit} =
             Preparation.prepare_request(policy(), %{request() | fields: fields})

    assert {:error, :source_backing_limit} =
             Preparation.prepare_request(
               policy(),
               %{request() | body: self(), fields: [{"trailer", "x"}], trailers: fields}
             )

    assert {:error, :invalid_policy} =
             Preparation.prepare_request(
               %{policy() | origin: shared_slice("http://" <> :binary.copy("a", 80) <> ".test")},
               request()
             )

    canonical = policy()
    option_origin = shared_slice("http://example.test/" <> :binary.copy("a", 80))

    invalid = %{
      canonical
      | open_options: Keyword.put(canonical.open_options, :origin, option_origin)
    }

    assert {:error, :invalid_policy} = Preparation.prepare_request(invalid, request())
  end

  test "counts complete source and canonical constructor trees independently" do
    assert {:ok, _, policy_manifest} = Preparation.prepare_policy(policy_source())

    assert policy_manifest.source == %{
             logical_bytes: 19,
             backing_bytes: 19,
             binary_occurrences: 1,
             cons_cells: 0,
             tuples: %{4 => 1},
             maps: %{3 => 1},
             atom_occurrences: 4,
             integer_occurrences: 4,
             pid_occurrences: 0
           }

    assert policy_manifest.owned == %{
             logical_bytes: 50,
             backing_bytes: 50,
             binary_occurrences: 3,
             cons_cells: 17,
             tuples: %{2 => 17, 4 => 2},
             maps: %{7 => 1},
             atom_occurrences: 31,
             integer_occurrences: 17,
             pid_occurrences: 0
           }

    assert {:ok, _, manifest} = Preparation.prepare_request(policy(), request())

    assert manifest.source == %{
             logical_bytes: 54,
             backing_bytes: 54,
             binary_occurrences: 5,
             cons_cells: 2,
             tuples: %{2 => 2},
             maps: %{7 => 1},
             atom_occurrences: 9,
             integer_occurrences: 2,
             pid_occurrences: 0
           }

    assert manifest.owned == %{
             logical_bytes: 62,
             backing_bytes: 62,
             binary_occurrences: 6,
             cons_cells: 2,
             tuples: %{2 => 2},
             maps: %{9 => 1},
             atom_occurrences: 12,
             integer_occurrences: 2,
             pid_occurrences: 0
           }

    assert %{source_plus_owned_backing_upper: 116, pair_reversal_extra_cons: 2} =
             manifest.transient

    assert scalar_manifest?(manifest)
    assert scalar_manifest?(policy_manifest)

    assert %{policy_source_backing_bytes: 1_114_112, request_source_backing_bytes: 196_608} =
             manifest.limits
  end

  test "counts SNI, opaque trust and PID occurrences without asserting resource ownership" do
    assert {:ok, _, manifest} = Preparation.prepare_policy(tls_source(["opaque"]))
    # The seven extra cons cells are five SSL pairs plus two version values;
    # one certificate and the twelve SNI bytes add thirteen more cons cells.
    assert manifest.owned.cons_cells == 17 + 5 + 2 + 1 + 12
    assert manifest.owned.integer_occurrences == 17 + 1 + 12
    assert {:ok, _, manifest} = Preparation.prepare_request(policy(), %{request() | body: self()})
    assert manifest.source.pid_occurrences == 1
    assert manifest.owned.pid_occurrences == 1
    assert scalar_manifest?(manifest)
  end

  defp policy_source,
    do: %{origin: "http://example.test", connect_address: {127, 0, 0, 1}, trust: nil}

  defp tls_source(trust), do: %{policy_source() | origin: "https://example.test", trust: trust}

  defp policy do
    {:ok, policy, _} = Preparation.prepare_policy(policy_source())
    policy
  end

  defp request do
    %{
      url: "http://example.test/upload?",
      method: :post,
      fields: [{"X-Repeat", "first"}, {"x-repeat", "second"}],
      body: nil,
      trailers: [],
      timeout: 1_000,
      connect_timeout: 500
    }
  end

  defp shared_slice(value, bytes \\ 8192) do
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

  defp scalar_manifest?(value) when is_atom(value) or is_integer(value), do: true

  defp scalar_manifest?(value) when is_map(value),
    do:
      :maps.fold(
        fn key, value, acc -> acc and scalar_manifest?(key) and scalar_manifest?(value) end,
        true,
        value
      )

  defp scalar_manifest?(_), do: false
end
