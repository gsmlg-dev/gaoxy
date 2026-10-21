# Gaoxy 0.6.0 release acceptance

Date: 2026-10-21, Asia/Shanghai. The user authorizes the next minor release,
including push and publication. Preparation is directly on `main`, from
`ec1fead80884804de9ab662e311ebb9c1cfdaf60`.

Status: **PUBLISHED — verification PASS**. The
[release plan](../plans/release-0.6.0.md) defines the source and verification
boundary. Release source `aaa613985b08edd146f393ddd48f65fd6f3665b2`
is committed and pushed to `origin/main`; the release tag preserves that source.
The subsequent documentation closeout does not alter the released payload.
Local receipts, source hashes, builds and reviews are stored under
`.audit/release-0.6.0/20261021T052454Z-ec1fead8/`.

The release includes the already qualified HTTP/TLS/QUIC `0.21.14` cohort and
Phoenix `1.8.16` / LiveView `1.2.13` example. Version preparation updates six
own manifests and current installation guides; dependency locks and runtime
implementation remain unchanged. Hex `abyss == 0.9.0` and Hell `0.1.2` are
retained. The five distributions are `gaoxy_websock_adapter`, `gaoxy`,
`gaoxy_http`, `gaoxy_http3` and `gaoxy_proxy`; `gaoxy_server` ships inside the
standalone application.

## Source and local preflight

**PASS:** all 512 captured candidate files match the release commit. The 16
release-owned changes synchronize six versions and current installation guides,
and add the release plan, notes and this record. The remaining 496 captured
files match the dependency-refresh baseline. All three locks, runtime source,
tests, workflows and vendored upstream source remain unchanged by version
preparation. An ordinary source copy isolates qualification from concurrent
unrelated files; no worktree was created or used for this release.

**PASS:** nine packaging regressions, five actual 0.6.0 package builds,
canonical formatting, actionlint, fresh locked dependency resolution and strict
production compilation. Independent preflight review checked all five archives,
128 regular payload files and 107 runtime files, including exact dependency
metadata and source equality. Fresh post-review formatting passed.

Local qualification used Linux x86_64, Elixir 1.18.5, OTP 28 / ERTS 16.4.0.5 and
`ELIXIR_ERL_OPTIONS='+S 2:2'`. The initial live-root formatter failed on a
concurrent untracked mixed-H2C test; that failure is retained. The unrelated
changes subsequently disappeared without release-task intervention. Isolated
candidate formatting and the committed-source hosted formatter both passed.
User-owned `prompt.md` remains untracked and unchanged.

## Required hosted gates on the release source

| Workflow | Result |
|---|---|
| [Static checks and build 39550306891](https://github.com/gsmlg-dev/gaoxy/actions/runs/39550306891) | PASS, formatter and Linux/macOS strict builds, attempt 1 |
| [Foundation integration tests 39550306889](https://github.com/gsmlg-dev/gaoxy/actions/runs/39550306889) | PASS, all five jobs, attempt 1: Linux/macOS portable checks, isolated network, optional QUIC and native HTTP/browser; native HTTP executes all 160 ordinary repair cases |
| [Unit tests 39550306902](https://github.com/gsmlg-dev/gaoxy/actions/runs/39550306902) | Linux attempt 1 PASS; macOS attempt 1 FAIL, sole unchanged-source macOS retry PASS, 141 required cases per platform |

The Linux result shown with unit attempt 2 is carried forward from attempt 1;
Linux was not rerun. The 141-case unit and 160-case repair gates have zero
failures, exclusions or skips in their successful executions. Independent
inspection verified the actual file summaries and raw log hashes.

The earlier dependency-refresh unit run
[39549217962](https://github.com/gsmlg-dev/gaoxy/actions/runs/39549217962) at
`ec1fead8` remains **FAIL**: the H2 Continue deadline test returned the
expected timeout but measured 125 ms against `<100 ms`. The release-source
unit attempt 1 failed the same assertion at
`apps/gaoxy_http/test/plug_body_test.exs:361` with 101 ms. Each failing
file passed 27 of 28 cases; Mix exited 2 and the required wrapper exited 1
before later files ran.

Twelve relevant files match the prior release, dependency-refresh baseline and
release source. Static tracing found no direct upgraded-package call on this
fake-owner path. The cause remains **UNRESOLVED**; unchanged files do not prove
a pre-existing failure or a host-timing cause. The single macOS retry used the
same source, assertions, matrix and timeouts and passed all 141 cases. This
establishes an intermittent result, without a fix or causal attribution.
Original failures and the retry decision are preserved. Publication began only
after all required final gates succeeded.

## Publication and public artifact verification

**PUBLISHED:** [Gaoxy v0.6.0](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.6.0),
2026-10-21 13:57:34 Asia/Shanghai (05:57:34 UTC). The existing
[release workflow 39552147775](https://github.com/gsmlg-dev/gaoxy/actions/runs/39552147775)
was dispatched with `version=0.6.0`, `git_ref=main` and the exact release
SHA. It passed nine packaging regressions, all 160 ordinary repair cases,
strict production compilation, standalone assembly and sequential core,
native H1/H2 gateway and H3 release smokes before publication.

The workflow published the following Hex packages in dependency order, compared
their public bytes with its built archives, then pushed `v0.6.0` and created
the GitHub Release:

- [gaoxy_websock_adapter 0.6.0](https://hex.pm/packages/gaoxy_websock_adapter/0.6.0)
- [gaoxy 0.6.0](https://hex.pm/packages/gaoxy/0.6.0)
- [gaoxy_http 0.6.0](https://hex.pm/packages/gaoxy_http/0.6.0)
- [gaoxy_http3 0.6.0](https://hex.pm/packages/gaoxy_http3/0.6.0)
- [gaoxy_proxy 0.6.0](https://hex.pm/packages/gaoxy_proxy/0.6.0)

**PASS:** fresh public downloads verify all seven GitHub asset digests and all
six `SHA256SUMS` entries. The five public Hex records and actual tarballs
match the GitHub bytes. Regenerating staging from immutable release Git objects
matches every packaged regular file. All five public package payloads and
normalized metadata also match the locally qualified packages.

Published core requires nonoptional Hex `abyss == 0.9.0`, Hell `== 0.1.2`
and telemetry. Internal Gaoxy requirements are exactly `== 0.6.0`; HTTP/TLS/
QUIC requirements retain the `0.21.14` cohort. The adapter distribution keeps
the OTP application alias `websock_adapter`. No package declares
`abyss_raw` or Rustler. Standalone application metadata and native-file
boundaries were inspected statically; execution evidence comes from the
successful workflow smokes, not a separate execution of the downloaded binary.

## Clean public-Hex consumers and boundary

**PASS:** fresh public Hex home, cache, dependencies and build directories
for the unchanged core, HTTP and Phoenix fixtures. Core executes **1**, HTTP
**3** and Phoenix **5** tests: **9 total, zero failures, exclusions or skips**.
All three strict compiles and effective dependency checks exit 0. Accepted
upstream versions are retained; all resolved dependencies use Hex.SCM, including
Hell 0.1.2 and Abyss 0.9.0. Core-only isolation and the adapter package/application
alias checks pass. No fixture assertions were changed.

All three effective graphs exclude `abyss_raw` and Rustler. The standalone
archive's shared objects belong to OTP asn1/crypto; no Abyss-owned native
implementation is bundled. Actual public package metadata, payloads, workflow
results and consumers have separate retained receipts. Independent publication
review verifies the downloaded bytes and committed source; the locally built
tar archives have different outer hashes but identical payloads and normalized
metadata, so this is not a claim of byte-reproducible local builds.

Fresh installed-content inspection covers 11 dependencies / 314 files for core,
18 / 462 for HTTP and 24 / 828 for Phoenix. These trees contain no Rust/Cargo
sources, native libraries/objects or explicit NIF-loading entrypoints. Installed
own-package payloads and Hex metadata match the public archives. These consumer
counts do not cover H3/proxy's separate published dependency cohort; its package
and runtime evidence is the publication review and hosted release gates above.

The completed [Abyss migration](abyss-hex-0.9.0.md) documents the coordinated
upstream 0.9.0 release and removal of the former Abyss-owned DHCP Rust NIF.
OTP/ERTS and OTP crypto/OpenSSL retain their own native components; this is not
a native-free application claim.

## Durable evidence and closeout

The compact [evidence index](evidence/release-0.6.0/manifest.json) records raw and
compressed log hashes. Receipts preserve their original local audit paths;
retained logs are compressed without altering their raw bytes. Package and
application binaries remain available from the public release and local audit,
with their verified hashes recorded rather than duplicate binaries in Git.

- [Local preflight review](evidence/release-0.6.0/preflight-review.json)
- [Final hosted gates](evidence/release-0.6.0/hosted-ci/result.json) and [CI review](evidence/release-0.6.0/ci-independent-review.json)
- [Release workflow](evidence/release-0.6.0/release-workflow/result.json)
- [Public artifact receipt](evidence/release-0.6.0/publication/verification.json) and [independent publication review](evidence/release-0.6.0/final-publication-independent-review.json)
- [Clean consumer receipt](evidence/release-0.6.0/consumers/result.json) and [consumer boundary review](evidence/release-0.6.0/consumer-results-review.json)
- [Final closeout review](evidence/release-0.6.0/closeout-independent-review.json)

There is no remaining publication blocker. The unexplained macOS elapsed-time
failure remains recorded above, separately from the successful final gates.

Specialist disconnect, blocked-upload, pressure/load qualification, deployment,
production operations, Vault, public management and disabled release-artifact
E2E are **NOT RUN**. Hosted Ubuntu adds no new Alpine or architecture portability
claim. No production service was changed.
