# M3 managed H1 fixed-endpoint acceptance

Status: **DONE — local managed H1 fixed endpoints accepted**. Independent SPEC
then CODE review passes with no unresolved findings. Fresh post-review checks
pass: **178 tests / 0 failures**, zero skips/exclusions, exit 0, canonical
`--check-formatted` and strict compile, all with stable source. The test count is
28 real endpoint/lifecycle cases, 12 identity cases, 77 foundation regressions
and 61 dedicated/group compatibility cases. Successful TCP/verified-TLS requests
prove reuse, wire fidelity, public cleanup, EOF and actor joins; rejected TLS
setup proves strict cleanup uncertainty and retained accounting, without claiming
cleanup success. Read the [local acceptance receipt](evidence/m3/managed-h1-fixed-endpoint/1791891933896/fixed-local-acceptance-summary.json).

Local implementation commit: `2bf0883cea1dce1a031016700bb012fb3faac8b5`; [commit receipt](evidence/m3/managed-h1-fixed-endpoint/1791891933896/fixed-local-commit.json).

Execution checkout: `.trees/m3-h1-resource-foundation`, branch
`codex/m3-h1-resource-foundation`. The [kickoff receipt](evidence/m3/managed-h1-fixed-endpoint/1791891933896/kickoff.json)
records the clean baseline/tree, source and cohort hashes, scope and writers.
Read the [design](../designs/m3-managed-h1-fixed-endpoint.md) and
[plan](../plans/m3-managed-h1-fixed-endpoint.md).

| Gate | Actual evidence | Status |
| --- | --- | --- |
| Full Foundation prerequisite | Independent SPEC/CODE/closure, fresh 77/0 proxy and complete 8/0 TCP/TLS, source-equivalent 36/0 core and 1/0 consumer, format/strict compile | PASS |
| Written fixed-endpoint design and readiness | Independent SPEC review before executable edits | PASS |
| Read-only owner identity compatibility | 12/12 expected RED; first GREEN 89/11 preserved; repaired 89/0, exit 0, independent SPEC then CODE PASS | PASS; fresh178/0 |
| Pure endpoint config/resources/outer holds | Expected RED preserved; repair 2 full affected suite177/0, exit0 | PASS |
| Activated Session guardian pins/checkout/original binding/cleanup | Real lifecycle/original-completion cases in177/0; native-before-headers case resolved | PASS; native-before-headers case added |
| Real TCP and verified-TLS fixed-endpoint matrix | Initial114/16 and repair1 177/2 preserved; repair2 177/0 with exact uncertainty and successful cleanup | PASS |
| Dedicated runtime/wire/TLS/completion compatibility | Separate61/0 and combined177/0, exit0 | PASS |
| Final independent SPEC then CODE/fresh verification | SPEC finding resolved; SPEC then CODE PASS; fresh178/0, formatcheck and strict compile, stable source | PASS |

Identity and endpoint workers have disjoint source/test ownership; the parent
serializes all Mix/build/format/live commands and commits. New identity tests are
separated from the real endpoint file only for ownership; all planned assertions
remain required. Dedicated default, groups, probes, Generation, upstream H2/H3
and standalone capability/config paths retain their existing behavior.

Inherited unsuccessful UP2 counts are **20 live / 8 production / 3 harness**,
Foundation Step7 unsuccessful attempts **5**, Astra recovery **2/2 exhausted**.
New fixed-endpoint unsuccessful implementation attempts are **3** (identity
initial 1, endpoint initial 1, endpoint repair 1) without resetting
inherited counters. Record actual RED/GREEN/counts/exits and source identities;
expected TDD RED is not acceptance or an unsuccessful repair. No third Astra
round, private dependency inspection, assertion weakening or skipped validation.

No push/release/deployment, production data/certificates, Vault/public management
or disabled release-artifact E2E is authorized by this kickoff. Local TLS fixture
certificates are test inputs. Hosted CI/publication/production acceptance remain
separate and are NOT RUN for this slice. `http_fetch#97` stays excluded; optional
fixed H1 ALPN Feature #107 is no prerequisite. Managed H1 preserves no ALPN
advertisement and the existing exact peer None/null profile.

## Historical public TLS diagnosis and review checkpoints

The [focused public diagnostic](evidence/m3/managed-h1-fixed-endpoint/1791891933896/fixed-tls-negative-public-diagnostic-1791895249738512569.json)
executed **2/2 failures**, exit 2, with 25 location exclusions and stable source;
the initial successful-cleanup oracle remains in that immutable run. Both cases
reject the handshake, return 502 and show no second connection. Repeated original
completion and scope retirement awaits report `cleanup_unconfirmed`; the public
snapshot reports a retired scope. The ledger retains one resource, one baseline
pin, one token and two physical reservations, with zero live helpers. This
matches the installed public documentation. The proposed strict failure contract
requires those exact holds, failed global stop/retirement, missing Service
receipt, real peer/helper joins and explicit failed-actor test teardown. It does
not turn cleanup uncertainty into success. At that checkpoint independent amendment review and
fresh unfiltered tests were pending; both subsequently passed as recorded below. Group compatibility focused GREEN is **2/0**,
exit 0, with 25 excluded cases; it is not full package acceptance.

Endpoint repair 1 full combined verification executed **177/2**, exit 2, with
zero skips/exclusions and stable source. Both failures are the exact post-global
retirement ledger assertion; all preceding strict public failure/stop and
pre-retirement accounting assertions passed. The [failure assessment](evidence/m3/managed-h1-fixed-endpoint/1791891933896/endpoint-repair1-failure-assessment.json)
records the diagnosis at that failed checkpoint. The first additional diagnostic did not execute
tests because of a helper syntax error (exit 1); its immutable receipt and
assessment record **one diagnostic harness failure**, separately from the three
unsuccessful implementation attempts. No runtime result is inferred from that
zero-test run. Dedicated compatibility separately passed **61/0**, exit 0.

The repaired post-global diagnostic executed **2/2 failures**, exit 2, and
[confirmed a Gaoxy lifecycle defect](evidence/m3/managed-h1-fixed-endpoint/1791891933896/post-global-ledger-root-cause.json):
the authenticated abort retry overwrites `:failed` with `:retiring` after both
helpers join. The custodian remains failed and no public cleanup confirmation
exists. Preserve the exact failed-resource assertion and fix this local state
transition; implementation acceptance was pending at that checkpoint.

Repair 2 strict compile and canonical format pass. The [complete affected GREEN](evidence/m3/managed-h1-fixed-endpoint/1791891933896/fixed-endpoint-repair2-full-green-1791896402425548257.json)
executed **177/0**, exit 0, no skips/exclusions and stable source. Independent
[SPEC review 1](evidence/m3/managed-h1-fixed-endpoint/1791891933896/fixed-final-spec-review1.json)
requires the additional native-owner death case before response headers; existing
cases cover after headers and transport-owner bind death. Preserve those cases
and add the missing real-peer/public-cleanup/actor-join assertions. CODE review
had not started at that checkpoint; final SPEC and CODE later passed. SPEC rejections are **1**, separate from the implementation and
diagnostic failure counters.

## Historical kickoff and initial verification

The local H1 resource foundation
is accepted at `5b73f5a951d506f194d090a0083183a79d577d6e`; its completion does
not accept this production endpoint/Session/adapter slice. Written design/plan
and independent readiness review pass before edits. Identity tests executed **12/12 expected failures**, exit 2, for the missing
read-only API with stable source. The first identity GREEN executed 89 tests
with 11 failures, exit 2; the original 77 regressions passed. The
[failure assessment](evidence/m3/managed-h1-fixed-endpoint/1791891933896/identity-green1-failure-assessment.json)
records strict-authority and fixture-starter diagnosis without weakening
assertions. Endpoint RED executed 22/22 failures for the missing managed config
entry, source stable, with no unexpected harness failure. Expanded endpoint RED
executed 25/25 failures with stable source, including uncertainty/binding/stale
cases. Identity repair 1 passed **89/0, exit 0**, then independent
[SPEC and CODE review](evidence/m3/managed-h1-fixed-endpoint/1791891933896/identity-independent-review.json)
passed with no actionable findings. Strict compile passed. First full GREEN
executed **114/16, exit 2**, source stable; its
[failure assessment](evidence/m3/managed-h1-fixed-endpoint/1791891933896/endpoint-green1-failure-assessment.json)
retains all failures. Twelve ordinary completed-request accounting checks ran while
downstream connection leases were still live; fixture repair closes downstream
before retaining the full zero-accounting assertions, with upstream reuse still
observed on the same peer socket. The two negative TLS cases additionally report public cleanup unconfirmed and
require separate diagnosis; closing downstream cannot establish public cleanup.
The uncertain token's baseline pin remains
until global stop and must be checked in its actual phase. Bind failure needs
a deterministic Service drain barrier to preserve the missing-receipt stop
oracle. Necessary group compatibility rejection prevents an unsupported member
handle from being erased into a dedicated request. Endpoint acceptance and
full-slice implementation review remain NOT RUN.


## Final local closure

The missing before-headers case passed in the complete178/0 run. Final independent
[SPEC then CODE review](evidence/m3/managed-h1-fixed-endpoint/1791891933896/fixed-final-spec-code-review2.json)
passes, followed by fresh formatcheck, strict compile and all178 affected tests.
Their exact commands, source/log hashes, counts and exits are in the local
acceptance receipt. Historical FAIL and zero-test diagnostic receipts remain
unchanged. Only this fixed-endpoint slice is accepted; managed groups/probes and
Generation proceed as separate stages under continuing authorization. Local
commit follows document closure; hosted/publication/deployment/production and
disabled release-artifact E2E remain NOT RUN.
