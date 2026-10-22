# Issue 15: peer closure during HTTP exchange creation

Date: 2026-10-22, Asia/Shanghai. The user explicitly requests internal-request
fixes directly on main and the next release. The initially clean checkout and
origin/main are `0e1f76b5a4a604cd6436f3d592ae7fb1fa36a1f0`; latest published
version is 0.12.1. GitHub MCP and live REST discovery found one eligible request,
[#15](https://github.com/gsmlg-dev/gaoxy/issues/15), with no unable-to-resolve
label or existing open fix/issue-15 PR. Direct-main execution overrides the
invoked skill's worktree/PR instructions.

## Design and acceptance

An ordinary cancelled HTTP1 upload can close its transport between parsed
request headers and socket identity lookup. Exchange.new/7 currently matches
only successful peer/local identity results, raising MatchError on a normal
transport error. Trace all constructor callers and the connection close path.
Handle the expected lookup failure without dispatching an application request,
inventing identity metadata, suppressing unrelated errors, or leaking admission.
Keep successful requests and finite/infinite request lifetime choices intact.

1. Add controlled, socket-free regression coverage and confirm the original
   constructor failure before production changes. Independently add a finite,
   synchronized real-peer protocol regression for listener/admission cleanup.
   Record which test directly proves the identity race; do not count an
   unobserved probabilistic race as deterministic proof.
2. Apply the smallest source repair, classify every new app test in the
   canonical manifest, and obtain independent specification/code review.
   Run the focused cases, exact-count ordinary gates, format/strict compilation
   and package checks. Preserve original failures and exact executed counts.
3. Release 0.12.2 as a compatible bug fix. Synchronize all seven own manifests
   and current installation examples without changing dependency pins/vendor
   provenance. Commit on main, push, verify exact-source hosted workflows,
   and dispatch guarded release.yml with the full versioned commit SHA.
4. Read back the immutable tag, stable GitHub release, eight assets/seven
   checksums and six public Hex distributions. Verify package payload/source
   identity and run the new issue regressions through a fresh Hex consumer.
   Record final evidence, close/label/comment the issue and audit the queue.

This work addresses the newly reported ordinary peer-close race. Historical
specialist blocked-upload, pressure, slow-peer and sustained-load evidence
retains its disposition. No deployment, operational data/certificates, Vault,
public-management changes or browser test gates are included. The released-server
E2E gate remains separate. Other writers' files must be preserved and only
task-owned paths staged. Parent owns manifests/version/docs/release; parallel
writers own the production/component repair and new protocol file respectively.

## Results

The repair returns identity lookup errors from `Exchange.new/7`. Its sole
production caller preserves successful exchange metadata, closes normally for
`:closed`, `:einval` and `:enotconn`, and retains an error disposition for other
reasons. Existing monitored-owner admission cleanup remains in use.

- Controlled RED: seven tests, five failures, exit 2, including the exact
  `MatchError` on `{:error, :enotconn}` for peer and local identity lookup.
  The initial BEAM stack reports version 0.12.0; both affected source files
  are byte-identical between its source `fbe59b76a68af38bce058456032f54dea5e28fd2`
  and the pre-fix HEAD. `red-source-identity.json` records this comparison.
- Controlled GREEN: the unchanged seven tests pass, exit 0. They cover expected
  closure reasons, unexpected `:eio`, finite/infinite deadlines, successful
  metadata and monitored-owner cleanup without real sockets. Because they use
  real Admission coordination, the file belongs to the component suite.
- Real TCP GREEN: two cases pass, exit 0, each observing actual peer identity
  failure `{:error, :enotconn}` before releasing the synchronous receive
  telemetry barrier. Both prove normal owner termination, no exception event
  or endpoint dispatch, restored admission, a healthy keep-alive sibling and
  a fresh healthy request. Submitted/observed body lengths were 0/0 and 3/3.
- Independent source/component review: no actionable findings. Independent
  protocol review found one fixture assumption about TCP coalescing; the
  corrected test accepts a valid received body prefix and records its length.
  Review of that correction, version metadata, notes and inventory found no
  remaining findings. No production repair failure or Astra recovery occurred.
- Fresh canonical ordinary gate: **466 executed, zero failures, excluded or
  skipped**, exit 0. The manifest has unit 198, component 144 and protocol 124,
  with 85 active and 149 unchanged retained test paths. Package staging:
  **12 tests, all pass**, exit 0. Whole-source formatting, strict test
  compilation, inventory and diff whitespace checks pass, exit 0.

Commands use `ELIXIR_ERL_OPTIONS='+S 2:2'`, `MIX_ENV=test` and the existing
`.audit/h2peer/bin/python` interpreter for pinned h2/aioquic peers. The full
ordinary command is `python3 scripts/check-repairs.py all`; focused runs use
`scripts/check-tests.py` with seed 20261022 and `--max-cases 1`. Exact commands,
durations, environment and source fingerprints are retained in
`../acceptance/evidence/peer-close-0.12.2/local-verification.json`. Raw logs
and the original RED are preserved there as byte-preserving gzip copies.
These local runs used the uncommitted repair/version tree based at the initial
HEAD; the later publication receipt records its exact commit identity.

Hosted qualification, publication and public-consumer execution are **NOT RUN**
at this source checkpoint. The final record belongs in
`docs/acceptance/release-0.12.2.md` after completion. Historical specialist
evidence and unrelated unscheduled test results are unchanged.

Final closeout: **PASS** on publication source
`55ed97d2b05ba2a8dd7c911472833e71dd6b87f7`. All ten required hosted jobs and
guarded release run 39803249750 completed successfully. Stable v0.12.2, all
eight assets/seven checksums, six public Hex distributions and 135 packaged
source files verified. A fresh Hex-only consumer passed all nine issue cases,
including two actual `:enotconn` TCP races. The initial artifact transfer's
180-second timeout remains **FAIL**; its resumed download and subsequent full
verification are separately **PASS**, with unchanged validation assertions.
Issue #15 is labeled fixed and closed; final MCP and paginated REST queries
both found zero open internal requests. See
[release acceptance](../acceptance/release-0.12.2.md) for commands, evidence,
review and scope. The earlier NOT RUN statement records the source checkpoint.
