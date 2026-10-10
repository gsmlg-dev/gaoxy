# Canonical cleartext green code review

Date: 2026-10-11 Asia/Shanghai. Direct independent Sol task
`m3_h1_preparation_spec_review/cleartext-canonical-code-review`.

**PASS for the bounded canonical-green code/spec gate; no blocking finding.**
The current capacity case requires the exact documented connection-capacity
error at the already-settled position. It removes only the obsolete expectation
and diagnostic/workaround wording. All other assertions, timeouts and cleanup
are preserved. Green execution remains NOT RUN by this reviewer and pending
parent qualification; this report permits a fresh frozen parent-owned run.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, HEAD `a6a210c720d4a0fa9b8fa5f485e5c07a825ad03c`.
Only this report is owned. Parent's code/status changes and the new architecture
memo/review were preserved. No fixture, dependency, other document, architecture
artifact or historical receipt was edited.

## Accepted red evidence

Independent checks of [repair1 analysis](cleartext-red-repair1-analysis.json),
[raw receipt](cleartext-red-repair1.json), actual log and before/after source
snapshots corroborate the expected-red gate:

- Exit1 with exactly the old `:pending_capacity` hard match rejecting the actual
  `{:error,{:transport_scope_capacity,:connections}}` at the settled capacity
  case position, recorded as probe line769.
- Exactly16 `MANAGED_CASE` receipts and17 `MANAGED_CLEANUP` receipts. The analysis
  records17 successful cleanups/17 joined peers; the raw log contains no cleanup
  failure or fixture exception. The failing capacity case shows both scopes
  already retired and all five recorded completions `:ok`, followed by
  `peer: :ok`, two retired scopes `:ok` and five cleanup completions `:ok`.
- Raw receipt reports no remaining owned peer, no timeout and429 unchanged
  inputs. The two actual429-entry maps are identical and include the reviewed
  repair1 e1a probe. Actual log SHA256 equals the raw receipt's digest.
- No capacity-case PASS or final24-case PASS appears. The16 reported case names
  precede capacity; fragment cases did not execute.

This is an accepted expected red, not24-case green. The original earlier
[cleanup-gate failure](cleartext-red-analysis.json) remains failed and preserved.
The repair1 result establishes the deliberately obsolete assertion's failure
with successful cleanup; it does not convert initial failed cleanup evidence
into a passing result.

## Exact canonical delta

Repair1 probe SHA256:
`e1a02712ff635da1c9d2f618c2777bdbc9f93ea8d965ee73f571d52ab9b20f59`.
Canonical candidate SHA256:
`0e266d6c278682e23d2611d053c8d155bb19d4354c6a5dfa2f411dc177c49520`.

Independent reconstruction restores only the removed PR81/source-discrepancy
comments, TODO/WORKAROUND, obsolete `source_error` binding and `source_expected`
diagnostic; replaces `^documented_error` with `^source_error`; and restores the
capacity report/final banner MISMATCH values. The reconstructed whole file
hashes exactly to repair1 e1a. Thus the complete delta is limited to:

- Removing obsolete comments, `source_error={:error,:pending_capacity}` and its
  extra diagnostic field.
- Changing the existing settled-position hard match to
  `^documented_error = actual_error`, where `documented_error` remains the exact
  literal `{:error,{:transport_scope_capacity,:connections}}`.
- Changing the capacity case's result annotation to `:match` and final banner
  text to MATCH.

The captured Promise result and diagnostic equality check remain unchanged.
The one canonical hard match is after both retirement/identity assertions and
before the case report. A wrong value may print the existing mismatch diagnostic
but cannot produce a successful capacity-case report or final PASS. No arbitrary
error alternative or broader tuple match was introduced.

Full-file reconstruction proves every other byte is preserved from repair1:
GOAWAY/PING acknowledgement, finite held stream, rejected completion `:ok`,
no-request bytes, exact accepts/paths/connection identities, independent-scope
progress, exact `abcdefgh` consumption, normal held completion `:ok`, old
connection closure, public zero connection/request/preparing/resource ledger,
replacement, both retirements, all cleanup bodies and deadlines. Earlier
abnormal completion allowances remain individually recorded exactly as before.
No assertion was deleted, softened or bypassed.

The39/24 driver, unknown-argument rejection before app/peer startup, helper
loading and fragment cases are also preserved. Cleartext selects H1/h2c common
and deadline groups, two H1 extras, one h2c capacity case and seven h2c fragment
cases: `2*(6+1)+2+1+7=24`. Default still asserts
`3*(6+1)+2+2*(1+7)=39`; its TLS gate remains blocked.

## README and green acceptance

Current README SHA256:
`c7f7814ef794dcac3ed04a9fcd751ac2584aa4bda1ea82ec68943e4eba155e32`.
Its current paragraph accurately reports accepted expected red with17 successful
joined cleanups, separately preserves the initial failure and states24-case
green is pending. It does not claim a new green PASS. The entire historical
0.21.0 narrative after its historical heading remains byte-identical to HEAD.

The parent-owned green run must record exit0,24 completed case receipts,
24 successful joined cleanups, exact canonical diagnostic MATCH and capacity-case
`:match`, the final24-case MATCH banner, no remaining owned peer and stable
frozen inputs. All original individual completion, peer-thread/exit, resource,
wire and replacement assertions still apply. A PASS banner alone is not the
full evidence gate. Formatter/VM/network execution and its runtime/environment
identities belong to the parent; none was run here.

TLS/full39, complete86 adversarial backlog, held preparing/connecting saturation,
complete P0–P6 and managed activation remain blocked/unqualified. Published and
installed0.21.1 source containment is already reviewed; no private transport
operation or dependency workaround was introduced by this fixture change.
The source-confirmed absence of the containing95 fix is unchanged despite the
later issue-closure observation. This green resource-property slice does not
qualify those separate obligations or advance M3/M4 by itself.

## Frozen inputs, verification and counters

The effective current429-entry freeze is
[cleartext-red-repair1-source-before.json](cleartext-red-repair1-source-before.json)
with only the probe value replaced by0e266 above. Python verified all429 current
hashes and found exactly that one difference from the accepted red snapshot.
README is an additional directly frozen input; it is outside that429 map.
Sixteen read code/spec/evidence inputs are pinned here:

```json
{
  "AGENTS.md": "c0e76e879d663635b89b4c4fde4274561fce3c4c51a9d086e07908959e9431ed",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-analysis.json": "c662889e72bc1fa6d912da06ab48343a65ca9cf863acfa3b60c490e667661b07",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-repair1-analysis.json": "5ae2391d0c00a28f07d7d983e891c58cbf1ce2d1504da8d15e4ecb49f201854a",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-repair1-review.md": "7d33005cc7254749935abe83747ab79aa8bbf5652d8e00695209bf412c7624a8",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-repair1-source-after.json": "b640c6235baf7b953dc228cd90ad59f204aa104d5d8534703228f2ca2e661cda",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-repair1-source-before.json": "b640c6235baf7b953dc228cd90ad59f204aa104d5d8534703228f2ca2e661cda",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-repair1.json": "19960512c7c262ccad1e5791967518dc9098118a1a75ce0fce525e10e3bcff28",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-repair1.log": "3feba5abf36acf19eddb92221b12e2e5580a1f9076ac3c3f5848910c4f97f8ee",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/installed-cohort-verification.md": "e9225b55172f2d71e86d78f3022c67e07c8734f2d0bdcbde8d9172eb9a0734d5",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/source-api-review.md": "79e9830c2a67574f07bac053de30a91fad6616d7beb980df7f4a1ae33172403a",
  "docs/plans/m3-upstream-0.21.1-cleartext.md": "301291d8ce4fdae1b1438812ae1cae72d8e2629016fffb92b588182423b3a0cf",
  "integration/http_fetch_contract/README.md": "c7f7814ef794dcac3ed04a9fcd751ac2584aa4bda1ea82ec68943e4eba155e32",
  "integration/http_fetch_contract/managed_peer.py": "319e9c9f2832ddf2ab9cc84aedd519bfe33f36e2152d24bb47bf5fcde8169d79",
  "integration/http_fetch_contract/managed_transport_probe.exs": "0e266d6c278682e23d2611d053c8d155bb19d4354c6a5dfa2f411dc177c49520",
  "integration/http_fetch_contract/pooled_completion_probe.exs": "f681723ff58754cb6169d0b42fb681a8439eeaa6c7ec7e94c752894405ce1e30",
  "integration/http_fetch_contract/upstream_peer.py": "f2e40b0e72362f06b4c933b14f45d49e768b2133bee4281c4241bbd122d9b95f"
}
```

Fresh Python checks exited0 for exact e1a reconstruction, accepted-red receipt,
log SHA/counts/error/cleanup evidence, identical429 before/after maps,429 current
effective hashes, candidate probe/README identities, obsolete-wording removal,
unchanged driver selection and historical README suffix. Final checks revalidate
these inputs, reconstruction, local links/JSON/fences/whitespace and
`git diff --check`. No scoped runtime or compiler check is claimed here.

New0.21.1 harness counters: initial runtime failure1 preserved; Sol repair1
successful; unsuccessful repairs0; Astra recovery0. This canonical expectation
update is the planned green step, not an additional failed repair. Historical
0.21.0 Sol2/Astra recovery1 remains its separate completed chain. No escalation
gate applies.

All own commands finished; no own background process, VM, Mix or network peer
was launched. No staging/commit or other file edit occurred. Ownership of review
inputs is released for the parent's fresh freeze/format/green execution. No new
product decision is needed for this bounded contract correction.
