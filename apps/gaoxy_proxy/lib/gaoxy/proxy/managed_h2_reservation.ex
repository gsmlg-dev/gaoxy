defmodule Gaoxy.Proxy.ManagedH2Reservation do
  @moduledoc """
  Static prospective managed H2 payload worksheet for the C2/R32/P0 profile.

  Sizes use external-term payload bytes, not heap, native or VM memory. The
  named subtotal omits retained adapter control/configuration/trailer-policy
  schemas and cannot supply a live reservation or activate managed H2.

  Request projections are precisely `{url, target, fields, trailers}`. Their
  wrapper allows two binaries, one four-tuple, 256 field pairs and 128 trailer
  pairs. Complete values already including a projection must not charge it again.
  Native limits are separate descriptions, not a native-memory certification.
  """

  alias Gaoxy.Proxy.ManagedH2Envelope

  @activation_bytes 9_444_956

  @doc "Returns the closed fixed-endpoint activation payload ledger."
  def activation_contract do
    %{
      unit: :external_term_payload_bytes,
      profile: %{connections: 2, requests: 32, pending: 0},
      components: %{
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
        data_event:
          component(3, 1_048_582, :adapter_session_and_pump, :full_write_ack_or_cleanup),
        upload: component(2, 65_542, :pump_and_upload_bridge, :accepted_upload_or_abort_join),
        downstream_piece: component(1, 16_390, :pump, :full_piece_write),
        extra_public_metadata: component(1, 213_965, :adapter, :bounded_head_extraction),
        proxy_normalization_scratch:
          component(1, 472_157, :adapter_and_pump, :workspace_transition),
        closed_controls: component(1, 65_536, :session_and_pump, :transition_or_termination)
      },
      proxy_subtotal_per_request: 8_920_668,
      renderer_allowance_per_request: 524_288,
      reservation_per_request: @activation_bytes,
      reservation_for_32_requests: 32 * @activation_bytes,
      opaque_capabilities: %{scope: 1, original_completion: 1, completion_shell_references: 2}
    }
  end

  @doc "Validates and measures complete public projections without discounting later phases."
  def evaluate_activation(
        %{
          request: request,
          config: config,
          checked_client: client,
          trailer_policy: trailer,
          response_policy: response_policy,
          response: response
        } = values
      )
      when map_size(values) == 6 do
    with :ok <- ManagedH2Envelope.validate_request(request),
         :ok <- ManagedH2Envelope.validate_config(config),
         true <- request.protocol == config.upstream_protocol,
         {:ok, _} <- ManagedH2Envelope.prepare(config, Map.delete(request, :protocol)),
         :ok <- optional_client(client, request.protocol, request.url),
         :ok <- optional_policy(trailer),
         :ok <- optional_policy(response_policy),
         :ok <- optional_response(response, request.url) do
      projections = %{
        request: request,
        config: config,
        checked_client: client_projection(client),
        trailer_policy: trailer,
        response_policy: response_policy,
        response: response_projection(response)
      }

      measured = Map.new(projections, fn {key, value} -> {key, measure(value)} end)

      if measured.request <= 205_337 and measured.config <= 147_456 and
           measured.checked_client <= 1_183_744 and measured.trailer_policy <= 67_689 and
           measured.response_policy <= 67_689 and measured.response <= 213_965 do
        {:ok,
         %{
           contract: activation_contract(),
           measured_external_bytes: measured,
           projections: projections,
           reservation_bytes: @activation_bytes
         }}
      else
        {:error, :activation_limit}
      end
    else
      _ -> {:error, :invalid_activation}
    end
  end

  def evaluate_activation(_), do: {:error, :invalid_activation}

  @doc "Returns the complete conservative request reserve after finite input validation."
  def reservation_bytes(fields, url_bytes, chunk_bytes)
      when is_integer(url_bytes) and url_bytes in 1..65_536 and
             is_integer(chunk_bytes) and chunk_bytes in 1..65_536 do
    if bounded_fields?(fields, 0, 0, 0),
      do: @activation_bytes,
      else: raise(ArgumentError, "invalid managed H2 reservation input")
  end

  def reservation_bytes(_, _, _), do: raise(ArgumentError, "invalid managed H2 reservation input")

  defp component(count, cap, owner, release),
    do: %{
      multiplicity: count,
      ceiling_bytes: cap,
      external_bytes: count * cap,
      owner: owner,
      release_point: release
    }

  defp optional_client(nil, _, _), do: :ok

  defp optional_client(client, protocol, url) do
    with :ok <- ManagedH2Envelope.validate_checked_client(client, protocol),
         # The accepted policy validator has checked this URI source before parsing.
         request_uri = URI.parse(url),
         policy_uri = URI.parse(client.policy.origin),
         true <-
           {request_uri.scheme, String.downcase(request_uri.host), request_uri.port} ==
             {policy_uri.scheme, String.downcase(policy_uri.host), policy_uri.port},
         do: :ok
  end

  defp optional_policy(nil), do: :ok
  defp optional_policy(policy), do: ManagedH2Envelope.validate_trailer_policy(policy)
  defp optional_response(nil, _), do: :ok

  defp optional_response(response, url) do
    with {:ok, _} <- ManagedH2Envelope.validate_response(response, url), do: :ok
  end

  defp client_projection(nil), do: nil

  defp client_projection(client),
    do: %{client | transport_scope: {:opaque, HTTP.ManagedTransport}}

  defp response_projection(nil), do: nil
  defp response_projection(response), do: %{response | headers: %HTTP.Headers{}, body: nil}
  defp measure(nil), do: 0
  defp measure(value), do: :erlang.external_size(value)

  defp bounded_fields?([], _, _, _), do: true

  defp bounded_fields?([{name, value} | rest], count, logical, backing)
       when count < 256 and is_binary(name) and is_binary(value) do
    logical = logical + byte_size(name) + byte_size(value)
    backing = backing + :binary.referenced_byte_size(name) + :binary.referenced_byte_size(value)
    logical <= 65_536 and backing <= 65_536 and bounded_fields?(rest, count + 1, logical, backing)
  end

  defp bounded_fields?(_, _, _, _), do: false

  @doc "Returns the closed prospective worksheet and later adapter obligations."
  def worksheet do
    %{
      unit: :external_term_payload_bytes,
      status: :prospective,
      runtime_reservation: :not_implemented,
      profile: %{connections: 2, requests: 32, pending: 0},
      formulas: %{
        binary: "B(b) = b + 6",
        field_list: "F(n,b) = b + 12n + 7",
        request_projection: "Q = 196608 + 4633 = 201241"
      },
      limits: %{
        projection_logical_bytes: 196_608,
        projection_external_bytes: 201_241,
        fields: 256,
        trailers: 128,
        field_bytes: 65_536,
        trailer_bytes: 65_536,
        upload_bytes: 65_536,
        data_delivery_bytes: 1_048_576,
        downstream_piece_bytes: 16_384
      },
      envelopes: %{
        source_request_projection: %{formula: "Q", multiplicity: 1, external_bytes: 201_241},
        canonical_request_projection: %{formula: "Q", multiplicity: 1, external_bytes: 201_241},
        response_heads: %{formula: "2F(256,65536)", multiplicity: 2, external_bytes: 137_230},
        response_trailers: %{formula: "2F(128,65536)", multiplicity: 2, external_bytes: 134_158},
        upload: %{formula: "2B(65536)", multiplicity: 2, external_bytes: 131_084},
        data_delivery: %{formula: "2B(1048576)", multiplicity: 2, external_bytes: 2_097_164},
        downstream_piece: %{formula: "B(16384)", multiplicity: 1, external_bytes: 16_390}
      },
      named_subtotal_per_request: 2_918_508,
      fixed_response_upload_write_subtotal: 2_516_026,
      named_subtotal_for_32_requests: 93_392_256,
      later_adapter: %{
        status: :required_before_runtime_reservation,
        retained_schemas: [:gaoxy_control, :configuration, :trailer_policy],
        required_facts: [
          :finite_maxima,
          :multiplicities,
          :owners,
          :release_points,
          :enforcement_points
        ],
        accounting_rules: %{
          opaque_completion_or_scope: :do_not_serialize,
          uninspected_projections: :must_not_charge_zero,
          complete_values_and_projections: :must_not_double_charge,
          pin_control_metadata: :owner_ledger,
          request_body_payload: :request_reservation
        },
        enforcement: %{
          request_retention: :compact_before_session,
          response_heads: %{fields: 256, bytes: 65_536, before: :cache_or_policy},
          response_trailers: %{fields: 128, bytes: 65_536, before: :cache_or_policy},
          data_delivery: %{logical_bytes: 1_048_576, backing_bytes: 1_048_576, before: :copy},
          upload: %{logical_bytes: 65_536, backing_bytes: 65_536},
          token_traversal: :finite_before_splitting,
          outstanding_deliveries: 1,
          acknowledgement: :after_downstream_write,
          request_hold_release: :after_public_original_completion,
          downstream_piece_bytes: 16_384
        }
      },
      public_native_limits: %{
        memory_certification: :not_claimed,
        included_in_etf_subtotal: false,
        profile: :native_v1,
        connections: 2,
        requests: 32,
        pending: 0,
        policy_external_bytes: 1_048_576,
        effective_field_bytes: 65_536,
        effective_field_count: 256,
        upload_bridge_bytes: 65_536,
        writer_bytes_per_connection: 1_048_576,
        receive_bytes_per_connection: 1_048_576,
        writer_receive_bytes_for_two_connections: 4_194_304,
        header_block_bytes: 65_536,
        header_fields: 256,
        header_frames: 256,
        informational_responses: 128,
        lifetime_metadata_bytes: 65_536,
        lifetime_notifications: 130,
        pseudo_fields: 4,
        push: 0,
        initial_window_bytes: 65_535,
        data_fragment_bytes: 16_384,
        header_fragment_bytes: 16_384,
        huffman: false,
        literal_indexing: false,
        priority_padding: false
      }
    }
  end
end
