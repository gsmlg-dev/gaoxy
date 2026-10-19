# Gaoxy v0.5.0 release acceptance

Date: 2026-10-20, Asia/Shanghai. **Status: preparation in progress.**
The user explicitly authorizes commit, push and the next minor GitHub release.
[Release plan](../plans/release-0.5.0.md) and
[portable design](../designs/release-0.5.0-portable.md) define ordinary-only gates.

| Gate | Actual status |
| --- | --- |
| Preparation | PASS: latest v0.4.0, next v0.5.0 absent; two local Hell commits, no remote-only commits; clean tracked checkout |
| Hell implementation | PASS at previously reviewed migration source; 429 functional files match its verified snapshot |
| Six source versions and static recipe checks | PASS: six own declarations at 0.5.0; lockfiles and toolchain pins unchanged; planned ordinary scope 210/144 |
| Independent specification and code review | NOT RUN |
| Fresh portable build, package and Hell runtime | NOT RUN |
| Fresh offline runtime and independent artifact/notes review | NOT RUN |
| Push, annotated tag and GitHub release | NOT RUN |
| Fresh downloads and independent publication review | NOT RUN |
| Documentation closeout | NOT RUN |
| New hosted CI, deployment and production acceptance | NOT RUN |

Hell is version 0.1.2 at Git pin
`59eed42b019ca41413d1b8cd7a7dc3e344bb93ee`; root lock SHA256 remains
`9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777`.
Existing [migration acceptance](hell-migration.md) remains historical evidence;
this release requires fresh artifact qualification before publication.

Specialist abnormal/disconnect, slow-peer, pressure, load and soak qualification
remain excluded. Their historical results/assertions are preserved. Deployment,
production operations, package/image publishing and disabled release-artifact
E2E remain outside this release.
