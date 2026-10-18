MATRIX COMPAT DIAGNOSIS1 — DONE / CAUSE UNPROVEN

Read-only diagnosis of the two matrix failures in frozen candidate8, worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, candidate entry head `fb7d0fda2b7c16c42c65579736dc1f643e17d812`. No source changes or new runtime.

Proven: diagnostic-fresh3 is actual FAIL52/3, exit2, source stable, collector nonforced/joined with no remaining process group. Both fixed/h1/tls and group/h1/tls temporal/trailers failures report connection2 response release deadline during fixture.stop → event → next_event. Pressure failure3 is separate and was not diagnosed here. Prior same-seed166590 diagnostic-fresh2 was PASS52/0; the five relevant files match candidate8 and both runs' source-before/after pins.

The fixture emits this failure only when respond/5 waits 5000ms without its matching send command. An application request has reached upload_end before respond; health requests bypass it. Worker rescue reports only connection and error, omitting request ordinal/method/route. Unmatched nonfailure peer events are queued by event/next_event, so the extra request can remain unselected until stop. Python reaches host.stop after both intended temporal/trailer responses, client joins, cleanup and accepted connection/TLS identity checks. Its accepted==1 assertion follows stop and is not reached on this failure. Listener-close join then encounters worker failure; run_case preserves the original failure while reporting forced-driver cleanup and peer noproc. These fixture warnings do not mean the outer collector was forced.

Unknown: what request connection2 carried, where it originated, and why its response command was absent. The current evidence does not establish a dependency defect, runtime/environment cause, retry mechanism or production root cause. No functional repair is justified yet.

Smallest useful next step: diagnostic-only attribution. Retain the original error and add bounded connection/request/method plus allowlisted fixed-route identity to response-release failures; capture sanitized queued request/upload_end/command phase summaries at stop failure. Preserve all assertions, accepted==1, the 5000ms release deadline, outer finite deadlines and cleanup-failure semantics. Avoid payload/raw-message/full-state dumps. Root can then run a scoped reproduction and distinguish extra/replayed work from command routing/stop sequencing. Do not increase timeouts or implement a dependency workaround on this evidence.

Strict relevant source pins (all PASS):

- `apps/gaoxy_proxy/test/support/managed_h1_matrix_fixture.exs`: `c1073325d4b816175462a4524d106a52ddae93a25429532608dc63e51460ffb0`

- `apps/gaoxy_proxy/test/upstream_transport_h1_matrix_test.exs`: `5b8a4c17cdd1b3f6ad5fc1c4e2a1b4907989f647fd20279174308397b3806b62`

- `integration/upstream_transport/run.py`: `ca5ba4136a67eee50d25aeb5fee4cdaf8494e682989e778e91e059997feda7ca`

- `integration/upstream_transport/fixture.exs`: `7f1ee353535d95b3c55830b216b6aff1089914fdf85810bdf41895f8174cacf0`

- `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py`: `d4429aa3fe49b9faca2c05bef631ef97cf6ca4f6fe69d350dea71bd147a367f0`

Evidence SHA256: diagnostic-fresh3 JSON `3d483a824505d68570efbacb4037d0460eb8ea06d083254686b5f67a672c5651`; log `998f7aee37999a3a6032324f1b38ed4eb06638d21c8ac458e32997a2a3d648d0`; diagnostic-fresh2 JSON `061d7fbd106f7c235459f8221c5f84bdd475579da0d8bef41b9fb70449608fb1`. Candidate8 SHA `90e1374f8686e7dd50682de959d2c774927c1ebc76b40dccb08b4623fa11371d`. No broad source pin revalidation.

Counter32 SHA `94eb4508761803db0917f5aff54ad812860d919c5de69ae4f98198f9d97d4fe4`: runtimefailed5 / Sol4 / Astra2of2 exhausted retained. Added tests/repair rounds: 0. New tooling incidents: 3 — initial log-context output crossed into adjacent pressure diagnostics; one broad search output was truncated; one read-only rg used a nonexistent production path and exited2. Subsequent reads were narrowed. No protected prompts/keys/private raw traces or managed-H2 close diagnostics were accessed.

Only these two /tmp reports were written. No repository edits, runtime, tests, compiler/formatter/browser/Git or agents. All commands finished synchronously; no background processes started. Existing failures remain unresolved. Parent owns further diagnostic assignment and verification. Custody returned at DONE; reports are immutable, and clarification requires a new path/version.

Concrete diagnostic contract before custody handoff: respond/5 receive-after (line869) keeps RuntimeError, original response release deadline prefix and 5000ms path. Use only existing base connection/request ordinals; method labels POST/DELETE/other and route labels temporal/trailers/other. At next_event/4 failure (or stop/2 rescue), summarize the fixture-owned queued events on failure only: at most16 summaries plus total count/truncated flag; whitelist accepted/request/upload_prefix/upload_end/command, counting other events without contents. Allowed summary fields: event, connection, request, method/route labels, action label send/continue_upload/other and ended when present. Never include headers/body64/raw target/payload/raw messages. No new success-path queries/messages/drains/helpers. This recommendation has not been implemented or runtime-validated.
