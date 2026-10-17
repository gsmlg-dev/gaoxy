# Managed-H2 slow-peer concrete-source SPEC1

**CHANGES_REQUIRED — two actionable findings. Runtime NOT RUN.**

Source candidate SHA256 `acec0d157fba4f74aa0749cc8a2e559f48b279f5fa3050f54e18b232c9be5319`; worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, entry `deef3b0f41b55d30d83fc615998c1fad16e7b4a4`. Initial and fresh final static checks match403 source,5 owned,8 document and12 installed-dependency pins.

## SOURCE-SPEC1-01 — wrong fixed cleanup reservation (high)

`upstream_transport_slow_peer_test.exs:10,453-458` unconditionally asserts16,478,862 bytes per cleanup. `http.ex:633-639` uses that group reservation only for group mounts; fixed mounts use `ManagedH2Client.reservation_bytes` (`managed_h2_client.ex:40-41`) and `ManagedH2Reservation`'s9,444,956 (`managed_h2_reservation.ex:17,104-109`). Thus both fixed rows cannot pass their first held checkpoint; the retained lower bound is also wrong.

Select exact expected bytes by mount: fixed9,444,956/group16,478,862. Preserve exact cleanup equality and count-derived lower bounds; do not weaken assertions or change production accounting. This is static failure evidence, not an executed failing test.

## SOURCE-SPEC1-02 — status waits bypass original deadline (medium)

The accepted design line24/plan line26 requires every controller wait clipped to original remaining request time. Test `:274-280` clips system calls and receive budgets, but status observations at`:428,434-447,462,624-625,648-649` call public APIs directly. `Gaoxy.status` starts a fresh5s budget (`gaoxy.ex:94-99`), transports a fresh1s (`upstream_transports.ex:208-212`) and groups100ms (`upstream_groups.ex:388`). An unresponsive observed actor can therefore hold these new controller/sampler observations beyond the remaining request deadline.

Bound these new observations with a test-only remaining-deadline mechanism and normal owned cleanup. Preserve production APIs, original request deadlines, assertions and separate failure-cleanup headroom. No runtime overrun was executed.

## Other reviewed source and limits

The four-row loop, explicit upload/window and native pending-write witnesses, stream1/3/5 identities, same upstream connection/distinct streams, original3→2→1→0 token/pin accounting, sibling-before-release ordering, upload-only resume and five held-byte response consumes are present. Finite queue/mailbox sampling distinguishes sampled maxima from persistent retained_high_water. Opt-in client/peer paths retain default paths and strict one-byte release; future Python11/browser checks remain required. Normal/failure cleanup paths are explicit, but their execution is NOT RUN.

Extraction2 independently passes byte checks: F changes only the equivalent script path and one removed trailing blank line; fixed original test suffix and G original module remain byte-exact after require prefixes. Its SHA256 is `d775d62ec9c04ec1a8f1fbe0ed6dd03cb515b54812b4e69b95dfbacf4d265da0`. Planned4/94/Python11/browser2 counts are future expectations, not executed results.

Five tool incidents this assignment only: two truncated displays, two guessed nonexistent source paths (rg exit2), one out-of-range static line projection (IndexError/exit1). Relevant reservation/byte/source evidence was subsequently read successfully. All own commands finished; no runtime, Git, imports, protected/private access or repository mutations. Only the requested two `/tmp` reports were written.

Counters preserved: entry root538/orchestration437/slowTool17; profile source/runtime/Sol0 at entry, inherited H1Sol4/Astra2/2 exhausted. This is one failed source SPEC gate with two findings, not an implementation repair round. No Astra escalation or new user decision. Ownership returned to root.
