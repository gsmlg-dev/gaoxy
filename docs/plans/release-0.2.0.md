# v0.2.0 release execution plan

Date: 2026-10-11. [ADR007](../adr/007-m3-beta-and-m4.md) defines the reviewed scope.
Authorization includes main integration, push, tag and GitHub standalone release.

1. Synchronize current rules/capabilities and all five versions to 0.2.0.
   Preserve historical receipts and the unrelated root prompt.
2. Build with canonical Elixir1.18.5/OTP28, run scoped compatibility tests and
   start the production release. Verify core and H1/H2 gateway traffic, finite
   shutdown and endpoint cleanup. Add checks before workflow publication.
   Distinguish local Nix evidence from the published artifact profile.
3. Obtain independent release specification/code/docs review, fix findings and
   independently review M4 architecture/plan. M4 runtime remains NOT RUN.
4. Commit task-owned files, fetch/recheck origin, fast-forward main, push and
   independently verify remote SHA. Keep main stable during release.
5. Dispatch `release.yml` with `version=0.2.0`, `git_ref=main`; inspect actual
   execution. If hosted execution cannot start, assess an equivalently qualified
   local Linux build without altering account/repository permissions or settings.
6. Verify remote main/tag, all five tagged versions, release assets and freshly
   downloaded checksums/archive inventory. Record publication separately from
   deployment and disabled release-artifact E2E. Leave M4 design/plan ready.

Diagnose failures; never weaken assertions or label unexecuted/failed gates PASS.
Upstream pools/H2 remain disclosed omissions, not capabilities of this release.
