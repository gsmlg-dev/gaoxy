Archive helper review: FINDINGS

Reviewed `.audit/release-0.4.0/archive_evidence.py` at SHA256 `dae8d15600266c58932aa867acd37214526fe5e60cfb5f023372c224783093d6`. AST parsing and compilation without execution passed. The helper was not executed or imported.

- **ARCHIVE-1 — high, line 20:** The private-key guard misses valid `-----BEGIN ENCRYPTED PRIVATE KEY-----` and `-----BEGIN DSA PRIVATE KEY-----` headers. Its optional prefix only accepts RSA, EC and OPENSSH. Those keys would be copied despite the no-private-keys claim. Cover actual private-key PEM headers while preserving anchored matching.
- **ARCHIVE-2 — medium, lines 23–29:** Compression can map two receipts to one destination. A large `foo.log` becomes `foo.log.gz`; a small sibling already named `foo.log.gz` uses the same destination and overwrites it. Both manifest rows retain PASS. Use unique stored paths or reject collisions before writing.

Individual files are copied as raw bytes or losslessly compressed, checked by round trip, and recorded with original/stored SHA256 values. Exact host `source-archive.stdout` and the publication `downloads/` subtree are intentionally omitted. Static inspection shows input paths are read only and writes remain in a newly created acceptance-evidence destination; there are no process, network, Git or publication calls.

Only the two review receipts were written. The pre-existing parent change to `portable/recipe/build.py` was preserved. No tests, builds, runtime or network commands ran. All commands finished; no background processes started. Astra remains 2/2 exhausted.

Attribution correction: the first receipt captured the post-repair hash after the original line inspection. The historical helper identity above is reconstructed by exactly reversing the two parent edits; original source bytes are retained in the JSON receipt. Historical findings remain valid for those original bytes. See `archive-helper-review-repair1.json` for the repaired-helper review.
