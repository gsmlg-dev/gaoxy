# Gaoxy 0.12.0 internal-request release

Date: 2026-10-22, Asia/Shanghai. Baseline main and origin/main:
`0b3f97fc08549649b4b367e3a85a8526e162f53f`, initially clean.
The user explicitly requests direct-main fixes and publication. This overrides
the invoked skill's worktree/PR workflow. The initial eligible batch is #12,
#13 and #14; none has an open fix PR or an `unable to resolve` label.

1. Fix HEAD representation metadata (#12), opt-in inactivity-only storage
   transfers (#13), and the exact Phoenix disconnected stop reason (#14).
   Parallel writers have disjoint ownership; the parent integrates manifests.
   Preserve red evidence and add ordinary behavioral regressions.
2. Independently review the specification, code and test classification. Resolve
   findings and run fresh scoped regressions, formatting, strict compilation,
   exact-count unit/component/protocol gates and package checks.
3. Advance own manifests and current install examples to 0.12.0. The minor
   version reflects the new supported request-lifetime configuration; finite
   defaults remain unchanged. Preserve dependency pins and vendor provenance.
4. Commit on main with issue-closing references, push and verify all current
   source CI workflows. Dispatch release.yml with the exact versioned SHA;
   retain its publication/source guards and qualification checks.
5. Read back the remote main/tag, GitHub release assets/checksums and all six
   public Hex packages; run fresh published consumers and issue regressions.
   Record evidence and issue closure/publication status.

No deployment, operational data/certificates, Vault/public-management changes,
specialist pressure/load/disconnect qualification or browser test gates belong
to this release. Existing historical evidence remains immutable.
