# M3 H1 resource foundation acceptance

Status: **IN PROGRESS**. Steps 1–5 are accepted. Owner/core retirement and
independent TCP/TLS acceptance are
**NOT RUN**. This package is existing M3 upstream-transport Task 4, before
production endpoint activation.

Execution checkout: `.trees/m3-h1-resource-foundation`, branch
`codex/m3-h1-resource-foundation`, verified kickoff
`449a4c4d470128d9e138564fe71b40e8fcebe358`. See the
[design](../designs/m3-h1-resource-foundation.md),
[plan](../plans/m3-h1-resource-foundation.md) and
[kickoff receipt](evidence/m3/h1-resource-foundation/1791870010586271722/kickoff.json).

## Accepted components

| Gate | Actual evidence | Status |
| --- | --- | --- |
| Generic lifecycle participants and immutable H1 options | Fresh 36 core + 30 proxy tests, zero failures; independent SPEC/CODE reviews | PASS |
| External core-only consumer | One executed test, zero failures, exit 0 | PASS |
| Ledger/custodian | Initial 40/0 GREEN rejected by review; repair 1 RED 44/4, then GREEN and fresh 44/0, exits 2/0/0 | PASS after repair |
| Ledger format and strict compilation | Stable source, exit 0 | PASS |
| Independent peer source | Repair 1 independently passes SPEC/CODE review; network execution not included | PASS source only |
| Metadata pins and request tokens | Expected RED 57/13; initial implementation 57/1, exit 2; review rejects grouped-pin removal; repair RED 58/1, GREEN and fresh 58/0; independent SPEC/CODE review | PASS after repair |
| Owner/core retirement integration | Contract investigation only | NOT RUN |
| Independent TCP/TLS public-API profile | No executed acceptance cases yet | NOT RUN |

[Core/options acceptance](evidence/m3/h1-resource-foundation/1791870010586271722/slice-a-options-acceptance.json),
[ledger acceptance](evidence/m3/h1-resource-foundation/1791870010586271722/ledger-step4-acceptance.json),
[rejected ledger review](evidence/m3/h1-resource-foundation/1791870010586271722/ledger-review-initial.json),
[accepted repair review](evidence/m3/h1-resource-foundation/1791870010586271722/ledger-review-repair1.json),
[peer source review](evidence/m3/h1-resource-foundation/1791870010586271722/peer-source-review-repair1.json)
and [Step 5 expected RED](evidence/m3/h1-resource-foundation/1791870010586271722/holds-step5-expected-red.json),
[rejected Step 5 review](evidence/m3/h1-resource-foundation/1791870010586271722/holds-review-initial.json)
and [accepted Step 5 repair review](evidence/m3/h1-resource-foundation/1791870010586271722/holds-review-repair1.json)
preserve the separate outcomes. Commands, hashes, counts, actual exits and raw
logs remain in the run directory. Expected RED is not an acceptance PASS.

## Environment and accounting boundary

Qualified commands use `nix develop --command env 'ERL_FLAGS=+S 2:2'
MIX_ENV=test`. Elixir 1.18.5, OTP 28, ERTS 16.4.0.6, Python 3.13.15 and
OpenSSL 3.6.5 were recorded. The seven-package HTTP/QUIC/TLS cohort is 0.21.4;
lock SHA256 `aa9220766e1699f5cfa9d8513df95910a613cf2cbba37e8ce977267e3b68d9ab`.
The public ManagedTransport facade SHA256 remains
`2f89d9535c116dfc129f7e64c36d54256271a24405d1f860d58911e2bc397e5a`.

Finite resource, per-handle metadata pin, request token and owned serialized
payload limits govern admission without queues. The payload counter covers
compact Gaoxy policy and metadata/control slots. It excludes opaque dependency
handles, process heaps, sockets and native/OS memory. It is not a total-memory
reservation or native reclamation certificate.

Request completion and physical transport retirement settle different holds.
Helper and creator termination remain independently joined. Unknown request
completion retains its token even after confirmed physical retirement; late
cleanup cannot rewrite an earlier failed stop result.

## Remaining gates and unchanged boundaries

Complete Steps 6–7, independent SPEC/CODE review, fresh scoped verification and
local commits before declaring the foundation DONE. Record real public Fetch,
RequestCompletion and ManagedTransport behavior against independent TCP and
verified TLS peers, exact bodies/trailers/request identities, genuine remote EOF,
all owned process/thread/socket joins and successful fixture removal.

Production endpoints remain dedicated H1. Managed-H1 endpoint/Session/generation
activation, groups/probes, upstream H2 and full M3 acceptance remain separate.
No foundation push, release, deployment, production data/certificate change,
public management, Vault change or disabled release-artifact E2E enablement is
authorized here. Historical hosted `BLOCKED_ENV` remains separate from local
foundation evidence.

Inherited unsuccessful UP2 counts remain **20 live / 8 production / 3 harness**;
**Astra recovery 2/2 exhausted**. Ledger repair 1 passed; peer source repair 1
passed source review. Step 5's initial implementation has one harness execution
failure and one production review rejection; its repair 1 passed. No
unsuccessful foundation repair is recorded yet. Expected TDD RED outcomes do not
add unsuccessful repair rounds. Historical evidence and
the reviewed dismissal of `gsmlg-dev/http_fetch#97` remain intact.
