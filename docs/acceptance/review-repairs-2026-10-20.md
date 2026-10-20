# October 20 correctness repair and patch release

Date: 2026-10-20; closeout: 2026-10-21, Asia/Shanghai.
Repairs are implemented, independently reviewed,
qualified and published as v0.5.3 from
`62a325fe5153c2438b3ea717cd7fdf4d82d7b871`. Public downloads and clean consumers
are verified. Separate optional QUIC setup and macOS strict-compilation CI
failures are preserved below; this is Linux ordinary-scope qualification.
The [integration plan](../plans/review-repairs-2026-10-20.md) preserves the user's
ordinary-only acceptance scope and authorizes commit, integration, push and patch
publication. Previous releases and historical evidence remain immutable.

## Source and contracts

Kickoff local main: `4f90967e06b906f3a862ec1541b1c4dd79bee83a`; refreshed remote
main: `c063607e65cb3486dc19c78827f1ea8c62dbc87a`. v0.5.2 was already published.
All five 0.5.3 Hex release endpoints returned 404 at kickoff, and no 0.5.3 Git tag
or GitHub release existed. The prepublication recheck at 15:48:46 UTC confirmed
that all five versions and the tag remained absent.

- R1: Plug logical aggregation is separate from native bounded reads. Logical
  length/demand, cumulative limit, completion and per-socket timeouts retain their
  documented contracts. Adapter chunks and final flattening copy are reserved
  through Admission; ownership transfers to Plug/application code on return.
  See [design](../designs/review-plug-body.md).
- R2: an explicit authority type check produces the existing structured H2 error.
  Strict IPv6 authority parsing uses bytes, so invalid UTF-8 is also rejected
  without a parser exception. An independent H2 peer verifies PROTOCOL_ERROR on
  the malformed stream, an active sibling response, PING and a third request.
- R3: shared request preparation combines H2/H3 Cookie fields in order with
  exactly `; `, after hop filtering and before final output limits. H1 input,
  unrelated repeated fields and response Set-Cookie remain unchanged. Real H1
  wire capture covers dedicated and managed modes and both downstream protocols.
- R4 was already implemented in `0d1bec9d`: H2/H3 ordinary requests and valid
  opt-in WebSocket extended CONNECT receive neutral 400 responses before an
  upstream session/connection. The existing H1 success regression remains.
- R5 updates canonical guides, exact-count ordinary test gates and source-bound
  publication. The standalone expansion in `27bffd83` already existed at kickoff;
  its managed H1/H2/h2c/groups/probes, H1 WebSocket and fixed relays are preserved.
  Future standalone expansion beyond current targets remains separate work.

The root and own app versions are 0.5.3. The staged `gaoxy_websock_adapter`
distribution follows that version while its retained upstream source project
remains WebSockAdapter 0.6.0. The lockfile cohort is unchanged.

## Verification ledger

Environment: Linux x86_64, Elixir 1.18.5, OTP 28.5 / ERTS 16.4.0.5,
`ELIXIR_ERL_OPTIONS='+S 4:4'`; host tools match the documented Linux profile.
The repository Nix-shell evaluation did not finish; product commands use the
verified host runtime and Nix-store unbuffer. Independent peers: Python 3.12.13,
h2=4.3.0, hpack=4.2.0, hyperframe=6.1.0, aioquic=1.2.0. Shared Mix operations
are serialized by `.audit/review-repairs/mix.lock`.

| Gate | Actual result |
| --- | --- |
| Baseline contract/codec/header tests | PASS: 37 tests, 0 failures |
| R1 initial focused red | FAIL as expected: 16 tests, 11 failures; native pieces escaped the Plug logical contract |
| R2 focused red | FAIL as expected: missing authority and invalid byte sequence parser exceptions |
| R2 focused green | PASS: 9 tests, 0 failures; independent stream-isolation peer included |
| R2 neighboring parser/codec/protocol/H3 headers | PASS: 29 tests, 0 failures |
| R3 pure red | FAIL as expected: 5 tests, 3 failures |
| R3 corrected real-wire red | FAIL as expected: 3 tests, 3 failures; separate Cookie fields observed in every row |
| R3 green and original header regressions | PASS: 27 tests, 0 failures |
| R1 final scoped compatibility and real parsers | PASS: 89 tests, 0 failures; separate legacy Admission compatibility 3/0 |
| Reviewed integration before commit | PASS: 158 tests, 0 failures, 0 exclusions/skips; canonical format and strict compile exit 0 |
| Gate/wrapper/package/smoke helper regressions | PASS: 6/8/8/5 tests; modern ExUnit summary red preserved before repair |
| Initial source core/HTTP/Phoenix consumers | PASS: 1/3/5 tests; final committed-source runs remain below |
| Browser at `20359557` | FAIL: six checks passed before an initial LiveView click preceded channel readiness; source restored and fixture stopped |
| Browser fixture readiness repair | PASS: 15 checks, including H1/H2 clicks, upload, reconnect, reload and shutdown; original assertions and deadlines preserved |
| Frozen-source repair and ordinary compatibility | PASS: 158 tests, 0 failures, 0 exclusions/skips at `62a325fe` |
| Frozen-source portable checks | PASS: 8 tests; fragmented-TCP selector executes 1 test with 7 intentionally excluded |
| Frozen-source core/HTTP/Phoenix consumers | PASS: 1/3/5 tests, 0 failures; real 20,000-byte JSON/form parsing included |
| Frozen-source browser | PASS: 15 checks, process exit 0, source restored |
| Production compile, release, five package builds and core/gateway/H3 smoke | PASS; H3 smoke executes 3 checks |
| Packaged ordinary H2/h2c/H3 WebSockets | PASS: 15/15 checks per protocol, 45 total |
| Independent R2 and R3 specification/code review | PASS; no actionable findings |
| Independent R1 and integration specification/code review | PASS; all findings resolved, including read-triggered Continue deadlines, write caps and late-token cleanup |
| Hosted release `39452129161` | PASS: actual source/version guards, repair gate 158/0, packaging and smoke steps before publication |
| Published v0.5.3 and tag | PASS: stable GitHub release, seven assets; tag resolves to qualified `62a325fe` |
| Public download checksums/packages | PASS: seven GitHub asset digests, six checksum entries and five public Hex tarballs; published packages match qualified local payloads/metadata |
| Clean public core/HTTP/Phoenix consumers | PASS: 1/3/5 tests, 0 failures, isolated public Hex/cache/build state and accepted upstream cohort |
| Hosted unit CI | PASS: Linux and macOS each execute 141 tests, no failures/exclusions/skips |
| Separate optional QUIC consumer CI | FAIL_SETUP: 4 tests, 1 failure; Python peer executable absent, network exchange NOT RUN |
| macOS Elixir 1.20 strict build/portable compile | FAIL: external bitstring size variables require pins; new and existing callsites, no baseline rerun |

`scripts/check-repairs.py [unit|protocol|all]` names each required file, runs the
existing nonempty-test wrapper, requires its exact count, and rejects failures,
exclusions and skips. It forces `MIX_ENV=test` even under the production release
parent. It also retains curated ordinary configuration, H1 framing/body, header policy,
response rendering, native accounting, successful H1 WebSocket proxy and native
H2/H3 WebSocket cases. Enabled unit/integration jobs and the publication workflow
use this gate.
The release accepts an expected full SHA, validates already-committed versions,
and reruns the ordinary repair gate before packaging and irreversible uploads.

Bounded raw logs remain under `.audit/review-repairs/`; final receipts record
exact commands, counts, exits, source hashes and log digests without embedding
transcripts in this document. Review findings and failed diagnostic
runs retain their actual status; a repaired fixture failure is not a product red.
The browser diagnosis held the real server's join reply and confirmed that a
disconnected click is dropped. Initial clicks now wait for `phx-connected`, as
the existing reconnect check already did. The failed attempt and causal probe
remain under `.audit/review-repairs/final/phoenix/` and
`.audit/review-repairs/browser-diagnosis-held-join/`.

## Frozen-source evidence and publication

The final Linux host qualification uses `.audit/review-repairs/final-ready/`;
its [exported receipt](evidence/review-repairs-2026-10-20/local-qualification.json)
preserves commands, source identities, counts, exits and log digests.
All five phase receipts identify `62a325fe`; all 29 recorded commands exit 0.
Independent final evidence review recomputed their log hashes, the source archive
and lock hashes, and the browser's before/after/current source hashes. Main and
the implementation worktree were identical and tracked-clean before push.
The aggregate receipt SHA256 is
`602364179b625c5c2d1278d3a4862788445b44497400733ad31ce9bf6ee7fe83`.

At publication, remote main and tag `v0.5.3` resolved to the qualified source.
The tag remains pinned while this documentation closeout advances main. The
[release run](https://github.com/gsmlg-dev/gaoxy/actions/runs/39452129161)
completed successfully and the
[stable release](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.5.3)
was published at 2026-10-20 15:53:42 UTC. The workflow made no source commit.
Its complete log contains `REPAIR_SOURCE 62a325fe5153c2438b3ea717cd7fdf4d82d7b871`
and `REPAIR_PASS 158 executed, 0 failures, 0 excluded, 0 skipped`;
log SHA256: `29c7f3936b8f74fb6d00446d30efecea5f5a22225892c3e85e0c3880fc444185`.

The [independent publication audit](evidence/review-repairs-2026-10-20/publication.json)
checks every GitHub asset API digest/size/state, all six SHA256SUMS entries,
the exact tag/source and successful actual hosted steps. Fresh public Hex
tarballs match all five uploaded package archives byte for byte. Their payload
bytes, file modes and parsed metadata match the qualified local/staged packages.
Raw local and hosted tarballs differ: hosted Hex 2.5.3 and local Hex 2.4.2
serialize metadata differently; this is recorded rather than hidden.
Audit receipt SHA256:
`1a6003556e5e2e5569703b339b970d2d87818a142a27c123ef115ede3b2e3d86`.

[Clean public consumer evidence](evidence/review-repairs-2026-10-20/public-consumers.json)
records run `1792510766249915308`, prepared and executed against the release
source. It uses isolated Hex home/cache/dependency/build directories, no
repository authentication or mirrors, actual Hex.SCM dependencies and the
accepted upstream lock cohort. Core 1, HTTP 3 and Phoenix 5 tests pass, including
the real large JSON/form bodies. Consumer receipt SHA256:
`d72bdbcc335dc22f1033817b0cd2120cc27ecc5322463be87cf79f72a63d2c39`.

The [review record](evidence/review-repairs-2026-10-20/independent-reviews.md)
retains specification/code reviews and the fixture readiness review. Final
independent evidence review approved all 29 local command log hashes and source
identities. No Astra repair round was used; historical budgets were not reset.

## Separate hosted CI results

The independently triggered
[Foundation CI](https://github.com/gsmlg-dev/gaoxy/actions/runs/39452105331)
optional QUIC job fails at `System.cmd/3`: its expected
`integration/quic_consumer/.venv/bin/python` does not exist (`:enoent`). The
optional job installs uv but does not provision that executable. Both the job
and consumer source are unchanged from kickoff remote `c063607e`; this is a
fixture setup failure before peer exchange, not protocol evidence. The failed
log is preserved with SHA256
`108f232195bbd1d4d3096af804bcb6b814dd3fd3422187523c440c900a1a7641`.
No repair outside the requested scope is included. Package uploads had already
completed when this separate failure was reported; immutable publication was
inventoried and its verification continued.

[Unit CI](https://github.com/gsmlg-dev/gaoxy/actions/runs/39452105274) passes
141 required unit tests on both Linux and macOS, with no exclusions or skips.
The Foundation native HTTP, isolated-network and Linux portable jobs pass;
native artifacts confirm repair 158/0, Phoenix 5/0, browser 15/source restored,
H2 RFC 40/0 and reverse-proxy 6/0. The deferred sustained-load step is skipped
intentionally.

[Static CI](https://github.com/gsmlg-dev/gaoxy/actions/runs/39452105268) and the
Foundation macOS portable job fail strict compilation under Elixir 1.20.1:
external bitstring-size variables must be pinned. This includes newly added
`Exchange.send_continue/2` line 227 and existing Exchange, framing, parser,
connection, renderer and WebSocket sites. No baseline rerun establishes a
previous pass, and this failure is not relabeled as passing or wholly historical.
The requested Linux Elixir 1.18.5 / OTP 28.5 profile passes strict compilation;
macOS 1.20 strict-compilation acceptance is not established by this patch.

The [CI receipt](evidence/review-repairs-2026-10-20/hosted-ci.json) records final
jobs, commands/counts, warning locations, actual source and log/artifact digests;
SHA256: `794a14161d1512dc0311aa31f03006540c60559a6acd904dc0772d2dce32bcc3`.
These outside-scope fixture/compiler migrations were not repaired. This closeout
advances main with documentation/evidence only; the published tag and all
qualified runtime/package inputs remain unchanged.

## Retained limits

Proxy responses declaring trailers together with Content-Length remain rejected
across H1/H2/H3. No H2/H3 WebSocket proxy bridge, outbound multiplexed WebSocket
transport, compression, new QUIC feature, ACME or public management is added.
Application-owned body memory after transfer is outside the native payload
ledger. Specialist exceptional/disconnect/slow-peer/pressure/load/soak/combined
qualification is NOT RUN by scope; its historical evidence is unchanged.
`http_fetch#97` remains dismissed. The release-artifact E2E job stays disabled.
Deployment, production data/certificates, Vault and public management are NOT RUN.
