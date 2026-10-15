defmodule Gaoxy.Proxy.ManagedH2ActivationReservationTest do
  use ExUnit.Case, async: true

  @reservation Gaoxy.Proxy.ManagedH2Reservation
  @envelope Gaoxy.Proxy.ManagedH2Envelope
  @preparation Gaoxy.Proxy.ManagedH2Preparation
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

  test "activation ledger sums complete bounded slots without changing historical worksheet" do
    b = fn bytes -> bytes + 6 end
    f = fn count, bytes -> bytes + 12 * count + 7 end
    n = fn count, bytes -> bytes + 5 * count + 7 end
    scratch = 3 * f.(256, 65_536) + 2 * n.(393, 65_642) + 2 * b.(65_536)
    assert scratch == 472_157

    proxy =
      5 * 205_337 + 5 * 147_456 + 2 * 1_183_744 + 2 * 67_689 +
        n.(128, 65_536) + 4 * f.(256, 65_536) + 4 * f.(128, 65_536) +
        3 * b.(1_048_576) + 2 * b.(65_536) + b.(16_384) + 213_965 + scratch + 65_536

    assert proxy == 8_920_668
    assert 2 * 81_920 + b.(65_536) + 4_096 == 233_478
    assert 131_072 + f.(1, 65_536) + b.(65_536) + 2 * 73_728 + 4_096 == 413_721
    assert 413_721 <= 524_288
    assert proxy + 524_288 == 9_444_956
    assert (proxy + 524_288) * 32 == 302_238_592
    assert @reservation.worksheet().named_subtotal_per_request == 2_918_508
    assert call(:reservation_bytes, [[], 1, 1]) == 9_444_956
  end

  test "closed activation contract names every complete slot, owner, release and multiplicity" do
    assert call(:activation_contract, []) == %{
             unit: :external_term_payload_bytes,
             profile: %{connections: 2, requests: 32, pending: 0},
             components: components(),
             proxy_subtotal_per_request: 8_920_668,
             renderer_allowance_per_request: 524_288,
             reservation_per_request: 9_444_956,
             reservation_for_32_requests: 302_238_592,
             opaque_capabilities: %{
               scope: 1,
               original_completion: 1,
               completion_shell_references: 2
             }
           }

    assert Enum.sum(Enum.map(Map.values(components()), & &1.external_bytes)) == 8_920_668
  end

  test "reservation facade never discounts small request or absent later values" do
    for fields <- [
          [],
          [{"x", "v"}],
          List.duplicate({"x", ""}, 256),
          [{"x", :binary.copy("v", 65_535)}]
        ],
        url_bytes <- [1, 65_536],
        chunk_bytes <- [1, 65_536] do
      assert call(:reservation_bytes, [fields, url_bytes, chunk_bytes]) == 9_444_956
    end

    input = values()
    assert {:ok, manifest} = call(:evaluate_activation, [input])
    assert manifest.reservation_bytes == 9_444_956
    assert manifest.contract == call(:activation_contract, [])

    assert Enum.sort(Map.keys(manifest)) ==
             Enum.sort([:contract, :measured_external_bytes, :projections, :reservation_bytes])

    assert manifest.projections.request == input.request
    assert manifest.projections.config == input.config
    assert manifest.projections.checked_client == nil
    assert manifest.projections.trailer_policy == nil
    assert manifest.projections.response_policy == nil
    assert manifest.projections.response == nil

    assert manifest.measured_external_bytes.request ==
             :erlang.external_size(manifest.projections.request)

    assert manifest.measured_external_bytes.config ==
             :erlang.external_size(manifest.projections.config)

    assert manifest.measured_external_bytes.checked_client == 0
  end

  test "facade validates finite proper fields and logical backing before returning a constant" do
    for fields <- [
          nil,
          %HTTP.Headers{},
          [{"x", "v"} | :improper],
          [{"x", :bad}],
          [{"x", "v", :extra}],
          List.duplicate({"x", ""}, 257),
          [{"x", :binary.copy("v", 65_536)}],
          [{"x", oversized_slice()}],
          [{"x", slice(32_768)}, {"y", slice(32_768)}]
        ] do
      assert_raise ArgumentError, fn -> call(:reservation_bytes, [fields, 1, 1]) end
    end

    for value <- [0, 65_537, nil, 1.0, :infinity] do
      assert_raise ArgumentError, fn -> call(:reservation_bytes, [[], value, 1]) end
      assert_raise ArgumentError, fn -> call(:reservation_bytes, [[], 1, value]) end
    end
  end

  test "evaluator requires the exact six-key input with request and config mandatory" do
    valid = values()

    for bad <- [
          nil,
          [],
          Map.put(valid, :extra, []),
          Map.delete(valid, :checked_client),
          %{valid | request: nil},
          %{valid | config: nil},
          Map.put(valid, :__struct__, URI)
        ] do
      reject(bad)
    end

    for key <- [:request, :config, :checked_client, :trailer_policy, :response_policy, :response] do
      reject(Map.put(valid, key, %{unknown: List.duplicate([], 2000)}))
    end

    reject(%{valid | request: Map.put(valid.request, :extra, [])})
    reject(%{valid | config: Map.put(valid.config, :extra, [])})
  end

  test "evaluator authenticates config origin and protocol against the request" do
    valid = values()
    reject(%{valid | config: %{valid.config | upstream_protocol: :h2c}})
    reject(%{valid | config: %{valid.config | uri: URI.parse("https://other.test")}})
    reject(%{valid | request: %{valid.request | protocol: :h2c}})
    reject(%{valid | request: %{valid.request | url: "https://other.test/a?", target: "/a?"}})
  end

  test "checked-client projection uses typed public scope marker without serializing interiors" do
    valid = values()
    client = checked_client()
    # This public shell is a type fixture only. It is never passed to Fetch.
    opaque = %{
      client.transport_scope
      | configuration: fn -> :never_serialize end,
        identity: :binary.copy("private", 200_000)
    }

    assert {:ok, manifest} =
             call(:evaluate_activation, [
               %{valid | checked_client: %{client | transport_scope: opaque}}
             ])

    projection = %{client | transport_scope: {:opaque, HTTP.ManagedTransport}}
    assert manifest.projections.checked_client == projection
    assert manifest.measured_external_bytes.checked_client == :erlang.external_size(projection)
    assert manifest.measured_external_bytes.checked_client <= 1_183_744
    assert manifest.reservation_bytes == 9_444_956
    reject(%{valid | checked_client: %{client | transport_scope: make_ref()}})
    reject(%{valid | checked_client: %{client | policy: %{client.policy | protocol: :h2c}}})

    reject(%{
      valid
      | checked_client: %{client | fetch_options: client.fetch_options ++ [timeout: 1]}
    })
  end

  test "complete validated request, config and both pump policies each measured once" do
    valid = values()
    policy = %{allowed: ["x-trace"], dropped: ["connection"], max_count: 128, max_bytes: 65_536}

    input = %{
      valid
      | checked_client: checked_client(),
        trailer_policy: policy,
        response_policy: policy
    }

    assert {:ok, manifest} = call(:evaluate_activation, [input])

    for {key, cap} <- [
          request: 205_337,
          config: 147_456,
          checked_client: 1_183_744,
          trailer_policy: 67_689,
          response_policy: 67_689
        ] do
      projected = Map.fetch!(manifest.projections, key)
      measured = Map.fetch!(manifest.measured_external_bytes, key)
      assert measured == :erlang.external_size(projected)
      assert measured <= cap
    end

    assert manifest.measured_external_bytes.trailer_policy == :erlang.external_size(policy)
    assert manifest.measured_external_bytes.response_policy == :erlang.external_size(policy)
    assert manifest.reservation_bytes == 9_444_956
  end

  test "metadata projection excludes separately charged initial heads and drops opaque body" do
    valid = values()

    response = %HTTP.Response{
      status: 200,
      status_text: "OK",
      ok: true,
      http_version: :http2,
      headers: %HTTP.Headers{headers: [{"x", :binary.copy("v", 65_535)}]},
      stream: self(),
      body: self(),
      url: URI.parse(valid.request.url)
    }

    assert {:ok, manifest} = call(:evaluate_activation, [%{valid | response: response}])
    assert manifest.projections.response == %{response | headers: %HTTP.Headers{}, body: nil}

    assert manifest.measured_external_bytes.response ==
             :erlang.external_size(manifest.projections.response)

    assert manifest.measured_external_bytes.response <= 213_965
    assert manifest.reservation_bytes == 9_444_956
    reject(%{valid | response: %{response | url: URI.parse("https://other.test/a?")}})

    reject(%{
      valid
      | response: %{
          response
          | informational: [{103, %HTTP.Headers{headers: [{"x", oversized_slice()}]}}]
        }
    })
  end

  test "evaluator rejects logical and referenced backing excess before accounting" do
    valid = values()

    for request <- [
          %{valid.request | fields: [{"x", oversized_slice()}]},
          %{valid.request | fields: List.duplicate({"x", ""}, 257)},
          %{valid.request | fields: [{"x", "v"} | :improper]}
        ] do
      reject(%{valid | request: request})
    end

    reject(%{
      valid
      | trailer_policy: %{
          allowed: [oversized_slice()],
          dropped: [],
          max_count: 128,
          max_bytes: 65_536
        }
    })

    reject(%{
      valid
      | response_policy: %{allowed: [], dropped: [], max_count: 129, max_bytes: 65_536}
    })
  end

  test "full maximal preparation return fits Request, manifest, accounting and wrapper caps" do
    {:ok, policy, _} =
      @preparation.prepare_policy(%{
        protocol: :h2c,
        origin: "http://example.test",
        connect_address: {127, 0, 0, 1},
        trust: nil
      })

    declaration = :binary.copy("x," <> :binary.copy("n", 65_494))
    prefix = "http://example.test/"

    source = %{
      url: :binary.copy(prefix <> :binary.copy("a", 32_797 - byte_size(prefix))),
      method: :post,
      fields: [{"Trailer", declaration}],
      body: self(),
      trailers: [{"x", :binary.copy("v", 65_529)}],
      timeout: 86_400_000,
      connect_timeout: 86_400_000
    }

    assert {:ok, request, preparation} = @preparation.prepare_request(policy, source)

    accounting = %{
      owned_serialized_payload_bytes: :erlang.external_size(request),
      preparation: preparation
    }

    complete_return = {:ok, request, accounting}
    assert map_size(request) == 9
    assert :erlang.external_size(request) <= 201_753
    assert Enum.sort(Map.keys(accounting)) == [:owned_serialized_payload_bytes, :preparation]
    assert :erlang.external_size(accounting) <= 3_456
    assert :erlang.external_size(preparation) <= 3_072
    assert :erlang.external_size(complete_return) <= 205_337

    assert :erlang.external_size(complete_return) - :erlang.external_size(request) -
             :erlang.external_size(accounting) <= 128

    assert preparation.kind == :request
    assert preparation.limits == @limits
    assert map_size(preparation.limits) == 15

    assert Enum.sort(Map.keys(preparation)) ==
             Enum.sort([
               :kind,
               :source,
               :owned,
               :transient,
               :source_external_bytes,
               :prepared_external_bytes,
               :source_projection_external_bytes,
               :canonical_projection_external_bytes,
               :effective_field_count,
               :effective_field_bytes,
               :limits
             ])

    assert preparation.source == constructor_facts(source)
    assert preparation.owned == constructor_facts(request)

    assert preparation.transient == %{
             source_plus_owned_backing_upper:
               preparation.source.backing_bytes + preparation.owned.backing_bytes
           }

    assert preparation.source_external_bytes == :erlang.external_size(source)
    assert preparation.prepared_external_bytes == :erlang.external_size(request)
    assert preparation.source_projection_external_bytes <= 201_241
    assert preparation.canonical_projection_external_bytes <= 201_241
  end

  defp components do
    %{
      request_representations:
        component(5, 205_337, :pump_session_and_fetch, :phase_completion_or_cleanup),
      fixed_configs: component(5, 147_456, :pump_and_session, :original_bind_and_cleanup),
      checked_policies: component(2, 1_183_744, :session_and_fetch, :fetch_and_original_bind),
      trailer_policies: component(2, 67_689, :pump, :upload_finish_and_terminal_write),
      downstream_declaration_names:
        component(1, 66_183, :downstream_response, :downstream_completion_or_cleanup),
      response_heads: component(4, 68_615, :adapter_session_and_pump, :head_handoff_and_write),
      terminal_trailer_lists:
        component(4, 67_079, :session_and_pump, :terminal_handoff_and_finish),
      data_event: component(3, 1_048_582, :adapter_session_and_pump, :full_write_ack_or_cleanup),
      upload: component(2, 65_542, :pump_and_upload_bridge, :accepted_upload_or_abort_join),
      downstream_piece: component(1, 16_390, :pump, :full_piece_write),
      extra_public_metadata: component(1, 213_965, :adapter, :bounded_head_extraction),
      proxy_normalization_scratch:
        component(1, 472_157, :adapter_and_pump, :workspace_transition),
      closed_controls: component(1, 65_536, :session_and_pump, :transition_or_termination)
    }
  end

  defp component(count, cap, owner, release) do
    %{
      multiplicity: count,
      ceiling_bytes: cap,
      external_bytes: count * cap,
      owner: owner,
      release_point: release
    }
  end

  defp call(function, args), do: apply(@reservation, function, args)

  defp reject(input) do
    assert {:error, reason} = call(:evaluate_activation, [input])
    assert is_atom(reason)
  end

  defp values do
    request = %{
      protocol: :http2,
      url: "https://upstream.test/a?",
      target: "/a?",
      method: :post,
      fields: [{"content-length", "3"}],
      body_mode: {:length, 3},
      max_upload_bytes: 65_536,
      request_limits: %{
        max_headers: 256,
        max_header_bytes: 65_536,
        max_trailers: 128,
        max_trailer_bytes: 65_536
      }
    }

    config = %Gaoxy.Proxy.HTTP{
      uri: URI.parse("https://upstream.test"),
      cacertfile: nil,
      connect_address: nil,
      transport: %{
        provider: Gaoxy.Proxy.UpstreamTransports,
        owner: self(),
        owner_epoch: make_ref(),
        resource: make_ref()
      },
      upstream_protocol: :http2,
      client: Gaoxy.Proxy.ManagedH2Client,
      limits: %{
        max_chunk_bytes: 65_536,
        opening_timeout: 5_000,
        idle_timeout: 60_000,
        write_timeout: 5_000,
        max_lifetime: 30_000
      }
    }

    assert :ok == apply(@envelope, :validate_request, [request])

    %{
      request: request,
      config: config,
      checked_client: nil,
      trailer_policy: nil,
      response_policy: nil,
      response: nil
    }
  end

  defp checked_client do
    {:ok, policy, _} =
      @preparation.prepare_policy(%{
        protocol: :http2,
        origin: "https://upstream.test",
        connect_address: {127, 0, 0, 1},
        trust: [<<48, 3, 2, 1, 1>>]
      })

    %{
      policy: policy,
      transport_scope: struct(HTTP.ManagedTransport),
      fetch_options: [
        http_version: :http2,
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

  defp oversized_slice, do: slice(65_537)
  defp slice(bytes), do: binary_part(:binary.copy("v", bytes), 0, 100)

  defp constructor_facts(value) do
    walk(value, %{
      logical_bytes: 0,
      backing_bytes: 0,
      binary_occurrences: 0,
      cons_cells: 0,
      tuples: %{},
      maps: %{},
      atom_occurrences: 0,
      integer_occurrences: 0,
      pid_occurrences: 0
    })
  end

  defp walk([], facts), do: facts

  defp walk([head | tail], facts),
    do: walk(tail, walk(head, Map.update!(facts, :cons_cells, &(&1 + 1))))

  defp walk(value, facts) when is_binary(value),
    do: %{
      facts
      | logical_bytes: facts.logical_bytes + byte_size(value),
        backing_bytes: facts.backing_bytes + :binary.referenced_byte_size(value),
        binary_occurrences: facts.binary_occurrences + 1
    }

  defp walk(value, facts) when is_tuple(value) do
    facts = %{facts | tuples: Map.update(facts.tuples, tuple_size(value), 1, &(&1 + 1))}
    Enum.reduce(Tuple.to_list(value), facts, &walk/2)
  end

  defp walk(value, facts) when is_map(value) do
    facts = %{facts | maps: Map.update(facts.maps, map_size(value), 1, &(&1 + 1))}
    Enum.reduce(Map.to_list(value), facts, fn {key, item}, acc -> walk(item, walk(key, acc)) end)
  end

  defp walk(value, facts) when is_atom(value),
    do: Map.update!(facts, :atom_occurrences, &(&1 + 1))

  defp walk(value, facts) when is_integer(value),
    do: Map.update!(facts, :integer_occurrences, &(&1 + 1))

  defp walk(value, facts) when is_pid(value), do: Map.update!(facts, :pid_occurrences, &(&1 + 1))
end
