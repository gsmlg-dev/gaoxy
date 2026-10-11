# H1 B21 independent specification review

Verdict: **PASS_STATIC_SPEC**. Task `m3_remaining_audit_h1_b21_spec_review`, direct bounded independent SPEC review. No open findings. B21 runtime, new baseline20 runtime and final CODE review are **NOT RUN**.

Reviewed repaired [plan](../../../../../plans/m3-h1-b21-tls-connecting.md), SHA256 `4d4a13ca67b5927d5e27c9d8ade8fb19d8b2448cd24dae9ff4ff9b35ba1b3e84`. Initial supplied plan hash was `b8745aa434a3a795f22b137b03800e5e97d81e1e14467bb20b2036f192069b9e`. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`; branch `codex/m3-gateway` and baseline `85c2284a035e0b4ecbf577279eee01142702b5a3` are parent-supplied. Other writers' changes are preserved.

## Resolved findings

- **B21-SPEC-01:** Preserve the historical passing started `mix run --no-compile --config .audit/m3-transport/h1-accounting-runtime-config.exs` launch. The original proposed `--no-start` conflicted with loaded application version checks and had no supported explicit startup. Parent repaired both baseline/TLS launch instructions.
- **B21-SPEC-02:** Preserve original loaded/disk comparisons plus monotonic loaded closure. Parent now explicitly requires every before-loaded row to remain identical and validates additions, excluding arbitrary intersection normalization. Candidate raw closure grows589→638; baseline583→631. Equal common identity digests do not imply identical full raw profiles.

## Review evidence

- **gate_admission:** Exact CLI and bounded 65537-byte read; reject malformed/stale/type/path/duplicate/unknown proof before registration/writes/allocations; gate envelope is parent attestation tied to current hashes and runtime binding.
- **actual_TLS95_artifacts:** Candidate raw five-case/five-cleanup/exit0; old 0.21.1 two inventory cases/two cleanups/exit1 with exact H1 observed1 expected3 and H2 observed2 expected4; all9 supplemental referenced hashes and6 baseline-negative input hashes match.
- **gate_capacity:** Current H1 required core bindings175 runtime sources+10 identity/1 BEAM rows serialize38610 compact JSON bytes. Remaining bounded native/profile/inventory/manifest/artifact rows fit declared256 rows/65536 bytes if parent uses compact serialization; final envelope must independently enforce both limits.
- **identity:** Parent directed original comparisons plus monotonic loaded closure explicit; candidate raw589 to638 rows, baseline583 to631. Existing H1 identity/1 module MD5/object-code/disk checks retained. Native environment before/after full bytes identical.
- **baseline_preservation:** Select20 or1 before registration with no skip/filter; preserve B01-B20 bodies/assertions, shared deadlines, model and peer grammar; use existing started/configured launch.
- **deterministic_connecting:** Original registered ACK before Promise.await; accepted and bounded ClientHello IDs1/2 within original3-second connect deadline; fixture attempt wire slots0/1 never substituted for peer IDs1/2.
- **capacity:** One G/three attempts; original third exact connection-capacity error plus completionok; snapshot connections2/pending0 and cut accepts2/HTTP requests0/no third accept.
- **public_uncertainty:** Actual failed ssl.connect marks lifecycle uncertainty; preserved originals yield cleanup_unconfirmed. No synthetic lost proof, private discovery/kill/suspend, refund or confirmed retirement claim.
- **failure_cleanup:** B21-only normal/late/cleanup uncertainty support; release accepted unused TLS gates even pre-head; immutable initial outcomes/original deadlines/fixed control wait slots; actor/peer joins required and forced fallbackFAIL.
- **root_ownership:** Only existing disposable public root converted to DER; gate metadata bounded; reserved policy-source actor reads/hashchecks DER after G reservation; controller never reads DER and upstream receives trust bytes, no filenames/PEM.

The raw recorded TLS candidate executes five exact cases, passes all five with five cleanups and exit0. The matched old0.21.1 negative run executes two cases, fails only the exact registration-count oracle, completes both cleanups and exits1. Hashes of all nine supplemental referenced artifacts and six negative-analysis inputs match current bytes. This review did not run either suite again.

Precise shipped SSL anchors are TCP registration24, connect-error42–45 and unconfirmed_setup95–97; the plan’s30/91 anchors are approximate but its stated consequences are correct. Public uncertainty is preserved without asserting private TLS-worker termination, confirmed retirement, N8 or native-credit refund.

## Ownership, verification and limits

Only these new MD/JSON reports were written. The reviewer did not alter the plan, source, model, manifests or frozen TLS inputs. Static reads, hashes, receipt parsing and compact gate-size arithmetic completed; report JSON and current reviewed input hashes were validated after writing. One initial read-only `git status --short` was inadvertently used to inspect pre-existing work and reported to parent; no Git mutation or independent HEAD verification occurred. No VM, Mix, test, peer, dependency or network command ran. All own commands finished synchronously; no background process exists.

H1 counters remain Sol2/unsuccessful2/Astra1; TLS Sol4/unsuccessful2/Astra2. This review adds zero repair rounds. Parent still owns actual gate generation, current H1 inventory/canonical rebinding, final source review and fresh baseline20/TLS1 execution. Native/numerical acceptance remains blocked by#97, and production activation remains disabled. No specification decision remains unresolved.
