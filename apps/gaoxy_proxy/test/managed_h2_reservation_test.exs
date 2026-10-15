defmodule Gaoxy.Proxy.ManagedH2ReservationTest do
  use ExUnit.Case, async: true

  alias Gaoxy.Proxy.ManagedH2Reservation, as: Reservation

  test "preserves the deterministic prospective worksheet alongside additive activation APIs" do
    worksheet = worksheet()
    assert worksheet == worksheet()
    assert worksheet.unit == :external_term_payload_bytes
    assert worksheet.status == :prospective
    assert worksheet.runtime_reservation == :not_implemented
    assert worksheet.profile == %{connections: 2, requests: 32, pending: 0}

    assert apply(Reservation, :__info__, [:functions]) == [
             activation_contract: 0,
             evaluate_activation: 1,
             reservation_bytes: 3,
             worksheet: 0
           ]

    refute Map.has_key?(worksheet, :reservation_bytes)
    refute Map.has_key?(worksheet, :activation_bytes)
    refute Map.has_key?(worksheet, :heap_bytes)
    refute Map.has_key?(worksheet, :vm_memory_bytes)
  end

  test "names binary, nonempty pair-list and four-tuple projection formulas" do
    assert worksheet().formulas == %{
             binary: "B(b) = b + 6",
             field_list: "F(n,b) = b + 12n + 7",
             request_projection: "Q = 196608 + 4633 = 201241"
           }

    assert worksheet().limits == %{
             projection_logical_bytes: 196_608,
             projection_external_bytes: 201_241,
             fields: 256,
             trailers: 128,
             field_bytes: 65_536,
             trailer_bytes: 65_536,
             upload_bytes: 65_536,
             data_delivery_bytes: 1_048_576,
             downstream_piece_bytes: 16_384
           }
  end

  test "the four-tuple request projection wrapper is exactly 4633 at maximum pair counts" do
    worksheet = worksheet()
    empty_projection = {"", "", pairs(256, 0), pairs(128, 0)}
    assert :erlang.external_size(empty_projection) == 4_633

    for payload <- [196_607, 196_608, 196_609] do
      projection = projection(payload)
      assert :erlang.external_size(projection) == payload + 4_633
    end

    assert :erlang.external_size(projection(196_608)) ==
             worksheet.limits.projection_external_bytes

    assert :erlang.external_size(projection(196_609)) >
             worksheet.limits.projection_external_bytes

    assert :erlang.external_size({"", "", pairs(257, 0), pairs(128, 0)}) == 4_645
    assert :erlang.external_size({"", "", pairs(256, 0), pairs(129, 0)}) == 4_645
  end

  test "source request projection row uses the literal four-tuple envelope once" do
    assert worksheet().envelopes.source_request_projection == %{
             formula: "Q",
             multiplicity: 1,
             external_bytes: :erlang.external_size(projection(196_608))
           }
  end

  test "canonical request projection row uses the literal four-tuple envelope once" do
    assert worksheet().envelopes.canonical_request_projection == %{
             formula: "Q",
             multiplicity: 1,
             external_bytes: :erlang.external_size(projection(196_608))
           }
  end

  test "received and normalized response heads have two 256-pair ETF envelopes" do
    row = worksheet().envelopes.response_heads
    assert row == %{formula: "2F(256,65536)", multiplicity: 2, external_bytes: 137_230}

    for payload <- [65_535, 65_536, 65_537] do
      assert :erlang.external_size(pairs(256, payload)) == payload + 12 * 256 + 7
    end

    assert row.external_bytes == 2 * :erlang.external_size(pairs(256, 65_536))
    assert 2 * :erlang.external_size(pairs(256, 65_537)) > row.external_bytes
    assert :erlang.external_size(pairs(257, 65_536)) == 65_536 + 12 * 257 + 7
  end

  test "cached and filtered response trailers have two 128-pair ETF envelopes" do
    row = worksheet().envelopes.response_trailers
    assert row == %{formula: "2F(128,65536)", multiplicity: 2, external_bytes: 134_158}

    for payload <- [65_535, 65_536, 65_537] do
      assert :erlang.external_size(pairs(128, payload)) == payload + 12 * 128 + 7
    end

    assert row.external_bytes == 2 * :erlang.external_size(pairs(128, 65_536))
    assert 2 * :erlang.external_size(pairs(128, 65_537)) > row.external_bytes
    assert :erlang.external_size(pairs(129, 65_536)) == 65_536 + 12 * 129 + 7
  end

  test "original and compact upload pieces have two 64KiB binary ETF envelopes" do
    row = worksheet().envelopes.upload
    assert row == %{formula: "2B(65536)", multiplicity: 2, external_bytes: 131_084}

    for payload <- [65_535, 65_536, 65_537] do
      assert :erlang.external_size(:binary.copy("x", payload)) == payload + 6
    end

    assert row.external_bytes == 2 * :erlang.external_size(:binary.copy("x", 65_536))
    assert 2 * :erlang.external_size(:binary.copy("x", 65_537)) > row.external_bytes
  end

  test "original and compact DATA deliveries have two separate 1MiB binary ETF envelopes" do
    row = worksheet().envelopes.data_delivery
    assert row == %{formula: "2B(1048576)", multiplicity: 2, external_bytes: 2_097_164}

    for payload <- [1_048_575, 1_048_576, 1_048_577] do
      assert :erlang.external_size(:binary.copy("x", payload)) == payload + 6
    end

    assert row.external_bytes == 2 * :erlang.external_size(:binary.copy("x", 1_048_576))
    assert 2 * :erlang.external_size(:binary.copy("x", 1_048_577)) > row.external_bytes
  end

  test "downstream frame or write pieces have one 16KiB envelope independent of DATA delivery" do
    worksheet = worksheet()
    row = worksheet.envelopes.downstream_piece
    assert row == %{formula: "B(16384)", multiplicity: 1, external_bytes: 16_390}

    for payload <- [16_383, 16_384, 16_385] do
      assert :erlang.external_size(:binary.copy("x", payload)) == payload + 6
    end

    assert row.external_bytes == :erlang.external_size(:binary.copy("x", 16_384))
    assert :erlang.external_size(:binary.copy("x", 16_385)) > row.external_bytes
    assert worksheet.limits.data_delivery_bytes == 64 * worksheet.limits.downstream_piece_bytes
  end

  test "named per-request subtotal includes exactly the seven independently sized envelopes" do
    worksheet = worksheet()

    assert Enum.sort(Map.keys(worksheet.envelopes)) ==
             Enum.sort([
               :source_request_projection,
               :canonical_request_projection,
               :response_heads,
               :response_trailers,
               :upload,
               :data_delivery,
               :downstream_piece
             ])

    expected =
      2 * :erlang.external_size(projection(196_608)) +
        2 * :erlang.external_size(pairs(256, 65_536)) +
        2 * :erlang.external_size(pairs(128, 65_536)) +
        2 * :erlang.external_size(:binary.copy("x", 65_536)) +
        2 * :erlang.external_size(:binary.copy("x", 1_048_576)) +
        :erlang.external_size(:binary.copy("x", 16_384))

    assert expected == 2_918_508
    assert worksheet.named_subtotal_per_request == expected

    assert Enum.sum(Enum.map(worksheet.envelopes, fn {_, row} -> row.external_bytes end)) ==
             expected
  end

  test "fixed response upload and write subtotal excludes both request projections" do
    worksheet = worksheet()

    expected =
      2 * :erlang.external_size(pairs(256, 65_536)) +
        2 * :erlang.external_size(pairs(128, 65_536)) +
        2 * :erlang.external_size(:binary.copy("x", 65_536)) +
        2 * :erlang.external_size(:binary.copy("x", 1_048_576)) +
        :erlang.external_size(:binary.copy("x", 16_384))

    assert expected == 2_516_026
    assert worksheet.fixed_response_upload_write_subtotal == expected
    assert worksheet.named_subtotal_per_request - 2 * 201_241 == expected
  end

  test "R32 named subtotal multiplies the prospective subtotal without adding native buffers" do
    worksheet = worksheet()
    assert worksheet.named_subtotal_for_32_requests == 32 * 2_918_508
    assert worksheet.named_subtotal_for_32_requests == 93_392_256

    assert worksheet.named_subtotal_for_32_requests ==
             worksheet.profile.requests * worksheet.named_subtotal_per_request
  end

  test "later adapter must define finite retained schemas multiplicities owners and release enforcement points" do
    adapter = worksheet().later_adapter
    assert adapter.status == :required_before_runtime_reservation
    assert adapter.retained_schemas == [:gaoxy_control, :configuration, :trailer_policy]

    assert adapter.required_facts == [
             :finite_maxima,
             :multiplicities,
             :owners,
             :release_points,
             :enforcement_points
           ]

    assert adapter.accounting_rules == %{
             opaque_completion_or_scope: :do_not_serialize,
             uninspected_projections: :must_not_charge_zero,
             complete_values_and_projections: :must_not_double_charge,
             pin_control_metadata: :owner_ledger,
             request_body_payload: :request_reservation
           }
  end

  test "later adapter obligations retain logical backing and lifecycle enforcement boundaries" do
    assert worksheet().later_adapter.enforcement == %{
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
  end

  test "public native limits remain separate descriptions without native memory certification" do
    native = worksheet().public_native_limits

    assert native == %{
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

    assert native.writer_receive_bytes_for_two_connections ==
             native.connections *
               (native.writer_bytes_per_connection + native.receive_bytes_per_connection)
  end

  defp worksheet, do: apply(Reservation, :worksheet, [])

  # Independent ETF witnesses: these are constructor shapes, not valid HTTP fields.
  defp pairs(count, payload) do
    [{"", :binary.copy("x", payload)} | List.duplicate({"", ""}, count - 1)]
  end

  defp projection(payload) do
    {:binary.copy("u", 65_536), :binary.copy("p", 65_536), pairs(256, payload - 2 * 65_536),
     pairs(128, 0)}
  end
end
