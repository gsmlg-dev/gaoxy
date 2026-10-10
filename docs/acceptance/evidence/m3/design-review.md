# M3 independent design/plan review

Date: 2026-10-10. Reviewer: independent Sol worker `upstream_cleanup`.
Assignment: review only; no design, plan, or implementation edits.
Worktree: `.trees/m3-gateway`, branch `codex/m3-gateway`.
Current checkout: `c1dfa94ef34e2b2c760b0a024b45aeb825e790ec`.
Design implementation baseline: `71f1b02032b440c5626263bd48aa4f622260e70a`.

**Final disposition: PASS — specification compliance and feasibility/quality.**
The initial findings below are historical and resolved by the independently
re-reviewed revision. No actionable findings remain before implementation.

## Final revision re-review

Design: 533 lines, SHA-256
`84c9064d5944fe71b6021ba25834f32acf321e7ff782561483ef2d9af45a0762`.
Plan: 212 lines, SHA-256
`fa1fc2d3a6c44ceaf97809b83277d6eb66393ccce5502c36ef9da8c5260b6c38`.

- Initial upstream-trailer finding resolved: design lines 43–51 and 502 name
  the distinct prerequisite; plan Task 1 and progression gates explicitly
  retain both #66 and #67. Feature [#67](https://github.com/gsmlg-dev/http_fetch/issues/67)
  was routed under existing authorization with source/public documentation
  evidence and no wire-test claim.
- Initial half-close finding resolved: design lines 369–387 select the
  supported synchronous passive owner pump for native relays and CONNECT,
  finite receive polls, explicit drain/monitor/writer handling, independent
  directions, and delayed callback return until bounded completion.
- Initial userinfo finding resolved: design line 349 now requires rejection.
- HPAX reserve/minimum validation is executable through the proposed pure
  Limits contract; the caller-supplied 512 MiB example preserves core defaults.
  P0 still must substantiate its allowances with the actual codec/runtime.
- Prepared/retiring group owners have explicit count/byte capacity and
  replacement rejection while old cleanup holds consume capacity. Pure Router
  snapshots remain outside that resource registry.

The revised source hashes were checked after both document owners stopped
their edits. `git diff --check` passed (exit 0). No implementation/runtime
acceptance is inferred; scoped implementation reviews and prescribed gates
remain required. The 10-minute local soak remains a design choice within the
existing sustained-load requirement and introduces no external permission.

## Initial review record

Reviewed entire `docs/designs/m3-gateway.md` (480 lines) and
`docs/plans/m3-gateway.md` (209 lines), `implement-plan.md`, `AGENTS.md`, and
the relevant current admission, HTTP, parser, HTTP Fetch, and Thousand Island
contracts. The architecture author confirmed its edits were stopped before
this conclusion. Review order: specification compliance, then feasibility and
quality. This is not implementation acceptance.

Reviewed SHA-256:

- Design: `b30f4d621981d6adf35168254551792bfdcaa27bea1a27131f16afd2a0408d2a`.
- Plan: `d7b91f01821482f19e288d798ffbb443dfba775c90dbba58375b18d4c9f59124`.

## Specification compliance: NEEDS_CHANGES

**P1 — Track H2 upload trailers as an additional upstream prerequisite.**
`docs/designs/m3-gateway.md:35` and `:449`, together with
`docs/plans/m3-gateway.md:74`, describe #66 resolution/dependency qualification
as the upstream-H2 unblock condition. However, the pinned
`deps/http_fetch/lib/http/http2/body_bridge.ex:143` handles uploaded trailer
events by stopping the stream with `:request_trailers_unsupported`. #66 requests
pooled completion and does not request upload trailers. The existing product
requirement (`implement-plan.md:218`) preserves trailers across proxy paths.
Explicitly add upload-trailer support to the P8 prerequisite/capability matrix,
route its missing public feature under AGENTS if upstream H2 is implemented,
and require a real-peer request-trailer regression before upstream-H2 acceptance.
Independent downstream-H2 → dedicated-H1 work remains unblocked.

The remainder respects the established M3 goals and application boundaries:
native H2, preserved H1/Plug/Phoenix, authenticated forward/CONNECT, separate
TLS modes, bounded UDP associations, groups/health, stable-listener generations,
and honest upstream pooling blockage. No extra product scope or routine approval
pause is introduced. Vault, restricted release-artifact E2E, publication,
deployment, production-data, and management-exposure boundaries remain intact.

## Architecture/feasibility quality: NEEDS_CHANGES

**P1 — Specify the supported passive owner pump for TCP half-close.**
`docs/designs/m3-gateway.md:339` presently suggests testing the TI close callback
then routing an upstream issue if it cannot preserve half-close. The dependency
already documents `handle_close/2` as its terminal callback
(`deps/thousand_island/lib/thousand_island/handler.ex:268`), and its generated
`tcp_closed` handler stops the owner (`:420`). Returning normal `{:continue, ...}`
also rearms `active: :once` (`:644`). A duplex relay relying on this callback
path cannot keep the downstream owner alive to deliver reverse bytes after FIN.
TI explicitly supports synchronous `Socket.recv` within its native callback
(`:12`, `:61`). Specify a synchronous passive pump in the socket owner, including
finite polling of receive/write/drain results and `exit_on_close: false`, and
defer callback return until both directions finish or a deadline fails. Qualify
that public path with Task 3's FIN→remaining-response wire assertion rather
than treating the documented callback semantics as a missing upstream feature.
The same rule must cover CONNECT's transition from the H1 endpoint callback.

**P2 — Preserve strict userinfo rejection.**
`docs/designs/m3-gateway.md:315` says forward HTTP strips userinfo. Current
`apps/gaoxy_http/lib/gaoxy/http/http1/parser.ex:159` rejects absolute-form targets
containing userinfo. Change the design to reject userinfo before authentication,
DNS, or dialing; stripping it implies accepting a currently invalid target and
weakens the intended strict request-target boundary. Add/retain the negative
wire case in the policy/parser compatibility gate.

## Important implementation prerequisites already required by the design

- HPAX pre-decode accounting is correctly required before `decode/2`, with
  retained-table/copy/list overhead and transient release after validation.
  For its default maximum compressed block/table, the payload bound alone is
  `16_384 * (4_096 + 2) = 67_141_632` bytes, above the core's 1 MiB default.
  P0 must derive and document the complete minimum, reject undersized enabled
  configurations before binding, and validate against the full service limits;
  current `HTTP.Options.normalize/1` only receives handler options. Do not
  silently raise core defaults or claim an application counter is total RSS.
- Stream-owned admission leases and guardian attachment preserve the actual
  PID-sensitive Admission contract. Worker death, owner/writer death, and
  delayed public upstream completion remain required deterministic tests.
- Snapshot/CAS outside endpoint execution avoids blocking the generation owner
  and avoids an old-Router registry. Initial reload explicitly selects prepared
  group owners. Keep runtime replacement unsupported until retired-owner count,
  bytes, pending cleanup holds, and retirement deadlines have finite bounds;
  repeated reload must not accumulate owners awaiting unresolved guardians.
- Public `connect_address` preserves original authority/TLS identity; explicit
  manual redirects and numeric pinning close the DNS re-resolution gap. Mixed
  DNS answers, IPv4-mapped IPv6, disallowed address ranges, proxy credentials,
  and certificate name/trust failures remain real-peer security gates.
- The 10-minute soak (`docs/designs/m3-gateway.md:452`) is a chosen measurable
  implementation of the existing sustained-load requirement, not a pre-existing
  user-specified duration. Its loopback execution needs no new external
  permission; results must retain offered/completed/error counts and finite
  teardown evidence. No hosted CI/deployment inference follows.

Checks: full document reads, source/API trace, and `git diff --check` (exit 0).
No runtime tests were required or run for this review. Three actionable findings
remain for the document owners; no code change or upstream workaround was made.
