# Managed H2 group accounting and activation acceptance

Status: IN PROGRESS. Controlled F remains ENABLED_PENDING_ACCEPTANCE. Startup50/0, live110/0 and repaired Session46/0 have passed. Native TLS41/2 and browser zero-completed FAIL are retained; both diagnosed TLS compatibility fixes are adopted after independent source reviews, awaiting fresh runtime. Ledger8 retains20 failed GREEN attempts/23 ordered root repair events; Astra2/2 exhausted. Final FULL review, prescribed fresh gates, browser and local commit remain pending.

Baseline local guard commit: `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`, tree `a26656f16425d35ccc08584ee0486abb296a3c39`. Its local receipt is preserved as `predecessor-local-commit1.json`. Current implementation is dirty/untracked and must be identified by its source manifest, not HEAD alone.

Evidence directory: `docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089/`. Preactivation collector is `command-runner27.py`, SHA256 `0e6c3e48174b2e86e2956402b380d8cae63af2c6d63ec1b76592bcc534d31ff4`; controlled-F collector is `command-runner28.py`, SHA256 `9fd17d518447c14f8ac1bf2e51f73cdbd7d61853870cb44ed43d3bd8e9af162d`. Commands run through Nix with Elixir1.18.5, OTP28, ERTS16.4.0.6, MIX_ENV=test, ERL_FLAGS=+S 2:2, seed33015/max-cases1 and a600-second command deadline. Actual receipts retain executable paths, argv, sources before/after, log bytes/hash, counts, exit and joined state.

## Fresh preactivation evidence

| Gate | Actual result |
| --- | --- |
| Formatting check; forced strict compile | PASS, exit0 each |
| A accountant; B owner | PASS68/0;24/0 |
| C initial Session; control preflight; transitions | PASS13/0;9/0;11/0 |
| Whole pin response; finite controls; actual public cancel | PASS6/0;16/0;2/0 |
| D initial Probe; Probe controls | PASS13/0;21/0 |
| Startup lease/full attachment reservation | PASS46/0 (fixed38 plus startup8) |
| Existing pure suites | PASS454/0 (452 retained plus2 additive nil-token cases) |
| Scoped H1/fixed-H2/H3/HTTP compatibility | PASS603/0 |
| Nil-token structural preopen regression | Authenticated intended RED200/2, then unchanged-test GREEN200/0 |
| Mixed Session control suite before F | FAIL46/6;40 pass, six postactivation cases stop at literal |
| Group live suite before F | Authenticated intended RED106/68; fixed38 pass,68 stop at literal |
| Final preactivation independent SPEC/CODE | PASS35/35; CODE no findings; exact126-source manifest authenticated |
| Controlled F integration | ENABLED_PENDING_ACCEPTANCE; authenticated preactivation review precedes mutation |
| Enabled matrix/capacity/lifecycle | FAIL106/19 then110/10; repairs pending fresh runtime |
| Browser three-case suite; standalone/core-only final gates | NOT RUN for this stage |
| Final full SPEC/CODE, fresh acceptance, local commit | NOT RUN |

All passing test rows have nonzero execution, stable source, real joined command exit0 and zero skips/exclusions/unexpected warnings. Aggregate rows include repeated fixed fixtures; counts are per command, not a sum of unique tests. Neither RED row is a green gate. The authenticated nil-token RED exposed missing pre-open/bind token refusal; the repair requires a reference token after queued/local terminal checks and before open/bind. Initial preattachment nil-token state remains valid. A fabricated reference shell is not Service authority.

Selected enforced payload contract: unchanged fixed9,444,956 plus group7,033,906 yields request/normal-Probe16,478,862; startup lease delta5,963,776. Full cleanup attach overlaps startup until the args-owning helper returns.32 cleanup reservations527,323,584; four normal probes65,915,448. These are finite serialized original-role payload charges, separate from physical memory or complete runtime acceptance. Config and control ledgers remain separate from probe bytes, T and Service holds.

## Retained failures and repair custody

`counter-ledger1.json` inventories every command attempt at its cutoff, every inherited/stream-local counter snapshot and ordered root repair receipts. At that preactivation cutoff, failed GREEN attempts totaled12: accountant2, owner1, transitions test-warning1, Probe1, startup3, legacy pure3 and fresh Probe1. Earlier implementation/repair/failure counters remain inherited from `kickoff1.json`; local author snapshots are preserved verbatim, without a guessed global sum or reset. Astra2/2 remains exhausted.

All initial/mixed RED, source/wrapper, diagnostic and failed GREEN logs remain immutable. The retained pure452/211 constructor failures led to actual GroupEndpoint/G7/client fixtures;452/26 and452/24 led to finite deadline and exact cleanup-capture contracts. Probe controls21/1 RED exposed a foreign-PID DOWN accepted under a real monitor ref; the repair matches both PID and ref, then21/0 passed. Startup gate disposal requires the actual killed exit; its other joins and full lease-adjust ordering are unchanged. Earlier compatibility603/1 timing attribution remains UNPROVED. No assertion was weakened, no verification skipped, and no failure relabelled as success. Before this status sync, all four edited documents were archived byte-for-byte in `preactivation-documents-before-sync1/`.

The historical negative TLS/browser cleanup result remains **UNCONFIRMED_WITH_RETAINED_FAILURE**. Missing Service is not zero usage or a cleanup receipt. The dismissed upstream97 proof remains excluded. No publication, deployment, operational certificates, Vault, public management, production data or disabled release-artifact E2E changes are authorized.

`controlled-activation1.json` records the authorized F mutation and stronger literal-contract replacements. This is not successful group runtime acceptance. The original CODE report store-path wording is retained with `gaoxy-group-preactivation-code-final1-toolchain-erratum.json`; actual canonical runtime is OTP28/ERTS16.4.0.6/Elixir1.18.5.

## Postactivation repair checkpoint — 2026-10-16

Actual enabled runs were106 tests/19 failures and then110/10, exit2,
joined/stable with zero skips/exclusions. The second includes four added E4
handoff/partial-native-write tests. Neither run passed; Session46 was NOT RUN
because of fail-fast. The guardian-only diagnostic ran48/2, exit2, with its
expected-exit2 wrapper exiting0; that wrapper result is not GREEN acceptance.

The first live failures led to the original-handle terminal Session repair and
exact initial health HEAD upload_end consumption. Independent SPEC/CODE then
reviewed post-bind queued cancellation before ready, exact earlier POST empty
DATA/DELETE upload attribution, and the handoff test's raw capacity-to-finite
invalid_resource_pin/502 contract. The guardian test now asserts the legitimate
intermediate source pin and exact pump/lease call queued behind its held Gate;
it resumes Gate before requiring the unchanged final pins1 predicate. Service
stays held and missing cleanup receipt still requires exact failed shutdown.
The gate dependency does not identify whether that update came from a connection
poll or response rendering. Fresh runtime is required for all adopted repairs.

The owner capacity deadline repair passed24/0. Its original24/1 expiry cause
remains UNPROVED. Browser harness source review passed but all three actual
Chrome cases remain NOT RUN. Historical negative TLS/browser cleanup stays
UNCONFIRMED_WITH_RETAINED_FAILURE. No missing Service is treated as zero.

Append-only counter-ledger3.json now records15 failed GREEN attempts and16
ordered root repair events. All inherited/local counters and metadata failures
remain preserved without a guessed global sum; Astra2/2 stays exhausted.
Collector31 retains the same600-second finite deadline/nonzero-test/no-skip
policy. Next: fresh format/strict compile, live110/Session46, browser3 and all
prescribed compatibility/isolation gates, complete independent FULL SPEC/CODE,
fresh acceptance, source/index byte audit and task-owned local commit.


## Full-review and runtime checkpoint — 2026-10-16

Fresh format and strict forced compile passed, then the complete enabled live
gate ran110 tests/2 failures (exit2, joined/stable, zero skips/exclusions).
Session46 remained NOT RUN after fail-fast. FULL independent SPEC/CODE review1
authenticated175 sources and required an OTP debug-state repair, four genuine
successful startup/full-attachment overlap regressions and recovery teardown
cleanup. Independent bounded SPEC/CODE review2 source-passed the adopted
repairs; it is not runtime acceptance. The complete startup gate now expects50
executed tests, including four new protocol/downstream positive cells.

The first actual Chrome command joined exit1, source stable, FAIL with zero
completed cases. Positive native TLS/h2 navigation returned503; the real peer
saw only the successful health HEAD. Source diagnosis identifies unsupported
full OTP TLS metadata in the new group pump validator; exact runtime attribution
and compatibility repair remain pending. All navigation, original-completion,
G/T/Service byte and cleanup assertions remain required. Do not count unstarted
negative scenarios as executed or passing. Historical negative TLS/browser
cleanup remains UNCONFIRMED_WITH_RETAINED_FAILURE.

The historical browser HOST receipt identifies actual loaded BEAM from OTP
28.5.0.7. Fresh command collectors resolve an erl executable from28.5.0.5; that
PATH identity alone is not proof of their actual loaded VM. Preserve both facts
and use actual loaded-process identity for new runtime claims.

Append-only counter-ledger4 records17 failed GREEN command attempts (the prior15,
new live110/2 and browser zero-completed failure) and19 ordered adopted root
repair events. Source-draft/reviewer metadata assertion failures are separate,
retained, and not runtime passes. All inherited/local snapshots remain verbatim;
Astra2/2 is exhausted. Next: fresh startup/live/Session and prescribed scoped
gates, actual TLS diagnostic/repair and browser3, independent review closure,
fresh acceptance and a local conventional commit.


## Bounded native TLS ownership compatibility repair

The canonical actual-pump trace in native-tls-startup-diagnostic2 records the
original invalid_group_accounting result, then :ok for the identical source
with only ssl:nil. The original native owner retains the identical full SSL
value and gate. There are38 real metadata entries, including nonzero session
data and OTP callback values; arbitrary scalar-whitelist widening is rejected.
This is a diagnostic of the retained browser failure, not browser acceptance.
Its loaded VM is OTP28.5.0.7. The first diagnostic collector failed to unwrap
the public {socket,state} callback tuple and incorrectly forced inner exit0;
both the qualification FAIL and collector failure remain immutable.

Recommended design: keep full SSL metadata on the existing native H2 connection
owner/connection lease; stop copying it into each native H2 Exchange. Preserve
normal endpoint/Plug full SSL metadata through the existing authenticated
Transport.operation(:ssl_data) path, gated by real caller worker, stream ID,
original token and authoritative stream deadline. The Exchange getter returns
nil for unavailable/unauthorized/expired reads. A foreign process with a copied
Exchange no longer receives metadata; other native operations already require
the actual stream worker. H1 direct Socket access, H3 stored metadata, peer
certificate/secure data, accountant grammar and every byte cap remain unchanged.
No new process, authority, payload discount or native-memory proof is added.

Plan: independently review the producer/getter and actual-network regressions;
run the genuine regression on the old producer as intended RED; integrate the
reviewed two-file producer/getter repair; format, strict compile, and execute
nonzero accounting/native TLS/startup/live/Session tests. Real TLS/h2 cases must
retain full nonzero metadata/API/Plug/owner equality, malformed/oversized/backing
rejections, exact original completion/full16,478,862 cleanup and actual joins.
Exercise the new authoritative deadline branch with an original worker call
queued before expiry, an extended local deadline and real watchdog workerDOWN
while only the native owner is suspended; never disable the Admission watchdog.
Then run prescribed native H2, H1/H3/standalone/core-only compatibility and the
unchanged three isolated Chrome cases, resolve independent review findings,
run fresh acceptance and commit locally. The current proposal's local-expiry
case alone does not cover the authoritative owner-deadline branch.


## Joined runtime checkpoint — 2026-10-16

Fresh startup50/0 (receipt fresh-startup-reservation-1792097143408941299.json)
and enabled live110/0 (fresh-group-live-1792097246968131925.json) are actual
joined/stable exit0 with zero skips/exclusions. Session control ran46/4, exit2,
joined/stable; failures remain open. Source diagnosis identifies an undeclared
response trailer in two streaming fixtures and a nonfatal exit signal sent to
a trap-exit native owner in two owner-DOWN fixtures; runtime attribution and
reviewed repair remain pending. Exact trailer/body, original diagnostic DOWN,
original completion and complete cleanup/peer joins remain required.

Counter-ledger6.json preserves19 failed GREEN attempts,20 adopted root repair
events and all predecessor snapshots. The first native-TLS diagnostic collector
failure is retained separately and is not another GREEN attempt. Proposal2
adds actual original-worker queued ssl_data deadline/watchdog coverage and the
role-specific native peer_closed join, with production/accounting proposal bytes
unchanged from proposal1; source review does not substitute for executed RED,
GREEN or unchanged canonical browser cases. Astra2/2 remains exhausted.


## Final source candidate preparation — 2026-10-16

Session fixture repair is independently source-reviewed and actually GREEN46/0
(fresh-session-control-1792098341265691639.json), joined/stable exit0 with zero
skips/exclusions. Its exact diagnostic DOWN, trailer/body, completion and cleanup
assertions are preserved; native H2 provides the genuine non-trapping worker.

TLS ownership proposal2 passed independent SPEC/CODE2 and intended RED41/3
(native-tls-red1-1792097811580202931.json). After the reviewed owner/getter
repair, actual GREEN failed41/2; the real queued owner-deadline/watchdog test
passed. The unchanged-test exception diagnostic41/2 exposed two exact RuntimeError
get_ssl_data-not-supported messages with Gaoxy.PlugAdapter unloaded. Production
Exchange.plug_conn now ensures its own adapter is loaded before constructing
the public Plug.Conn, following independent SPEC/CODE review. The ordinary
PlugEndpoint has the same first-use path. No test-only adapter preload, weaker
metadata grammar, fake response, or assertion/time-limit change is adopted.
The original TLS test source is SHA601d497749e5daee3c4dc43d6351ddcc70abe5bda17f888be49eee5cd2be4ea3.

Counter-ledger8.json preserves20 failed GREEN attempts and23 ordered adopted
root repair events, every inherited counter, both diagnostic failures/expected
diagnostic exits and Astra2/2 exhausted. Diagnostic wrappers are not GREEN.
Collector34 preserves the600-second deadline and real exits/nonzero test/zero
skip policy, adding source bindings for the native worker, Plug adapter boundary
and supported dependency callbacks. Final-required-gates2.txt specifies25 command
gates, plus the unchanged separate three-case Chrome suite. Current source still
requires final FULL review and fresh runtime; controlled :ok alone is no acceptance.
Negative TLS/browser cleanup remains UNCONFIRMED_WITH_RETAINED_FAILURE.
