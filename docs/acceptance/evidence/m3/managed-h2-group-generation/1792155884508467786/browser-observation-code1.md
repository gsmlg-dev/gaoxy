# Browser bounded observation independent CODE1

Task: gaoxy-group-generation-browser-observation-code1. **DONE — CODE1 PASS; no actionable findings.** Source review only.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`
Branch: `codex/m3-h1-resource-foundation`
Baseline: `8131af39a846c292a022ccbfd32c53376cd57887`

Independent SPEC1 PASS was root-verified before assignment and rebound here: JSON `a47814f17daf3950b7eb3ec8c6cd139cd10b1e84067aedb3d6fad8aa94cfcd3b`, Markdown `a9b921e3866332cea08fa518a2e773a7e09a43554ec1b8c6cc9e4bb7ded0934c`. SPEC/CODE/runtime remain distinct.

## Exact return-only instrumentation

Host3:845–862 lists exactly six public Gaoxy targets:

- ManagedH2GroupAccounting.validate/2
- ManagedH2GroupAccounting.startup/2
- ManagedH2GroupAccounting.preflight_control/2
- ManagedH2Envelope.validate_group_source/1
- HTTP.captured_resources?/2
- Admission.adjust_bytes/3

Each exact local pattern uses return_trace and message=false; raw call events/arguments are suppressed. Only the captured actual active native PID gets :call enabled immediately before original dispatch; it is disabled in the original returned handler. The handler checks actual native/MFA and limits handled return events to64. Normal teardown removes the exact patterns. No set_on_spawn, new observer, broad receive/send tracing, dependency-private target or production edit is introduced.

Known public return contracts are finite: validation/preflight/source return ok/error, captured_resources? is boolean, startup has two bounded numeric counts, and actual Admission.adjust_bytes replies are ok or finite rejection/stale errors. Startup projection emits only those two integers, each0..851968.

The patterns themselves are legacy VM-wide instrumentation within the root-owned test VM; emission is restricted by native call tracing. Cohort1's separate dynamic trace session and source remain unchanged. Normal teardown removes patterns; failures still owe original VM/Actor cleanup.

Return observations are a finite available-event prefix. No trace-delivery barrier or call selector capture is added; ordinal describes handled events only. Missing returns do not establish missing calls/Session or a complete causal history. Unexpected/cap overflow fails closed and never creates acceptance. Runtime trace installation and64-event sufficiency remain unverified by this reviewer.

## Bounded result observation

The returned_observed_v1 event is emitted before the unchanged native/ref/bound/returned assertion. The exact endpoint result and both Captured barriers remain unchanged.

Projection enforces depth3/nodes15/tuple arity4, atom128-byte and safe integer bounds. Tuple traversal stops siblings when the node budget is exhausted; arbitrary map/list/binary/PID/ref interiors are elided. There is no whole Exchange, raw headers/body/private state or ETF/external_size traversal. diagnostic_emit asserts at most4096 encoded JSON bytes.

Known Exchange results expose only tag/arity, response mode projection, close boolean, bounded original error reason and separately labelled finite_reason. Correlation uses actual label/native/ref/equality/phase/deadline/present flags and handled boundary count. Exchange status remains null/not_retained: :sent is never treated as an HTTP status or hidden rejection reason. Unknown shapes remain explicitly elided.

## Acceptance and CDP

The first842 host lines, including constructors and Captured wrapper, are byte-identical. Original native95/P/N/W/B, genuine G/T/Service/source lifetime, custody/peer GET/bound/completion and exact baseline T1record/2weightedholds/G1record assertions remain. Original live-before-close, explicit browser close, real zero states, role joins and rebind remain.

Runner3 only binds host3 and adds the error snapshot. Actor, assert_capture, run_case and main blocks are byte-identical to runner2. Four rows, two real navigations and all8 required screenshots, exit0/nonforced/readers/groups/adopted joins and source/artifact gates remain unchanged.

On actual Page.navigate error, the new event uses the exact target URL for responseReceived and requestWillBeSent IDs for responseReceivedExtraInfo correlation. It emits at most4 status/protocol heads,4 extra numeric statuses and128 error characters, inside the original2048 CDP-event bound. It runs before the unchanged navigation assertion and adds no wait/retry. Empty lists preserve UNKNOWN; an immediate snapshot can omit later events and is not a completeness proof. No raw CDP/NetLog/header/body dump is added.

Diagnostic events do not count as custody, bound, peer, completion or cleanup receipts.

## Verification binding and limits

**102 inputs remained byte-stable:**12 assigned fixture/proposal/diagnosis/SPEC/static-receipt files plus90 product libraries. All7 proposal hashes,2 base hashes and production http.ex binding match. Full before/after manifests are in JSON.

- Host3 SHA256: `a3dd5731a954f509ed724fa77910eb9ab377466f0c03d7434cf3444997eb51a4`
- Runner3 SHA256: `7739650e7b07f0b25448bf32a5f2c36e875f4efbd136645747429d94a3038757`
- Cohort1 SHA256: `7b758fd2d105e4a9c06dafbad4b2e3687b29d3d0f5abfd4f7f630f887dcb5078`
- Proposal1 SHA256: `08ed2d49489ab65ed9c44cce9949114efd44cd505a34dbb006095581abe96b12`
- Extracted browser JS SHA256: `607e1dc80d38cee1dd6e804f7a0dec585ca28e0bd5d5997f176c574e186ecf69`; AST extraction matches syntax1 receipt.

Source/metadata/hash/AST commands exited0; diff exits1 reflect expected source changes. Python source was parsed without importing it. Historical syntax1 is static evidence only; no Elixir or trace runtime success is inferred.

**Reviewer tests executed0.** No target runtime/import/browser/build/network/process action; raw NetLogs/private keys/forbidden terminal trace and excluded new group test were not read. Concurrent root scoped-initial3 was untouched. Only these two /tmp reports were written; every own command completed synchronously with no remaining session.

Browser-green2 remains FAIL and exact early-return cause UNKNOWN. Collector17 mock PASS/actual91 pending are separate parent-reported evidence. Full-stage freeze/review and prescribed fresh scoped/browser/consumer acceptance remain pending.

Counters retained: group failedGREEN50/root96/orchestration29; stage failedGREEN5/production1/fixture7/orchestration22. Own repair rounds0, Astra2/2 exhausted, no reset/escalation. No new user decision is required. **CODE1 PASS authorizes no production-fix, milestone or runtime PASS claim.**

