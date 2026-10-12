# M4 upstream continuation implementation plan

> For agentic workers: execute the existing reviewed plans task by task using
> `executing-plans` or `subagent-driven-development`. The coordinator assigns
> disjoint writers and independent Sol reviewers; serialize Mix/live execution.

**Goal:** complete the remaining upstream-H3 and standalone-origin rows of the
existing M4 milestone after its functional dependency blocker is resolved.

**Architecture:** retain the selected protocol-specific public Fetch adapter,
shared Session/policy and data-only standalone Generation integration from the
[reviewed design](../designs/m4-upstream-standalone.md) and
[implementation plan](m4-upstream-standalone.md). This queue orders their remaining
tasks; it adds no product scope or replacement architecture.

**Tech stack:** existing Elixir/OTP umbrella and locked Nix environment, a
compatible coordinated HTTP Fetch/QUIC cohort, independent aioquic origins and
downstream clients, and the existing Chromium/Phoenix gate.

## Starting evidence and authorization

As of 2026-10-12, the root cohort remains **0.21.3** and its lock is unchanged
(SHA256 `16542ddd554f9b78139ddf456288450a12da5781cf3900576edd7e83f159dc25`).
[UP0 review](../acceptance/evidence/m4/upstream-contract/review-up0.json)
verified **7 diagnostic rows: 5 PASS, 2 BLOCKED**. Required request trailers
depend on [gsmlg-dev/http_fetch#101](https://github.com/gsmlg-dev/http_fetch/issues/101),
currently OPEN, Feature, `internal request`, severity blocker. See the
[dependency request](../dependency-requests/http-fetch-h3-request-trailers.md).

G3's downstream H3-to-dedicated-H1 and real Phoenix/Chromium gate has **19 PASS
checks**, independently reviewed in
[review-runtime.json](../acceptance/evidence/m4/matrix/review-runtime.json).
[ST1 review](../acceptance/evidence/m4/standalone/review-st1.json)
accepts implementation source and **58 scoped tests / 0 failures**. Neither
substitutes for upstream acceptance. Coordinator execution and independent
review now accept ST2 static/H1-origin startup/streaming/reload/rollback/stop:
**11 checks** and a fresh repeat. Clean core **1/0**, H1/H2 **2/0** and H3 **2/0**
consumers passed; their [review](../acceptance/evidence/m4/matrix/review-consumers-runtime.json)
explicitly preserves the missing author peer-hash finding and genuine independent
pre/post supplement. Final affected tests passed **274/0**, exact53-file format
and strict umbrella/Phoenix H3 builds. Fresh shared/downstream gates passed
**59/19** checks; [acceptance](../acceptance/m4.md) binds the exact runs. UP1/UP2
and the standalone H3-origin row remain unimplemented/blocked.

The continuing and conditional publication authorizations in
[AGENTS.md](../../AGENTS.md) govern execution. Continue ordinary design,
implementation, diagnosis, review and local commits without routine approval
pauses. While #101 is unresolved, stop dependent adapter work and finish other
unblocked M4 work. Preserve the reviewed exclusion of `http_fetch#97`; it is
neither a prerequisite nor an equivalent native-accounting requirement here.

## Task 1 — containing upstream release and coordinated dependency update

Owner: coordinator. Files: relevant exact pins in umbrella app `mix.exs` files,
root `mix.lock`, `integration/quic_consumer/{mix.exs,mix.lock}`,
`integration/h3_consumer/mix.exs`, and `examples/phoenix_native/mix.lock` where
their selected closures consume the updated cohort.

- [ ] Verify #101's resolution and the **published compatible containing
  release**, its immutable source identity and installed public upload contract.
  Issue closure or an unreleased source change alone does not unblock execution.
- [ ] Update coordinated exact pins/locks together, retaining existing compatible
  boundaries. Inspect the lock diff and preserve unrelated entries; do not perform
  an unrelated dependency refresh or edit `deps/`. Record archive/source identities
  and root/consumer lock hashes for the selected version.
- [ ] Re-audit public Fetch/Stream/AbortController/Session behavior and fixed H3
  options against that installed release. Any necessary change to the selected
  adapter contract receives independent specification review before implementation.
- [ ] Under the exclusive Mix lease, run locked resolution and strict compilation;
  retain actual exits and nonzero scoped compatibility counts. Freeze the updated
  cohort and harness sources for the subsequent live gates.

## Task 2 — fresh complete public contract qualification (UP0)

Owners/files: independent peer implementer owns
`integration/http3/upstream/{origin.py,probe.exs,run.py,README.md}`; coordinator
owns new unique evidence under `docs/acceptance/evidence/m4/upstream-contract/`.
Follow Task 1 of the reviewed implementation plan.

- [ ] Preserve the 0.21.3 failed/blocked runs unchanged. Add the containing-release
  success contract: `finish/2` after exactly zero or three DATA bytes must produce
  the exact ordered repeated fields `[{"x-check", "one"}, {"x-check", "two"}]`
  in independent trailing HEADERS with terminal request FIN, exactly once.
  A local `:ok` alone is insufficient. Assert the successful public result,
  response protocol/body and normal public upload/task/response-stream termination.
- [ ] Qualify both declaration-free and valid declaration-bearing H3 requests.
  Preserve progressive upload/download barriers, duplicate response trailers,
  the two separately certified authorities and no retry/replay assertions.
- [ ] Execute the documented missing negative rows: wrong CA, wrong hostname,
  absent trust and unsupported `connect_address`, with no origin request for
  rejected configurations. Execute blocked-upload and downstream-owner-loss
  cancellation alongside the existing pending-header/unacknowledged-response rows.
- [ ] Establish a supported transport-appropriate lifecycle contract usable by
  the existing Service cleanup token. Record public results/DOWN and independent
  cancellation separately; do not equate an abort acknowledgment, Promise
  resolution or uncertain cleanup with completed transport cleanup. An equivalent
  public API may qualify without adopting H1's API spelling.
- [ ] Run from the worktree root:

  ```sh
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python \
    integration/http3/upstream/run.py --gate contract \
    --evidence docs/acceptance/evidence/m4/upstream-contract
  ```

  Extend the current diagnostic runner to represent the new success/negative
  cases before running it; its current seven-row BLOCKED oracle is not the new
  containing-release acceptance oracle. Require nonzero executed cases, source
  hashes unchanged, finite deadlines, child exits and UDP rebinds. Obtain
  independent source/evidence review, then fresh affected verification.

## Task 3 — explicit public upstream adapter (UP1)

Owner/files: client implementer owns the exact proxy files and tests listed in
Task 2 of [m4-upstream-standalone.md](m4-upstream-standalone.md). UP0 must pass
before production activation; retain G3's qualified framed-header compatibility.

- [ ] Write the prescribed configuration and lifecycle regressions first and
  retain their intended red results. Implement `HTTP3FetchClient` and the
  allowlisted `upstream_protocol: :http1 | :http3` selection in endpoint and
  Session using the reviewed public lifecycle contract.
- [ ] Preserve H1 defaults, HTTPS/explicit CA requirements, protocol/client
  struct revalidation, forbidden address pinning and injected modules, bounded
  upload/response deliveries, original deadlines, ordered fields and trailers.
  Reject mismatched response protocols and oversized deliveries visibly.
- [ ] Preserve H1-only groups/forwarding, authentication and destination policy.
  Add no automatic fallback, replay, pool/reuse activation, H3 forward/CONNECT,
  or private dependency owner access. Cleanup uncertainty retains reservations;
  never call `complete_cleanup` on an unqualified acknowledgment.
- [ ] Run the **complete explicit scoped UP1 test command** in Task 2 of the
  reviewed implementation plan, including existing H1, forward and group tests.
  Require nonzero tests, strict compile/exact-file formatting, independent
  specification/code review and fresh affected checks before the local commit.

## Task 4 — independent upstream matrix (UP2)

Owners/files: peer implementer extends
`integration/http3/upstream/{origin.py,fixture.exs,run.py,README.md}`; coordinator
owns `docs/acceptance/evidence/m4/upstream-matrix/`. Follow Task 3 of the reviewed
implementation plan; the current runner implements only `--gate contract`.

- [ ] Implement the planned `--gate matrix` runner and independent native H1,
  H2 and H3 downstream peers routing to real aioquic H3 origins. Interleave two
  configured authorities with distinct TLS identities; assert correct authority
  and identity on every origin request and sibling/other-listener survival.
- [ ] Execute all three downstream-to-H3 rows for the reviewed GET/HEAD, upload/
  download, 1 MiB/tiny-window, bodyless, duplicate/compressed-byte, escaped-path/
  empty-query, redirect/no-replay, ordered zero/nonzero trailers, early-final,
  downstream-cancel, upstream-reset and timeout cases. Preserve finite stalled-peer
  delivery/queue limits and eventual admission/cleanup baselines.
- [ ] Run the newly implemented gate under the Mix/live lease:

  ```sh
  nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python \
    integration/http3/upstream/run.py --gate matrix \
    --evidence docs/acceptance/evidence/m4/upstream-matrix
  ```

  Require exact nonzero case counts, independent protocol/authority/certificate
  receipts, stable source hashes and every owned child exit. Obtain independent
  evidence review and rerun affected checks after findings are resolved.

## Task 5 — standalone H3-origin JSON route

Owner/files: standalone implementer owns
`apps/gaoxy_server/lib/gaoxy/server/route_config.ex` and affected standalone tests;
peer implementer owns the standalone fixture/peer/runner. This depends on UP1.

- [ ] Allowlist reverse-proxy JSON `upstream_protocol` strings through the
  qualified `HTTP.init` path, retaining omission as H1, unknown-value rejection,
  HTTPS/CA checks and no atom creation. Until UP1 passes, keep unsupported H3-origin
  selection rejected rather than accepting a nonfunctional route.
- [ ] Add the standalone H3-origin row to the real Config.load/Supervisor fixture
  and independent origin suite. Preserve already prescribed static/H1-origin
  rows, stable-listener reload, invalid rollback, concurrent snapshot isolation,
  startup rollback, bounded stop and UDP rebind assertions.
- [ ] Run the six-file scoped standalone command from Task 4 of the reviewed
  implementation plan, followed by the standalone runner from Task 5. Record the
  H3-origin row separately and require independent review/fresh affected evidence.

## Task 6 — complete M4 verification and conditional publication

Owner: coordinator, with independent Sol specification/code/evidence review.

- [ ] Synchronize final ST2 and clean core/H1-H2/H3 consumer evidence; require
  actual executed counts, resolved/running closure isolation and owned cleanup.
  Rerun `scripts/external-consumer.sh`, `scripts/http-consumer.sh` and
  `scripts/h3-consumer.sh` against the updated cohort under the execution lease.
- [ ] Run exact authored-file formatting, `mix compile --warnings-as-errors`,
  all prescribed affected scoped suites and independent network/browser gates
  against frozen final sources. Resolve review findings and rerun affected gates.
  Update acceptance, capabilities, implementation status, dependency audit,
  standalone usage and M4 checklists with separate G0-G3/UP0-UP2/ST1-ST2 results.
- [ ] Only after **all prescribed M4 gates and independent reviews pass**, use
  the conditional authorization to integrate reviewed local commits into main,
  verify the integrated source, push and confirm the remote SHA. Create the new
  version/tag/release with exact source identity and asset manifests/checksums;
  verify the remote tag, actual published artifacts and relevant platform/runtime
  qualification. Record hosted execution separately; an unstarted hosted job is
  BLOCKED_ENV, with an authorized independently qualified local route where
  applicable, without account/settings changes or renewed quota requests.
- [ ] Publication does not establish deployment or production acceptance. Keep
  deployment, production data/certificates, Vault, public management and the
  disabled release-artifact E2E restrictions. After the authorized release proof,
  prepare the **next stage already specified by the product plan**, with its
  written design/implementation plan and independent review; do not invent a
  replacement milestone or describe the current blocked M4 as release-ready.

## Repair ledger and handoff

Preserve cumulative chains across resume, dependency updates and reviewer handoffs:

| Chain | Sol rounds / unsuccessful | Astra rounds / unsuccessful |
| --- | --- | --- |
| Connection | 3 / 2 | 1 / 0 |
| Options | 4 / 1 | 0 |
| Pure protocol | 2 / 0 | 0 |
| G0 | 2 / 1 | 0 |
| G2 Connection repair (included in Connection total) | 1 / 0 | 0 |
| G2 peer informational response | 1 / 0 | 0 |
| G2 root schema and busy-contract corrections | Coordinator-owned ledger preserved | No inferred/reset value |
| Proxy | 3 / 1 | 0 |
| UP0 diagnostic | 2 / 1 overall | 0 |
| ST1 | 0 / 0 | 0 |
| ST2 | 2 / 1 | 0 |
| G3 browser | 2 / 1 | 0 |
| G3 ownership | 1 / 0 | 0 |
| G3 read-poll | 1 / 0 | 0 |
| Historical H1 | 3 / 2 | 1 |
| Historical TLS | 4 / 2 | 2 |
| Historical model | 2 / 1 | 0 |
| Historical H2 | 1 / 0 | 0 |

These values come from existing acceptance/review receipts, including the
[G2 Connection ledger](../acceptance/evidence/m4/shared/review-connection.json),
[G2 peer ledger](../acceptance/evidence/m4/shared/peer-informational-repair.json),
[G3 runtime ledger](../acceptance/evidence/m4/matrix/review-runtime.json) and
[UP0 disposition](../acceptance/evidence/m4/upstream-contract/functional-disposition.json).
Root-owned G2 schema/busy corrections remain recorded without inventing totals.
The values are not a reset or new repair allowance. Carry subsequent coordinator-recorded ST2/consumer
or repair outcomes forward before dispatch. Architecture drafting and this queue
add zero recovery rounds. No third historical Astra recovery is authorized.
Retain failed/red evidence and unchanged assertions, preserve concurrent edits,
and report commands finished/stopped, task-owned diff, source identity and
PASS/FAIL/BLOCKED/NOT RUN separately at every handoff.
