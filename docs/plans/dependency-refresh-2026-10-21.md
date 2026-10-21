# Mix dependency refresh — 2026-10-21

Base: `0a0f9d195db688719d9000abc1bb4915341c61d5`; develop directly on `main`.

## Scope and decisions

- Use `mix hex.outdated --all` to audit the complete active Hex graph and update
  every available stable release through normal Mix resolution.
- Keep the seven HTTP/TLS/QUIC packages on the shared `0.21.14` release, including
  the independent H3 and QUIC consumer requirements. Upgrade the Phoenix example
  to `1.8.16` and resolve its ranged dependencies to current stable versions.
- Preserve the published `abyss == 0.9.0` boundary and the latest Hell `0.1.2`
  source pin. Do not introduce `abyss_raw`, Rustler or bundled native sources.
- Refresh all three tracked lockfiles. Synchronize the package metadata regression
  expectations with the updated real manifests. Preserve historical qualifications
  and vendored source provenance.

## Execution and verification

1. Save the source, manifest/lock baselines and user-file hash; capture the Hex
   audits. Resolve the umbrella, independent QUIC consumer and Phoenix example.
2. Use fresh dependency/build directories for strict compilation and the existing
   exact-count ordinary repair gate. Run focused core and HTTP Fetch integration,
   all three external consumer boundaries, QUIC and Phoenix example tests.
3. Run script/packaging regressions, which build and inspect the five actual Hex
   tarballs. Check formatting, final dependency graphs and outdated reports.
4. Complete independent diff review and fresh focused verification. Record command
   exits/counts and any failures without weakening assertions or repairing unrelated
   code. Preserve the excluded specialist stress/disconnect scope.

Logs and baseline copies are under
`.audit/dependency-upgrade/20261021T044833Z-449fc25f/`.
