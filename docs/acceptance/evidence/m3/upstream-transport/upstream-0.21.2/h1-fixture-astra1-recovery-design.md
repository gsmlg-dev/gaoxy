# H1 fixture Astra recovery 1: diagnosis and proposed amendment

Task `m3_h1_fixture_astra1_recovery`; mode **diagnosis**, with parent-authorized
documentation output only. Gate **SOL_REPEATED_FAILURE**, confirmed by parent:
two unsuccessful Sol fixture repair/validation rounds. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, parent-verified HEAD `85c2284a035e0b4ecbf577279eee01142702b5a3`.

**DONE diagnosis/documentation. BLOCKED_DESIGN for executable B17 repair until
this amendment is independently reviewed and parent gives GO. B11/B12 are
blocked on an upstream dependency defect; no local timing workaround.** This
report does not establish passing implementation or functional acceptance.

## Evidence and ownership

Parent confirmed predecessor stopped writing all three executable files and
baseline2 finished with no peer remaining. Parent preserves the three sources
in `h1-fixture-preastra1-*`, with manifest `h1-fixture-preastra1-source.json`.
The parent-only Git inventory at
`.audit/m3-transport/h1-fixture-preastra1-git-inventory.txt` records 21 pre-existing
tracked modified files (353 insertions/151 deletions), many untracked evidence
files, and the three untracked fixture executables. All remain owned by their
existing writers. This assignment writes only this report and its JSON sibling.

Current SHA256 bindings, independently read with `sha256sum`:

| Input | SHA256 |
| --- | --- |
| `managed_h1_accounting_fixture.exs` | `937bdfd98d23a0045a2e685cca123bbde7492467bef43f85bcc3489c4a554735` |
| `managed_h1_accounting_fixture_test.exs` | `09cd6382d3158666db69de784e05dc55b76b42641a2437de278b779c4ee50ac0` |
| `managed_h1_accounting_peer.py` | `e997a5fcd0d7391cf56ba278e5dccf3d61b5e68fbb2bae4cbedf1c69f75e0fb2` |
| `docs/plans/m3-h1-qualification-fixture.md` | `01acb850d85b90c2409092d7bf25c5400ad2e519d233858d9194dbce211e6720` |

Read the canonical fixture specification, complete-accounting design/plan,
preserved failures/attempt/generation rows, both Sol repair diffs, and current
public dependency source. Repair1 preserves typed ledger refusal state and
unconditional owned shutdown, removes false B17 cleanup acceptance, and requires
actual late receipt `:ok`. Repair2 corrects only `:beam_lib.md5` tuple shape.
Preserve those fixes. The parent identity-test contract correction is separate.

Historical parent command for both baselines:

```sh
nix develop --offline --command bash -c 'unbuffer mix run --no-compile --config .audit/m3-transport/h1-accounting-runtime-config.exs integration/http_fetch_contract/managed_h1_accounting_fixture_test.exs --baseline'
```

Environment: `MIX_ENV=test`, `ERL_FLAGS='+S 2:2'`,
`HTTP_FETCH_PEER_PYTHON=/tmp/gaoxy-m3-h2-soak-venv/bin/python`,
`PYTHONDONTWRITEBYTECODE=1`. Baseline1 exit1 before tests: actual
`{:ok, {HTTP, binary_md5}}` mismatched the old list pattern. Baseline2 exit1:
20 tests/4 failures/0 skipped/0 excluded; 16 passed, B05/B11/B12/B17 failed;
52.167 seconds, all 1,132 selected inputs unchanged, no remaining peer.
The historical counters in command receipts describe their start state;
parent's received cumulative counters are Sol2/unsuccessful2/Astra0.

## B05: exact backing construction

At fixture `source_parts/4:1756-1765`, URL parent construction uses append.
`byte_size(parent)==backing` does not imply allocated/referenced backing equals
that value. `url_backing_constructed` fails before preparation or Fetch; the
later reply deadline is secondary. Parent's isolated OTP28/Elixir1.18.5 probe
completed exit0 and confirms this mechanism:

| Requested/logical parent | Actual referenced parent and slice | After copying parent, both references |
| --- | --- | --- |
| 65536 | 131072 | 65536 |
| 131072 | 157286 | 131072 |

Probe log `h1-fixture-astra1-b05-backing-probe.log` SHA256
`4dd493c241a51c668b2c5e6a69f6a1febd38afd2bef45e98ab3eb05dc7445bdc`.
Smallest proposed implementation: materialize the completed URL parent using
`:binary.copy/1` before `binary_part/3`; retain the exact referenced-size
assertion, slice greater than64 bytes, original boundary expectations and zero
Fetch oracle. Both append temporary and exact copy are bounded source-construction
roots after R reservation; they are not native-frontier release evidence.
No test assertion or accepted input boundary changes are needed.

## B11/B12: upstream parser error versus lifecycle cancellation

Source provenance: `deps/http_fetch/mix.exs` identifies
`https://github.com/gsmlg-dev/http_fetch`; installed `http_fetch/http_core` are
0.21.2. `HTTP.SocketClient.fail/2:1560` sends lifecycle abort before sending
`HTTP.Stream.error(stream, reason)`. `HTTP.RequestLifecycle.handle_info(:abort):321`
cancels the stream through `cancel/2:412`, sending
`{:request_lifecycle_stop, :aborted}` from a different sender. In
`HTTP.Stream.loop/1:185`, that stop path flushes and then exits unconditionally.
`flush/1:325` does nothing when no reader exists. Consequently:

1. A stream can disappear without ever delivering the original parser error
   to a subsequently attached supported reader.
2. An already attached reader can receive `:aborted` before the exact parser
   reason. A fixture reader-attachment gate cannot order the two upstream senders.

The public failure mechanism is source-evidenced. The precise scheduler order
in the preserved baseline was not traced and must not be claimed as observed.
Actual B11 attempt1 (`line8193`) and B12 attempt2 (`forbidden`) returned status200,
then consumer deadline at fixture1488; their cleanup abort waits returned `:ok`.
B12 attempt1 delivered `:trailers_too_large`, demonstrating the success path can
win this race. The peer waits for consumer error before EOF in the affected
cases; releasing EOF early changes the oracle and is not a repair.

Dependency source SHA256:

| Path | SHA256 |
| --- | --- |
| `deps/http_fetch/lib/http/socket_client.ex` | `32790c3df4be3519957cc31404a8c4b6d533db38a36c02a0010c5f9ad4e004e3` |
| `deps/http_fetch/lib/http/stream.ex` | `552c5951d30c21ce864a77c1a61dc5e8bcda038559040028e4f3282074325d05` |
| `deps/http_core/lib/http/request_lifecycle.ex` | `7ea6f109aea3c32d556cf02a957cc56f8075a4c89d678645338f789b4edb5a37` |

Suggested minimal public reproduction for parent/upstream, **not run by Astra**:
open one managed H1 scope; call Fetch with the canonical fourteen options,
register original completion before awaiting Promise; independent peer sends
only `200 OK` chunked head and waits for a controller command. After the public
response arrives, peer sends8193 ASCII zeros without CRLF and holds the socket
open. Invoke one original `RequestCompletion.await` with a finite budget before
reader attachment, then attach via `{:read_chunk,self(),:ack}` and require
`:line_too_long` within a finite receive. Current source permits completion `:ok`
followed by no error delivery. If completion remains pending, attach and retain
that result separately; do not infer failure merely from pending. Preserve
all actual outcomes and clean the original scope through supported APIs.
This uses no private PID inspection, suspension, tracing or reconstructed handle.

Route a **Bug**, severity **blocker**, in `gsmlg-dev/http_fetch`, requesting
`gsmlg-opt/gaoxy` on `codex/m3-gateway`. Suggested title:
`[internal] H1 parser errors race lifecycle cancellation and disappear before stream readers attach`.
Parent owns issue creation, `internal request` label/type, callsite TODO and
any additional reproduction. B11/B12 remain unchanged and visibly blocked until
the upstream issue is resolved and the dependency is updated. Do not replace
the required error with `:aborted`, ignore EOF/data/trailer checks, or patch deps.

## B17: proposed finite late-observation amendment

Current code observes first pending at D=t0+500, releases the already-reserved
abort helper, joins request cleanup/consumer, then consumes its second original
receipt wait with timeout0 (`scenario/2:2834`). Request completion does not
establish whole-generation retirement. No supported ordering edge guarantees
the second zero-time wait can observe `:ok`; baseline records two genuine
pending results. Scope cleanup correctly fails once both wait slots are spent.
The required late `:ok` assertion must remain.

Amend only B17's second pre-reserved observation as follows:

- At t0 retain primary=t0+15000, cleanup=t0+25000, shutdown=t0+30000,
  retirement D=t0+500. Original request/connect deadlines remain unchanged.
- Wait0 uses original D and publishes `{:error,:cleanup_pending}` by D with
  tolerance<=100ms. Preserve that result, original D, and model `:timed_out`.
- The one abort-initiation helper is still reserved/started before D and held
  at the existing owned pre-call barrier. Release after original pending;
  register its actual original receipt before waiting.
- Wait1, already in the two-slot ceiling, is explicitly a **late cleanup
  observation**, using remaining time from predeclared cleanup=t0+25000.
  Require actual public `await_retired(original_abort_receipt, remaining)` to
  return `:ok`. Its result never replaces wait0 or extends retirement D.
- Record separate observation purpose/deadline for the two fixed slots:
  `original_retirement/500` and `late_cleanup/25000` relative to t0. Capture
  compact actual public results separately. Enforce that late cleanup mode is
  available only for B17's second reserved wait after original pending/D500.
- No third wait, new helper, retry/poll, sleep, new receipt, extra graceful or
  abort operation, private barrier, snapshot-derived success or native refund.
  Failure/pending at cleanup end remains FAIL; all owned joins use original
  shutdown=t0+30000. Other cases retain the current original-D semantics.

The fixture-spec role-table sentence requiring every retirement helper to use
original D, original-deadline section, and B17 zero-time-wait paragraph must
explicitly describe this exception before code. This document proposes that
change; it does not silently supersede the canonical plan. Parent owns canonical
plan update and independent review. The lease model already preserves timed-out
outcome on late `scope_retired` (`managed_h1_lease_model.exs:256-277`); no model
or dependency change is needed. If this amendment is declined, B17 remains
BLOCKED_DESIGN; a larger zero-time scheduling gamble is not an alternative.

## Bounded implementation and acceptance handoff

After independent amendment review and parent GO, executable repair scope is
B05 exact parent copy and B17 finite second observation in the fixture, with
only necessary B17 evidence assertions in its existing test. Keep all20 test
definitions and cases, original parser/data/trailer/error assertions, peer,
finite roles/buffers and operation ceilings. Parent may add upstream TODOs.
No collector, TLS tooling, model, dependency or production edits belong here.

Parent validation order: preserve immutable originals and existing RED reports;
review specification; implement bounded repair; review implementation SPEC then
CODE QUALITY; run scoped B05/B17 verification under frozen source identity.
B05 requires three exact rejects/three compact copies and zero Fetch. B17
requires original pending/D500/tolerance, exactly1 graceful/1abort/2waits,
separate predeclared observation deadlines, late real `:ok`, all joins and no
frontier refund. Recheck ledger-refusal and identity regressions as prescribed.
An explicit selected diagnostic run must not be described as baseline20 success.
All20 definitions remain intact. B11/B12 are blocked rather than skipped or
rewritten; full green baseline20 acceptance awaits updated upstream dependency
and fresh qualification. Do not rerun blocked cases to seek a favorable race.
B21 stays deferred/fail-closed before allocation; N8/#97 and numerical/M3/Task4
activation remain blocked. Exhausted TLS chain remains separate and frozen.

Verification by Astra: synchronous `rg`, `sed`, `cat`, `diff -u`, `wc -l`,
`sha256sum` reads; exact source bindings PASS. `diff` exit1 denotes expected
historical differences, not a test failure. VM/Mix/network/parser/formatter/Git
and fresh tests NOT RUN by Astra. Parent B05 probe PASS as above. No processes
launched in background; all Astra commands completed synchronously.

Cumulative received counters: fixture Sol2/unsuccessful2/Astra0; assigned next
repair is Astra1 of at most2. This diagnosis/documentation performs zero
failure-directed executable edit-plus-validation rounds. Parent preservation
manifest labels the reserved recovery lane `astra:1`; it is not evidence that
a repair validation has occurred. An exhausted Sol budget remains exhausted;
further same-task Sol repairs require explicit additional authorization.
Residual risks: proposed B17 implementation untested; upstream public repro
not yet run; baseline20 remains failed. Decisions needed: parent independent
amendment review/GO and upstream blocker routing/update, not routine user approval.
