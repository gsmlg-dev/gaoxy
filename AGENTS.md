# Gaoxy agent instructions

Gaoxy is an Elixir/OTP server runtime: native HTTP/1.1, HTTP/2 and HTTP/3, a Plug
and Phoenix adapter, reverse/forward proxying and a standalone JSON-configured
release. This file holds the rules that are in force now. Earlier time-boxed
authorizations and stage dispositions are archived in
[docs/history/agents-instructions-2026-10.md](docs/history/agents-instructions-2026-10.md)
and grant nothing.

## Layout

| Path | Contents |
| --- | --- |
| `apps/gaoxy` | Core: service lifecycle, admission gate, adaptive resource budget, TCP/TLS/UDP/QUIC bridges |
| `apps/gaoxy_http` | Native H1/H2, WebSocket, Plug and Phoenix adapters, listener sets, routing generations |
| `apps/gaoxy_http3` | Optional native H3 over QUIC |
| `apps/gaoxy_proxy` | HTTP/WebSocket/stream/UDP proxying, forward proxy policy, upstream groups and transports, gateway |
| `apps/gaoxy_server` | Standalone application and JSON config; ships in the release, not on Hex |
| `apps/gaoxy_test` | Test-only HTTP fixtures published for consumers |
| `vendor/websock_adapter` | Gaoxy distribution of WebSockAdapter, published as `gaoxy_websock_adapter` |
| `integration/`, `examples/` | Independent consumers, protocol peers and sample applications |
| `docs/` | Guides, ADRs, designs, plans and release notes |
| `suggest.md` | Review backlog from 2026-11-13; check an item against current code before acting on it |

Dependency direction is `gaoxy` ← `gaoxy_http` ← `gaoxy_http3` / `gaoxy_proxy` ←
`gaoxy_server`. Core-only consumers must keep compiling without the HTTP apps.

## Commands

Toolchain: Elixir 1.18.5, OTP 28.5, Rust stable, Python 3.12. CI sets
`ELIXIR_ERL_OPTIONS='+S 2:2'`.

```sh
mix deps.get --check-locked
mix format --check-formatted
mix compile --warnings-as-errors
python3 scripts/check-test-inventory.py     # every app test file is classified
python3 scripts/check-repairs.py unit       # no sockets, exact case counts
python3 scripts/check-repairs.py component  # real component integration
python3 scripts/check-repairs.py protocol   # real network and protocol peers
python3 scripts/check-tests.py <test file>  # one file, as the gates run it
```

The gate scripts set `GAOXY_QUIC_PYTHON` to `.audit/h2peer/bin/python`. Export it
when running a QUIC or HTTP/3 network test file directly, or the test fails for
lack of its Python peer rather than for a product reason.

`_build` and `deps` are shared: run one build or test command at a time, including
across parallel agents.

## Working rules

- Work on the current checkout and branch. Create a branch or worktree only when
  the user asks for one; then put worktrees under `.trees/` on a `codex/` branch.
- Make the smallest correct change in the existing style. No unrelated cleanup, no
  speculative features. Preserve unrelated changes and untracked user files, and
  stage only files the task owns.
- Commits follow Conventional Commits, without generated-by or AI co-author trailers.
- Give parallel agents disjoint files and explicit ownership. The coordinating
  agent reviews and verifies the combined result.
- Ordinary test or implementation failures go to diagnosis and repair, not to a
  request for approval. Stop only for a new external permission, a product
  decision, or an external blocker; keep working on whatever is not blocked.

## Design rules

- Configuration and policy live in pure modules. Add a process only for mutable
  runtime state, concurrency or fault isolation.
- Gaoxy owns server lifecycle and adapters. Use supported dependency APIs; do not
  patch `deps/`, depend on private client processes, or hide Bandit as the
  production server.
- Do not ship an open proxy. Forward and CONNECT policies require explicit
  authentication and destination rules, validated at connection time against the
  address that is actually dialled.
- Never build atoms from external input. Bound every buffer, queue and table that
  a peer can grow, and count work the server does on a peer's behalf (resets,
  rejections) against the same limits as work the peer sends.
- Failing closed is the default under uncertainty, and every such state needs a
  way out: emit telemetry with the reason when entering it, and give it a bounded
  retry or a documented operator action. A state that needs a reload or restart to
  clear is a defect unless the docs say so.
- A timed-out `GenServer.call` means the outcome is unknown, not that the callee
  is gone. Reconcile by token or retry; do not tear down a connection, listener or
  transport because one accounting call was slow.
- Prefer events to timers. Do not add millisecond polling where a monitor, an
  active socket or a message already signals the change.
- The admission gate, the budget Authority and Ledger, `Generation.Store` and the
  upstream owners are each one process. Keep per-chunk and per-frame paths off
  them: account on transitions, keep counters incrementally, index instead of
  scanning.
- Do not validate another module's private state shape at runtime, and do not put
  test fixtures or qualification worksheets under `lib/`.
- Keep one definition of protocol and security tables (header grammar, hop-by-hop
  and forbidden-trailer lists, reserved address ranges); reuse it, do not copy it.

## Tests

- `test.yml` runs one Linux unit job. Unit tests use mocks or controlled doubles
  and must not open listeners or sockets, call even localhost services, launch
  protocol peers or start a complete multi-component runtime.
- `e2e.yml` owns component integration, real network and protocol tests and
  independent HTTP-client acceptance. `portable.yml` alone owns cross-platform
  execution: one native HTTP start, `GET /health` returning 200 and `ok`, and a
  clean stop. `package.yml` owns package staging, clean consumers, dependency
  isolation and the source-built release smoke.
- No browser automation, Playwright, Chromium, UI assertions or screenshots in
  server test gates. Use HTTP clients and protocol peers.
- `scripts/check-repairs.py` is the manifest of scheduled files and their exact
  case counts. Classify every new app test file there as `unit`, `component` or
  `protocol`, or list it in `scripts/test-inventory.json` with a reason. Tests that
  guard a security rule belong in a scheduled suite.
- Reproduce a bug with a failing test before fixing it where feasible. Never weaken
  an assertion, skip a required case, or report a failed, blocked or unexecuted
  check as passing. Require a nonzero executed count.
- Assert behaviour through public APIs and `status/1`-style observation, not
  `:sys.get_state` or exact internal byte constants. Use deterministic
  synchronization, not sleeps, for lifecycle races, with finite deadlines.
- Specialist slow-peer, pressure, disconnect and sustained-load qualification is
  deferred to a dedicated environment and does not block ordinary work. Its
  recorded failed and unexecuted results keep their status.

## Verification and evidence

- Run the scoped tests and the gates a change touches, then review the final diff.
  Get an independent review for protocol, accounting or security changes before
  they are released.
- Report commands, source commit, counts and exit status, keeping PASS, FAIL,
  BLOCKED and NOT RUN distinct. Hosted CI, local runs, publication and production
  acceptance are separate facts; do not infer one from another.
- `docs/acceptance/` is local and untracked. Do not commit logs, source snapshots
  or key material as evidence; summarize results in the commit, pull request or
  release notes.

## Dependencies

The transport and client stack (`hell`, `abyss`, `http_core`, `http_fetch`,
`http_web_socket`, `elixir_quic*`, `ex_ssl`) is developed in the
`gsmlg-dev/http_fetch` monorepo and released as one version cohort. For a bug or
missing feature in a dependency from gsmlgorg, gsmlg-dev, duskmoon-dev, gsmlg-app,
Gao-OS, gsmlg-opt, gsmlg-ci, gsmlg-games or gsmlg-com:

1. Resolve the source repository from package metadata, and search its open and
   closed issues first.
2. Create the issue with `gh issue create --type Bug` or `--type Feature`, label
   `internal request`, title `[internal] <concise description>`. Include the
   requesting repository and branch, the need, a minimal reproduction or expected
   behaviour, and severity `blocker`, `needed` or `nice-to-have`.
3. Add `# TODO(upstream): org/repo#<number>` at the affected callsite.
4. For a blocker, stop that task without a local workaround and resume only after
   the fix is released and the dependency updated. For lesser severities, mark any
   temporary repair `# WORKAROUND(upstream): org/repo#<number>` with its removal
   condition.

Do not re-raise `gsmlg-dev/http_fetch#97`; the user reviewed and dismissed it.

## Release

Fixes that land on `main` are released; do not stop at "fixed but unreleased".

1. Bump the patch version in every `mix.exs` and the README. The user decides
   minor and breaking bumps.
2. Add `docs/releases/<version>.md`.
3. Push, and wait for green CI on that commit.
4. Run `gh workflow run release.yml -f version=<version> -f expected_sha=<full sha> -f git_ref=main`.
5. Confirm the GitHub release and the Hex packages.

If a hosted job cannot start, record it as NOT RUN; do not change account or
repository settings or request spending or quota increases.

These always need separate, explicit authorization: deployment, production data,
operational certificates, a public management endpoint, changes to frozen Vault
material, and enabling the released-artifact E2E workflow before its harness is
qualified.
