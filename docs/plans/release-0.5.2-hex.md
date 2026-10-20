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
that Hex is unpublished and report the actual hosted-build status; a source-only
fallback must state that no standalone binary is included. Specialist
abnormal/disconnect, slow-peer, pressure, load and soak suites, deployment,
production operations, Vault, public management and disabled release-artifact
E2E remain outside this packaging release. No new runtime capability or Debian
portability claim follows from an Ubuntu hosted build.

## Actual first attempt

Source `ff06d13bfed97744e47b452d10fc17c2bfba5fff` passed local preflight and
independent review, was pushed to `main`, and ran in hosted job `39386137306`.
All build and ordinary standalone smoke gates passed. Publication stopped
before uploading because `HEX_API_KEY` was empty. The organization secret is
inaccessible to this private repository on GitHub Free; a repository-level
secret is required. No tag or release was created, so 0.5.2 remains available
for a new dispatch. Prepared public consumers remain unexecuted. Preserve the
hosted artifact, logs and actual outcomes while awaiting that external change.
