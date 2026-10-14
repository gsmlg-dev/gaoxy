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
