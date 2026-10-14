# Fixed H2 activation architecture proposal

Source: completed read-only `/root/h2_fixed_activation_architecture` report,
resent to the parent on 2026-10-14. Gate: `PROJECT_ARCHITECTURE`, zero recovery.
Last inspected baseline `29068aa8575d4dfd47d04200d9019bdc27d2d193`, worktree
`.trees/m3-h1-resource-foundation`; lock SHA256
`aa9220766e1699f5cfa9d8513df95910a613cf2cbba37e8ce977267e3b68d9ab`.
No additional inspection, edits, runtime execution or recovery occurred on resend.
This is a proposal requiring written design, independent readiness, implementation
and executed evidence. It does not change the accepted pure-preparation worksheet
or declare a live reservation. Astra recovery remains 2/2 exhausted.

## Boundary and implementation

Add `Gaoxy.Proxy.ManagedH2Client` implementing existing `UpstreamClient`;
reuse owner, Custodian and Session cleanup. Preserve H1 `HTTPFetchClient`.
Activate only fixed TLS-H2 and h2c after Generation and preparation acceptance.
Groups/probes, Generation-H2 acceptance, standalone configuration, sustained load
and publication are later slices. Keep the partial worksheet subtotal 2,918,508
as a prospective sum rather than a runtime reserve.

Construct a validated compact envelope before `DynamicSupervisor.start_child/2`
in `HTTP.start_session/5`:

```elixir
%{
  protocol: :http2 | :h2c,
  url: compact_binary,
  target: compact_binary,
  method: supported_method,
  fields: compact_pairs,
  body_mode: :none | :chunked | {:length, unsigned_64},
  trailer_policy: bounded_policy,
  limits: bounded_request_limits
}
```

Retain neither original Exchange nor arbitrary limits/extra request keys/path
copies. Preserve accepted preparation and effective-header limits and raw empty
query. Create upload PID after admission and prepare again before public Fetch.
Retained limits include header/trailer counts/bytes, upload chunk size and the
five proxy chunk/timeout limits: heads256/65,536; trailers128/65,536;
upload65,536; timeouts1..86,400,000; body length unsigned64; deadlines signed64.
Clear Session's envelope after Fetch and successful original-completion binding.

Preserve exact four-key trailer policy:

```elixir
%{allowed: names, dropped: names, max_count: integer, max_bytes: integer}
```

Preflight proper finite source/backing lists before split/normalization/dedup/join.
Count at most128 Trailer and128 Connection tokens, including duplicates.
Allowed<=128; dropped<=265 (128 Connection +128 removed forwarding +9 fixed hop
names). Combined token payload<=65,536+106; compact every retained token and keep
existing forbidden-name safety. Proposed ETF ceiling67,689 =82 wrapper/scalar
bytes +5*(128+265) binary wrappers +65,536 dynamic +106 fixed bytes.
Retain one request and one response policy in pump; release after use, preserving
declared-safe forwarding, identity filtering and ordered duplicates.

## Proposed enforced payload ceiling

Unit is external-term payload, never total/native/heap memory. Add a private
evaluator of exact finite request/configuration/trailer-policy/control schemas;
compute complete sizes after validation, once per projection. The compatible
`reservation_bytes/3` facade charges maxima for unavailable arguments.

| Component | Named multiplicity | Proposed bytes |
| --- | --- | ---: |
| Accepted response/upload/write | Existing worksheet rows | 2516026 |
| Complete request representations | 2*(201241+4096) | 410674 |
| Fixed configuration | Five slots*147456 | 737280 |
| Checked-out prepared policy | One Session copy | 1183744 |
| Trailer policies | Request+response | 135378 |
| Public Response extra metadata | One transient projection | 213965 |
| Control/message wrappers | Closed finite schemas | 589824 |
| Normalization scratch | Four named slots | 266523 |
| Conservative facade/request | Sum | 6053414 |
| R32 allowance | 32*6053414 | 193709248 |

These constants require executable validation and independent review:

- Request Q201,241+4,096 covers wrapper/scalars/limits/body-mode/PID, with two
  slots for source/canonical overlap and no arbitrary maps/diagnostics.
- Public nine-field URI<=132,096 (2*65,536+1,024), plus15,360 for exact HTTP config,
  finite handle/client/protocol/limits. Five slots: pump config, Session config,
  fixed selector, awaiting-checkout config, opening config. A sixth copy changes
  the ceiling.
- Policy1,048,576+2*65,536+4,096=1,183,744 includes accepted SSL/socket limit,
  origin occurrences and finite fields; owner metadata uses its separate ledger.
- Control whitelist: Session/pump lifecycle scalars, current/original handle
  shells, four monitor pairs, three timer slots and fixed handoff/pin/token/
  message wrappers; <=256 scalar leaves and4,096 constructor bytes. ASCII
  keys/enums<=64; scalar ETF<=2,048; bounded integers. 256*(67+2,048)+4,096=545,536
  below589,824. No functions, payload binaries, histories, queues or arbitrary
  nested errors. Normalize errors, retain one poll timer.
- Scratch: one additional field list68,615, joined declaration65,542 and two
  token-list workspaces132,366 total266,523; release before reusing slots.

Opaque scope/completion/receipt internals are outside this unit, with bounded
capability counts and public lifecycle obligations; do not serialize, assign
zero charge or present a native-memory certificate. Resource-owner policy/pin/
token/control payload ledger remains separate from service request/body reserve.

## Public response metadata

Public `HTTP.Response` includes URL/status text/informational blocks/wrappers,
which the worksheet omits. Before head delivery, validate protocol`:http2`
(including h2c), final status200..599, nil/empty or PID-streamed body (no buffered
body), URL nil or bounded submitted-derived URI, status text<=64, proper
informational blocks<=128 with aggregate name+value+32<=65,536 and total fields
<=2,048. Bound flags/type/PID slots and require immutable streamed trailers empty.
Initial fields separately<=256/65,536 before normalization.

Informational ceiling7+128*63+65,536=73,607;63 covers status/Headers/list wrappers.
Extra metadata132,096 URI+73,607 informational+70 status text+8,192 scalars/
wrappers=213,965, excluding initial fields already charged. Extract bounded head
and discard unused Response metadata immediately; retain no full Response in
Session/original handle. Native terminal256 fields still require adapter128
rejection before Session cache.

## Delivery, identity and cleanup

Use supported public `HTTP.fetch`, `HTTP.Stream`, `HTTP.Promise.completion`,
`HTTP.RequestCompletion`. Enforce logical/backing before copying: DATA1MiB;
upload65,536; heads256/65,536; terminal trailers128/65,536. One outstanding DATA
reference; reject overlap as`:upstream_delivery_overlap`. ACK after complete
downstream write.16KiB is framed piece rather than DATA delivery bound. Bind
original completion before ready. Preserve order:

```text
original public completion confirmed
-> owner token finished -> request pins released -> service reservation completed
```

Terminal events/death do not establish completion; uncertainty retains holds;
Custodian separately confirms scope retirement. Statuses: invalid request400,
unsupported method/target501, unavailable/capacity503, timeout504, upstream
protocol/metadata/delivery502. After response start cancel/terminate, never ACK a
failed write or synthesize completion.

Owner identity must include protocol in validation/delegation. H1 and h2c share
scheme/host/port; map H1 to`:http1` and H2 to exact`:http2`/`:h2c`, reject mismatch
before checkout/Fetch. Require managed handle, exact TLS-H2/HTTPS or h2c/HTTP,
no per-request trust/address/scope overrides. Preserve exacth2/no-fallback and
h2c prior knowledge. Generic reachability does not establish Generation-H2.

## Scope and required gates

New client and optional pure envelope; extend reservation while preserving
worksheet; policy dispatch in Options; protocol fetch/identity in owner;
initialization/client/pre-Session reserve in HTTP; fixed selection/event bounds/
envelope release in Session; bounded token preflight in Headers. Custodian need
not change. FramedResponse changes require demonstrated compatibility defect.

Real fixed TLS-H2/h2c independent peers and H1->H2/H2->H2 must prove exact ALPN/
no fallback, CA/name rejection, numeric+authority/SNI, multiplexing/reuse,
C2/R32/P0 refusal/no replay, reset/GOAWAY/sibling survival, streaming before EOF,
early response, ordered permitted trailers, raw compressed/bodyless/CL behavior.
DATA>16KiB within1MiB succeeds; over1MiB/backing rejects; upload65,537 rejects.
Exact/over head/trailer/informational/declaration limits and native-valid129
trailers reject; paused downstream proves one delivery and ACK-after-write.
Deterministic cancel/producer/Session/owner/instance death, timeouts, unread body,
pending completion, retirement/release order; malformed/improper/forged/backing
schemas and arithmetic for every component remain required.

Run relevant H1 prep/options/headers/fixed proxy/identity/handoff/Generation/
failure/group/probe/completion/wire/TLS/runtime compatibility. Shared Header/
Session changes require affected H3 tests. Independent SPEC/CODE, repair and
fresh gates precede commit/advancement.

Static source/diff inspection PASS at last inspected baseline. Runtime, compile,
tests, format and peers NOT RUN as assigned. Proposed ceilings are unqualified;
extra copies/errors/queued events invalidate the sum. No new user decision is
needed; parent can write and independently review the activation design after
predecessor gates. No further Astra recovery is authorized.
