# October 20 correctness repair and patch release

Date: 2026-10-20, Asia/Shanghai. Repairs are implemented and independently
reviewed. Exact committed-source qualification and publication are pending.
The [integration plan](../plans/review-repairs-2026-10-20.md) preserves the user's
ordinary-only acceptance scope and authorizes commit, integration, push and patch
publication. Previous releases and historical evidence remain immutable.

## Source and contracts

Kickoff local main: `4f90967e06b906f3a862ec1541b1c4dd79bee83a`; refreshed remote
main: `c063607e65cb3486dc19c78827f1ea8c62dbc87a`. v0.5.2 was already published.
All five 0.5.3 Hex release endpoints returned 404 at kickoff, and no 0.5.3 Git tag
or GitHub release existed. Final publication rechecks this state.

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

The root and own app versions target 0.5.3. The staged `gaoxy_websock_adapter`
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
| Final repair gate, compatibility/build/package/consumers/browser | NOT RUN on frozen publication source |
| Independent R2 and R3 specification/code review | PASS; no actionable findings |
| Independent R1 and integration specification/code review | PASS; all findings resolved, including read-triggered Continue deadlines, write caps and late-token cleanup |
| Hosted release, tag, public packages/assets and consumers | NOT RUN |

`scripts/check-repairs.py [unit|protocol|all]` names each required file, runs the
existing nonempty-test wrapper, requires its exact count, and rejects failures,
exclusions and skips. It forces `MIX_ENV=test` even under the production release
parent. It also retains curated ordinary configuration, H1 framing/body, header policy,
response rendering, native accounting, successful H1 WebSocket proxy and native
H2/H3 WebSocket cases. Enabled unit/integration jobs and the publication workflow
use this gate.
The release accepts an expected full SHA, validates already-committed versions,
and reruns the ordinary repair gate before packaging and irreversible uploads.

Bounded raw logs remain under `.audit/review-repairs/`; the final receipt will
record exact commands, counts, exits, source hashes and log digests without
embedding transcripts in this document. Review findings and failed diagnostic
runs retain their actual status; a repaired fixture failure is not a product red.
The browser diagnosis held the real server's join reply and confirmed that a
disconnected click is dropped. Initial clicks now wait for `phx-connected`, as
the existing reconnect check already did. The failed attempt and causal probe
remain under `.audit/review-repairs/final/phoenix/` and
`.audit/review-repairs/browser-diagnosis-held-join/`.

## Retained limits

Proxy responses declaring trailers together with Content-Length remain rejected
across H1/H2/H3. No H2/H3 WebSocket proxy bridge, outbound multiplexed WebSocket
transport, compression, new QUIC feature, ACME or public management is added.
Application-owned body memory after transfer is outside the native payload
ledger. Specialist exceptional/disconnect/slow-peer/pressure/load/soak/combined
qualification is NOT RUN by scope; its historical evidence is unchanged.
`http_fetch#97` remains dismissed. The release-artifact E2E job stays disabled.
Deployment, production data/certificates, Vault and public management are NOT RUN.
