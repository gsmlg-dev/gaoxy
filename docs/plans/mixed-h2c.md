# Mixed cleartext HTTP implementation plan

> Execute independent tasks with explicit file ownership, then review the
> integrated specification and code before release. Continue without routine
> approval pauses under the user's standing authorization.

**Goal:** Serve native H1 and prior-knowledge H2 on a single cleartext listener.

**Architecture:** Pure bounded classifier plus a detecting phase in the native
connection handler. Reuse engines, the owner lease and first-input deadlines.

**Tech stack:** Elixir/OTP, Hell active-once sockets, HPAX, ExUnit and Python h2.

## 1. Configuration and documentation (independent owner)

- [x] Add positive mixed-mode and preserved-invalid tests in HTTP defaults,
  standalone configuration and Phoenix adapter tests; observe baseline rejection.
- [x] Extend only the explicit prior-knowledge combination in `http.ex` and
  `http/options.ex`; change standalone conversion only if needed.
- [x] Document embedded/standalone/Phoenix examples, defaults, fixed detection
  deadlines and the distinction from Upgrade.
- [x] Run the focused configuration/adapter tests and inspect the diff.

## 2. Detector and engine initialization (one coupled owner)

- [x] Add classifier tests for empty input, complete preface, each split,
  single-byte deliveries, mismatches and copied carry bounded to 23 bytes.
- [x] Implement `Gaoxy.HTTP.ProtocolDetector` and its bounded pure feed API.
- [x] Add focused lifecycle tests before implementing detecting state, first
  input, timers and selected-engine initialization in `connection.ex` and
  `http2/connection.ex`; modify admission only if necessary.
- [x] Reuse one owner lease; grow H2 reservations before resources, retain
  drain identity, preserve request admission and safe initialization failures.
- [x] Preserve exact bytes and fixed first-engine budgets, explicitly consume
  stale detector tokens before delegation, and check limits before copies.
- [x] Run classifier/lifecycle tests plus affected H1/H2 regressions.

## 3. Real network and integration verification (parent owner)

- [x] Add live same-port explicit H1 and Python h2 tests with both sockets open,
  asserting protocol, response, endpoint identity and exact-once bodies.
- [x] Cover deciding-delivery H1 body/pipeline and H2 coalesced bytes, fragmented
  prefaces, no H2 output while undecided, fixed deadlines and failure cleanup.
- [x] Verify standalone routing and Phoenix HTTP reach one native listener.
- [x] Run exact-count ordinary CI gates and focused compatibility tests; record
  command, source identity, environment, count, exit and outcome in acceptance.

## 4. Review, integration and publication (serialized)

- [x] Obtain independent specification review, repair findings and rerun tests.
- [x] Obtain independent code-quality review and fresh final verification.
- [x] Inspect current version/tag/release policy, coordinate own package/example
  versions, run format/build/package/portable smoke gates and update current docs.
- [ ] Commit only task-owned files with conventional messages, integrate main,
  push and verify remote SHA. Preserve untracked `prompt.md`.
- [ ] Run established release workflow (or independently qualified local
  portable process when hosted execution cannot start); verify tag, checksums,
  downloaded artifacts and release links. Record hosted/deployment limitations.
