# Thousand Island to Hell migration

## Design and scope

Replace the TCP/TLS host dependency with `gsmlg-dev/hell`, pinned to
`59eed42b019ca41413d1b8cd7a7dc3e344bb93ee` (Hell 0.1.2). Use the public `Hell`
API directly for listener lifecycle, handlers, sockets and transports. Preserve
Gaoxy's existing ownership, accounting, protocol defaults and admission behavior.
Native handlers now implement `Hell.Handler`; no compatibility shim or second
TCP/TLS host is introduced. Abyss and the HTTP/QUIC dependency cohort stay fixed.

Update live source, test fixtures and independent consumer locks together.
Historical acceptance evidence, release recipes and published v0.4.0 retain their
original source identities. Update current dependency documentation explicitly.

## Implementation and verification

- [x] Independently compare used public APIs and document any required changes.
- [x] Run an ordinary TCP/HTTP baseline on the unchanged source.
- [x] Replace the application, pinned dependency and live module references;
  refresh the root, Phoenix example and QUIC consumer locks without unrelated
  dependency upgrades.
- [x] Check formatting and compile production with warnings as errors.
- [x] Run scoped ordinary TCP/TLS lifecycle and HTTP/H2/h2c/WebSocket tests,
  including the previously accepted 200-case ordinary compatibility selection.
- [x] Verify isolated core/HTTP consumers and Phoenix adapter compatibility.
- [x] Complete independent specification/code review, resolve findings, then
  perform fresh affected verification.
- [x] Commit locally and integrate into local main, preserving unrelated files.

Run only finite ordinary scenarios. Dedicated abnormal/disconnect, slow-peer,
pressure, sustained-load and soak tests remain excluded and unexecuted. Preserve
all assertions and historical failures. Do not patch dependency source or use
private APIs. Route actual upstream issues under AGENTS.md. Astra recovery is
already exhausted at 2/2. Any local commit carries `[skip ci]`.

Record actual source, commands, exits, nonzero executed counts and exclusions in
the migration acceptance receipt. This task does not republish v0.4.0 or deploy.

## Results

Implementation and ordinary qualification **PASS**: strict production/Phoenix
compilation, 210 ordinary regression executions with zero failures, 3 isolated
consumer tests, 30 independent H2/h2c peer case checks and 24 Phoenix H2/H1
browser case checks. No executed case skipped. Independent specification and
final code reviews pass. Setup/startup failures retain their actual zero-test
FAIL status alongside successful reruns. See the
[migration acceptance](../acceptance/hell-migration.md) and its archived receipts.
Implementation `b93ee724c51ac928408896bcdc7294e8e96bd1db` is committed and
fast-forwarded into local main. Main's additional 10 ordinary network executions
pass with zero failures; strict dev/test/prod compilation passes and each app
specification uses Hell. The unrelated untracked prompt is preserved byte-for-byte.
See [integration evidence](../acceptance/evidence/hell-migration/main-integration.json).
Publication and deployment remain outside this task.
