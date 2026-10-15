# Sol20 H1 group fixture lifetime repair

## Evidence and cause

0.21.10 pre-review full58 FAIL853/1 exposed protected group fixture cleanup
without its inner assertion. Diagnostic1 group21/0 did not resolve it.
Diagnostic2 original full58 FAIL853/1 instead exposes the sibling probe
fixture status assertion: expected resources/pins/request_tokens/helpers/
reserved_connections all0, actual {:error, :not_running}; exit2 and stable
source, logSHA69d8d4a3edf9493ea16fc5a14e29682ecf4b3c6c55c8c5d2844d291cd77b3de8.
The failing test calls Gaoxy.stop in its body through the existing stop helper.

Transport owners remain alive after retirement while their instance lives,
but retire and normally self-stop after instance DOWN once records/tokens
are empty. Fixture cleanup currently stops the instance, then calls release/
retire/status on its owners. A Process.alive? guard is not a lifetime lease.
Source inspection identifies the same permitted race in both fixtures.
The exact first hidden group assertion is not independently recovered yet;
it must not be misreported as observed.

## Tests-first plan

1. Add only deterministic owner termination barriers before current post-stop
   owner calls. Group fixture: monitor before unchanged Gaoxy.stop, join normal
   DOWN after it, then retain all original cleanup calls/assertions. Probe
   stop helper: monitor before unchanged Gaoxy.stop, join normal DOWN, then
   assert the same original five-field zero status. Run both complete files
   once. Require actual intended not_running assertion failures, not syntax or
   timeout errors. Preserve all original tests/deadlines and failure receipts.
2. After genuine RED, release one minimal fixture-only repair. Group cleanup
   releases baseline, waits empty groups, retires owners, awaits retirement
   and asserts unchanged zero-status while instance/owners live. Then core
   stop still exercises participant acknowledgments; preinstalled monitors
   prove normal owner DOWN. Positive DOWN replaces racy explicit owner stop.
3. Probe fixture must distinguish ownership already explicit in existing tests.
   Normal body-owned core stop remains unchanged and may clean in-flight
   work. Install an exact owner monitor at fixture creation, before the body
   can stop it; require actual normal DOWN in cleanup. Never treat noproc,
   liveness skipping or arbitrary sleeps as successful termination proof.
   If fixture cleanup itself must stop a live instance, retain the original
   retire/await/five-field-zero-status predicates before that stop, then join
   normal DOWN. Keep the failed short-stop test and TLS unconfirmed mode,
   original stored failures and all uncertainty assertions untouched.
4. This explicitly amends an impossible post-termination status contract: a
   stopped owner cannot answer status. For body-owned core stop, actual
   Gaoxy.stop success plus a preinstalled normal-DOWN join proves cleanup;
   the owner only exits normally after records/tokens are empty, pins are
   cleared by retirement, and helpers/reserved connections are contained in
   records. The previous liveness guard could skip all of these checks.
   Independently review this equivalence; do not silently omit an assertion.
5. Keep diagnostic exception preservation unless independent review finds a
   simpler equivalent. Run complete affected files, then independent bounded
   SPEC followed by CODE. Extend owned51/format42 by the already-scoped probe
   file, keeping every original full58 path. Require complete stage reviews
   and fresh format43/strict compile/full58/public63/matrix135/browser3.

## Ownership and counters

Root alone applies repository changes and runs all runtime/format commands.
Workers write only assigned /tmp reports/patches and do not revert others.
All source/test/docs/collector writers freeze during runtime. This repair
is Sol20 fixture-only, not a new production workaround or upstream defect.
Retain all existing cumulative counters plus new0.21.10 full58failed2;
Astra recovery2/2 remains exhausted. No97-derived proof, production scope
expansion, publication, deployment, Vault or E2E permission is introduced.
