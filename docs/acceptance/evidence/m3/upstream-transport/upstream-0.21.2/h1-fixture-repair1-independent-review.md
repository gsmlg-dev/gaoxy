# Independent H1 fixture repair1 review

Task `m3_h1_fixture_repair1_review`; direct bounded static independent review.
Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`; loose branch ref matches
`85c2284a035e0b4ecbf577279eee01142702b5a3`. Historical comparison baseline:
`b2ac78b518f459ec2c95b7823226640413f2ca95`.

## Implementation SPEC — PASS

Reviewed implementation compliance before CODE QUALITY against the unchanged
canonical plan SHA256
`01acb850d85b90c2409092d7bf25c5400ad2e519d233858d9194dbce211e6720`.
The original full review and failed source are preserved; this review covers
the exact bounded repair delta and its integration, not a replacement claim
for the original failed implementation.

F1 is resolved statically. B17 at fixture lines2834–2835 requires its second
original late receipt observation to return actual `:ok`; its test also asserts
`retirement_confirmation: :ok`. Initial pending outcome and original500ms
deadline remain immutable, with exactly one graceful/one abort and two wait
slots. Common scope cleanup at line3351 requires `row.retired`, without a B17
pending exception. A pending second result fails while preserving the actual
result; no retry, renewed deadline, extra public wait or native proof is added.

F2 is resolved statically. Ledger command refusal preserves the exact state
for unavailable and in-flight actors (lines379–388). `take_command/2` handles
these compact refusals, and scenario/per-step cleanup catches distinguish them
from successful public operations. A dead peer or retained peer operation no
longer destroys custody. Peer release/stop failure remains FAIL while the
existing per-attempt/per-scope cleanup still processes registered originals.
The outer `after` in `run/1` performs owned shutdown and ledger teardown even
when cleanup or result serialization raises.

The guarded exceptional fallback retains a failed verdict, attempts joins
against existing actor/upload monitors and shutdown deadline, and preserves
available rows without declaring root/native release or confirmed public
cleanup. Unknown/missing proof is not converted into success. It adds no
actor, monitor, helper, public operation, or deadline. Normal cleanup still
registers late originals, uses unused existing public slots, joins owned roles,
releases local roots and exports bounded rows. B21 remains fail closed before
runtime allocation. Numerical accounting remains blocked by Feature97/N8.

## CODE QUALITY — PASS

Reused the initial full executable/contract review and independently read the
complete repair diff against the preserved canonical original. The only two
changed entries in the208-source map are fixture and test;206 entries remain
identical. Peer/model/plan/public dependencies/TLS inputs are unchanged.
Current fixture is3596 lines; test254 lines with exactly20 explicit tests and
20 scenarios. The only additional identifier edit is `_policy` for a previously
unused source-pattern argument; no behavior changes there.

Integrated failure-path trace:

- A peer actor DOWN leaves its fixed slot consumed. Command refusal leaves
  ledger and original results available; `cleanup_step` records refusal and
  proceeds to the registered attempts/scopes. No replacement actor is spawned.
- An unsettled original peer command retains its operation/counters. Refusal
  does not overwrite it or issue another command; cleanup records failure and
  reaches the same existing original-resource and owned-join paths.
- Primary refusal is caught into compact failure evidence. Cleanup refusal is
  caught per step and peer-stop path. Unexpected cleanup exceptions invoke a
  fallback whose `ok:false` cannot emit `PASS_FUNCTIONAL`. Available rows and
  actual joined/alive statuses remain separate from public cleanup results.
- Outer `after` uses the recorded original context, sends stops only to owned
  alive actors, joins through existing monitor rows, and stops its own ledger.
  The same original shutdown budget applies. These local joins are not public
  retirement confirmation, and the repaired B17 cannot use them as such.

No actionable findings remain in the bounded repair. This is static source
acceptance; runtime gates must still confirm actual joins, failure receipts,
line-size bounds and all20 functional cases.

## Evidence binding and validation limits

Canonical executable SHA256:

- `managed_h1_accounting_fixture.exs`:
  `caeb5fa1fb68b45fb7661577fb32f89a01a3029f3b6d3e60fa4f6d9bd10c9800`
- `managed_h1_accounting_fixture_test.exs`:
  `09cd6382d3158666db69de784e05dc55b76b42641a2437de278b779c4ee50ac0`
- `managed_h1_accounting_peer.py`:
  `e997a5fcd0d7391cf56ba278e5dccf3d61b5e68fbb2bae4cbedf1c69f75e0fb2`

Repair inventory SHA256:
`f0298a3b151f3c384c00352e3f55ff9d8c0ef0c3339c3785a9d2537787c01da2`.
All208 source and11 receipt/helper bindings match current bytes. Original
review MD/JSON and pre-repair canonical source hashes remain exact.

The immutable local regression SHA256 is
`6d76d6b9e207303a2c7f24520816ed786f0c5129f154ebd936f14193b5a371ef`;
audit and tracked copies match. Both tests exercise a live Ledger GenServer,
not an implementation text check: one joins a deliberately stopped actor before
refusal; one reserves an original in-flight operation. They assert ledger
liveness, exact refusal, and unchanged entire state, then join their original
actor/ledger monitors in `after`. Parent RED actually executed2 tests/2 failures
and exited1. Parent GREEN executed the same2 tests/0 failures, skipped0,
excluded0, seed21112026, and exited0. Both1132-entry before/after maps are
identical; all1132 GREEN identities also match current bytes. The logs match
receipt hashes. No Python peer or baseline network case was started by them.

Parent canonical formatter/check exited0 with0 tests; its1132-entry maps differ
only at the fixture's permitted formatting change. AST receipt for the
unchanged peer remains AST-only. These local probes prove ledger refusal
behavior; they do not execute `Fixture.run/1`, public completion/retirement,
B17, teardown integration or network qualification. Those integration paths
were reviewed statically here and remain subject to fresh parent runtime.

Reviewer commands: synchronous `cat`, `sed`, `nl`, `rg` and Python stdlib
hash/JSON/diff inspection; all exit0. VM, Mix, parser, formatter, Git, network,
peer launch and dependency operations were NOT RUN by reviewer. Only this NEW
report and JSON companion were written. No command/process remains active;
ownership released after final binding check.

Review outcome: DONE_REVIEW_ONLY, implementation SPEC PASS then CODE QUALITY
PASS. Baseline actual cases0 / NOT RUN; review prerequisite satisfied for the
parent's fresh baseline20, not functional/runtime/M3 acceptance. B21 deferred,
Feature97/N8 blocked; no refunds or TLS-chain repair. Fixture cumulative
Sol repair1/unsuccessful0/Astra0; separate model Sol2/unsuccessful1/Astra0;
separate exhausted TLS Sol2/unsuccessful2/Astra2. Reviewer repair edits0;
no Astra gate asserted. Remaining decision/action: parent runtime gate under
the exact repaired source/helper freeze; no new user design decision needed.
