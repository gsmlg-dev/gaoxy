defmodule Gaoxy.Proxy.ManagedH1AccountingTest do
  use ExUnit.Case, async: true
  alias Gaoxy.Proxy.ManagedH1Accounting, as: Accounting

  test "reports named partial constructor facts and refuses production activation" do
    facts = Accounting.facts()
    assert %{connections: 2, attempts: 32, pending: 0} = facts.profile
    assert facts.constructors.request_pair_skeleton_bytes == 256 * (2 + 3) * 8
    assert facts.constructors.trailer_pair_skeleton_bytes == 128 * (2 + 3) * 8
    assert facts.constructors.response_pair_skeleton_bytes == 16_384 * (2 + 3) * 8
    assert facts.constructors.max_upload_framing_bytes == byte_size("10000") + 4

    assert {:error, {:unqualified, [:p0, :p1, :p2, :p3, :p4, :p5, :p6]}} =
             Accounting.activation_status()
  end

  test "keeps pinned provenance and all seven obligations explicitly unqualified" do
    facts = Accounting.facts()
    assert :unqualified = facts.qualification

    assert %{version: "0.21.3", packages: 7, tag: "ceecbf2df62ca80c361597c7303f65a153f2ce3c"} =
             facts.cohort

    assert %{elixir: "1.18.5", otp: "28.5.0.7", erts: "16.4.0.6", ssl: "11.6.0.6", word_bytes: 8} =
             facts.runtime

    assert %{
             protocol: :http1,
             tls_backend: :ssl,
             http2_profile: :native_v1,
             buffer: 8192,
             recbuf: 8192,
             sndbuf: 8192,
             stream_response: true,
             decode_body: false,
             redirect: :manual
           } = facts.profile

    assert [
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
           ] = facts.obligations
  end

  test "keeps source and pair limits separate without inventing delivery or activation totals" do
    facts = Accounting.facts()
    assert facts.limits.policy_source_backing_bytes == 65_536 + 1_048_576
    assert facts.limits.request_source_backing_bytes == 3 * 65_536
    assert facts.limits.certificate_bytes == 65_536
    assert facts.limits.certificates == 128
    assert facts.limits.trust_bytes == 1_048_576
    assert facts.constructors.request_pair_cap == 256
    assert facts.constructors.trailer_pair_cap == 128
    assert facts.constructors.response_pair_cap == div(65_536, byte_size("a:\r\n"))
    refute Map.has_key?(facts, :activation_bytes)
    refute Map.has_key?(facts, :delivery_bytes)
    refute Map.has_key?(facts, :proofs)
  end

  test "successful preparation cannot activate or supply caller proof constants" do
    assert {:ok, policy, _} =
             Gaoxy.Proxy.ManagedH1Preparation.prepare_policy(%{
               origin: "http://example.test",
               connect_address: {127, 0, 0, 1},
               trust: nil
             })

    assert {:ok, _, _} =
             Gaoxy.Proxy.ManagedH1Preparation.prepare_request(policy, %{
               url: "http://example.test/",
               method: :get,
               fields: [],
               body: nil,
               trailers: [],
               timeout: 1,
               connect_timeout: 1
             })

    for _ <- 1..3 do
      assert {:error, {:unqualified, [:p0, :p1, :p2, :p3, :p4, :p5, :p6]}} =
               Accounting.activation_status()
    end

    assert_raise UndefinedFunctionError, fn ->
      apply(Accounting, :activation_status, [%{profile: :other, proofs: %{p1: 0, p2: 0, p5: 0}}])
    end

    refute function_exported?(Accounting, :evaluate, 2)
  end
end
