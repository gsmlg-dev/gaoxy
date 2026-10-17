# Managed H2 Same-authority Identity Rotation

Status: READY FOR IMPLEMENTATION after independent readiness SPEC1→CODE1 PASS. All successor runtime gates are NOT RUN.

This is the existing Task5 requirement in `docs/plans/m3-upstream-transport.md`: replace CA contents at the same caller-owned path between preparations, change the numeric address while preserving the authority, and prove old/new trust, routing, hostname rejection, credential isolation and resource retirement. The group Generation predecessor closed locally at feature `f7b4c32c24a33b5e34c4ce909943846d5335bc0d`, documentation `4f08008f2bdb830bbc0191ba9db39786bb7ea905`, tree `727c9bf62dd4109eddf4c5dac2361bf07ade8141`. Its actual closure receipt is preserved in this stage's kickoff evidence.

Worktree `.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`. Evidence: `docs/acceptance/evidence/m3/managed-h2-identity-rotation/1792172407862323696/`. HTTP Fetch/Runtime 0.21.10 and the lock remain unchanged. Continuing authorization selects and executes this design without another routine approval.

## Chosen approach and scope

Extend the existing fixed and group Generation tests with TLS-only identity-rotation cases for native H1 and H2 downstreams. Reuse their real candidate holders, checked Store captures, independent accounting, dispatch/return barriers, original completions and physical retirement joins. Add explicit numeric bind-address/listen-port controls to the independent Python H2 peer, retaining existing defaults. Browser qualification uses separate derived fixed/group fixtures, each with two TLS rows. No production change is currently justified.

The caller reads a bounded public PEM file into DER before calling the existing four-key preparation API. Existing `ManagedH2Preparation.prepare_policy/1` copies DER into immutable `cacerts` and keeps URL host/SNI separate from `connect_address`. A path-valued production trust API would add unnecessary product surface. Configuration-only tests would omit the required network and lifetime witnesses. The caller-bound real-peer approach exercises the existing contract with the smallest change.

Positive scope is fixed and two-member/single-owner group, TLS-H2 upstream, native H1/H2 downstream. Existing h2c cases remain required scoped compatibility; they are not trust-rotation evidence. This slice does not close the complete streaming matrix, multi-owner composition, twenty-reload plateau, selected-A R32/B-available saturation, standalone integration, managed load profiles, H3 accounting, whole Task5 or M3.

## Identity and preparation sequence

Use independently generated test chains and concurrent numeric loopback listeners. Fixed uses old `127.0.0.1:P` and new `127.0.0.2:P`. Group adds old B `127.0.0.3:P` and new B `127.0.0.4:P`. P is the first listener's actual ephemeral port; every later listener must bind that exact port on its distinct address. All sources use byte-identical `https://localhost:P`. There is no fallback to another port, wildcard bind or DNS alteration.

For each fixed/member slot:

1. Copy only the old peer's public CA into a stable test-owned PEM path. Read at most 1,048,577 bytes before decoding, reject an over-limit source, and require the fixture's nonempty bounded DER certificates. Prepare OLD through its real coordinator.
2. Capture OLD native request(s) after genuine Store source-pin acquisition and before forwarding checkout. For groups, first complete real member health probes as described below.
3. Replace the contents of the SAME path with the new public CA, decode that path again, and prepare NEW with the new numeric address. Assert unchanged path/origin/host/port, distinct PEM/DER/leaf hashes and distinct actual resource identities.
4. Activate NEW through the real CAS, release actual preparation/baseline holds, and require OLD admission closed while original OLD captures remain valid. Remove or replace the caller's source PEM with invalid public text before forwarding.
5. Dispatch captured OLD and fresh NEW through their real endpoints. Their new TLS handshakes must reach the intended numeric peers with h2 ALPN and SNI `localhost`; exact `:authority`, escaped target, response bytes and per-peer counts must agree. Inspect actual retained OLD/NEW policy DER/address and verify OLD did not change after replacement. No file is reread at checkout.

Distinct old/new request targets identify captures; unchanged authority does not mean the two deliberately different targets are identical whole request URLs. Public evidence contains hashes and numeric identities, never key material or credentials.

## Group health and cold connections

An existing warmed health connection alone cannot establish post-replacement trust. Each group still has two real HEAD probes, original successful completions, normal probe-worker DOWNs, healthy/nonstale members and restored probe/control accounting. After each original HEAD completion, send the peer's existing GOAWAY command with that completed stream as `last_stream` and error0. Await the exact health connection's physical termination before captured forwarding.

The first selected forward for each old/new member must have a new actual accept and TLS event, a connection different from its health connection, and the original frozen trust. Further selected-A forwards may reuse that new connection. Keep the existing standard test's warmed-reuse assertion unchanged; use a dedicated rotation request helper. The socket cases retain old/new selection0→1→0 and the last selected-A source retaining unselected B.

Each socket peer therefore has two accepts; A has HEAD plus two GETs, B has HEAD plus one GET. Browser selects only A: A has two accepts/two requests, B one accept/one HEAD. Record health closure separately from final selected-forward closure and actual G/T retirement; an already-closed B socket does not replace custodian/resource joins. The existing per-resource two-connection limit is unchanged. If GOAWAY does not yield the required finite physical close, diagnose the real result before making a bounded peer-owned close adjustment; never change private client state or infer closure.

## Security and failure witnesses

Use distinct synthetic `Proxy-Authorization` markers on OLD/NEW requests and assert neither reaches any upstream request. Ordinary origin `Authorization` remains an ordinary per-request field: when markers are sent, each peer must see only its own request's value. Do not introduce a new policy removing origin Authorization or Cookie. URL userinfo remains rejected by the existing preparation grammar; TLS options contain no client key/certificate callbacks.

Real fixed TLS denial cases cover old CA/new address, new CA/old address, and trusted CA with a wrong URL hostname. They use genuine prepared resources and Generation captures, return the existing finite502, observe the actual handshake failure and zero upstream HTTP requests, and assert no retry, H1 fallback or other peer request. Record the exact original completion before racing cleanup. A confirmed completion must satisfy its complete zero-accounting/normal-join contract. `cleanup_unconfirmed` must remain sticky with its real charged records and failed receipts; disposal of test-owned failed actors is recorded separately and is never normal success. Preserve the existing H2 negative lifecycle/group evidence and its limits.

For same-authority cross-generation misuse, retain genuine original captures and dispatch them against the other resource/group only as an explicit negative input. Assert finite refusal before checkout/bind/Fetch or fallback acquisition, unchanged original source rights and no application bytes. Do not alter owner records or manufacture authentic receipts. Group probe-only TLS refusal must be labeled probe-only; it cannot be presented as selected forwarding rejection. The four positive browser rows make no negative-cleanup claim.

## Lifetimes, accounting and verification

Complete NEW original requests while OLD originals remain pending. Then complete OLD originals, join Session/selected children and G/T request tokens, and hold OLD endpoint returns. OLD authentic source pins and custodians remain alive with closed admission. Only the last original source release permits actual G/T retirement, custodian normal DOWN and final socket close. Preserve all original independent native/accounting assertions, Service cleanup identity and finite deadlines.

No production constructor, multiplicity, cap, grammar or lifetime changes are planned. Existing fixed9,444,956/group16,478,862/startup5,963,776 accounting, actual native95/P/N/W/B calculations, H/Q65,536, <=64 handles/receipts, C2/R32/P0, max_resources4/pins256/request_tokens64/payload8MiB and Service512MiB limits stay in force. Actual admission must prove each overlap. Changed test source operands are recomputed by the existing independent helpers. A newly necessary retained production constructor or lifetime change requires explicit bounded source SPEC→CODE before runtime consumption.

Independent design/readiness SPEC precedes CODE. Freeze and review new fixture sources before runtime, then full implementation SPEC→CODE, followed by fresh unfiltered scoped tests, strict compile, active format/Python/JavaScript syntax, core/HTTP isolated consumers, and four real browser rows. Fixed and group browser commands qualify two rows each; their aggregate is four rows/eight root-viewed images. Keep real Actor exits, process groups, readers/adopted waits, original completions, loaded-source/BEAM identities, live-before-close/request_clean, explicit Chrome close, final zero/joins and listener rebind.

Root is the sole repository/evidence/Git writer and runtime/build/test/browser operator. Delegates own explicit `/tmp` proposal/review files, preserve concurrent edits and never run competing fixtures. Preserve every original failure and cumulative counter; Astra is exhausted at2/2. Failures enter Sol diagnosis with unchanged assertions. Final acceptance must bind exact argv, source/environment, nonzero counts, exits, joins and artifact hashes. Local conventional commits follow independent review and actual disk/index/commit verification. No push, release, deployment, production/Vault/certificate/public-management/account changes or disabled release-artifact E2E activation is authorized here.
