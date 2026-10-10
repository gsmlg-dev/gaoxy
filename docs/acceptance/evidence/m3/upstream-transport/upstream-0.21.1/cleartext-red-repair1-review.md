# Cleartext red harness repair1 review

Date: 2026-10-11 Asia/Shanghai. Direct independent Sol task
`m3_h1_preparation_spec_review/cleartext-red-repair1-review`.

**PASS for the bounded static repair/spec gate; no blocking finding.** The
only probe delta from the prior frozen cleartext driver moves the same obsolete
capacity hard match after the existing successful completion/retirement checks,
before the capacity case report. Expected values, wire/lifecycle assertions,
timeouts and cleanup remain unchanged. This permits the parent to freeze and
execute repair1; it does not claim the repaired runtime gate passed.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, HEAD `a6a210c720d4a0fa9b8fa5f485e5c07a825ad03c`.
Ownership is this report only. Parent/architecture-agent changes are preserved;
no fixture, dependency, product, other document or historical receipt was edited.
Reviewed the [updated cleartext plan](../../../../../plans/m3-upstream-0.21.1-cleartext.md),
the [prior driver review](cleartext-red-code-review.md), the exact source delta,
public completion/retirement source contracts and original failure evidence.

## Original run remains a failed cleanup gate

The original [analysis](cleartext-red-analysis.json) correctly records
`FAIL_EXPECTED_RED_CLEANUP_GATE`. Its [raw receipt](cleartext-red.json) and
verified log show exit1, the exact intended canonical-versus-pending MatchError,
16 completed case receipts and17 cleanup attempts. All17 peers joined, both
scopes in the failing case retired `:ok`, but only16 cleanup receipts succeeded:
that case's original held completion was recorded as expected `:ok` and became
`{:error,:cleanup_unconfirmed}` after abort. The unchanged individual hard match
inside cleanup correctly rejected it. `with_peer/2` logged cleanup failure and
re-raised the primary mismatch; that primary exception cannot hide the failed
gate.

Python verified the raw log SHA256,16 `MANAGED_CASE` labels,17 `MANAGED_CLEANUP`
labels and one `MANAGED_CLEANUP_FAILURE`. Its429 before/after source maps are
identical, with the prior probe hash below. The raw receipt records no remaining
owned peer and no timeout. The fixture is not an ExUnit suite: its raw `tests:0`
field is not a case count; the16 case receipts are the executed-case evidence.
No initial receipt was changed or relabeled as an accepted red/24-case pass.

The evidence identifies a harness-ordering issue: the deliberate obsolete match
interrupted the normal held-stream path, so failure cleanup canceled a still-live
request whose completion could conservatively become unconfirmed. No new
upstream defect is established by this evidence. Broadening that completion's
expected result would weaken the case and is not the repair.

## Exact one-line movement

Prior frozen probe SHA256:
`93336bb15c67f05bfd607930e7a797dcc1c02efcd487e7d95447b5e5df080c8f`.
Repair1 probe SHA256:
`e1a02712ff635da1c9d2f618c2777bdbc9f93ea8d965ee73f571d52ab9b20f59`.

Independent reconstruction removes the unique line
`      ^source_error = actual_error` from its new location and inserts those
identical bytes before the original `Peer.complete(cr)`/wire-check sequence.
The reconstructed whole file hashes to the prior933 value in the original red
before/after snapshots. This establishes the complete delta, including the
already-reviewed profile driver, without relying on a guessed saved source.

Relative to that prior file, the movement is:

```diff
-      ^source_error = actual_error
       Peer.complete(cr)
       no_request_bytes(peer, wire_before)
       ...
       true = independent_cid != cid and replacement_cid != cid
+      ^source_error = actual_error

       report(
```

`actual_error` is still captured at the rejected Promise before any subsequent
request and reported with the canonical comparison. `source_error` remains
exactly `{:error,:pending_capacity}`. Both bindings are unchanged immutable
values; later operations do not replace the observed rejection. The moved
line still fails that exact hard match before the capacity case can increment
its report count. No obsolete expectation is accepted silently.

Before the moved match, the repaired case must now satisfy every previously
existing assertion in order:

- Rejected-request completion `:ok`, unchanged no-request-byte snapshot, exact
  initial2 accepts/two request paths.
- Independent-scope progress while the original body remains held, with one
  original active request, zero pending queue and one connection.
- Explicitly finish the original peer response, consume exactly `abcdefgh`,
  establish original completion `:ok`, and observe its connection closure.
- Reach the public zero connection/request/preparing/resource ledger within the
  existing3,000 ms absolute deadline; make the replacement request.
- Gracefully retire both scopes with the existing finite `:ok` receipt checks;
  require exactly3 accepts, the four exact request/connection identities, shared
  independent connection reuse and distinct replacement/original identities.

The GOAWAY/PING barrier, original rejection observation, no replay, field/body
bytes, cleanup body, normal/abnormal completion expectations, protocol selection
and39/24 counts are all byte-identical outside the moved line. Delaying the
intentional failure makes those resource checks execute; it does not bypass any
failed check or convert any abnormal completion into normal success.

## Public contract and cleanup rationale

Installed `HTTP.RequestCompletion` documents `:ok` as tracked request-resource
cleanup, `:cleanup_pending` as unfinished cleanup and `:cleanup_unconfirmed` as
lost evidence, including owner death. It distinguishes pooled stream/reservation
release from shared connection shutdown. Its terminal latch logic preserves
`:ok` on repeated waits after successful completion.

The unchanged `Peer.complete/1` requires `:ok` in current/cross-process waits,
joins the completion waiter normally, then repeats the zero-time wait. The
normal completion proof therefore precedes the intentional mismatch for both
the rejected request and held response, without changing their recorded `:ok`
expectations. New independent/replacement drains also use the existing normal
completion path.

Installed `HTTP.ManagedTransport` documents that graceful retirement lets
admitted work finish and provides a durable repeatable receipt. Its public
`retire/2` returns the receipt for an already-retired latch; finite
`await_retired/2` still checks the coordinator's termination. The existing
fixture `retire/2` requires `:ok` within3,000 ms. The failure cleanup can then
repeat retirement and request abort/waits without requiring a still-held normal
request to survive a deliberately premature exception. This is a source-based
ordering rationale, not proof of the rerun's cleanup outcomes.

## Required repaired red result

Driver order and the report location remain unchanged. If all intervening checks
pass, the repaired expected red must contain:

- Exactly16 completed case receipts and17 cleanup receipts; the failing capacity
  case still produces no PASS report, and fragment cases have not executed.
- The canonical observed error
  `{:error,{:transport_scope_capacity,:connections}}` failing the unchanged
  obsolete `^source_error` match at its new location, exit nonzero.
- All17 cleanup receipts successful, all17 peers joined, no cleanup-failure
  diagnostic or remaining owned peer. The failing capacity case's remembered
  completions must all preserve their original `:ok` expectations. Earlier
  abnormal cases retain only their already-recorded exact outcomes.
- Identical429 runtime input hashes across the run, a finite parent-owned command
  and explicit profile/runtime/dependency identities.

An earlier assertion failure, pending/unconfirmed normal completion, another
primary error or any cleanup failure fails this repair gate. Even an accepted
red is not24-case green. Only after that result may the separately reviewed
canonical-tuple expectation/diagnostic revision run to24 cases/24 joined cleanups
with exact MATCH. No private transport operation or dependency workaround is
introduced. TLS95's containing fix is still absent in installed0.21.1; TLS,
complete P0–P6 and activation remain blocked/unqualified as previously recorded.

## Freeze, verification and counters

The original429-entry red snapshot remains immutable. The effective repair1
freeze is [cleartext-red-source-before.json](cleartext-red-source-before.json)
with only `integration/http_fetch_contract/managed_transport_probe.exs` replaced
by the e1a hash above. Independent fresh hashing found precisely that one
snapshot difference and verified all429 effective inputs. Sixteen directly
read code/spec/evidence inputs are additionally frozen here:

```json
{
  "AGENTS.md": "c0e76e879d663635b89b4c4fde4274561fce3c4c51a9d086e07908959e9431ed",
  "deps/http_fetch/lib/http/request_completion.ex": "2579b9bbae473603227bcf0edc9509adb8c070927d44fb4e141e7d11160bcb9f",
  "deps/http_runtime/lib/http/managed_transport.ex": "8b00fbfdb570a2605da7bc90d122ab75d41208c928c61a1144c304e587971d8a",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-analysis.json": "c662889e72bc1fa6d912da06ab48343a65ca9cf863acfa3b60c490e667661b07",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-code-review.md": "741484801d52944e569306dd052697c8fc42ae3679ec1091cbd3228d1f4eafe7",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-source-after.json": "d7781892ec9fc9667aaa01fea765690f6053c64e4be86bffd3735e92ad0face8",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-source-before.json": "d7781892ec9fc9667aaa01fea765690f6053c64e4be86bffd3735e92ad0face8",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red.json": "dcd950883300e5ad3988d09ef017f3cd2489a23d5c1c6f8e448835246e00a89b",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red.log": "22ec991d8723d8291ec2dba07f226759904ee749fefacc9d1873f325ac1485fa",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/installed-cohort-verification.md": "e9225b55172f2d71e86d78f3022c67e07c8734f2d0bdcbde8d9172eb9a0734d5",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/source-api-review.md": "79e9830c2a67574f07bac053de30a91fad6616d7beb980df7f4a1ae33172403a",
  "docs/plans/m3-upstream-0.21.1-cleartext.md": "301291d8ce4fdae1b1438812ae1cae72d8e2629016fffb92b588182423b3a0cf",
  "integration/http_fetch_contract/managed_peer.py": "319e9c9f2832ddf2ab9cc84aedd519bfe33f36e2152d24bb47bf5fcde8169d79",
  "integration/http_fetch_contract/managed_transport_probe.exs": "e1a02712ff635da1c9d2f618c2777bdbc9f93ea8d965ee73f571d52ab9b20f59",
  "integration/http_fetch_contract/pooled_completion_probe.exs": "f681723ff58754cb6169d0b42fb681a8439eeaa6c7ec7e94c752894405ce1e30",
  "integration/http_fetch_contract/upstream_peer.py": "f2e40b0e72362f06b4c933b14f45d49e768b2133bee4281c4241bbd122d9b95f"
}
```

Fresh Python checks exited0 for full-file reconstruction, exact one-line delta,
log hash/counts, identical429 original before/after maps and the one changed
current snapshot path. Final verification rechecks these frozen hashes,
reconstruction and local report links/JSON/fences/whitespace, with
`git diff --check`.

Counters for this new0.21.1 harness chain: initial harness runtime failure1;
Sol repair1 pending runtime validation; unsuccessful repairs0; Astra0.
This static review has no implementation repair. Historical0.21.0 Sol2/Astra
recovery1 is the separately completed earlier-cohort chain, preserved unchanged.
No escalation gate applies. A missing future rerun result is NOT RUN, not PASS.

All own commands finished; no own background process, VM, Mix or network peer
was launched. No staging/commit or other file edit occurred. Parent may freeze
and execute this reviewed repair1. Runtime result and any later green change
remain parent-owned separate gates; no additional design decision is needed.
