# ARB-H1H2 frozen recovery handoff

Mode implementation; SOL_REPEATED_FAILURE, historical Sol2/Astra2 evidence in
../recovery/receipt.json. Current cumulative Sol2/Astra16. User's fixed12-hour
grant ends2026-10-30T02:09:44Z; no reset. Main bc8a5ef unchanged. Sole Astra source
ownership and shared build lane released; all commands terminal. No agents spawned.

Scoped implementation DONE; parent final acceptance/review remains pending.
receipt-final.json has all679 final fingerprints, protected CORE/H3 hashes,
15 owned changed paths, exact commands/results and log hashes. task-final.patch
is relative to the transferred HTTP source, preserving prior integration edits.
No CORE/H3/example/manifest/lockfile changes by this worker. No publication.

## Final verification

- Original compatibility file set, seed0/maxcases1:340/0 (original337 plus3 added
  cases in existing WS/idle files).
- H1 budget3, H2 budget10, WorkerAccounting8, default TLS concurrency1, helper16:
  38/0. Disjoint from compatibility; final combined378/0, no exclusions/skips.
- Scoped format check, mix compile --warnings-as-errors, scoped git diff --check:
  all exit0. All five final receipts have identical679-file source fingerprints
  and no source mutation. Earlier34/0 WS and18/0 final-close review subsets are
  supplementary, not added to378.
- Parent manifest changes required: H2 budget5->10, H2 WS idle6->8, WS stream22->23.
  No new test files beyond pre-existing untracked H1/H2 budget files. Component
  total increases by8; unit/protocol unchanged. Parent owns canonical manifest.

## Causal changes and review pointers

Exchange funding preserves actual retained/temporary classification and exact
memberships, explicitly repartitions inside paid total and uses checked growth.
H2 constructor accounting includes funding map and phase_receipt request/reply.
Expired pre-reserve spawn proof requires original alias+matching token; ordinary
ambiguous timeout remains charged. Exact ETF constructor assertions remain.

H2 Connection.receive_options reads public effective TCP buffer, with16384 minimum
copy profile; TLS keeps old conservative bound. Limits separates2*buffer completion
from independent2*buffer+8*delivery receive floor. resize_connection invariant is
max(F,R+receive)+current_decode_peak. Partial-only input, parser rest, continuation,
input and delivered/rest slices detach excess backing; delivered ownership remains
charged until acknowledgment. See receive-completion-invariants.md and H2 budget
regressions for actual readback, fragmentation/parser-turn1, held body, HPACK, drain
floor and rejected beyond-funded growth. No zero-retained fiction or HPACK highwater.

WebSocket reserves254 transport completion bytes; application bytes remain separate
and never become transport credit. Paid-bound metadata follows callback admission
and each popped output; known growth directly calls checked update, without false
rejection probes. Exact10MB payload under explicit1MB transport cap and healthy H2
sibling now also require zero rejections. Unfunded H3/legacy paths remain compatible.
Stream.run does not restore pre-upgrade HTTP request funding after WS own lifetime.

H2 close handles socket-close overtaking the exact final writer receipt, including
expired HEADERS :close. Queued FIN alone is no proof. Completed workers join final
bookkeeping under one shared cleanup/drain/request deadline; unfinished workers
cancel. Actual writer DOWN precedes discarding all parent buffers and authenticated
stream/resource proofs. CORE independently requires child DOWN/EXIT/canonical commit.
New real-END_STREAM gate-barrier, shared-expiry, expired-HEADERS and unfinished DATA
cancellation regressions retain their precise outcomes.

## Residual boundaries

Forced writer deadline expiry intentionally submits no unconfirmed resource proof.
Its inherited canonical fallback is not qualified here; no pressure/slow-peer/soak
or historical blocked-upload slice was run. TLS profile reduction was not attempted.
Historical H3 helper callback drain failures remain preserved, despite latest16/0;
H3 remains parent's separate recovery task. Final independent review, manifests,
whole-project gates and authorized delivery remain parent's responsibility.
