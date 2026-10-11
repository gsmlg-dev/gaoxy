defmodule Gaoxy.Proxy.ManagedH1Accounting do
  @moduledoc false

  # Named partial facts for the reviewed profile, not a certified runtime budget.
  # A change of cohort, runtime, source or profile requires independent requalification.
  def facts do
    %{
      qualification: :unqualified,
      cohort: %{version: "0.21.3", packages: 7, tag: "ceecbf2df62ca80c361597c7303f65a153f2ce3c"},
      runtime: %{
        elixir: "1.18.5",
        otp: "28.5.0.7",
        erts: "16.4.0.6",
        ssl: "11.6.0.6",
        word_bytes: 8
      },
      profile: %{
        connections: 2,
        attempts: 32,
        pending: 0,
        protocol: :http1,
        tls_backend: :ssl,
        http2_profile: :native_v1,
        buffer: 8192,
        recbuf: 8192,
        sndbuf: 8192,
        stream_response: true,
        decode_body: false,
        redirect: :manual
      },
      constructors: %{
        request_pair_cap: 256,
        trailer_pair_cap: 128,
        response_pair_cap: 16_384,
        cons_words: 2,
        pair_tuple_words: 3,
        request_pair_skeleton_bytes: 256 * (2 + 3) * 8,
        trailer_pair_skeleton_bytes: 128 * (2 + 3) * 8,
        response_pair_skeleton_bytes: 16_384 * (2 + 3) * 8,
        max_upload_chunk_bytes: 65_536,
        max_upload_framing_bytes: 9
      },
      limits: %{
        url_bytes: 65_536,
        field_bytes: 65_536,
        trailer_bytes: 65_536,
        certificates: 128,
        certificate_bytes: 65_536,
        trust_bytes: 1_048_576,
        policy_source_backing_bytes: 65_536 + 1_048_576,
        request_source_backing_bytes: 3 * 65_536
      },
      obligations: [
        %{id: :p0, status: :unqualified, reason: :boundary_admission_enforcement},
        %{id: :p1, status: :unqualified, reason: :delivery_logical_and_backing_bound},
        %{id: :p2, status: :unqualified, reason: :runtime_representation},
        %{id: :p3, status: :unqualified, reason: :policy_transformation_peaks},
        %{
          id: :p4,
          status: :unqualified,
          reason: :request_phase_copy_overlap,
          coverage: [
            :eof_content_length_delivery,
            :one_byte_event_batches,
            :complete_long_chunk_size_integers,
            :rejected_parser_heads
          ]
        },
        %{id: :p5, status: :unqualified, reason: :turnover_controls},
        %{id: :p6, status: :unqualified, reason: :independently_reviewed_composition}
      ]
    }
  end

  # TODO(upstream): gsmlg-dev/http_fetch#97 — supported control accounting gates activation.
  # Deliberately no proof/constant arguments, evaluator or activation-success path.
  def activation_status, do: {:error, {:unqualified, [:p0, :p1, :p2, :p3, :p4, :p5, :p6]}}
end
