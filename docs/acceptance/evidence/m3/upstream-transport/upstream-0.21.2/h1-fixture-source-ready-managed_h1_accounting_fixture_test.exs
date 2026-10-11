Code.require_file("managed_h1_accounting_fixture.exs", __DIR__)

Gaoxy.Qualification.ManagedH1AccountingFixture.configure!(System.argv())

defmodule Gaoxy.Qualification.ManagedH1AccountingFixtureTest do
  use ExUnit.Case, async: false
  alias Gaoxy.Qualification.ManagedH1AccountingFixture, as: Fixture
  @moduletag timeout: 35_000

  test "B01 four generation reservations before opening" do
    assert %{generation_busy: 2, opens: 2, occupied_generations: 4, local_uncertainty: true} =
             Fixture.run(:b01)
  end

  test "B02 local preparing R32 gate" do
    assert %{preparing: 32, busy: true, fetches: 0, requests: 0, released_local: 32} =
             Fixture.run(:b02)
  end

  test "B03 initial and effective field counts" do
    assert %{accepted_counts: [256, 256, 255], local_rejects: 1, public_rejects: 4,
             wire_oracle: true, rejected_wire: 0} = Fixture.run(:b03)
  end

  test "B04 exact 65536 charges and opaque empty query" do
    assert %{subcases: 12, accepted: 6, rejected: 6, targets: ["/b04", "/b04?"],
             exact_charge_oracle: true, wire_oracle: true} = Fixture.run(:b04)
  end

  test "B05 bounded backing and malformed input" do
    assert %{backing_rejects: 3, compact_copies: 3, malformed: :invalid_fields,
             excess: :trailer_limit, malformed_128: :invalid_trailers, fetches: 0} =
             Fixture.run(:b05)
  end

  test "B06 retained H1 connection C2" do
    assert %{capacity: {:error, {:transport_scope_capacity, :connections}}, connections: 2,
             pending: 0, requests: 2, rejected_wire: 0, held_consumers: 2} = Fixture.run(:b06)
  end

  test "B07 unread stream through graceful retirement" do
    assert %{initial_completion: {:error, :cleanup_pending}, initial_retirement: {:error, :cleanup_pending},
             final_completion: :ok, final_retirement: :ok, body_sha256: digest, body_length: 1} =
             Fixture.run(:b07)
    assert digest == Fixture.sha256("h")
  end

  test "B08 PID upload preloaded chunk and ACK order" do
    assert %{preloaded_without_ack: true, upload_lengths: [65_536, 65_536], upload_acks: [:ok, :ok],
             root_before_next_input: true, head_before_body: true, body_length: 131_072,
             body_sha256: digest, finish: :ok} = Fixture.run(:b08)
    assert digest == Fixture.upload_sha256()
  end

  test "B09 one-byte fanout with controlled ACK" do
    assert %{held_credit: 1, second_offer: {:error, :ownership_pending}, body_length: 1365,
             body_sha256: digest, ends: 1, trailers: [], credit_order: true} = Fixture.run(:b09)
    assert digest == Fixture.sha256(:binary.copy("a", 1365))
  end

  test "B10 content-length and EOF preserve data larger than F" do
    assert %{lengths: [131_073, 131_073], digests: [cl, eof], ends: [1, 1], completions: [:ok, :ok]} =
             Fixture.run(:b10)
    expected = Fixture.pattern_sha256(131_073)
    assert cl == expected and eof == expected
  end

  test "B11 finite chunk-size lines and real bignum outcome" do
    assert %{boundary: %{length: 0, ends: 1, error: nil}, over: :line_too_long,
             bignum: %{length: 3, digest: digest, error: :closed}, invalid: :invalid_chunk_size,
             completion_handles: 4} = Fixture.run(:b11)
    assert digest == Fixture.sha256("z\r\n")
  end

  test "B12 trailers count forbidden field and exact wire limit" do
    assert %{ordered_128: true, excess: :trailers_too_large,
             forbidden: {:forbidden_trailer, "content-length"}, exact_wire: 65_536,
             over_wire: :trailers_too_large, upload_validations: [
               {:error, :trailers_too_large}, {:error, {:forbidden_trailer, "content-length"}}, :ok
             ], upload_ordered_128: true} = Fixture.run(:b12)
  end

  test "B13 expired pre-Fetch nonce cannot change occupied replacement" do
    assert %{old_outcome: :timed_out, old_deadline: 200, slot_reused: true, nonce_changed: true,
             stale_replies: 2, replacement_unchanged: true,
             launched_release: {:error, :ownership_pending}} = Fixture.run(:b13)
  end

  test "B14 owned source death before and after launch" do
    assert %{before_launch_fetches: 0, after_launch_registered: true, declared_deaths: 2,
             fabricated_public_outcomes: 0, original_cleanup: :ok, refunds: 0} = Fixture.run(:b14)
  end

  test "B15 retirement closes local preparing and late opening" do
    assert %{late_launch: {:error, :invalid_phase}, fetches: 0, requests: 0,
             late_scope_registered: true, late_readiness_published: false, retirements: [:ok, :ok]} =
             Fixture.run(:b15)
  end

  test "B16 abort A while B exchanges bytes" do
    assert %{a_retirement: :ok, b_completion: :ok, b_length: 1, b_digest: digest,
             b_connection_preserved: true, b_ends: 1} = Fixture.run(:b16)
    assert digest == Fixture.sha256("h")
  end

  test "B17 original D survives one abort escalation" do
    assert %{deadline: 500, published: {:error, :cleanup_pending}, late_published: {:error, :cleanup_pending},
             graceful_calls: 1, abort_calls: 1, late_receipt_registered: true, overshoot_ms: elapsed} =
             Fixture.run(:b17)
    assert elapsed in 0..100
  end

  test "B18 public waits remain distinct from lost fixture proof" do
    assert %{success: :ok, pending: {:error, :cleanup_pending}, lost_public_oracle: :ok,
             lost_fixture_proof: true, lost_release: {:error, :lost_proof},
             pending_preserved: true, retirement_pending: {:error, :cleanup_pending}, retirement_final: :ok} =
             Fixture.run(:b18)
  end

  test "B19 finite connection reuse keeps held sibling and nine proof slots" do
    assert %{sequential: 8, reused_connection: true, accepted_connections: 2,
             held_sibling_length: 1, held_sibling_ends: 1, occupied_proof_slots: 9,
             refunds: 0} = Fixture.run(:b19)
  end

  test "B20 operation caps invalid commands and stale replies" do
    assert %{snapshots: 3, invalid_operation: {:error, :invalid_operation}, duplicate_cached: true,
             stale_ignored: true, counts_unchanged: true, fixed_shape: true, row_bytes: bytes,
             final_snapshot_valid: true} = Fixture.run(:b20)
    assert bytes <= 4096
  end
end

Gaoxy.Qualification.ManagedH1AccountingFixture.finish!(ExUnit.run())
