defmodule Gaoxy.Proxy.ManagedH2PreparationTest do
  use ExUnit.Case, async: true

  @moduletag :managed_h2_policy
  @preparation Gaoxy.Proxy.ManagedH2Preparation
  @policy Gaoxy.Proxy.ManagedH2Preparation.Policy
  @sockets [
    buffer: 8192,
    recbuf: 8192,
    sndbuf: 8192,
    nodelay: true,
    send_timeout: 30_000,
    send_timeout_close: true
  ]
  @limits %{
    url_bytes: 65_536,
    fields: 256,
    trailers: 128,
    field_bytes: 65_536,
    trailer_bytes: 65_536,
    effective_field_count: 256,
    effective_field_bytes: 65_536,
    projection_logical_bytes: 196_608,
    projection_external_bytes: 201_241,
    certificates: 128,
    certificate_bytes: 65_536,
    trust_bytes: 1_048_576,
    ssl_socket_policy_external_bytes: 1_048_576,
    policy_source_backing_bytes: 1_114_112,
    request_source_backing_bytes: 196_608
  }

  test "builds the exact numeric-pinned prior-knowledge h2c policy" do
    assert {:ok, policy, manifest} = prepare_policy(policy_source())

    assert policy == %{
             __struct__: @policy,
             protocol: :h2c,
             origin: "http://example.test",
             scheme: :http,
             host: "example.test",
             port: 80,
             connect_address: {127, 0, 0, 1},
             open_options: [
               origin: "http://example.test",
               connect_address: {127, 0, 0, 1},
               http_version: :h2c,
               tls_backend: :ssl,
               http2_profile: :native_v1,
               max_requests: 32,
               max_connections: 2,
               max_pending: 0,
               idle_timeout: 30_000,
               ssl: [],
               socket_opts: @sockets
             ]
           }

    assert manifest.kind == :policy
    assert compact_tree?(policy)
    assert prepare_policy(policy_source()) == {:ok, policy, manifest}
  end

  test "uses explicit DER trust with fixed TLS values and no managed ALPN key" do
    trust = [<<48, 3, 2, 1, 1>>, <<48, 3, 2, 1, 2>>]
    source = %{tls_source(trust) | origin: "https://EXAMPLE.test:443/"}
    assert {:ok, policy, _} = prepare_policy(source)

    assert %{protocol: :http2, scheme: :https, host: "example.test", port: 443} = policy
    assert policy.origin == source.origin

    assert policy.open_options == [
             origin: source.origin,
             connect_address: source.connect_address,
             http_version: :http2,
             tls_backend: :ssl,
             http2_profile: :native_v1,
             max_requests: 32,
             max_connections: 2,
             max_pending: 0,
             idle_timeout: 30_000,
             ssl: ssl_options(trust),
             socket_opts: @sockets
           ]

    refute Keyword.has_key?(policy.open_options[:ssl], :alpn_advertised_protocols)
    assert compact_tree?(policy)
  end

  test "accepts root URLs, numeric IPv4 and IPv6, exact ports and host boundary" do
    for origin <- ["http://example.test", "http://EXAMPLE.test/", "http://example.test:80/"] do
      assert {:ok, %{host: "example.test", port: 80}, _} =
               prepare_policy(%{policy_source() | origin: origin})
    end

    for port <- [1, 65_535] do
      assert {:ok, %{port: ^port}, _} =
               prepare_policy(%{policy_source() | origin: "http://example.test:#{port}"})
    end

    for address <- [{0, 0, 0, 0}, {255, 255, 255, 255}, {0, 0, 0, 0, 0, 0, 0, 65_535}] do
      assert {:ok, %{connect_address: ^address}, _} =
               prepare_policy(%{policy_source() | connect_address: address})
    end

    assert {:ok, %{host: "::1", port: 80}, _} =
             prepare_policy(%{
               policy_source()
               | origin: "http://[::1]/",
                 connect_address: {0, 0, 0, 0, 0, 0, 0, 1}
             })

    host = :binary.copy("a", 253)

    assert {:ok, %{host: ^host}, _} =
             prepare_policy(%{policy_source() | origin: "http://" <> host})

    assert {:error, :invalid_url} =
             prepare_policy(%{policy_source() | origin: "http://" <> host <> "a"})
  end

  test "requires the exact four-key source and supported protocol" do
    for source <- [
          %{},
          [],
          "http://example.test",
          URI.parse("http://example.test"),
          Map.delete(policy_source(), :protocol),
          Map.delete(policy_source(), :trust),
          Map.put(policy_source(), :ssl, []),
          Map.put(policy_source(), :http_version, :http2),
          Map.put(policy_source(), :alpn_advertised_protocols, ["h2"]),
          Map.new(1..2000, &{&1, []})
        ] do
      assert {:error, :invalid_policy} = prepare_policy(source)
    end

    for protocol <- [nil, :http1, :http3, "http2", :unknown] do
      assert {:error, :invalid_policy} = prepare_policy(%{policy_source() | protocol: protocol})
    end
  end

  test "rejects malformed root URLs, authority and port text" do
    for origin <- [
          nil,
          ~c"http://example.test",
          "",
          "http://",
          "ftp://example.test",
          "http://user:secret@example.test",
          "http://example.test#",
          "http://example.test?",
          "http://example.test/nonroot",
          "http://example.test:0",
          "http://example.test:65536",
          "http://example.test:%",
          "http://example.test:80junk",
          "http://[::1",
          "http://example.test/%2",
          "http://example.test/%gg",
          "http://exa mple.test",
          "http://example.test\\",
          "http://example.test\n",
          "http://exämple.test",
          :binary.copy("a", 65_537)
        ] do
      assert {:error, :invalid_url} = prepare_policy(%{policy_source() | origin: origin})
    end
  end

  test "rejects nonnumeric and out-of-range address tuples" do
    for address <- [
          nil,
          "127.0.0.1",
          [127, 0, 0, 1],
          {1, 2, 3},
          {256, 0, 0, 1},
          {-1, 0, 0, 1},
          {1, 2, 3, :bad},
          {1, 2, 3, 1.0},
          {0, 0, 0, 0, 0, 0, 0, 65_536},
          {0, 0, 0, 0, 0, 0, 0, -1}
        ] do
      assert {:error, :invalid_policy} =
               prepare_policy(%{policy_source() | connect_address: address})
    end
  end

  test "requires exact protocol, scheme and trust pairing" do
    for source <- [
          %{policy_source() | protocol: :http2},
          %{policy_source() | protocol: :http2, trust: ["der"]},
          %{tls_source(["der"]) | protocol: :h2c},
          %{tls_source(nil) | protocol: :h2c},
          %{policy_source() | trust: ["der"]},
          tls_source(nil)
        ] do
      assert {:error, :invalid_trust} = prepare_policy(source)
    end
  end

  test "rejects empty, improper and unsupported explicit trust trees" do
    for trust <- [
          [],
          "file.pem",
          ~c"file.pem",
          %{cacertfile: "file.pem"},
          [cacertfile: "file.pem"],
          [fn -> :bad end],
          [""],
          ["valid" | :bad],
          [["der"]],
          [123]
        ] do
      assert {:error, :invalid_trust} = prepare_policy(tls_source(trust))
    end
  end

  test "enforces exact certificate count, leaf and aggregate logical boundaries" do
    assert {:ok, _, _} = prepare_policy(tls_source(List.duplicate("x", 128)))

    assert {:error, :trust_limit} =
             prepare_policy(tls_source(List.duplicate("x", 129)))

    cert = :binary.copy("x", 65_536)
    assert {:ok, _, _} = prepare_policy(tls_source([cert]))
    assert {:error, :trust_limit} = prepare_policy(tls_source([cert <> "x"]))
    assert {:ok, _, _} = prepare_policy(tls_source(List.duplicate(cert, 15)))

    # The logical aggregate is allowed; the complete SSL/socket wrapper exceeds its cap.
    assert {:error, :policy_limit} = prepare_policy(tls_source(List.duplicate(cert, 16)))

    assert {:error, :trust_limit} =
             prepare_policy(tls_source(List.duplicate(cert, 16) ++ ["x"]))
  end

  test "checks complete SSL and socket ETF at the exact boundary independently" do
    overhead = :erlang.external_size({ssl_options(List.duplicate("x", 16)), @sockets}) - 16
    last_bytes = 1_048_576 - 15 * 65_536 - overhead
    assert last_bytes in 1..65_536
    trust = List.duplicate(:binary.copy("x", 65_536), 15) ++ [:binary.copy("x", last_bytes)]
    assert :erlang.external_size({ssl_options(trust), @sockets}) == 1_048_576
    assert {:ok, _, _} = prepare_policy(tls_source(trust))

    over = List.duplicate(:binary.copy("x", 65_536), 15) ++ [:binary.copy("x", last_bytes + 1)]
    assert :erlang.external_size({ssl_options(over), @sockets}) == 1_048_577
    assert {:error, :policy_limit} = prepare_policy(tls_source(over))
  end

  test "checks leaf and aggregate referenced backing before copying trust" do
    exact = shared_slice(:binary.copy("d", 80), 65_536)
    assert :binary.referenced_byte_size(exact) == 65_536
    assert {:ok, _, _} = prepare_policy(tls_source([exact]))
    assert {:ok, _, _} = prepare_policy(tls_source(List.duplicate(exact, 16)))

    origin = shared_slice("https://" <> :binary.copy("a", 80) <> ".test", 65_536)
    source = %{tls_source(List.duplicate(exact, 16)) | origin: origin}
    assert {:ok, _, manifest} = prepare_policy(source)
    assert manifest.source.backing_bytes == 1_114_112

    assert {:error, :source_backing_limit} =
             prepare_policy(tls_source(List.duplicate(exact, 17)))

    over = shared_slice(:binary.copy("d", 80), 65_537)
    assert :binary.referenced_byte_size(over) == 65_537
    assert {:error, :source_backing_limit} = prepare_policy(tls_source([over]))
  end

  test "checks URL referenced backing at its exact boundary before parsing or copying" do
    origin = "http://" <> :binary.copy("a", 80) <> ".test"
    exact = shared_slice(origin, 65_536)
    assert :binary.referenced_byte_size(exact) == 65_536
    assert {:ok, _, _} = prepare_policy(%{policy_source() | origin: exact})

    over = shared_slice(origin, 65_537)
    assert :binary.referenced_byte_size(over) == 65_537

    assert {:error, :source_backing_limit} =
             prepare_policy(%{policy_source() | origin: over})
  end

  test "enforces URL logical bytes independently of the bounded host and valid port" do
    prefix = "http://example.test:"
    origin = :binary.copy(prefix <> :binary.copy("0", 65_536 - byte_size(prefix) - 2) <> "80")
    assert byte_size(origin) == 65_536
    assert :binary.referenced_byte_size(origin) == 65_536
    assert {:ok, %{port: 80}, _} = prepare_policy(%{policy_source() | origin: origin})

    over = prefix <> "0" <> binary_part(origin, byte_size(prefix), 65_536 - byte_size(prefix))
    assert byte_size(over) == 65_537
    assert {:error, :invalid_url} = prepare_policy(%{policy_source() | origin: over})
  end

  test "copies every retained policy binary and counts source backing occurrences" do
    origin = shared_slice("https://" <> :binary.copy("A", 80) <> ".test")
    cert = shared_slice(:binary.copy("d", 80))
    source = %{tls_source([cert, cert]) | origin: origin}
    assert :binary.referenced_byte_size(origin) == 8192
    assert :binary.referenced_byte_size(cert) == 8192
    assert {:ok, policy, manifest} = prepare_policy(source)
    assert policy.origin == origin
    assert policy.host == :binary.copy("a", 80) <> ".test"
    assert policy.open_options[:ssl][:cacerts] == [cert, cert]
    assert compact_tree?(policy)
    assert manifest.source.backing_bytes == 3 * 8192
    assert manifest.source.logical_bytes == byte_size(origin) + 160
    assert manifest.source.binary_occurrences == 3

    assert manifest.transient == %{
             source_plus_owned_backing_upper:
               manifest.source.backing_bytes + manifest.owned.backing_bytes
           }
  end

  test "reports exact policy manifest, complete external sizes and alias without projections" do
    source = policy_source()
    assert {:ok, policy, manifest} = prepare_policy(source)

    assert manifest == %{
             kind: :policy,
             source: %{
               logical_bytes: 19,
               backing_bytes: 19,
               binary_occurrences: 1,
               cons_cells: 0,
               tuples: %{4 => 1},
               maps: %{4 => 1},
               atom_occurrences: 6,
               integer_occurrences: 4,
               pid_occurrences: 0
             },
             owned: %{
               logical_bytes: 50,
               backing_bytes: 50,
               binary_occurrences: 3,
               cons_cells: 17,
               tuples: %{2 => 17, 4 => 2},
               maps: %{8 => 1},
               atom_occurrences: 33,
               integer_occurrences: 17,
               pid_occurrences: 0
             },
             transient: %{source_plus_owned_backing_upper: 69},
             source_external_bytes: :erlang.external_size(source),
             prepared_external_bytes: :erlang.external_size(policy),
             policy_external_bytes: :erlang.external_size(policy),
             limits: @limits
           }

    assert manifest.policy_external_bytes == manifest.prepared_external_bytes
  end

  test "counts complete TLS constructor trees including SNI and opaque DER" do
    source = tls_source(["opaque"])
    assert {:ok, policy, manifest} = prepare_policy(source)
    assert manifest.source == constructor_facts(source)
    assert manifest.owned == constructor_facts(policy)
    assert manifest.owned.cons_cells == 17 + 5 + 2 + 1 + 12
    assert manifest.owned.integer_occurrences == 17 + 1 + 12
    assert manifest.source_external_bytes == :erlang.external_size(source)
    assert manifest.prepared_external_bytes == :erlang.external_size(policy)
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "prepares exact request fields with compact target and deterministic defaults" do
    source = request_source()
    assert {:ok, prepared, manifest} = prepare_request(policy(), source)

    assert prepared == %{
             __struct__: Gaoxy.Proxy.ManagedH2Preparation.Request,
             url: source.url,
             method: :post,
             fields: [{"x-repeat", "first"}, {"x-repeat", "second"}, {"user-agent", "gaoxy"}],
             body: nil,
             trailers: [],
             timeout: 1000,
             connect_timeout: 500,
             target: "/upload?"
           }

    assert compact_tree?(prepared)
    assert prepare_request(policy(), source) == {:ok, prepared, manifest}
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "matches the public native H2 effective projection for all methods and body modes" do
    for method <- [:get, :head, :post, :put, :delete, :patch, :options], body <- [nil, self()] do
      source = %{request_source() | method: method, body: body}
      assert {:ok, prepared, manifest} = prepare_request(policy(), source)
      {effective, native_body} = native_projection(prepared)
      assert effective == pseudo_fields(prepared) ++ prepared.fields
      assert native_body == if(is_nil(body), do: "", else: {:stream, body})
      assert manifest.effective_field_count == length(effective)
      assert manifest.effective_field_bytes == field_bytes(effective)
    end
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "preserves raw empty query and native authority across TLS and IPv6 origins" do
    for {policy_source, url, target, authority} <- [
          {policy_source(), "http://EXAMPLE.test:80/%2f?x=1&x=2", "/%2f?x=1&x=2", "example.test"},
          {tls_source(["der"]), "https://EXAMPLE.test:443/?", "/?", "example.test"},
          {%{
             policy_source()
             | origin: "http://[::1]:8080",
               connect_address: {0, 0, 0, 0, 0, 0, 0, 1}
           }, "http://[::1]:8080?", "/?", "[::1]:8080"},
          {policy_source(), "http://example.test", "/", "example.test"}
        ] do
      {:ok, selected, _} = prepare_policy(policy_source)
      assert {:ok, prepared, _} = prepare_request(selected, %{request_source() | url: url})
      assert prepared.target == target
      {effective, ""} = native_projection(prepared)
      assert effective == pseudo_fields(prepared) ++ prepared.fields
      assert List.keyfind(effective, ":authority", 0) == {":authority", authority}
    end
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "keeps supplied defaults and ordinary duplicates while moving PID Content-Length last" do
    fields = [
      {"Content-Length", "17"},
      {"X-Repeat", "first"},
      {"User-Agent", "custom"},
      {"x-repeat", "second"},
      {"Content-Type", "application/custom"},
      {"content-length", "17"}
    ]

    source = %{request_source() | body: self(), fields: fields}
    assert {:ok, prepared, _} = prepare_request(policy(), source)

    assert prepared.fields == [
             {"x-repeat", "first"},
             {"user-agent", "custom"},
             {"x-repeat", "second"},
             {"content-type", "application/custom"},
             {"content-length", "17"}
           ]

    {effective, {:stream, _}} = native_projection(prepared)
    assert effective == pseudo_fields(prepared) ++ prepared.fields

    assert {:ok, prepared, _} =
             prepare_request(policy(), %{source | fields: [{"Content-Length", "17"}]})

    assert prepared.fields == [
             {"user-agent", "gaoxy"},
             {"content-type", "application/octet-stream"},
             {"content-length", "17"}
           ]

    assert {:ok, nil_prepared, _} = prepare_request(policy(), %{source | body: nil})

    assert nil_prepared.fields == [
             {"x-repeat", "first"},
             {"user-agent", "custom"},
             {"x-repeat", "second"},
             {"content-type", "application/custom"}
           ]
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "validates unsigned64 Content-Length syntax and identical duplicate framing" do
    for length <- ["0", "00000000000000000000", "18446744073709551615"] do
      source = %{
        request_source()
        | body: self(),
          fields: [{"Content-Length", length}, {"content-length", length}]
      }

      assert {:ok, prepared, _} = prepare_request(policy(), source)
      assert List.last(prepared.fields) == {"content-length", length}
      assert {:ok, prepared, _} = prepare_request(policy(), %{source | body: nil})
      refute List.keymember?(prepared.fields, "content-length", 0)
    end

    for values <- [
          [""],
          ["-1"],
          ["+1"],
          [" 1"],
          ["1 "],
          ["1,1"],
          ["1.0"],
          ["18446744073709551616"],
          [:binary.copy("0", 21)],
          ["1", "2"],
          ["01", "1"]
        ],
        body <- [nil, self()] do
      fields = Enum.map(values, &{"Content-Length", &1})

      assert {:error, :invalid_fields} =
               prepare_request(policy(), %{request_source() | body: body, fields: fields})
    end
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "accepts TE trailers only and rejects pseudo and forbidden H2 fields" do
    for value <- ["trailers", " \tTrAiLeRs\t "] do
      assert {:ok, prepared, _} =
               prepare_request(policy(), %{request_source() | fields: [{"TE", value}]})

      assert prepared.fields == [{"te", "trailers"}, {"user-agent", "gaoxy"}]
    end

    for name <- [
          ":method",
          ":path",
          "Host",
          "Connection",
          "Keep-Alive",
          "Proxy-Connection",
          "Transfer-Encoding",
          "Upgrade"
        ] do
      assert {:error, :invalid_fields} =
               prepare_request(policy(), %{request_source() | fields: [{name, "x"}]})
    end

    for value <- ["", "gzip", "trailers,gzip", "trailers, trailers"] do
      assert {:error, :invalid_fields} =
               prepare_request(policy(), %{request_source() | fields: [{"te", value}]})
    end
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "validates then removes Trailer declarations while retaining ordered upload trailers" do
    source = %{
      request_source()
      | body: self(),
        fields: [{"Trailer", " \tx-end, X-End\t "}],
        trailers: [{"X-End", "one"}, {"x-end", "two"}]
    }

    assert {:ok, prepared, _} = prepare_request(policy(), source)

    assert prepared.fields == [
             {"user-agent", "gaoxy"},
             {"content-type", "application/octet-stream"}
           ]

    assert prepared.trailers == source.trailers
    {effective, {:stream, _}} = native_projection(prepared)
    assert effective == pseudo_fields(prepared) ++ prepared.fields

    for {fields, trailers} <- [
          {[], [{"x", "v"}]},
          {[{"trailer", "x"}], [{"y", "v"}]},
          {[{"trailer", "content-length"}], [{"content-length", "1"}]},
          {[{"trailer", "authorization"}], [{"authorization", "secret"}]},
          {[{"trailer", "x"}], [{"x", "bad\n"}]},
          {[{"trailer", ""}], []},
          {[{"trailer", "x,"}], []},
          {[{"trailer", ",x"}], []},
          {[{"trailer", "bad name"}], []}
        ] do
      assert {:error, :invalid_trailers} =
               prepare_request(policy(), %{source | fields: fields, trailers: trailers})
    end

    assert {:error, :invalid_trailers} = prepare_request(policy(), %{source | body: nil})
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "bounds upload declaration tokens before the public validator" do
    tokens = Enum.join(List.duplicate("x", 128), ",")

    source = %{
      request_source()
      | body: self(),
        fields: [{"Trailer", tokens}],
        trailers: [{"x", "v"}]
    }

    assert {:ok, _, _} = prepare_request(policy(), source)

    for fields <- [[{"Trailer", tokens <> ",x"}], [{"Trailer", tokens}, {"trailer", "x"}]] do
      assert {:error, :invalid_trailers} = prepare_request(policy(), %{source | fields: fields})
    end
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "admits exact source keys, method enum, nil or PID body and bounded integer timeouts" do
    for method <- [:get, :head, :post, :put, :delete, :patch, :options],
        body <- [nil, self()],
        timeout <- [1, 86_400_000] do
      assert {:ok, _, _} =
               prepare_request(policy(), %{
                 request_source()
                 | method: method,
                   body: body,
                   timeout: timeout,
                   connect_timeout: timeout
               })
    end

    for source <- [
          nil,
          [],
          Map.put(request_source(), :options, []),
          Map.put(request_source(), :duplex, :half),
          Map.delete(request_source(), :timeout),
          Map.new(1..2000, &{&1, []})
        ] do
      assert {:error, :invalid_request} = prepare_request(policy(), source)
    end

    for change <- [
          %{method: "GET"},
          %{method: :connect},
          %{method: :trace},
          %{body: ""},
          %{body: []},
          %{body: fn -> :bad end},
          %{timeout: :infinity},
          %{timeout: 0},
          %{timeout: 86_400_001},
          %{timeout: 1.0},
          %{connect_timeout: 0},
          %{connect_timeout: 86_400_001}
        ] do
      assert {:error, :invalid_request} =
               prepare_request(policy(), Map.merge(request_source(), change))
    end
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "rejects malformed pair trees and invalid field or trailer octets" do
    for fields <- [
          [{"x", ~c"value"}],
          [{~c"x", "v"}],
          ["x"],
          [{"x", "v", "extra"}],
          [{"x", "v"} | :improper],
          %HTTP.Headers{},
          [[[]]],
          [{"", "v"}],
          [{"bad name", "v"}],
          [{"ümlaut", "v"}],
          [{"x", "\r"}],
          [{"x", <<0>>}],
          [{"x", <<127>>}]
        ] do
      assert {:error, :invalid_fields} =
               prepare_request(policy(), %{request_source() | fields: fields})
    end

    for trailers <- [[{"x", "v"} | :improper], [[[]]], [{"x", :bad}], [{"bad name", "v"}]] do
      assert {:error, :invalid_trailers} =
               prepare_request(policy(), %{request_source() | body: self(), trailers: trailers})
    end

    value = <<9, 32, 128, 255>>

    assert {:ok, prepared, _} =
             prepare_request(policy(), %{request_source() | fields: [{"X", value}]})

    assert prepared.fields == [{"x", value}, {"user-agent", "gaoxy"}]
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "rejects origin mismatches and malformed request URLs before projection" do
    for url <- ["https://example.test/upload?", "http://other.test/", "http://example.test:81/"] do
      assert {:error, :origin_mismatch} =
               prepare_request(policy(), %{request_source() | url: url})
    end

    for url <- [
          URI.parse(request_source().url),
          ~c"http://example.test",
          "http://user:secret@example.test/",
          "http://example.test/#",
          "http://example.test/%",
          "http://example.test/%zz",
          "http://example.test/a b",
          "http://example.test/\r",
          "http://example.test/\\",
          "http://example.test/é",
          "http://example.test:80junk/",
          :binary.copy("a", 65_537)
        ] do
      assert {:error, :invalid_url} = prepare_request(policy(), %{request_source() | url: url})
    end

    prefix = "http://example.test/"
    exact = :binary.copy(prefix <> :binary.copy("a", 65_536 - byte_size(prefix)))
    assert byte_size(exact) == :binary.referenced_byte_size(exact)

    assert {:error, :request_limit} =
             prepare_request(policy(), %{request_source() | url: exact, fields: []})

    assert {:error, :invalid_url} =
             prepare_request(policy(), %{request_source() | url: exact <> "a", fields: []})
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "revalidates forged Policy exact fields, scalars, fixed options and compactness" do
    selected = policy()

    assert {:ok, _, _} =
             prepare_request(struct(@policy, Map.from_struct(selected)), request_source())

    for modified <- [
          nil,
          Map.from_struct(selected),
          Map.put(selected, :extra, :bad),
          %{selected | protocol: :http2},
          %{selected | scheme: :https},
          %{selected | host: "other.test"},
          %{selected | port: 81},
          %{selected | connect_address: {256, 0, 0, 1}},
          %{selected | open_options: List.duplicate([], 50_000)},
          %{selected | open_options: [origin: selected.origin] ++ [:bad | :improper]},
          %{selected | open_options: Keyword.put(selected.open_options, :max_requests, 33)},
          %{selected | open_options: Keyword.put(selected.open_options, :http_version, :http2)},
          %{
            selected
            | open_options: Keyword.put(selected.open_options, :socket_opts, buffer: 8193)
          }
        ] do
      assert {:error, :invalid_policy} = prepare_request(modified, request_source())
    end

    origin = "http://" <> :binary.copy("a", 80) <> ".test"
    {:ok, large_host, _} = prepare_policy(%{policy_source() | origin: origin})
    source = %{request_source() | url: origin <> "/"}

    for modified <- [
          %{large_host | origin: shared_slice(origin)},
          %{large_host | host: shared_slice(large_host.host)},
          %{
            large_host
            | open_options: Keyword.put(large_host.open_options, :origin, shared_slice(origin))
          }
        ] do
      assert {:error, :invalid_policy} = prepare_request(modified, source)
    end
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "rejects forged TLS options, oversized or improper trust and injected ALPN" do
    {:ok, selected, _} = prepare_policy(tls_source([:binary.copy("d", 80)]))
    source = %{request_source() | url: "https://example.test/"}
    ssl = selected.open_options[:ssl]

    for modified_ssl <- [
          ssl ++ [alpn_advertised_protocols: ["h2"]],
          Keyword.put(ssl, :verify, :verify_none),
          Keyword.put(ssl, :depth, 5),
          Keyword.put(ssl, :versions, [:"tlsv1.2"]),
          Keyword.put(ssl, :server_name_indication, ~c"other.test"),
          Keyword.put(ssl, :server_name_indication, List.duplicate(1, 50_000)),
          Keyword.put(ssl, :cacerts, List.duplicate("x", 129)),
          Keyword.put(ssl, :cacerts, ["x" | :improper]),
          Keyword.put(ssl, :cacerts, [shared_slice(:binary.copy("d", 80))]),
          Keyword.put(ssl, :cacerts, List.duplicate(:binary.copy("d", 65_536), 16))
        ] do
      modified = %{
        selected
        | open_options: Keyword.put(selected.open_options, :ssl, modified_ssl)
      }

      assert {:error, :invalid_policy} = prepare_request(modified, source)
    end
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "counts source fields before normalization and effective fields after pseudo and defaults" do
    source = %{
      request_source()
      | body: self(),
        fields: List.duplicate({"Content-Length", "0"}, 256)
    }

    assert {:ok, _, _} = prepare_request(policy(), source)

    for last <- [{"Content-Length", "0"}, List.duplicate([], 50_000)] do
      assert {:error, :request_limit} =
               prepare_request(policy(), %{source | fields: source.fields ++ [last]})
    end

    for {body, count} <- [{nil, 251}, {self(), 250}] do
      fields = List.duplicate({"x", ""}, count)
      source = %{request_source() | body: body, fields: fields}
      assert {:ok, _, %{effective_field_count: 256}} = prepare_request(policy(), source)

      assert {:error, :request_limit} =
               prepare_request(policy(), %{source | fields: fields ++ [{"x", ""}]})
    end

    fields = List.duplicate({"x", ""}, 251) ++ [{"User-Agent", "custom"}]

    assert {:ok, _, %{effective_field_count: 256}} =
             prepare_request(policy(), %{request_source() | fields: fields})
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "enforces source field bytes even when Trailer is removed" do
    declaration = :binary.copy("x," <> :binary.copy("n", 65_495))
    source = %{request_source() | body: self(), fields: [{"Trailer", declaration}]}
    assert field_bytes(source.fields) == 65_536
    assert {:ok, _, _} = prepare_request(policy(), source)

    assert {:error, :request_limit} =
             prepare_request(policy(), %{
               source
               | fields: [{"Trailer", :binary.copy(declaration <> "n")}]
             })
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "enforces exact effective field bytes including generated User-Agent and PID Content-Type" do
    for body <- [nil, self()] do
      source = %{request_source() | url: "http://example.test/", body: body, fields: [{"x", ""}]}
      assert {:ok, base, base_manifest} = prepare_request(policy(), source)
      value_bytes = 65_536 - base_manifest.effective_field_bytes
      source = %{source | fields: [{"x", :binary.copy("v", value_bytes)}]}
      assert {:ok, prepared, %{effective_field_bytes: 65_536}} = prepare_request(policy(), source)
      assert field_bytes(pseudo_fields(prepared) ++ prepared.fields) == 65_536

      assert {:error, :request_limit} =
               prepare_request(policy(), %{
                 source
                 | fields: [{"x", :binary.copy("v", value_bytes + 1)}]
               })

      expected_defaults = if is_nil(body), do: 47, else: 47 + 68

      assert base_manifest.effective_field_bytes ==
               field_bytes(pseudo_fields(base)) + 33 + expected_defaults
    end
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "enforces exact trailer counts and wire bytes before upload validation" do
    source = %{
      request_source()
      | body: self(),
        fields: [{"Trailer", "x"}],
        trailers: List.duplicate({"x", ""}, 128)
    }

    assert {:ok, _, _} = prepare_request(policy(), source)

    for last <- [{"x", ""}, List.duplicate([], 50_000)] do
      assert {:error, :trailer_limit} =
               prepare_request(policy(), %{source | trailers: source.trailers ++ [last]})
    end

    source = %{source | trailers: [{"x", :binary.copy("v", 65_529)}]}
    assert {:ok, _, _} = prepare_request(policy(), source)

    assert {:error, :trailer_limit} =
             prepare_request(policy(), %{source | trailers: [{"x", :binary.copy("v", 65_530)}]})
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "enforces exact source projection logical cap including removed declarations" do
    declaration = :binary.copy("x," <> :binary.copy("n", 65_494))
    prefix = "http://example.test/"

    source = %{
      request_source()
      | body: self(),
        url: :binary.copy(prefix <> :binary.copy("a", 32_797 - byte_size(prefix))),
        fields: [{"Trailer", declaration}],
        trailers: [{"x", :binary.copy("v", 65_529)}]
    }

    target = binary_part(source.url, 19, byte_size(source.url) - 19)
    projection = {source.url, target, source.fields, source.trailers}
    assert constructor_facts(projection).logical_bytes == 196_608
    assert {:ok, prepared, manifest} = prepare_request(policy(), source)
    assert manifest.source_projection_external_bytes == :erlang.external_size(projection)

    assert manifest.canonical_projection_external_bytes ==
             :erlang.external_size(
               {prepared.url, prepared.target, prepared.fields, prepared.trailers}
             )

    assert manifest.source_projection_external_bytes <= 201_241
    assert manifest.canonical_projection_external_bytes <= 201_241

    assert {:error, :request_limit} =
             prepare_request(policy(), %{
               source
               | fields: [{"Trailer", :binary.copy(declaration <> "n")}]
             })
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "rejects oversized source backing and aggregate pair backing before copying" do
    value = shared_slice(:binary.copy("v", 80), 65_537)
    assert :binary.referenced_byte_size(value) == 65_537

    assert {:error, :source_backing_limit} =
             prepare_request(policy(), %{request_source() | fields: [{"x", value}]})

    url = shared_slice("http://example.test/" <> :binary.copy("a", 80), 65_537)

    assert {:error, :source_backing_limit} =
             prepare_request(policy(), %{request_source() | url: url})

    value = shared_slice(:binary.copy("v", 80))
    fields = List.duplicate({"x", value}, 9)

    assert {:error, :source_backing_limit} =
             prepare_request(policy(), %{request_source() | fields: fields})

    assert {:error, :source_backing_limit} =
             prepare_request(policy(), %{
               request_source()
               | body: self(),
                 fields: [{"Trailer", "x"}],
                 trailers: fields
             })

    exact = shared_slice(:binary.copy("v", 80), 65_535)
    assert {:ok, _, _} = prepare_request(policy(), %{request_source() | fields: [{"x", exact}]})
    over = shared_slice(:binary.copy("v", 80), 65_536)

    assert {:error, :source_backing_limit} =
             prepare_request(policy(), %{request_source() | fields: [{"x", over}]})
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "admits the complete request source backing envelope without double charging projections" do
    url = shared_slice("http://example.test/" <> :binary.copy("a", 80), 65_536)
    declaration = shared_slice("x," <> :binary.copy("n", 80), 65_529)
    value = shared_slice(:binary.copy("v", 80), 65_535)

    source = %{
      request_source()
      | url: url,
        body: self(),
        fields: [{"Trailer", declaration}],
        trailers: [{"x", value}]
    }

    assert {:ok, _, manifest} = prepare_request(policy(), source)
    assert manifest.source.backing_bytes == 196_608
    assert manifest.source == constructor_facts(source)
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "copies every retained request binary and reports the exact complete request manifest" do
    url = shared_slice("http://example.test/" <> :binary.copy("a", 80) <> "?")
    name = shared_slice(:binary.copy("n", 80))
    value = shared_slice(:binary.copy("v", 80))
    trailer_name = shared_slice(:binary.copy("t", 80))

    source = %{
      request_source()
      | url: url,
        body: self(),
        fields: [{name, value}, {"Trailer", trailer_name}],
        trailers: [{trailer_name, value}]
    }

    assert {:ok, prepared, manifest} = prepare_request(policy(), source)
    assert compact_tree?(prepared)
    assert prepared.url == url
    assert prepared.trailers == source.trailers
    source_target = binary_part(source.url, 19, byte_size(source.url) - 19)
    canonical_projection = {prepared.url, prepared.target, prepared.fields, prepared.trailers}
    effective = pseudo_fields(prepared) ++ prepared.fields

    assert manifest == %{
             kind: :request,
             source: constructor_facts(source),
             owned: constructor_facts(prepared),
             transient: %{
               source_plus_owned_backing_upper:
                 constructor_facts(source).backing_bytes +
                   constructor_facts(prepared).backing_bytes
             },
             source_external_bytes: :erlang.external_size(source),
             prepared_external_bytes: :erlang.external_size(prepared),
             source_projection_external_bytes:
               :erlang.external_size({source.url, source_target, source.fields, source.trailers}),
             canonical_projection_external_bytes: :erlang.external_size(canonical_projection),
             effective_field_count: length(effective),
             effective_field_bytes: field_bytes(effective),
             limits: @limits
           }

    assert manifest.source.pid_occurrences == 1
    assert manifest.owned.pid_occurrences == 1
    assert manifest.source.backing_bytes == 6 * 8192 + 7
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "matches native numeric IPv4 ports and default IPv6 authorities with empty queries" do
    for {protocol, scheme, origin, url, address, authority} <- [
          {:h2c, "http", "http://127.0.0.1", "http://127.0.0.1:80/probe?", {127, 0, 0, 1},
           "127.0.0.1"},
          {:h2c, "http", "http://127.0.0.1:8080", "http://127.0.0.1:8080/probe?", {127, 0, 0, 1},
           "127.0.0.1:8080"},
          {:http2, "https", "https://127.0.0.1", "https://127.0.0.1:443/probe?", {127, 0, 0, 1},
           "127.0.0.1"},
          {:http2, "https", "https://127.0.0.1:8443", "https://127.0.0.1:8443/probe?",
           {127, 0, 0, 1}, "127.0.0.1:8443"},
          {:h2c, "http", "http://[::1]", "http://[::1]:80/probe?", {0, 0, 0, 0, 0, 0, 0, 1},
           "[::1]"},
          {:http2, "https", "https://[::1]", "https://[::1]:443/probe?", {0, 0, 0, 0, 0, 0, 0, 1},
           "[::1]"}
        ],
        body <- [nil, self()] do
      trust = if protocol == :http2, do: ["der"], else: nil

      {:ok, selected, _} =
        prepare_policy(%{
          protocol: protocol,
          origin: origin,
          connect_address: address,
          trust: trust
        })

      source = %{request_source() | url: url, body: body, fields: [{"X", "value"}]}
      assert {:ok, prepared, manifest} = prepare_request(selected, source)

      ordinary =
        if is_nil(body),
          do: [{"x", "value"}, {"user-agent", "gaoxy"}],
          else: [
            {"x", "value"},
            {"user-agent", "gaoxy"},
            {"content-type", "application/octet-stream"}
          ]

      expected =
        [
          {":method", "POST"},
          {":scheme", scheme},
          {":authority", authority},
          {":path", "/probe?"}
        ] ++ ordinary

      assert prepared.target == "/probe?"
      assert prepared.fields == ordinary
      {native_fields, native_body} = native_projection(prepared)
      assert native_fields == expected
      assert native_body == if(is_nil(body), do: "", else: {:stream, body})
      assert manifest.effective_field_count == length(expected)
      assert manifest.effective_field_bytes == field_bytes(expected)
    end
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "matches native projection after successful TE trailers normalization" do
    for value <- ["trailers", " \tTrAiLeRs\t "], body <- [nil, self()] do
      source = %{request_source() | body: body, fields: [{"TE", value}]}
      assert {:ok, prepared, manifest} = prepare_request(policy(), source)

      ordinary =
        if is_nil(body),
          do: [{"te", "trailers"}, {"user-agent", "gaoxy"}],
          else: [
            {"te", "trailers"},
            {"user-agent", "gaoxy"},
            {"content-type", "application/octet-stream"}
          ]

      expected =
        [
          {":method", "POST"},
          {":scheme", "http"},
          {":authority", "example.test"},
          {":path", "/upload?"}
        ] ++ ordinary

      assert prepared.target == "/upload?"
      assert prepared.fields == ordinary
      {native_fields, native_body} = native_projection(prepared)
      assert native_fields == expected
      assert native_body == if(is_nil(body), do: "", else: {:stream, body})
      assert manifest.effective_field_count == length(expected)
      assert manifest.effective_field_bytes == field_bytes(expected)
    end
  end

  @tag managed_h2_request: true, managed_h2_policy: false
  test "matches native PID framing for Content-Length first middle and last with both content types" do
    for {ordinary_source, expected_ordinary} <- [
          {[{"X", "value"}, {"Y", "tail"}],
           [
             {"x", "value"},
             {"y", "tail"},
             {"user-agent", "gaoxy"},
             {"content-type", "application/octet-stream"},
             {"content-length", "17"}
           ]},
          {[{"X", "value"}, {"Content-Type", "application/custom"}, {"Y", "tail"}],
           [
             {"x", "value"},
             {"content-type", "application/custom"},
             {"y", "tail"},
             {"user-agent", "gaoxy"},
             {"content-length", "17"}
           ]}
        ],
        position <- [0, 1, length(ordinary_source)] do
      body = self()
      fields = List.insert_at(ordinary_source, position, {"Content-Length", "17"})

      assert {:ok, prepared, manifest} =
               prepare_request(policy(), %{request_source() | body: body, fields: fields})

      expected =
        [
          {":method", "POST"},
          {":scheme", "http"},
          {":authority", "example.test"},
          {":path", "/upload?"}
        ] ++ expected_ordinary

      assert prepared.target == "/upload?"
      assert prepared.fields == expected_ordinary
      {native_fields, native_body} = native_projection(prepared)
      assert native_fields == expected
      assert native_body == {:stream, body}
      assert manifest.effective_field_count == 9
      assert manifest.effective_field_bytes == field_bytes(expected)
    end
  end

  defp prepare_policy(source), do: apply(@preparation, :prepare_policy, [source])

  defp prepare_request(policy, source),
    do: apply(@preparation, :prepare_request, [policy, source])

  defp policy do
    {:ok, policy, _} = prepare_policy(policy_source())
    policy
  end

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

  defp pseudo_fields(prepared) do
    uri = %{URI.parse(prepared.url) | host: String.downcase(URI.parse(prepared.url).host)}

    [
      {":method", prepared.method |> Atom.to_string() |> String.upcase()},
      {":scheme", uri.scheme},
      {":authority", HTTP.Request.authority(uri)},
      {":path", prepared.target}
    ]
  end

  defp native_projection(prepared) do
    uri = URI.parse(prepared.url)

    request = %HTTP.Request{
      method: prepared.method,
      url: %{uri | host: String.downcase(uri.host)},
      headers: %HTTP.Headers{headers: prepared.fields},
      request_mode: :proxy,
      body: prepared.body,
      duplex: if(is_pid(prepared.body), do: :half, else: nil)
    }

    {:ok, fields, body} = HTTP.HTTP2.request_headers(request, :native_v1, order?: false)
    {fields, body}
  end

  defp field_bytes(fields),
    do:
      Enum.reduce(fields, 0, fn {name, value}, total ->
        total + byte_size(name) + byte_size(value) + 32
      end)

  defp policy_source do
    %{protocol: :h2c, origin: "http://example.test", connect_address: {127, 0, 0, 1}, trust: nil}
  end

  defp tls_source(trust) do
    %{policy_source() | protocol: :http2, origin: "https://example.test", trust: trust}
  end

  defp ssl_options(trust) do
    [
      verify: :verify_peer,
      depth: 4,
      versions: [:"tlsv1.3", :"tlsv1.2"],
      cacerts: trust,
      server_name_indication: ~c"example.test"
    ]
  end

  defp shared_slice(value, bytes \\ 8192) do
    parent = :binary.copy(value <> :binary.copy("p", bytes - byte_size(value)))
    binary_part(parent, 0, byte_size(value))
  end

  defp compact_tree?(value) when is_binary(value),
    do: :binary.referenced_byte_size(value) == byte_size(value)

  defp compact_tree?(value) when is_map(value),
    do:
      Enum.all?(Map.to_list(value), fn {key, item} ->
        compact_tree?(key) and compact_tree?(item)
      end)

  defp compact_tree?(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.all?(&compact_tree?/1)

  defp compact_tree?(value) when is_list(value), do: Enum.all?(value, &compact_tree?/1)
  defp compact_tree?(_), do: true

  defp constructor_facts(value) do
    terms = finite_terms(value)

    %{
      logical_bytes: terms |> Enum.filter(&is_binary/1) |> Enum.map(&byte_size/1) |> Enum.sum(),
      backing_bytes:
        terms
        |> Enum.filter(&is_binary/1)
        |> Enum.map(&:binary.referenced_byte_size/1)
        |> Enum.sum(),
      binary_occurrences: Enum.count(terms, &is_binary/1),
      cons_cells: Enum.count(terms, &match?([_ | _], &1)),
      tuples: terms |> Enum.filter(&is_tuple/1) |> Enum.frequencies_by(&tuple_size/1),
      maps: terms |> Enum.filter(&is_map/1) |> Enum.frequencies_by(&map_size/1),
      atom_occurrences: Enum.count(terms, &(is_atom(&1) and &1 != [])),
      integer_occurrences: Enum.count(terms, &is_integer/1),
      pid_occurrences: Enum.count(terms, &is_pid/1)
    }
  end

  defp finite_terms([]), do: []
  defp finite_terms([head | tail] = value), do: [value | finite_terms(head) ++ finite_terms(tail)]

  defp finite_terms(value) when is_tuple(value),
    do: [value | Enum.flat_map(Tuple.to_list(value), &finite_terms/1)]

  defp finite_terms(value) when is_map(value),
    do: [
      value
      | Enum.flat_map(Map.to_list(value), fn {key, item} ->
          finite_terms(key) ++ finite_terms(item)
        end)
    ]

  defp finite_terms(value), do: [value]
end
