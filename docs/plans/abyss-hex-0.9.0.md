# Abyss 0.9.0 Hex migration and Gaoxy 0.5.5 release

## Design and scope

Use the completed coordinated upstream release `0.9.0`, tag `0.9.0`, commit
`f336d939ff8a23b38c66072f1d1ba5873b5ef43b`. Both public Hex archives
(`abyss` and `abyss_raw`) and their correspondence to that commit were verified.
Gaoxy depends only on core Hex `abyss == 0.9.0`; it must not depend on
`abyss_raw` or carry the previous bundled DHCP native implementation.

The user requires development directly on `main`, preserving existing changes.
Keep Hell, HTTP, TLS and QUIC versions unchanged. Preserve historical acceptance
records and deferred specialist tests. No deployment or production changes.

The development manifest and all generated Hex manifests must agree. Remove the
obsolete Abyss Git-to-Hex conversion from the package staging script and retain
its rejection of unsupported Git/path dependencies. The publication unit remains
the existing five Hex packages and standalone application, versioned `0.5.5`.

## Execution and verification

- [x] Verify latest completed upstream two-package release, source identity,
  public tarball checksums and archive contents against the upstream tree.
- [x] Change core requirement, normally resolve all three tracked lockfiles,
  and verify unrelated dependency versions stay unchanged.
- [x] Remove obsolete staging conversion; regress rejection of old Abyss pins
  and verify the dependency metadata of all five built package archives.
- [x] Use fresh dependency/build directories to inspect the effective graph,
  installed core contents and remaining native build owners.
- [x] Run ordinary UDP/configuration/lifecycle contracts, external core consumer,
  isolated IPv4/IPv6 unicast/broadcast/multicast integration, and affected optional
  QUIC consumer with an independent peer. Record environment blockers explicitly.
- [x] Run repository static checks, exact-count ordinary repair suites, strict
  compilation, production release and core/gateway/HTTP3 smoke gates.
- [x] Update current build requirements and release notes. Obtain independent
  specification/code review and fresh verification before committing.
- [x] Commit and push `main`, verify remote SHA and applicable hosted gates, then
  dispatch the existing release workflow with version and exact expected SHA.
  Any failed required publication gate blocks its publication.
- [x] Verify public Hex artifacts (especially core Abyss requirement), checksums,
  shared Gaoxy tag/source, GitHub Release and standalone artifact. Record exact
  commands, counts, exits and PASS/FAIL/BLOCKED/NOT RUN states in acceptance notes.
