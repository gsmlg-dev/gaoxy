# Native H1 pressure source SPEC1

Verdict: PASS. Status: DONE (read-only source specification review). No actionable findings. All runtime remains NOT RUN.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Parent-supplied actual predecessor: `fb7d0fda2b7c16c42c65579736dc1f643e17d812`; no Git operation performed.
Frozen source candidate SHA256: `36f381a4d01a751806eb48d8aa5d378426705608d62a6b35ed29e9261c7f10bc`.

All frozen hashes match:404source,2owned,11documents,12installed dependencies,41evidence. Unique manifest union:467. Rechecked at report construction. Fixture delta18 additions/1 removal;402 original sources unchanged; new test1240 lines; exactly1 fixed/TCP/native-H1 test, no selectors, expected first run1/0/excluded0.

## Source requirement assessment

- **S1 scope and default fixture compatibility: PASS.** `test:1-104; fixture:13-23,139-147,211-215`. Exactly one fixed/TCP upstream/native cleartext H1 test, two raw downstream sockets, no only/skip/tag selectors. Default start/1 behavior preserved by empty start/2 overrides; original command/2 unchanged. Diff18 additions/1 removal;402 original source files unchanged, only fixture changed and new1240-line test added.
- **S2 real native socket witness and original identity: PASS.** `test:20-64,114-145,548-629`. ObservedEndpoint captures actual native owner/socket/gate/lease/deadline before delegation and sets only slow socket sndbuf1024. Socket backlog>0, exact lease owner, same pending16384-byte Admission operation and bounded MFA-only native TCP send stack are required together; no sys native-owner state query.
- **S3 persistence through healthy overlap: PASS.** `test:150-173,486-535,548-568`. Pressure snapshots before sibling, at two-original overlap, after healthy cleanup, immediately before release all bind identical operation O; prior completion event is rejected. Healthy client, native owner and upstream connection differ; healthy exact one-byte body and original normal cleanup finish while slow O stays pending.
- **S4 actual reader release and telemetry outcome: PASS.** `test:172-189,288-340,921-940`. Unique release ref is received by the slow client; event-generation release/read-entry timestamps precede its first body recv. Existing scoped Admission send telemetry must report actual outcome ok for the same O at/after read entry with bytes16384; delayed controller receipt and clearing the slot cannot substitute.
- **S5 producer EOF hold is separate from pressure: PASS.** `test:130-145,184-202,975-1009`. Prefix is262144 deterministic bytes with valid complete upstream chunk framing. Last zero byte and upstream zero terminator remain absent until O completion, exact prefix/hash consumption and still-pending slow-original checkpoint. Final body262145 and exact SHA256/chunk termination are mandatory.
- **S6 original identity and two-to-one-to-zero conservation: PASS.** `test:150-166,200-201,412-546`. Capture native owner/guardian/public original completion/transport token/Session token/pins. Each guardian owner and original RequestCompletion match captured authority; live token set and exact pin union are checked. Overlap2, healthy_joined1, all_originals_joined0; public completion must remain pending while owned and become ok before guardian normal join. No private dependency process inspection.
- **S7 exact original reservation and native bounds: PASS.** `test:433-466,486-535,714-748; HTTPFetchClient:29-36; Exchange:333-376`. Actual forwarded-header ETF and URL bytes feed unchanged HTTPFetch reservation formula7749672+2*ETF+2*URL. Each original<=8011816 and matching exact cleanup charge. Native<=149504 includes one pending16384 write; combined2*8011816+2*149504=16322640<16777216. Service max_active64 and capacity16MiB remain unchanged.
- **S8 independent transport and Service ledgers: PASS.** `test:105-127,486-535,646-653,714-789`. Transport limits exact2 resources/32 pins/64 tokens/4194304 payload, reserved_connections2, exact live request-token identity and baseline/request-pin union. Sampled/native/cleanup/payload/mailbox limits remain separate; sampled Service bytes and persistent high-water both bounded; no total VM/kernel-memory claim.
- **S9 finite sampler and event retention: PASS.** `test:318-328,670-829`. Sampler starts before finite response prefix, uses5ms turns with <4096 turn bound, phase barriers and normal stop/join. Bounds include native pending write<=16384, socket send_pend<=1MiB, actor mailbox<=64, retained telemetry<=128. Only one sampler and sequential monitored observers per caller; helper protocols retain finite owned results.
- **S10 finite raw consumer and parser: PASS.** `test:831-1055`. Both raw sockets use passive TCP with actual recbuf/buffer in1..16384. Slow consumes head only until unique release. Head<=8192, chunk-size line<=1024, chunk<=65536, body<=262145, wire<=1MiB, exact CRLF/chunk0 ending/no trailers. All socket recv waits use original captured deadlines; clients explicitly close and join normally.
- **S11 deadline preservation and observer joins: PASS.** `test:342-361,792-829,1068-1168; Exchange:350-361`. Captured native request10s and native write2s unchanged; phase deadlines=min(original remaining,5s barrier, active O send-start+2s). Every sys/status/socket/public stack observation runs unlinked monitored helper; returned value plus exact normal DOWN must both precede phase expiry. Timeout/forced observer cleanup remains failure. Endpoint defaults opening5s/idle60s/write5s/max_lifetime30s are asserted, not extended.
- **S12 complete normal cleanup before receipt: PASS.** `test:196-286,536-546,1039-1055; fixture:374-417`. After public completion+guardian joins: close/join both clients and native owners with expected peer_closed shutdown; Service active/retained/cleanup0/no cleanup failure; release exact baseline pin, retire resource with original deadline, verify resource/pin/token/helper/reservation0; fixture peer accepted2/forced0/live0 plus owner/instance normal joins and listener rebind. Success receipt emitted only after all assertions.
- **S13 failure cleanup remains failure: PASS.** `test:92-102,1117-1134,1170-1234`. Failures retain original exception and cleanup_failures; separate bounded5s cleanup may kill only owned observers/clients/sampler. It cannot convert deadline expiry or forced cleanup into successful receipt. Telemetry handler and observer table removed on exit.
- **S14 progression and claim boundaries: PASS.** `test:66-68; source-candidate1:initial_case_count/excluded/limits; design-spec2:readiness`. Expected initial source1/0/excluded0 only. Other fixed/group TCP/TLS cases remain unimplemented; expansion needs real witness PASS, independent receipt review and fresh sourceSPEC-to-CODE. This review neither runs nor qualifies socket pressure, browser, full matrix, Task6/Task5/M3, publication or deployment.

## Frozen owned source pins

- `c1073325d4b816175462a4524d106a52ddae93a25429532608dc63e51460ffb0` `apps/gaoxy_proxy/test/support/managed_h1_matrix_fixture.exs`
- `68476956a03e3b2b219bb2ecc5ab60fadc4e27f96898f020b0ef9b95c7704ec1` `apps/gaoxy_proxy/test/upstream_transport_native_h1_pressure_test.exs`

## Validation and boundaries

Read-only manifest/delta/selector/worksheet checks completed with exit0. Compile, strict format check, actual socket pressure, other3 cases, full matrix and browser are NOT RUN by this reviewer. Root format preparation is frozen evidence only. No dependency defect or upstream issue established.

This report adds0 tooling incidents and0 implementation/runtime repair rounds. Previous author/preflight/future-preparation incidents are not recounted. Inherited H2 sourceSol1/H1Sol4/Astra2/2 exhausted remain unchanged.

## Remaining risks

- Real native socket-pressure feasibility is unexecuted: OS buffer readback, positive send_pend, installed OTP stack witness, healthy progress and same-operation outcome must all pass the actual initial1 run.
- Read-entry is the client event immediately before first recv; success still requires actual matching telemetry outcome, exact prefix progress and unchanged producer EOF hold. No source inspection substitutes for these runtime observations.
- SourceSPEC PASS is not independent CODE review, compile/format PASS, runtime PASS or whole-task completion. Root must preserve strict gates and diagnose actual failures without weakened assertions.

Concrete sourceSPEC1 PASS. Return exact frozen candidate for independent CODE review and root-owned strict compile/format gates before first actual fixed/TCP1. No routine user approval or future sole-disconnect implementation is requested.

Return repository/docs/evidence/runtime/Git custody to /root. Reviewer changed only requested /tmp source-spec1 JSON/Markdown reports.

All reviewer commands finished; no repository edit or runtime process was started.
