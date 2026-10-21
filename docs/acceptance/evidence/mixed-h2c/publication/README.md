# Gaoxy 0.7.0 public publication verification

[Release](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.7.0) and
[workflow 39555029237](https://github.com/gsmlg-dev/gaoxy/actions/runs/39555029237)
are PASS on source `14287f30b83ccec207ffc944867413043cb8f360`.
`verification.json` preserves the exact completed verifier receipt: seven
GitHub asset digests, six checksum entries, five public Hex records and
archives, GitHub/Hex byte equality, immutable Git staging payload hashes,
qualified local payload/metadata comparisons, standalone versions and native
library provenance. Local package tar bytes can differ; payload and metadata
comparisons passed. All 28 recorded commands exited zero or returned HTTP 200.

The full release workflow log preserves 207 executed native HTTP tests with
zero failures/exclusions/skips, packaging tests (9), core transports (3),
gateway exchanges (7, including 5 mixed), H3 checks (3), and publication steps.
Integration receipts preserve the normal PR merge, both parents, the expected
merge tree and all 131 unchanged qualified package inputs. The availability
receipt and `preparation.json` are historical prepublication states; they do
not supersede the completed PASS receipt.

Reproduction from the worktree root used:

```sh
python3 .audit/mixed-h2c/publication/verify-publication.py \
  --source 14287f30b83ccec207ffc944867413043cb8f360 \
  --run 39555029237 \
  --artifacts-dir .audit/mixed-h2c/publication/qualified-local-artifacts
```

`verify-publication.py` is an exact audit helper copy and assumes its original
`.audit/mixed-h2c/publication/` placement. The README is explanatory; all raw
captures/receipts are byte-preserving copies, with text command streams and
metadata compressed deterministically. Binary downloads, the source tar and
expanded staging trees remain in the original audit directory and are omitted
from Git. Their hashes remain in the exact receipt. This is a compact evidence
archive, not a complete artifact mirror. The downloaded standalone execution
has its own [runtime evidence](../downloaded-runtime/README.md).
