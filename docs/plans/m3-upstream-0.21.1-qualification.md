# M3 published0.21.1 qualification

Date: 2026-10-11 Asia/Shanghai. Continuing authorization applies. This is a
patch-cohort qualification within M3, not activation approval or progression
to M4. The existing [transport design](../designs/m3-upstream-transport.md)
and [accounting architecture](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-accounting-architecture.md)
remain the product and technical boundaries.

## Design decision

Qualify the seven existing HTTP-family packages together at exact0.21.1.
[Remote metadata](../acceptance/evidence/m3/upstream-transport/upstream-0.21/upstream-status-refresh3.json)
observed GitHub and Hex publication at2026-10-10T19:52:26Z; issues86–89 are
closed,95 is open. Independently establish containing source and shipped
artifacts before reopening affected qualification. Issue closure and publication
do not replace that gate. Keep managed integration disabled while complete
P0-P6, TLS tracking/release or any prescribed runtime gate remains unqualified.

Preserve0.21.0 evidence and its failure history. Finish, independently review
and locally commit active source/identity deliveries before replacing their
installed dependency inputs. Save the old installed cohort under ignored audit
storage with exact hashes. Historical formulas remain tied to their old source;
do not relabel them as0.21.1 qualification.

## Current checkpoint

[Release provenance](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/release-provenance.json)
and [tag/source provenance](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/tag-source-provenance.json)
identify tag `bdf849adf119039ed679d24d5fbb0a321f5e578a`, tree
`2188645d94575d7cb452e41eab156e80d38a26ef`. Independent
[source/API review](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/source-api-review.md)
confirms fixes86–89 present and TLS95 absent. Independent
[installed-cohort verification](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/installed-cohort-verification.md)
passes196 shipped-file matches and seven archive/inner/outer/lock identities.
Both existing direct Fetch/WebSocket pins are exactly `== 0.21.1`; exactly seven
lock entries changed and17 unrelated entries remain byte-identical.

Fresh [compatibility](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/compatibility.json)
**PASS:486 tests / 0 failures**, seed21111026, exit0,429 unchanged frozen source
identities; strict global/probe format and strict compile passed sequentially.
The [cleartext green](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-green-analysis.json)
passes24 distinct cases (9 H1,15 h2c),24 successful joined cleanups, exact
canonical MATCH, exit0,429 unchanged inputs and no remaining peer after
[canonical code review](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-canonical-code-review.md).
The [initial red](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-analysis.json)
remains a cleanup-gate FAILURE (16 cases,17 peer joins,16 successful cleanups).
The [repaired expected red](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-red-repair1-analysis.json)
passes with16 cases and17 successful cleanups; the same hard match moved after
normal finite completion, weakening no expectation. Harness Sol repair1 succeeded,
unsuccessful0, Astra0; historical0.21.0 counters stay separate.

[Refresh4](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/upstream-status-refresh4.json)
observed20:19:06Z that#95 is CLOSED (updated20:05:59Z), latest GitHub/Hex0.21.1.
Its containing fix remains absent in installed/published0.21.1. Full39/TLS is
**BLOCKED95** under the [cleartext contract](m3-upstream-0.21.1-cleartext.md).
Source fixes and finite PASS do not establish full#86 adversarial backlog, held
preparing/connecting saturation, P0–P6 or Task4/M4 activation. Fresh [final scoped checks](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/final-checks-repair1-analysis.json)
pass44/0 with strict format/compile and429 stable inputs. The failed initial
44/18 invocation remains recorded and diagnosed: the mixed network suite
incorrectly used `--no-start`; repair1 removed only that flag, preserving all
tests/assertions. This command chain has one successful Sol repair, zero
unsuccessful repairs and Astra0. Final independent delivery review and local
commit remain pending.

## Execution and verification

- [x] Complete the historical0.21.0 proof/identity deliveries and independent reviews;
  verify the frozen executable identities before the local delivery commit.
- [x] Fetch all seven published archives and Hex release metadata into a new
  ignored cache. Verify actual archive SHA256, GitHub asset byte identity,
  matching internal package requirements and actual tag/tree identities.
- [x] Independently review the0.21.1 source delta for issues86–89 and TLS95;
  identify the exact fixes present and remaining accounting/runtime obligations.
- [x] Preserve old installed sources; update both existing exact Fetch/WebSocket
  direct pins to `== 0.21.1` and only seven coordinated lock entries. Preserve
  all17 unrelated entries; no unrelated dependency refresh.
- [x] Review compatibility changes required by the new cohort. Preserve assertion
  strength and unqualified activation; update source fingerprints and tests
  together where the actual source changes justify it.
- [x] Run canonical formatting, strict compile and scoped umbrella compatibility
  tests, recording real nonzero counts, seed, exits and source hashes.
- [x] Run only independently reviewed public regression fixtures applicable to
  the containing fixes. Preserve finite peers/deadlines and joined cleanup.
  TLS-dependent qualification stays blocked unless the actual95 fix is present
  and independently qualified; do not bypass it with private tracking.
- [ ] Independently review the delivered changes and fresh evidence; record
  PASS/FAIL/BLOCKED/NOT RUN separately and commit locally. Return to Task3's
  outstanding source/runtime obligations. No push, merge, release or deployment.

Independent source/evidence work can proceed in parallel with archive collection.
Serialize dependency mutation, Mix/VM execution and network fixture runs. Parent
owns those operations and freezes their executable inputs. Sol handles routine
work and review; the existing two-failed-repair/technical-impasse Astra rule and
cumulative counters continue to apply.
