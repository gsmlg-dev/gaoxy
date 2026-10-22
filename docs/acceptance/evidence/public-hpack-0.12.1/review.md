# 0.12.1 independent review record

The public HPACK migration received separate specification and code-quality
reviews before commit `fcb92582212f9c461429aa4c0de306dbca2c2ea2` and final local
qualification. Both returned no actionable findings, as recorded in
`docs/plans/public-hpack.md`. The release-preparation audit then verified all
seven versions, package isolation assertions, release notes and guarded
publication gates before `dd70d7667d5cc3aa631cce9444efeda5d3d5e5c2` was pushed.

The macOS portable job on that source failed twice during independent cold
compilation, with zero HTTP requests. Its first log reached Gaoxy compilation;
the rerun reached Plug compilation. Both exceeded the 300-second preparation
budget after compiling the newly required HTTP/TLS/QUIC dependencies.

An independent read-only review accepted the single-line setup repair in
`c94d71d438fae77c6d8a88b2d5f9782d45807177`: the compile budget changes from 300
to 600 seconds. The reviewer and parent separately normalized that constant
in Python ASTs and confirmed the entire script otherwise matches the previous
source. Locked resolution, independent compilation, mandatory dependencies,
strict compiler flags, the 180-second dependency-resolution budget,
30-second runtime budget, exact health response and successful stop assertions
are unchanged. The 15-minute workflow deadline is unchanged.

The reviewer returned no findings. The setup repair still requires actual
macOS HTTP success in fresh CI; this review does not substitute for execution.
Original failed run metadata, logs and both portable consumer artifacts are
retained in `source-ci-prerepair-raw.tar.gz`.

The final source-CI evidence was independently reviewed after all five
workflows completed. All raw source identities match `c94d71d4`; 10 required
jobs succeeded and the separate manual release-client job was skipped.
Logs confirm 198 unit, 137 component and 122 protocol cases, all passing
without exclusions or skips. The final macOS artifact confirms one HTTP
request, normal stop and exit 0. Both earlier timeout failures and the archive
checksum remain intact. This evidence review returned no findings; it does not
claim unfinished publication gates passed.

The completed release and public-artifact evidence received a final independent
read-only review. Raw release logs confirm 9 source-consumer, 457 ordinary,
7 built-consumer, 18 Phoenix regression and 7 published-consumer cases, with
zero failures, plus eight unified Phoenix checks and clean source restoration.
The public receipt matches the raw release and Hex metadata: eight assets,
seven checksums, six unretired packages, 135 exact-source files, 33 application
metadata records and seven HTTP/TLS/QUIC dependencies at 0.21.16. Required
`http_core` metadata, HPAX absence, tag identity and receipt/verifier hashes are
consistent. Links resolve, completed publication has no pending claims, and
historical failures and specialist exclusions remain preserved. No actionable
findings were returned. The saved readiness record retains its historical
pre-execution status; the completed receipts establish the final result.
