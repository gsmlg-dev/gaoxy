# v0.5.2 release plan

Date: 2026-10-20, Asia/Shanghai. The user requests another release attempt,
using the next patch version after moving the repository to `gsmlg-dev/gaoxy`.
Commit, push, GitHub release and Hex publication are authorized. Work directly
on `main`, without creating a branch or worktree. `HEX_API_KEY` stays in Actions.

## Design and verification

Reuse the reviewed v0.5.1 staging and release workflow. Synchronize the six own
versions and current installation examples to 0.5.2. Preserve runtime code,
locked dependencies, adapter provenance, historical releases and evidence.
The five distributions remain `gaoxy_websock_adapter` (OTP application
`websock_adapter`), `gaoxy`, `gaoxy_http`, `gaoxy_http3` and `gaoxy_proxy`.

Build and inspect all five packages before uploading. Verify runtime payloads
and dependency metadata independently against the qualified v0.5.1 packages.
Run scoped packaging regressions, formatting, workflow lint and strict production
compilation. Then commit and push the reviewed source, verify remote main and
dispatch the existing release workflow for 0.5.2 in the new organization.
The workflow retains ordinary standalone core/native H1/H2 smoke checks,
dependency-ordered publication and public package byte comparison before tagging.

Inspect the actual hosted result. Verify GitHub tag/source, downloaded assets
and checksums separately from all five public Hex release records and tarballs.
After publication, use fresh public-Hex core, HTTP and Phoenix consumers with
the existing assertions and documented adapter override. Record actual counts
and source identities in [release acceptance](../acceptance/release-0.5.2.md).
Complete independent review and push the publication closeout.

A hosted no-start remains BLOCKED_ENV; it does not authorize billing changes or
secret extraction. Any locally qualified source-package fallback must state
that Hex is unpublished and that no new standalone binary was built. Specialist
abnormal/disconnect, slow-peer, pressure, load and soak suites, deployment,
production operations, Vault, public management and disabled release-artifact
E2E remain outside this packaging release. No new runtime capability or Debian
portability claim follows from an Ubuntu hosted build.
