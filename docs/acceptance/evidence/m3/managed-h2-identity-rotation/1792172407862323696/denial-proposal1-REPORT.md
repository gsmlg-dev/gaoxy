Task h2_identity_denial_impl — DONE: CODE PROPOSAL ONLY, direct assignment.

Repository/worktree /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation;
baseline HEAD verified 8f6b884524d81d8defa7c5081230b8ab635e8107, initial status clean.
Later modifications to the fixed Generation test and Python peer belong to root;
this worker made NO repository/evidence/Git changes. Only this /tmp directory is
worker-owned. No subagent, runtime/build/test/fixture/browser/network/Git-mutating
command, private-key read, raw NetLog read or forbidden trace-file read occurred.

Apply denials.exs.fragment followed by misuse.exs.fragment inside the existing
Gaoxy.Proxy.ManagedH2FixedGenerationTest module immediately before its final end.
No replacement of existing functions/assertions is necessary. In particular,
FailureFixed and CapturedFixed remain unchanged. New helpers use rotation_denial_
and rotation_misuse_ prefixes; the nested RotationMisuseFixed endpoint is test-only.
Use the root-owned new --bind-address/--listen-port peer interface. Keep both
concurrent CA/address peers alive on the same actual port. No production edits.

Source and behavior traced

* Existing fixed test capture/4: actual checked Store capture, authentic original
  T8, acquisition operation, holder, owner source record, independent B fixed point,
  native Gate lease and retained accounting. Both proposal cases reuse it verbatim.
* ProxyHTTP.call (apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:281-294) tests complete
  selected handle membership in the authentic source before dispatch_request and
  before native caller invokes DynamicSupervisor.start_child. Source pin is kept
  untouched for Generation.checked_router's real after/release path.
* Session.open_selected (http/session.ex:1215-1224) sets original_request then calls
  bind; bind (1681-1697) sends that original public RequestCompletion to Transports.
  Proposal captures that actual incoming bind call, monitors its genuine Session
  before continuing, then captures actual owner :out ledger at bind. No posthoc
  polling for an original and no querying Session while it blocks on owner.
* Session.settle/cleanup_complete (1346-1420): :ok original cleanup calls finish
  once and then Service complete_cleanup; cleanup_unconfirmed stops in
  cleanup_failed before finish_transport or Service receipt. The proposal uses
  existing exact positive effects assertions for :ok; separately asserts ZERO
  Session finish calls for sticky failure (not the positive finish-once helper).
* Service/Gate observers use existing supported :sys callback :out/:noreply actual
  state shapes from integration/http_fetch_contract/managed_h2_fixed_qualification.py
  (start:498-550, rejection_cleanup:1290-1388). They retain at most64 distinct
  adjacent projections per actor and assert overflow absence and sequence coverage.
  Complete original cleanup reservation is9_444_956, correlated to real native
  lease and Service cleanup token, not inferred from a502 or physical EOF.
* Sticky Service guardian-DOWN barrier + queued stop follows
  upstream_transport_generation_test.exs:2120-2203. Failure native return occurs
  before unblocking Service; actual public stop must preserve exact Service missing
  receipt AND matching registered owner cleanup_unconfirmed. Sticky resource/token,
  scope and owner receipts are reasserted before/after explicit failed-actor disposal.
* Failed-custodian completion/retention shape follows H1 test:448-620 and existing
  H2 independent qualification:1328-1388, including complete payload-byte sum,
  failed transport C2 charge, unchanged policy/scope, helper slots empty and actual
  custodian initial graceful→abort, two control calls. Stop-owned actor joins do
  not relabel the original or public stop as successful.
* :trace.delivered(Session, Tracee) signature verified by source only in OTP28.5.0.2
  /nix/store/6w4yszkbsv17jiql21i26jmp41hnx9ic-erlang-28.5.0.2/lib/erlang/lib/kernel-10.6.3.2/src/trace.erl:1260-1265.

Actual constructors and finite admission operands for misuse

The deliberate negative schedule PREPARES NEW before OLD capture. This is NOT the
positive rotation ordering. The real NEW preparation stays coordinator-held until
actual CAS. The OLD endpoint init takes OLD options and explicit NEW options,
constructs BOTH pure ProxyHTTP configs during Generation.prepare, and retains
{old_config, explicit_new_config, parent} in its compiled router. Its resources and
generation_validate expose authentic OLD only; NEW is explicit test-only negative
input, never a manufactured source right. Source maps/DER remain on test/preparer
processes, not embedded in either ProxyHTTP config.

Both complete input routes AND complete compiled router are asserted <=1_048_576
in rotation_misuse_candidate. Store input_bound/compiled_bound enforce the same M
in apps/gaoxy_http/lib/gaoxy/http/generation.ex:638-691. Generation request capture
uses M=1_048_576 and reserves the existing full conservative B; capture/4 measures
actual Exchange retained value, recomputes independent B and checks actual Gate
lease/admission bytes. ManagedGenerationAccounting's six complete M roles cover
whole router/selected routing contexts; BOTH configs are already inside that same
bounded router. The later rotation_misuse_dispatch message contains ONLY the
original ref. Endpoint destructuring aliases the already-retained NEW config;
there is NO post-capture NEW options map, config constructor, source/DER file read,
Session, or Fetch allocation. New config remains inside the already-paid full
router bound while ProxyHTTP rejects exact handle membership. The original
Exchange, source pin, and entire owner records/pins/tokens must remain exactly
unchanged until native endpoint return. A bounded per-native isolated trace and
trace-delivered fence prove no DynamicSupervisor.start_child/2 attempt. Zero
owner delegation/checkout/bind/finish, zero native pin_many fallback, and exact
peer joined accept/request totals0 prove refusal before network work.

Bounds remain existing4resources/256pins/64tokens/8MiB owned payload and512MiB
Service admission. Fixed endpoint dispatch/return5s-or-original-deadline barriers,
all completion/peer/joins5s, existing preparer15s/candidate publication5s preserved.
No original operation deadline is extended; no configuration or resource limit is
raised. Public PEM reads are caller-owned, <=65_536 bytes, DER <=1MiB; only public
CA paths are read. Peers and public CAs are prepared before opening native requests.

Checks and status

PASS: read-only HEAD/status inspection, source API tracing, proposal files written
only under /tmp and inspected. SHA256 manifest generated separately.
NOT RUN: Elixir parsing/format, compilation, all Mix/test/build commands, actual
native denial matrix, either completion terminal branch, misuse refusal, fixture
startup, protocol/browser/network verification and independent review. Root owns
integration, formatting and fresh independent SPEC→CODE review before runtime.
This proposal is not implementation acceptance and does not advance stage gates.

Errors/counters and shutdown

Own3 tooling/source lookup events, all recovered without repository/runtime effect:
1. Rejected exec used the not-yet-created proposal directory as cwd; NO child
   command started. Created the directory from /tmp and wrote files afterward.
2. Guessed apps/gaoxy/lib/gaoxy/http/generation.ex lookup missing.
3. Guessed apps/gaoxy/lib/gaoxy/http/exchange.ex lookup missing.
Recovered exact core paths via rg --files: apps/gaoxy_http/lib/gaoxy/http/{generation,
exchange}.ex. A bounded source inventory rg under /nix/store yielded session75970;
subsequent write_stdin returned exit0 and final paths. All own commands finished.
No source/proposal runtime failure, repair-and-validation round, production/fixture
failure or Astra escalation. Own Sol repair rounds0. Astra2/2 exhausted inherited.
Root frozen cutoff after acknowledging these events: root148/orchestration76/
tooling16; group failedGREEN54; stage runtime0/production0/fixture0. Root may have
advanced independently after this cutoff; do not overwrite cumulative counters.

Remaining uncertainty: proposal has not been parsed/executed. Strict expected
Service/Gate DOWN reasons, failed ledger exact shape, timing and both literals are
source-supported assertions requiring fresh root verification. A runtime deviation
must remain visible and enter authorized diagnosis; do not weaken assertions or
normalize failed receipts. No product decision or new dependency need identified.
