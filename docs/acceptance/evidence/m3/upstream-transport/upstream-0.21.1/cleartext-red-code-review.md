# Cleartext expected-red code/spec review

Date: 2026-10-11 Asia/Shanghai. Direct independent Sol task
`m3_h1_preparation_spec_review/cleartext-red-code-review`.

**PASS for the static code/spec gate before the parent-owned cleartext
expected-red run. No blocking finding.** The reviewed delta preserves existing
assertions and cleanup, selects exactly24 H1/h2c cases with `--cleartext`, and
retains the obsolete capacity hard match for the planned red capture.
This report is not a runtime result. TLS/full39 stays BLOCKED on95; complete
P0–P6 and managed activation remain unqualified.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`.
Branch: `codex/m3-gateway`. Diff baseline:
`a6a210c720d4a0fa9b8fa5f485e5c07a825ad03c`. Ownership is this report only.
Parent owns accounting/dependency changes and serialized runtime execution;
another worker owns the probe/README. Their changes were preserved. This
review uses the prior [fixture specification](cleartext-fixture-spec-review.md)
and [cleartext plan](../../../../../plans/m3-upstream-0.21.1-cleartext.md).
Completed source and installed-cohort identity reviews were referenced rather
than repeated.

## Driver selection and unchanged case bodies

`run/0` matches exactly `[]` to `:full` and exactly `["--cleartext"]` to
`:cleartext`; every other argument list raises `ArgumentError`. The branch
happens before `Peer.start_apps()` and before any case reaches `Port.open`.
The unchanged helper-loading prefix sets `HTTP_FETCH_PROBE_LIBRARY=1`, suppresses
the helper's top-level runner, then restores the prior environment value. Helper
loading does not start apps or a peer. This is a source assessment; unknown
arguments were not executed by this reviewer.

The private driver selects full protocols H1/TLS/h2c with TLS/h2c H2 cases, or
cleartext protocols H1/h2c with only h2c H2 cases. `^expected_cases` hard-matches
the completed case count to39 or24. The profile banner and final report identify
the selected profile, scope and TLS block.

Independent Python comparison proves the30563-byte prefix before `run/0` is
byte-identical to baseline, SHA256
`f2cdfbad180f75894d6bfd62934d7a4e4491de0a8a00485ff86dd32b5a2c3ffb`.
That prefix contains every case, helper, timeout and cleanup body. The unchanged
module-ending/top-level run invocation is also retained. External
`pooled_completion_probe.exs`, `managed_peer.py` and `upstream_peer.py` equal
their baseline bytes. The subsequently released MANAGED_README addition is
reviewed below; its entire original narrative remains unchanged. All probe changes are
inside the run driver; no existing assertion or cleanup body changed.

Independent static report-site and loop enumeration gives:

| Group | Cases per protocol/group | Full selection | Cleartext selection |
| --- | ---: | --- | --- |
| common | 6 | H1/TLS/h2c | H1/h2c |
| deadline | 1 | H1/TLS/h2c | H1/h2c |
| h1_extra | 2 total | H1 | H1 |
| h2_capacity | 1 | TLS/h2c | h2c |
| fragments | 2+4+1=7 | TLS/h2c | h2c |

Full count is `3*(6+1)+2+2*(1+7)=39`; cleartext count is
`2*(6+1)+2+1+7=24`. Each selected case retains its original independent peer,
finite deadlines, exact bytes/counts, no replay, scope/completion/retirement
checks and joined cleanup. TLS certificate/OpenSSL/context creation remains
conditional on the TLS protocol in the inherited peer; cleartext selection does
not select that branch.

## Expected-red assertion and cleanup boundary

The h2 capacity case still sets `source_error={:error,:pending_capacity}` and
hard-matches `^source_error=actual_error`. It reports the observed value and
comparison with `{:error,{:transport_scope_capacity,:connections}}` before that
match. The historical WORKAROUND/MISMATCH comments and diagnostic remain
intentionally for this red revision; they must change only after the precise
red result has been captured. No assertion is weakened or obsolete expectation
silently accepted.

With retained order,16 earlier cases can complete before this h2c hard match;
there should be17 joined cleanup attempts including the failing case. Those are
predictions, not runtime counts. Accept the red gate only for the observed
canonical tuple failing this exact obsolete match, with joined cleanup confirmed.
An earlier unrelated failure or any cleanup failure does not satisfy it.
The incomplete red run cannot count as24 passed cases.

The unchanged `with_peer/2` records primary and cleanup diagnostics, attempts
cleanup after primary failure, and rethrows the primary error. Therefore the
parent must inspect cleanup diagnostics separately even when the expected
primary mismatch appears. Cleanup visits all remembered scopes/completions,
hard-matches each recorded completion outcome, requires zero live peer threads
and exit0. The broader aggregate completion list does not widen any individual
recorded expectation.

All capacity wire checks, GOAWAY/PING acknowledgement barrier, held admitted
stream, independent-scope progress, zero pending queue, old connection closure,
public zero connection/request/preparing/resource ledger and replacement checks
remain unchanged. Their runtime execution follows the obsolete hard match and
will require the later canonical-tuple green revision.

## Accounting identity and historical evidence

Python byte comparison proves accounting facts and their test differ from
baseline only in exact cohort version/tag literals:0.21.1 and
`bdf849adf119039ed679d24d5fbb0a321f5e578a`. Both existing direct Fetch/WebSocket
pins differ only by0.21.0→0.21.1. Previously reviewed coordinated lock identity
remains a separate receipt. No runtime identity, constructor formula, bound,
obligation or activation assertion was relaxed.

Current facts remain `qualification: :unqualified`; all seven P0–P6 obligations
remain unqualified. `activation_status/0` still returns
`{:error,{:unqualified,[:p0,:p1,:p2,:p3,:p4,:p5,:p6]}}`, with no evaluator,
caller proof arguments or activation-success path. The tests still reject
invented totals and caller-provided proof constants. Merely updating cohort
identity does not relabel an old proof as containing-source qualification.

The parent's [accounting red analysis](cohort-red-analysis.json) is supported by
its raw [repair1 receipt](cohort-red-repair1.json) and verified log:4 tests,
1 failure, exit2, caused by the new exact test identity observing old facts.
The429-entry before/after source maps are identical. The old fact source hash
equals baseline; the test source hash equals the current identity-only test
revision. Current facts subsequently align the identity. Scoped compatibility
was running separately at assignment time and completed before documentation
release. Its parent-owned receipt records486 tests/0 failures, exit0 and429
unchanged before/after source hashes; its actual log hash was checked. This
reviewer did not run that command or expand its scoped acceptance.

The first collector attempt failed before command startup because argparse
consumed `--timeout` as the executable. That failure is preserved and is not
an executed red test. Corrected collector argument ordering produced the
expected red above. Collector repair1/unsuccessful0/Astra0 and the separate
successful dependency-fetch repair1/unsuccessful0/Astra0 remain recorded;
expected-red mismatches are not implementation repair failures. This static
review needed no repair or escalation.

README adds the current0.21.1 preparation/invocation paragraph and marks the
old section historical. Its entire historical narrative after that heading is
byte-identical to baseline, SHA256
`44e67392b8bbd90b13e7925d7029eed1e27eec9202a1cf536bbf05909fd757d9`.
No historical0.21.0 evidence file changed in the baseline diff.

The released MANAGED_README adds a current0.21.1 checkpoint and explicit
historical boundary before the complete unchanged original narrative. The
released acceptance/design/plans and five dependency-request documents were
reviewed from their actual Markdown deltas: they distinguish source fixes and
installed/compatibility identity from pending cleartext RED/green, preserve
TLS95 blocking, keep full accounting/activation disabled, and explicitly bind
old formulas/probes to0.21.0. Their486/0 compatibility statement agrees with the
parent receipt and its verified log. None relabels an old conditional proof as
0.21.1 qualification.


Parent's later [remote observation](upstream-status-refresh4.json), at
2026-10-10 20:19:06 UTC, reports95 CLOSED (updated20:05:59Z), while GitHub/Hex
latest remain0.21.1. This observation does not change the reviewed immutable
installed tag or supply its absent95 tracking fix. Installed TLS qualification
therefore stays BLOCKED. The frozen status documents' earlier OPEN wording is
a pending documentation synchronization for final delivery after red/green;
it is not evidence that the containing TLS fix shipped. No frozen code or
status document was rewritten by this reviewer in response to the observation.

## Frozen review inputs and verification

The first report freeze had SHA256
`a28c72f03b877bbb9c811c134e1794e7f11d8b9b95adbd1130f5d8abf595673e`.
Its final validation exited1 when checking MANAGED_README against the429-entry
compatibility snapshot. The concurrent Markdown addition landed after the initial
static body comparisons. Compatibility before/after maps retain the old value
`637ec5f07d4cdcc1ac529f353d8f3878e3817086c84f99e1c75cf7cf2062425d`. The first report's26 directly
read input table already recorded the new released value
`146b8a41ad295c161c50a4aa7fb371aad7f43dbeee7cc3f952a6f4172266ab2e`; the failure was in the
blanket429-map comparison, not that26-input table. The initial report's prose
claim that MANAGED_README still equaled baseline was consequently stale and is
corrected by the reviewed addition and one-entry snapshot override below.
No stale frozen PASS was delivered. Parent and writer explicitly confirmed all
document writes released before this refresh. Review freeze-refresh1 is a
concurrent documentation rebase, not a failed implementation repair.

The renewed429-entry freeze is defined by
[compatibility-source-before.json](compatibility-source-before.json), with only
the MANAGED_README value replaced by the released hash above. All429 effective
hashes were freshly checked:428 map entries match verbatim, one Markdown entry
has the reviewed prefix addition, and executable code/fixture/dependency/lock
values are unchanged. The38 directly read spec/code/evidence inputs below are
additionally pinned, including the compatibility receipt/log/after map and every
released Markdown delta read in this refresh. Existing source/installed reports
remain frozen historical review references; their original-time inputs are not
relabeled as this newer document checkpoint.

```json
{
  "AGENTS.md": "c0e76e879d663635b89b4c4fde4274561fce3c4c51a9d086e07908959e9431ed",
  "apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_accounting.ex": "81b990206b77a83d8c19aa97d451a752b4b9ec3e0cc0859f2a1a8b282079aff1",
  "apps/gaoxy_proxy/mix.exs": "14215a63b452ce1031746cf08bb1a641c57802fc20a6df45a35bf22e585e28e2",
  "apps/gaoxy_proxy/test/managed_h1_accounting_test.exs": "3396d538167b7b950a7c38291cd4da6e5a1e4dc0621180d6856fc61efd413856",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cleartext-fixture-spec-review.md": "ab703196aef32068c002e3ab51545c29d98e0f58d295f1e2ddd1ffc5db286bb7",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cohort-red-analysis.json": "d5c6cd0d4b5ef2d9dbca51e2c1a9df5f830a371703b9fc58b5e91e0e2e2d6048",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cohort-red-repair1-source-after.json": "7e4157efde226352b7325cc7fa333551026a9b10ce3c05e9fae9ee61680ea605",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cohort-red-repair1-source-before.json": "7e4157efde226352b7325cc7fa333551026a9b10ce3c05e9fae9ee61680ea605",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cohort-red-repair1.json": "5fb938cb3d85d519a344d90d967a138d50ff06f9d170ee9e5dc342bf409c9a65",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cohort-red-repair1.log": "4d2c632d9a06e5c0897e944bea252670fd3216430f66dd768fb3dc8778971188",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cohort-red.json": "4bf71044b92cf06b5cf8c8851f01df9180e8bef15ec5fe449c2901b6a585f7c2",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/cohort-red.log": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/compatibility-source-after.json": "cb26baddb8591fe049c3ea6962c71c9b23551e1b3253ef9a179b5513fcaf033f",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/compatibility-source-before.json": "cb26baddb8591fe049c3ea6962c71c9b23551e1b3253ef9a179b5513fcaf033f",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/compatibility.json": "f81edb1cb89988b4b99b6a83b4dda68345acca27da470c3ed1c2f7c84a0a9c78",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/compatibility.log": "1d3799a6586b80634395264f212205222807903df83c8d1130ec8a5d10235482",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/installed-cohort-verification.json": "ae1479dbaa9d08412d19c0e94226c0647ba1c801e43d57188039753feb0cda26",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/installed-cohort-verification.md": "e9225b55172f2d71e86d78f3022c67e07c8734f2d0bdcbde8d9172eb9a0734d5",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/source-api-review.json": "e9cfb8619626d31d858c40799a4bf77c61f40d9c0570eddea97d93c64f0886c8",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/source-api-review.md": "79e9830c2a67574f07bac053de30a91fad6616d7beb980df7f4a1ae33172403a",
  "docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/upstream-status-refresh4.json": "3130f0e972d73ad03650a3dd75f48d512f3fa38e1211bcb19ca26623e781cf77",
  "docs/acceptance/m3.md": "6d510ffb608b206ef281a3811e415c4186593a8b4ef59a55091353b71bd7f565",
  "docs/dependency-requests/http-fetch-h2-header-control-bounds.md": "98692514a3552578076d735a1f94c1d039b4203d19ddb0ca57af21f09fe0d4ba",
  "docs/dependency-requests/http-fetch-managed-capacity-error.md": "eae95ae3e849906b051d4c2cd4ee948cb78c45bc915250344273d91a99160095",
  "docs/dependency-requests/http-fetch-managed-request-inputs.md": "a417a85760c6c371f4aae30a1922d2f383f4179ee2c299364fe18e179be4a4e8",
  "docs/dependency-requests/http-fetch-managed-tls-backing.md": "0cfb92add0bbb95ecd1ca3eb9b0e50187c13f167ad9d293518f203ebb2aef625",
  "docs/dependency-requests/http-fetch-otp28-tls-tracking.md": "242273c8ec60e7ddbc7e68f118a5e812aa1d527e9e0384dec9ea7430c5c0ca75",
  "docs/designs/m3-upstream-transport.md": "c68924ac74b59ddab236129ce54583f0fd92931aec53260841aa53c9178fc521",
  "docs/plans/m3-upstream-0.21.1-cleartext.md": "eeb4effe566dc33a9f099dc89552a511928932a248bb1fad8795389640287c0d",
  "docs/plans/m3-upstream-0.21.1-qualification.md": "365b8786b65f662cb29ea32b01c47521d0afef7b25da7f8559294d381e22a606",
  "docs/plans/m3-upstream-transport.md": "76bfe7906f675aaeb72a9a72fbd03264c7963b856a88df1aa3c5b523b54ff1a4",
  "integration/http_fetch_contract/MANAGED_README.md": "146b8a41ad295c161c50a4aa7fb371aad7f43dbeee7cc3f952a6f4172266ab2e",
  "integration/http_fetch_contract/README.md": "4befabd68d1faa6232de18e61c6b48e241968ef1d90c8230679ac76f9fa8e3db",
  "integration/http_fetch_contract/managed_peer.py": "319e9c9f2832ddf2ab9cc84aedd519bfe33f36e2152d24bb47bf5fcde8169d79",
  "integration/http_fetch_contract/managed_transport_probe.exs": "93336bb15c67f05bfd607930e7a797dcc1c02efcd487e7d95447b5e5df080c8f",
  "integration/http_fetch_contract/pooled_completion_probe.exs": "f681723ff58754cb6169d0b42fb681a8439eeaa6c7ec7e94c752894405ce1e30",
  "integration/http_fetch_contract/upstream_peer.py": "f2e40b0e72362f06b4c933b14f45d49e768b2133bee4281c4241bbd122d9b95f",
  "mix.lock": "9e3b1039598e3384cbf50387be7d9eb4700097ed275e5bcd85f32733e061e1ad"
}
```

Fresh Python checks exited0 for driver-prefix/helper/history equality,
identity-only facts/test/pin deltas, exact profile/argument branches,
case-count arithmetic, expected-red log/receipt/before-after identities and
all429 current effective snapshot hashes. Final checks revalidate these frozen inputs,
report links/fences/whitespace and `git diff --check`.
A guessed obsolete module-path glob failed during an initial read and was
corrected to the actual `lib/gaoxy/proxy` path; no code execution or edit
resulted from that selector diagnostic.

No VM, Mix, compiler, network peer, dependency mutation, code/fixture edit,
commit or child agent was launched. All own commands finished; no own background
process remains. Runtime expected-red/green, 24 joined cleanups, canonical MATCH,
TLS95, complete86 adversarial backlog, held preparing/connecting saturation and
memory-ledger/activation acceptance remain separate gates. No new decision is
needed for the bounded driver. Parent may proceed with the reviewed expected-red
cleartext run after its final
runtime input freeze is recorded.
