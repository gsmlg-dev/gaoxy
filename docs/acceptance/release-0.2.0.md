# Gaoxy v0.2.0 release receipt

Date: 2026-10-11. Status: IN PROGRESS; publication is not yet claimed.

[ADR007](../adr/007-m3-beta-and-m4.md) defines the reviewed gateway beta subset.
[Execution plan](../plans/release-0.2.0.md) records authorized steps. All five
versions are synchronized to 0.2.0. Historical protocol/browser/load receipts
retain their original candidate identities.

| Verification | Current result |
| --- | --- |
| Canonical format / strict compilation | PASS, exit0, Elixir1.18.5 / OTP28.5.0.7 |
| Scoped compatibility regression | PASS, 486 tests / 0 failures, exit0 |
| Local production core and gateway artifact smoke | PASS, 3 core transports + 2 H1/H2 proxy exchanges; finite exit and rebind |
| Independent release and M4 design review | PASS, no active findings; M4 implementation NOT RUN |
| Main integration / remote SHA | NOT RUN |
| Hosted build / pre-publication artifact smoke | NOT RUN |
| Tag / release assets / downloaded SHA256 | NOT RUN |
| Production deployment / release-artifact E2E | NOT RUN; not authorized |

Local Nix smoke establishes behavior on the recorded Nix host; it is not a
generic portable Linux artifact. The published build needs its own platform
provenance and pre-publication smoke.

[Local verification](evidence/release-0.2.0/local-verification.json) records exact
commands, source/log hashes and counts. [Smoke receipt](evidence/release-0.2.0/smoke-results.json)
preserves the initial `invalid_http_protocols` fixture failure (exit1, zero
exchanges) and its repaired execution (exit0, two exchanges). The repair uses
separate supported H1/H2 cleartext listeners; traffic assertions remain intact.
Release-smoke counters: Sol1, unsuccessful0, Astra0. Existing transport counters
remain unchanged.

[Independent review](evidence/release-0.2.0/independent-review.md) and its
[machine receipt](evidence/release-0.2.0/independent-review.json) cover the release
changes and M4 architecture. The owner-loss design finding is resolved; M4
implementation is not claimed.

Raw execution logs are stored as lossless gzip archives. The local verification
receipt includes compressed and decompressed SHA256 values; no log whitespace
or failure output was normalized.
