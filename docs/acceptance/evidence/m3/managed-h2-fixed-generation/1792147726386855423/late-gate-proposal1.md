# fixed_generation_late_gate1 — source-only investigation

Status: DONE for assigned report/snippet, direct assignment. Runtime acceptance NOT RUN.
Repository/worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.
Parent baseline: `aa272c3dca700a9275a00bd23920d09bbd4748a1`; HEAD/Git NOT RUN.
Only these three assigned `/tmp/gaoxy-fixed-generation-late-gate1` outputs changed.
Root owns repository/runtime/Git. Source was read while root integrated its draft;
hashes bind observed bytes, not a frozen/loaded tree. No repository mutations,
application/test/build/browser/network execution, private dependency-process
inspection, or delegation occurred. All commands finished synchronously.

## Recommendation

Keep the original Session cancellation AND owner lifecycle held after actual
failed Gaoxy.stop(instance,0), real native:killed, and failed instance completion
observation. While Session and the original managed scope creator still live,
call the supported public `HTTP.RequestCompletion.abort_and_await(original,@timeout)`;
require actual :ok on the unchanged original completion. Then release original
owner lifecycle, obtain its original retirement receipt, require the exact failed
result, release Session cancellation, and require original Session normal DOWN,
authentic Service receipt, physical peer termination after scope retirement,
ownerzero and every original join/rebind/sticky-failure assertion.

This order preserves failed public stop before genuine late original completion.
The design/plan require the earlier failure remain failed; neither requires the
retirement receipt be observed before original completion. Owner begin_retirement
retains the authentic expired deadline; retirement_progress checks expired deadline
before empty records/tokens, so it truthfully produces failure even after completion.
Do not require EOF just from reusable request completion before owner retirement.
The actual peer termination assertion remains after retirement.

## Root cause and evidence

Parent reports GREEN4 joined 83 tests/8 failures, exit2; read log independently
confirms those totals and both late rows receiving cleanup_unconfirmed. Six other
identity rows had draft502 vs real503; root already repaired expected statuses.
These are parent runtime results, never this worker's test execution.

Session handle_info cleanup_cancel records its real issued deadline (287–305).
For managed H2 begin_cleanup uses min(original deadline+1000, requested deadline)
(1369–1388). ManagedH2Client.cleanup performs a zero-time original abort/poll
(57–84). If pending after the expired cancellation is released, Session.cleanup_pending
immediately stops :cleanup_unconfirmed (1424–1432), losing its clean guardian join.
The public independent abort while Session is held gives the original cleanup a
finite real opportunity to finish. On release, the same handle now polls :ok;
there is no fabricated completion, replacement receipt, deadline extension, or
premature Gate/owner refund. Proposed execution remains NOT RUN.

## Original Gate and actual terminal Service ledger

Admission.handle_call(:force) kills native leases and clears send fields, but
retains lease/cleanup maps and bytes (409–419). Lifecycle.force calls this Gate
with50ms timeout and then kills original Gate/resources (121–125). Observe original
charged Gate input at the real Admission.handle_call(:force,from,state) using a
filtered compact call trace, and separately require that exact Gate:killed.
This is an actual charged force-input ledger, NEVER a live post-force Gate0.

Do not block a Gate observer: its caller can time out after50ms. A :sys out hook
is also not deterministic here: OTP gen_server.reply sends the reply BEFORE its
debug hook (2591–2594), allowing Service to kill Gate before it emits observation.

Service.complete_cleanup acknowledges only authentic guardian/token and sets its
receipt true even if Gate is already dead (130–145). Observe its real :sys out
state, emitting only receipt/count/failure metadata. Its normal guardian DOWN
removes cleanup (494–515); finish_drain runs only when original native resources
are dead and cleanups empty, and returns mode:stopped/drain:nil (600–626).
OTP does not emit a :sys noreply/terminate event for {:stop,reason,state}; it
passes state to module terminate directly (gen_server2571–2585,2731–2733).
Therefore observe the actual Service.terminate(:normal,state) function entry with
compact filtered metadata: mode:stopped, cleanup_count0, cleanup_failed:nil,
drain_nil:true; still require actual normal DOWN separately.

The additive .txt uses current OTP dynamic trace sessions, exact original Gate/
Service process selection, exact original lease/cleanup identity predicates and
:arity, so no raw state/request/header/body trace escapes. Dynamic sessions avoid
mutating another test's trace patterns and are destroyed on_exit. API was added
OTP27 and is present in inspected current OTP28 sources. Match-spec syntax and
behavior are NOT RUN; root must compile/execute/review it. A source assertion is
not substituted for actual terminal-state observation.

## Draft contract review

- Six identity mismatch502 expectations are wrong: actual unavailable maps503;
  preserve exact owner :transport_endpoint_mismatch assertion (root already did).
- Double Resources.release(preparation) is idempotent here: owner release checks
  authentic pin identity and returns :ok on absent pin; no fix required (380–399).
- F.physical_termination after finish can still consume already delivered EOF:
  finish's selective receives do not consume the EOF/reset packet. No definite
  bug found there; late fixture keeps physical join before collector stop anyway.
- Empty capture intentionally uses standalone behavior. Draft nonempty malformed
  copy tests do not prove authentic Store corrupts output; preserve that distinction.
- Late authentic Service cleanup token is Session.state.token, NOT held.token
  (the latter is a transport-owner token). New observer must use the former.
- No further obvious fixture defect established by source review. Do not infer
  remaining cells pass from static review.

## Verification, counters, and remaining work

Executed only source reads/searches and data-only Python report/hash writes.
No parser, formatter, compile, tests, browser, runtime, network or Git command.
Source lookups at guessed paths and one unmatched zsh glob were corrected; they
are not implementation or runtime repair attempts. No background commands exist.
All proposed runtime checks: NOT RUN. Parent must integrate, review, execute and
retain fresh exact evidence before acceptance. No external permission/design
question is needed for the bounded proposed fixture/observer repair.

Latest parent-reported cumulative counters: group44/root59/Astra2of2 exhausted;
successor failedGREEN3/fixtureRepair2/productionRepair0/orchestrationRepair1.
Delegate Sol repair rounds0; received Astra recovery2/2. No escalation;
astra_gate not applicable. Existing failed evidence/assertions remain intact.

## Source hashes

- `/tmp/gaoxy-fixed-h2-generation-failure-draft1.txt`: `0e6bdad4cfa9a6e1168f0796532c0c1b88296cffca28e0c766943a20925a75c1`
- `/tmp/gaoxy-fixed-h2-generation-failure-draft1.md`: `cb6dc9d5691dcd4f8a516450b054146d4a2494f727b59ece85efbed8a5832529`
- `apps/gaoxy/lib/gaoxy/admission.ex`: `81c96e55e56d514f4bd93cecb7af906a55279927d3f100f7b2045181f1eaf107`
- `apps/gaoxy/lib/gaoxy/service.ex`: `740d69a364e52cda9d05a997136ce864e9ec464149adcc81045bc9c109ed4472`
- `apps/gaoxy/lib/gaoxy/lifecycle.ex`: `7f673e89f59b41af72057ce1afa553fa6c62e56125b450e6d09e58da0a434f75`
- `apps/gaoxy/lib/gaoxy/telemetry.ex`: `749421579aa4d6c5c8d8def5d9cdf502a59c7aa194203a8fb6c3051de1b72961`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`: `8a041a6bc217ef5ec626dc9e4efc2ec495db3a668912214420ad01bd4d449eac`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex`: `e8c60d1d5a67f3b9737478149ac6e28b8e9ddf778289a2fac6035054379e7313`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex`: `877bb6e4c891ee3f8c93a425a67b10f390137fcead2eeb52ccd9b78d9b2b1f51`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/custodian.ex`: `71eef3a58914cc1b685784ab2c30fef95e8a645c27b71fa75ef5544cdbe8c1ba`
- `apps/gaoxy_http/lib/gaoxy/http/resources.ex`: `0a1afd048e559f98aa7d18031989d33eb1b8a6882803679f1e79612ecdebc8b2`
- `apps/gaoxy_proxy/test/managed_h2_fixed_generation_test.exs`: `7b6c9954a3d2d8bdf2b3d1290543963c677124053e1f46a3b687578327f53403`
- `apps/gaoxy_proxy/test/upstream_transport_generation_test.exs`: `63c521979cee9ecea809c1bf78e00e121f97e7b7a65d416d70cf5b620a84b9f4`
- `apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs`: `51a72d2f78481d27a000111543276fdd6211b5212d24f051af55db2ee724eddb`
- `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs`: `e89adb9c7cefa1c64385e9a90962ece819d7dfb492807b42e7b77644f042c33a`
- `deps/http_fetch/lib/http/request_completion.ex`: `157a371b838a2f72117a7e92f97d2f602a0363cc228411c77c1e22ba7865237c`
- `deps/http_fetch/lib/http.ex`: `61ea03a1b6d43054fa91f19a1614fd2441ad6b730fb12553a847ffb4e2344238`
- `deps/http_fetch/lib/http/socket_client.ex`: `245784a82edfdc741d18a967f611568cf81682409c3f8acb212e0dcd5b12c6ef`
- `docs/plans/m3-managed-h2-fixed-generation.md`: `96865d660780324ffe2ce9856798b819c08e8f88d46b65d46a1ef9595e8946ff`
- `docs/designs/m3-managed-h2-fixed-generation.md`: `44992f92facc36ecac0f7b7f8b9a463061ac39c629a9ada72e85bcc88b16dc1e`
- `docs/acceptance/m3-managed-h2-fixed-generation.md`: `801c6b5492cbde8b8d56ea0b6e871ce3a20625063267fe46c00570a5a89afd64`
- `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/fixed-generation-failures-green4.log`: `5f95b224344b7b9480e7ed2441eba9cb24f3268bb1bb21f3ef47aca70c967287`
- `/run/current-system/sw/lib/erlang/lib/stdlib-7.3.0.1/src/gen_server.erl`: `66a4a649c8ed58f3c9ed317047f28ea2e2a61b38032cc467565fbad2c53a09db`
- `/run/current-system/sw/lib/erlang/lib/kernel-10.6.3.3/src/trace.erl`: `bce5fb3521bcd2efb48ca116968a58f61e732b2a7be1bf730db7e7ee314bc3c0`
- `/run/current-system/sw/lib/erlang/lib/erts-16.4.0.5/src/erlang.erl`: `eef4e95a8a0fc09b0eaaab18e777b0f9f32c36f5890f114476a14000f488cad0`
- `/tmp/gaoxy-fixed-generation-late-gate1.txt`: `a3ab7503a4e65efb704d323dd5fb56a5e13683dccd50b7bcf70b9f9e715092df`
