# 0.7.0 Hex package audit evidence

The copied `receipt.json` records the successful final local audit against
commit `930fba3abfeab48838d09aa4d838704c1259b746` plus the recorded version and
documentation diff. All five actual archives passed metadata, dependency,
license and source-payload checks. The 108 runtime files include the new mixed
protocol detector. All 131 packaging inputs remained unchanged during this run.

`SHA256SUMS` preserves the original archive checksums and audit-relative paths;
the package archives themselves remain in local audit storage and are omitted
here. The source hash snapshots and compressed diff identify the exact inputs.
Metadata JSON, build/staging logs, the audit program and existing nine-test
packaging regression log are included. Raw logs and HTTP response headers use gzip with mtime zero and retain
exact original bytes; `manifest.json` records compressed and raw hashes.

Hex release responses returned 404 for all five 0.7.0 packages, and local and
remote Git tag queries returned no `v0.7.0` at audit time. Those are availability
snapshots before publication. No public-consumer or downloaded-runtime result
is implied. The source audit originals and the earlier input-change failure
remain preserved under `.audit/mixed-h2c/package-0.7.0/`.
