# Final public release evidence review

Date: 2026-10-22, Asia/Shanghai. Task: `final_public_review`.
Disposition: **PASS — no actionable factual or scope findings.**

Independent document/archive review on `main` at
`ed3fbbfbe4016906b10a97711193d341f3d9ed4f` in
`/home/gao/Workspace/gsmlg-opt/gaoxy`. Ownership was limited to this report;
the existing acceptance/plan edits and public receipts were preserved.
This reviews recorded qualification evidence; it does not rerun product tests.

The [acceptance](../../release-0.9.0.md) and
[six-step plan](../../../plans/release-0.9.0.md) agree with the
[curated qualification receipt](public-qualification.json) and archived raw
receipts:

- The release source, local tag and recorded remote `v0.9.0` tag identify
  `ed3fbbfbe4016906b10a97711193d341f3d9ed4f`. All ten prerequisite hosted
  jobs at that SHA succeeded before release execution. Release run
  `39653398896` succeeded; publication is recorded at `2026-10-21T18:41:04Z`.
- Five public packages, seven assets, six checksum entries and 122 runtime
  payload files agree across receipts. Package API, GitHub/Hex and consumer-cache
  checksums agree. Public consumers record 18/0, public Phoenix records 18/0,
  and the downloaded standalone records 13 successful checks.
- The initial H2 contract failure remains in the separate repair evidence.
  Initial macOS failures retain 634/250 ms and 157/100 ms assertion values,
  with 604/127 ms scheduler lateness; `plug_body_test.exs` is unchanged between
  the initial and final candidates. Neither failure is relabeled passing.
- The first standalone receipt remains FAIL before VM startup, with zero
  application checks: its log names missing `libtinfo.so.6`, and linkage also
  lists zlib and the C++ runtime. The successful receipt uses the same archive
  digest and explicitly records Nix host library paths. No default-NixOS
  portability claim is made.
- The final recorded remote audit has issues #3/#5/#6/#7/#8/#9/#10 CLOSED with
  `internal request fixed`, and zero open internal requests. Preparation-time
  pending fields in raw dispatch/consumer receipts are explicitly explained by
  the curated receipt and superseded by completed command/remote records.
- Deployment, specialist pressure/load qualification, production, Vault,
  public management and disabled release-artifact E2E boundaries remain intact.

Verification commands and actual outcomes:

| Command/check | Result |
|---|---|
| `git status --short`, `git rev-parse HEAD`, `git diff --stat`, scoped document diff and `git tag --points-at HEAD` | Expected document/evidence-only pending changes; baseline and local release tag match |
| Python `tarfile`/`hashlib` validation of `public-audit.tar.gz` and `files.json` | PASS: 67 unique regular-file members, all 66 payload member sizes/hashes match; archive SHA-256 and 341258-byte size match the curated receipt |
| Archive member-name and private-key-content scan | PASS: no dependency/build/cache directories, private fixture key files or private-key blocks |
| Curated receipt hashes, archived/raw receipt byte comparisons and four decompressed verifier-script hashes | PASS: all match |
| Hosted JSON SHA/status/job-count/time checks and release log inspection | PASS: 3 + 2 + 5 successful prerequisite jobs; successful exact-SHA release; recorded 46/0 issue, 265/0 ordinary, 17/0 Phoenix, 8 browser and 13 standalone gates |
| Public JSON arithmetic/checksum cross-checks and archived log inspection | PASS: package/asset/payload counts, 18/0 consumers, 18/0 Phoenix, 13 standalone checks and environment limitation agree |
| Consumer/Phoenix receipt source-test hashes against original fixture files | PASS; injected HTTP/H3 shutdown tests resolve to their app test paths, and the generated Phoenix isolation test is separate |
| `gzip`/JSON sorted source-manifest fingerprints; `git show HEAD:<file>` comparisons | PASS: both 557-entry fingerprints match documentation; six original source-manifest/local-audit/repair files remain byte-identical |
| Local Markdown target existence checks and manual scope/completion review | PASS: all four local acceptance/plan links resolve; no contradictory completion claim |
| `git diff --check` | PASS, exit 0 |

An initial reviewer hash lookup assumed the injected shutdown test lived in its
consumer fixture directory and returned `FileNotFoundError`; using the verifier's
documented app-test source paths completed that check successfully. No product
test, source repair or assertion change resulted.

No product tests, issue mutations, commits, pushes or publication were performed
by this reviewer. All commands finished. Sol repair rounds for this assignment:
0; no Astra recovery. Remaining limitation: this is archival consistency review,
not additional portability, deployment or production qualification.
