# Managed H2 group accounting and activation — design 1

Status: ADOPTED for bounded implementation; independent design review pending. Implementation and runtime acceptance NOT RUN. Root owns repository/runtime/evidence/Git; source-only authors and reviewers own only assigned /tmp artifacts.
Baseline R: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`
HEAD: `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`.
Predecessor queued-terminal control is committed and verified; tree `a26656f16425d35ccc08584ee0486abb296a3c39`. Its authenticated actual local-commit receipt is preserved in this stage evidence.

## Product outcome and boundaries

Enable explicitly prepared homogeneous managed-H2 groups over existing public
transport APIs: bounded selection, request forwarding, health probes and genuine
cleanup. Preserve H1, fixed H2 and H3 behavior. Permit homogeneous :http2 or
homogeneous :h2c groups; reject mixed protocols/profiles for this initial package.
This is the recommended narrow supported profile, not a new mixed-protocol
feature. Existing H1 accepted inputs retain their existing rules.

Gaoxy owns no new client pool or native transport. Preserve original guardian
authority, original opaque completion identity, real Resources pins, staged
selection/open/result/bind/drop transitions and queued-terminal guards. Do not
introduce publication, deployment, operational certificates, public management,
Vault, disabled release-artifact E2E or production-data work.

## Accounting claim

Unit: serialized external-term payload of named owned original source roles.
This is the existing payload-accounting scope, not heap/VM/native/stack/process
memory, arbitrary incoming mailbox or a private dependency proof. The fixed
endpoint contract remains exactly **9,444,956**. A new group supplement pays
conservatively for complete group source roles, even when that duplicates a
payload already budgeted in a fixed role. It never discounts the fixed base.

An original complete containing value pays for its contents once within that
role. Equal originals held by distinct named owners/roles may each be charged;
this is an upper accounting convention, not a physical-copy count. A projection
may replace only recognized opaque scope/completion interiors or payload already
assigned explicitly to the unchanged fixed ledger. Every exclusion names its
other ledger role. No arbitrary map key or diagnostic term is projected away.

All new limits below are **enforced H2-only design choices**, not measurements or
claims that current source already enforces them. Exact shape, bounded proper
traversal, finite scalars, logical/backing limits and capability identity precede
external_size. No constructor builds an unbounded list/map merely to check size.
Public PIDs/refs use the fixed contract's per-scalar ETF<=2,048 rule; signed64
times and finite module/enumeration atoms apply. Opaque capabilities are original
values at runtime; account only their already accepted typed shell markers.

## Finite original-role caps

Introduce internal `ManagedH2GroupAccounting`; expose an executable contract,
validators/projectors and reservation function to production call sites/tests.
No new dependency or public owner option is required.

| Symbol | Original role and exact content | New cap bytes |
| --- | --- | ---: |
| P | pump group projection: GroupEndpoint/H, captured full resource_pins, transport handoff handles/source_pins/ref/used, finite group-specific controls; fixed Exchange/policy/event roles have typed named markers | 1,048,576 |
| S | complete Session or normal Probe state projection: every exact allowed field retained; original H/selector/selection, neutral or prepared request, Selected/awaiting, K, T/pins and controls remain charged; fixed event payloads and opaque interiors use typed ledger markers only | 2,359,296 |
| L | complete Selected3, with compact ID, actual validated C and max_inflight | 196,608 |
| N | original validated compact neutral6 | 205,337 |
| K | original checked3 with only opaque scope interior projected | 1,183,744 |
| X | actual boundary context6, including complete H, actual instance, limits and signed times | 131,072 |
| R | complete assembled request8 (or complete preparer return assigned this role), validated by Envelope | 205,337 |
| O | complete prepared options7, including R and K, and finite timeout/deadline/write controls | 1,572,864 |
| A | complete actual Session args10 / normal Probe args7 / caller `{Module,args}` data root; one containing role, not separate args plus wrapper charges | 786,432 |
| W | actual public supervisor start request root, containing A and the finite call/normalized-child shell | 851,968 |
| I | one complete synchronous group/resource owner call or pin response envelope, including H/pins/provider wrappers/keys/handles and finite call controls; only supported completion interior may use its opaque marker | 393,216 |
| U | supported original open-result envelope, with original handle/completion/scope interiors typed opaque and shell identity validated | 8,192 |
| E | closed group control envelope family total reserved per phase, including transient Lifecycle replies, identity/handoff, cancellation/timer/monitor shells and recovery startup shells | 131,072 |

Keep the existing HTTP acceptance of complete captured pins: at most64
aggregate entries and complete ETF<=65,536. The group's accounting cap196,608
is conservative and does not widen that existing HTTP gate. Preserve every
captured pin, including unrelated routes and nested Generation captures. Only
this group's required dependency subset is at most33 handles (H plus1..32 Ts).
Do not impose a new global33 or unique-handle64 limit on the aggregate capture.
Validate the required H manifest and each actual declared provider manifest
using real Resources.validate (each at most64/65,536), with bounded64x64
aggregate traversal. I pays the complete enclosing response shell as well.
G public pins have7 keys without holder; T public pins have8 including holder.
Authenticate G holder through existing owner request-pin authority. Reject
unknown/expanded provider keys, mismatched manifest/operation/epoch and stale
identity while preserving the broader unrelated H1 shapes accepted by the
existing mixed-generation path. Never discard unrelated captures to fit a cap.

Actual Session args10 retain GroupEndpoint plus selector
`{:group,H,all_matching_G_provider_pins}`; the full capture and filtered T
source_pins/handoff handles remain in the pump. Before alias drop, S may retain
H through config, selector and selection. Normal Probe uses args7/state23;
recovery uses args4/state5. Validate these distinct actual source constructors
and nil/staged alternatives, with no fabricated public holder or normal-state
schema substituted for recovery.

P and S projectors are exact constructors, not `Map.take` followed by accepting
unknown keys. Their known data-valued fields remain in full; known absent values
are nil. S covers all accepted normal state keys and staged alternatives. For
post-head fixed response/body events, preserve the existing fixed ledger and
replace only those named payload fields with typed role markers; validate their
original bounded values through the existing adapter first. Do not serialize a
raw event/monitor reason as part of S/E.

I covers the full actual G checkout/bind/finish or T pin/checkout/finish wire
envelope, rather than pretending its H/pin payload is free because S also
retains it. These calls serialize within the actor; one I slot per phase covers
the current actual synchronous call/response source role. Selection replies L
and checked-client replies K are their separate explicit actual roles. Validate
the enclosing fixed scalar shell in E; no payload is dropped without a role.

E is a conservative finite allowance for named serialized wrappers, not a cap
on arbitrary external mailbox traffic. Implement a closed family schema and
one live source slot per enumerated synchronous/public control transition.
The accepted queued-terminal guard consumes at most one recognized event;
unmatched traffic remains pending. No arbitrary mailbox size or scan-time bound
is claimed, and this allowance never charges or projects away arbitrary incoming
traffic. Any new retained control queue/family requires ledger revision. Prove named wrapper maxima from fixed syntax and the
existing scalar bounds; do not inspect process dictionaries/private actors.
The explicit E arithmetic is16 existing closed fixed control-envelope slots
at2,048 plus4 additional group source-family slots at24,576 =131,072. The four
additional families are: (1) raw-root/protocol/instance validate or transport
handoff identity; (2) Service/Admission lease-adjust/attachment scalar call and
reply; (3) G/T synchronous owner-call scalar shell with whole I/L/K payload
extracted to its charged role; (4) Probe claim/recovery/ready/finite outcome
scalar shell. Each family uses one current source slot through its serialized
call/return or message transfer; no retained per-call history. Their exact
constructors must include every original scalar, preserve matching PID/ref
provenance and reject expansions. Required tests must exercise raw-root8,192
plus real handle/scalar overhead and maximal existing public scalar caps.

## Executable phase table and exact formula

The startup data ownership roles are launch caller, actual supervisor request,
child init input and returned initial state. A's caller includes `{Module,args}`
when that is the actual original. Child input uses A; returned state uses S.
These are four named source roles, not a universal claim of four physical copies.
The test-support catalog's CALL/ENTRY descriptors are syntax only and add no
payload roots or charge. Temporary saved entry args are undefined.

| Phase | Conservatively charged simultaneous named original roles | Sum bytes |
| --- | --- | ---: |
| startup | P + A(caller) + W(actual request) + A(child init input) + S(initial state) + E | 5,963,776 |
| selected/awaiting | P + S + L(actual selected reply/local) + I(actual owner call/pin response) + K(actual checkout reply) + E | 5,312,512 |
| boundary preparation | P + S(input retained by callback) + L + N + K + X + R + O(return construction) + E | **7,033,906** |
| open/result/bind | P + S(staged caller state) + O(actual open input) + U(actual original result) + I(actual bind call) + E | 5,513,216 |
| streaming | P + S + E | 3,538,944 |
| cleanup/recovery transition | P + S + I(actual finish call) + E; G/T recovery owner records remain separately charged | 3,932,160 |

Here L/N/K/X/R/O are actual existing constructor inputs/returns at their source
ownership points, not a synthetic combined map invented to obtain a size. This
deliberately charges both retained S and caller argument/return roles; it avoids
an undocumented claim that callback aliases erase a fixed slot. Within O, R and
K are not added again. R's separately listed role is the actual preparer return
before transfer into O, conservatively reserved even if their lifetimes shorten.
Release source roles on callback return/continuation transfer, not forced GC.

    G = max(5_963_776, 5_312_512, 7_033_906, 5_513_216, 3_538_944, 3_932_160)
      = 7_033_906
    B_group_request = 9_444_956 + G = 16_478_862
    B_group_request_32 = 527_323_584 (cleanup reservations only)
    B_normal_h2_probe = B_group_request = 16_478_862
    B_normal_h2_probe_4 = 65_915_448 < default probe_bytes 67_108_864

Probe conservatively reserves the same formula, including unused P/fixed
renderer/data roles; do not discount those roles in this first package. Its
actual startup and preparation schema is smaller and must satisfy the same caps.
These numbers are design arithmetic, calculated from proposed enforced caps.
They are not executed source/runtime acceptance. Independent review must verify
the table/source mapping; production validators must enforce it before activation.

## Production insertion and release points

* HTTP dispatch: choose ManagedH2Client immediately from H's immutable profile;
  validate original target/path/query/backing/fields, preserve empty query.
  Before the new group-specific neutral copies/startup roots (existing Exchange
  inputs remain under their ordinary request lease/fixed roles), use existing authenticated
  `Admission.adjust_bytes(gate, lease, +5_963_776)` to reserve startup bytes on
  the actual request lease; denial returns before child/selection/open. Build
  neutral6 with prepare_group_source. Validate GroupEndpoint/H, full captured
  pins and P; build/validate actual A and enforce W's public-source bound before
  starting Session. The future GenServer call/monitor reference is created
  inside DynamicSupervisor.start_child and is not inspectable before that
  supported call. W is bounded by validated A plus65,536 closed source-derived
  wrapper overhead, not a fabricated authoritative request/ref or private
  supervisor introspection. Pure constructor tests cover admitted public shapes.
  Init validates child input A and state S without calling its blocked owner.
* Keep existing Service attach_cleanup sequence: before attach, Session has no
  activation token and cannot select/open. Attach the full16,478,862 to the real
  child while startup lease bytes remain charged. Admission adds cleanup bytes
  without replacing lease bytes. Release only the extra5,963,776 startup delta
  in the outer caller AFTER the args-owning helper has returned and its startup
  source roles ended. This also covers Service activation racing the caller's
  return; selection/preparation may overlap still-owned startup roots. On denied
  attach, cancel and join the owned inactive child and unwind the helper before
  refunding the startup delta; ambiguous/unconfirmed cleanup fails closed.
  Test exact no-effect/child-join lifecycle and startup/refund ownership. Use
  the existing public adjust_bytes API, without a new Service/Admission API.
  Peak extra bytes per such overlapping request are22,442,638, plus existing
  ordinary lease bytes;32-way simultaneous startup+attach could add718,164,416.
  These are temporary budget overlaps, not a second lifetime cleanup reserve.
  Retain full Service cleanup reservation until confirmed original cleanup and existing
  required ledger finishes; never refund a failed/unconfirmed cleanup.
* After G checkout, validate original L and new S before retaining/awaiting.
  G has already atomically admitted its selection/control record. Validate
  original identity/handoff and full I before capturing; release genuine newly
  acquired pins on a local validation failure. Preserve fail-closed uncertain
  cleanup rather than forcing a refund.
* T checkout reply: existing owner policy/token admission remains authoritative.
  Validate original K, exact protocol/raw-root identity and new S before pure
  prepare. At boundary construct/validate X, N and L before assembly; validate
  actual R/preparer return and O, then sanitized output S before return. Early
  validation failure follows normal genuine cleanup with held ledgers intact
  until its protocol confirms release.
* Before open and bind: guard queued terminals first, enforce staged O/S and
  live deadlines/pins/token state; capture genuine U before any rejection.
  Preserve result/drop semantics, original identity and transport-then-group
  bind. Drop opening request/K/Selected/config roles on the staged transition;
  residual submitted_url occupies its existing fixed request role until head.
* Streaming/cleanup transitions validate closed S/P controls without copying
  raw public payload/diagnostics. Genuine original completion cleanup precedes
  normal T finish, pin release, G finish and Service completion.
* Probe owner: build and validate A/W first; atomically install provisional
  probe entry plus full16,478,862 before child start, then start. On success
  attach child PID/monitor; on failure remove/refund that exact provisional
  record. Child claim queues until owner callback returns, so a provisional
  unclaimed record must reject wrong claimant. Never allow a zero/H1 reserve.
  Every normal finish/recovery refund subtracts the stored entry bytes once.

## Separate owner ledgers and finite controls

For H2 groups, construct the complete retained group record projection before
insertion. Include both `compiled` and expanded runtime `members`, their actual
configs, handle/manifest and finite health/cursor/inflight/lifecycle controls.
Omit only exact self-accounting `bytes` from that projection. Reserve its actual
complete initial ETF bytes PLUS131,072 growth bytes for bounded mutable controls,
and enforce a per-record total charge cap **12,582,912**. Charge that stable
total against existing max_config_bytes until group removal. Before each update,
validate original complete record and require its ETF<=the reserved total; no
new mutable control growth may escape that charge. This avoids making a safe
health update depend on spare config capacity at the time of the update.
For this new H2 profile, saturate consecutive success/failure counters at their
configured thresholds (<=100), preserving health decisions; keep all checked/
due/deadline times signed64 and inflight/cursor/probe fields bounded. The32
member refs/scalar fields fit the explicit131,072 growth reserve under existing
per-scalar bounds; executable constructor tests must verify it. Keep existing
H1 accounting/counter behavior unchanged. Unknown/expanded update fields fail
closed without overwriting a valid held record.

Add a private H2 owner-control byte ledger capped at **16,777,216** in addition
to existing real count limits. Charge original complete record projections:
pin record<=196,608; held selection<=32,768; held probe<=32,768, including added
recovery PID/monitor fields. Completion interior is the existing opaque shell;
all other original fields remain measured. A pin record containing any H2 group
key is charged in full, including other keys, so mixed resource preparation
does not evade charging or reject otherwise valid H1-only work. Admit provisional
pin/token/probe/recovery updates before effects and store exact per-record bytes.
Reserve a conservative provisional record/delta using finite scalar maxima
BEFORE creating monitors/timers or starting a child, because genuine future
identities do not yet exist. Then install genuine identities and reconcile the
actual measured charge; release only proven excess and roll back exact owned
effects on failure. Do not fabricate authoritative refs/PIDs. Explicitly exclude
only each new exact self-accounting control_bytes field from its charge;
probe.bytes remains the full request/probe reservation, a separate ledger.
Pass real group key/index from launch_probes to launch_group_probe so provisional
records retain actual finish authority. Cover every pin/token/probe/recovery
mutation, passive finish failures, lifecycle/reconciliation, duplicate/late
outcomes and H2 threshold saturation. On exhaustion fail closed/retire as
appropriate; never lose a held record to fit the budget. This is an internal
H2-only finite design choice.

Actual G config/control payload, Service request bytes, P full probe bytes and
T policy/token/pin bytes are independent ledgers. G may refund an authenticated
recovery result before helper DOWN under its established protocol. It does not
imply T refunds: T independently retains until its own join/cleanup succeeds.
No helper-through-exit or strict T-before-G recovery order is required. Preserve
original guardian bind/finish auth and prebind nil completion's retained holds.

## Admission/profile and activation wiring

Options recompilation preserves real H2 protocol/client/transport. Managed H2
members require exact Envelope config; compact IDs/health path; homogeneous
protocol; each real transport matches instance/raw root/protocol at preparation.
H is exact8 with execution_profile:managed_h2 and raw-root max_url_bytes. Real
Resources.validate remains mandatory; no profile grants runtime authority.

Update GroupEndpoint documentation/profile handling and HTTP selected_client
for both pump and Session. Ready currently changes limits/deadline only; it
cannot repair a pump initially running the H1 upload/ACK client. New group
reservation selection is explicit and separate from ManagedH2Client's fixed
reservation callback. Probe launch must implement reserve/start/record rather
than merely change its literal gate branch to `:ok`.

Change the literal accounting_not_ready denial as a controlled final integration
step after accountant/constructor/schema/capacity-denial/no-effect gates and
source review of production admissions pass. Successful public B/D pin/probe
claim/open/bind tests remain authenticated RED until this gate change; they
cannot all pass while launch_group_probe still returns state at literal denial.
Do not invent a bypass/fake client to avoid this dependency. This source change allows real live gates to execute; it is not stage
acceptance. Run complete live/browser and full independent SPEC/CODE review,
then fresh gates, before committing accepted activation. Preserve actual
resource/Service-token guards. Tests that
currently assert literal denial must instead demonstrate public no-effect
denial on capacity/invalid schema/unauthorized state plus genuine successful
admission/open/bind/cleanup. No weakening to "some error" or accepted fake open.

## Acceptance and source receipt

See [companion plan](../plans/m3-managed-h2-group-accounting-activation.md) for RED/public admissions, pure boundary/cap counterexamples,
real h2c/TLS peers, required downstream matrix, browser and compatibility gates.
All implementation/test/live/review checks are NOT RUN in this source-only task.
Root owns repository/index/Git/runtime/evidence. No third Astra or dismissed
http_fetch#97 work. Proposal repairs0; inherited Astra2/2 exhausted. Current
cumulative Sol implementation counter is parent-owned, not reset here.

Complete source identities are in this stage kickoff1.json. Key source SHA256s:

```
fa49c98a914947e517436d41f2d8d0bacb15a5ed8cec3c085ba635bbe48e9138  group_endpoint.ex
f6f638d1f1f88b53c8282dc121466eb0614d241fe8ec56cc57a8a2a8b0d4096e  upstream_transports.ex
169f311b2a4995b3de901ac41b5c2768208c8f8c3e26d2e57a58fdefdc013a75  gaoxy/admission.ex
740d69a364e52cda9d05a997136ce864e9ec464149adcc81045bc9c109ed4472  gaoxy/service.ex
9e0c90640fb057108e3dcd174b56186e8194f8f06bf946cdf03bcc68ac12bf71  gaoxy_http/exchange.ex
c80d8e60c2973dbfedd78761c81ccc142f90f486268b36c03ff29746f521d99f  http/session.ex
9f3de8e0fc74f8ebfe358629d3e11ca6c65ee20c34fe4043b4b2770f199bcd63  upstream_groups/probe.ex
```

The actual predecessor commit/tree above and unchanged Session c80d8e60c2973dbfedd78761c81ccc142f90f486268b36c03ff29746f521d99f are bound by the stage kickoff receipt before implementation.
Necessary adjustments to proposed caps/table require explicit written arithmetic
and tests, not silent absorption. No user product decision is currently needed.
