# Mixed H1/h2c hosted CI evidence

This compact archive preserves final PR CI evidence for API head
`2a096b7db1a4e52d7296c7c65cc1c94fb26cc647`. All ten jobs in PR runs
[Unit 39553035130](https://github.com/gsmlg-dev/gaoxy/actions/runs/39553035130),
[Static 39553035149](https://github.com/gsmlg-dev/gaoxy/actions/runs/39553035149),
and [Foundation 39553035150](https://github.com/gsmlg-dev/gaoxy/actions/runs/39553035150)
passed. Their checkout logs identify GitHub's synthetic PR merge
`c46c99ff48123d58b765f3ba79944c0ba703524a`. The local integration merge at
archival was `14287f30b83ccec207ffc944867413043cb8f360`; these logs do not
claim a fresh run on that local merge. The read-only GitHub commit API
confirms the synthetic merge tree equals the API head tree. Their difference
from the local merge is limited to 225 acceptance-document evidence files,
as enumerated in `source-identity.json`. Corrected-head push Static 39553029494
and Foundation 39553029332 also passed; their status/job records are preserved.
Main CI, publication, deployment, and production acceptance are separate.

Unit executed 180 tests on each platform (Ubuntu Elixir 1.18.5/OTP 28.5;
macOS Intel Elixir 1.20.1/OTP 29.0.2), with zero failures, exclusions, or
skips. Foundation native HTTP records `REPAIR_PASS 207 executed, 0 failures,
0 excluded, 0 skipped`, followed by five Phoenix listener ownership tests.
Optional QUIC records four tests, zero failures. Portable loopback, external
core consumer, and release assembly jobs passed. Raw portable summaries retain
`8 tests, 0 failures` and `8 tests, 0 failures, 7 excluded`; the latter means
one executed test. Displayed totals are not blindly added together.

Historical head `1be0f0fb6cff0932274b86c30aa3e8aa57247875` retains its actual
outcomes: PR Unit 39551788377 **FAIL** (macOS TLS fixtures selected OpenSSL
1.1.1; two TLS tests failed before requests), PR Static 39551788252 **PASS**,
and PR Foundation 39551788325 **CANCELED** after the superseding push. Only
its macOS portable job was canceled; four other jobs passed. Initial push
Static 39551762619 **PASS** and Foundation 39551762663 **CANCELED** retain
the same distinctions. The fixture workflow repair changed provisioning,
without weakening runtime or test assertions. Existing
[initial macOS failure evidence](../initial-hosted-unit-failure/receipt.json)
remains separate and unchanged.

`manifest.json` lists original audit paths, sizes, and SHA-256 hashes.
Status JSONs, three run-download receipts, three count/job receipts, and the
compressed original monitoring receipt are byte-preserving copies. The three
full successful PR logs use gzip level 9 with zero mtime; their decompressed
bytes match the originals. `counts-and-source.json` extracts actual count
and checkout lines for convenient review. Full `.audit/mixed-h2c/hosted/`
originals and polling history remain intact; polling snapshots are not copied.
