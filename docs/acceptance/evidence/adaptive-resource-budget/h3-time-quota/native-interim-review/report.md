# ARB-H3-REVIEW — provisional native cleanup source review

DONE for this bounded early read-only review, not final H3 acceptance. Direct
assignment; repository `/home/gao/Workspace/gsmlg-opt/gaoxy`, existing `main`,
baseline `bc8a5ef5199293ada3b432c2e2741070d3b2d115` plus preserved dirty integration.
Only this review directory was written. No builds, tests, BEAM, peers, listeners,
network, source edits or Git mutations were performed. All reviewer commands are
terminal. Reviewer Sol0/Astra0; received H3 implementation counters Sol2/Astra6.

## Actionable finding

**P2 — cap the cooperative termination window by applicable existing terminal
bounds.** `apps/gaoxy_http3/lib/gaoxy/http/http3/connection.ex:146` currently uses
`now() + min(50, callback_timeout)` alone. An entry whose `cancel_deadline` or
existing terminal deadline expires earlier can therefore receive a fresh wait
past that bound. The same shared 50 ms window is correctly reused across all
workers, so this is not an unbounded per-worker wait; the missing constraint is
its relation to already-established cleanup bounds. Parent forwarded this to the
sole implementation owner, who acknowledged it and will cap the shared window
by applicable entries' existing `terminal_deadline`, including `cancel_deadline`.
The reviewed source still lacks that cap. Repair and final review remain pending.
This finding consumes no implementation repair round in this reviewer.

## Native ownership trace

The original native-lifetime P1 has a provisionally addressed source path:

- `QUICBridge.init` asks Service to reserve native ownership before application
  handler init. Service retains the original opaque connection/handle in the
  prepared guardian state. Admission authenticates the registered Service.
- `Ledger.reserve_native` records a Service-owned `:guardian` row with measured
  native bytes plus bookkeeping, one connection membership, and one pending
  process credit. Callback death does not own or release that pending row.
- Admission binds a live, distinct guardian monitor before canonical split.
  Ledger atomically preserves native token/bytes/membership while moving its
  owner and consuming the funded pending-process credit. A separate empty
  callback `:transport` row is created and checked against ordinary `max_active`.
  Guardians do not create an ordinary request or extra connection membership.
- Callback state and native charge then retire separately. Authenticated native
  replacement preserves existing membership/accounting and uses canonical
  revision/operation/deadline mutation machinery. Scalar request cleanup
  eligibility remains unchanged.
- Guardian is inert before activation. A healthy activated connection has no
  cleanup deadline until triggered; callback DOWN or a closed notification
  triggers observation, rather than issuing a receipt. Repeated triggers keep
  the earliest established guardian cleanup deadline.
- Only the exact public result `{:error, :closed}` on the stored connection
  enters `Service.complete_cleanup`. Service authenticates the registered
  guardian; Admission authenticates Service. Adaptive refund requires the
  receipt and normal guardian terminal evidence. Timeout, malformed/wrapped
  errors, callback terminal pairs and abnormal guardian termination do not
  satisfy that path. Public info runs in the funded observer, outside the
  Admission/Service critical handlers; its internal five-second timeout remains
  a real latency limit and was not shortened by this review.
- Late reservation receipts retain the Service-pinned obligation; split failure
  keeps the guardian bound to the original pending charge. Service/gate loss
  without matching terminal proof leaves canonical ownership unconfirmed.
  Reconciler treats native rows as guardians requiring exact-token normal
  proof, rather than releasing them through ordinary callback terminal pairs.

No new source-level premature native refund P1 was established. This is not a
final closure of the prior P1: the source is still changing, final frozen review
and parent fresh verification are required.

## SSE compatibility extension and limits

The added `Admission.begin_native_cleanup` authenticates the existing lease
owner, requires the native callback marker, permits ready/draining only, and
rejects bytes above the existing paid callback charge. `QUICBridge.terminate`
uses it so local teardown can run during drain without admitting new growth.
`Connection.terminate` revokes local Operations capabilities before waiting for
worker monitors and retains the existing final clear/kill fallback.

Existing `handle_event({:closed, _})`, failed reads and `fail` paths can call
`clear` before `terminate`; `clear -> stop_endpoint` immediately kills workers
and empties the stream map. The new cooperative window therefore does not apply
to those paths. The owner confirmed this is intentionally preserved previous
forced/peer-closed behavior. The reproduced SSE branch reaches Bridge terminate
with live streams, without a prior clear. No new requirement for global graceful
drain is inferred, and no regression from those unchanged paths was established.

## Coverage observations

Reviewer validated terminal receipt metadata and actual log hashes/count lines:

| Existing writer receipt | Executed count | Result |
| --- | ---: | --- |
| recovery3/native-complete-invariants.json | 115 | 0 failures, exit 0 |
| recovery3/native-negative-dedup.json | 60 | 0 failures, exit 0 |
| recovery3/helper-native-teardown-repair.json | 2 network + 16 helper | 0 failures, exit 0 |
| recovery3/initial-network.json | 2 | 0 failures, exit 0 |
| recovery3/native-lifetime-repair.json | 3 | 0 failures, exit 0 |

All five logs match recorded SHA256; all five commands report terminal, no
source changes during their individual executions, and no skipped/excluded
cases. These are observations of existing writer evidence, not reviewer reruns.
Receipts overlap and must not be summed into a unique-test total.

Controlled `quic_context_test` exercises the actual Service/Bridge/guardian seam
using an injected public observation result: native ownership remains after
callback kill and across timeout/unavailable/malformed/wrapped-closed results,
then reaches zero after exact closed proof. Admission tests cover callback loss
before split, both terminal orders, authentication, duplicate/stale/expired
requests, definite split rollback, guardian kill and ambiguous reservation late
commit. The reviewed sources do not establish equivalent deterministic runtime
coverage for ambiguous split late commit, guardian registration failure and
Service loss at every partial-init boundary. These remain final contract-to-test
coverage checks; source reasoning does not convert them into executed proof.

Original persistent WebSocket coverage remains failing: parent reports a fresh
2-test/1-failure reproduction with the original 5 MiB payload/deadline, diagnosis
ongoing and cause unknown. The 18/0 helper/network receipt does not supersede it.
Final combined suites, package/release qualification and publication remain
separate and unverified by this review.

## Source identity and handoff

`receipt.json` records 13 initial inputs, six supplementary inputs, after hashes,
five observed terminal receipts and their log counts/hashes. All saved initial
snapshots match the initial recorded hashes. Admission and QUICBridge drifted
during review; the exact drift was read and preserved under `differentials/`.
Other initial/supplementary inputs matched their after hashes at report capture.

Disposition: resolve the acknowledged P2 deadline precision gap, finish existing
WebSocket diagnosis/ordinary qualification, establish a frozen candidate, then
perform final independent review and parent fresh checks. No permission or new
product decision is needed for this bounded review. Reviewer work is stopped;
no runtime process was created or left running.
