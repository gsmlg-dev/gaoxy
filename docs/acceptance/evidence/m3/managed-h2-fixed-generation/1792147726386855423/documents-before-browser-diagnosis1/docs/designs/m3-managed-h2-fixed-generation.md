# Managed H2 Fixed-Transport Generation

Status: IMPLEMENTED, final full-stage review and fresh gates pending. Independent
readiness SPEC1 then CODE1 and browser-fixture SPEC1 then CODE1 passed. Initial
failure coverage GREEN6 passed83/0 and browserGREEN1 passed four rows with eight
images viewed. Only the pure Generation guard changes production behavior;
this singleton slice does not complete M3.

## Goal and exact profile

Qualify one prepared fixed transport route through the production checked
Generation endpoint for each explicit upstream protocol `:h2c` and TLS `:http2`.
Use native downstream H1 and H2. A request that captured the old generation
before CAS must delegate, check out and complete on the old transport even
after ordinary old admission closes. A new request must use the new transport.
Original completion and the original snapshot pin independently delay normal
resource retirement.

The predecessor native worker stage is locally closed at feature
`a39c821bb09dcdc78f4626305350dcff4dddfdb0`, documentation closure
`aa272c3dca700a9275a00bd23920d09bbd4748a1`. Its 561/0 and browser2/2 are
predecessor evidence, not this stage's runtime results. Initial stage evidence:
`docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/`.
The source/test maps there are investigations, not design or code approvals.

## Smallest change and alternatives

Before this slice, `Gaoxy.Proxy.HTTP.generation_validate/1` rejected every H2
config. The implemented branch uses the existing pure canonical-envelope validator:

```elixir
def generation_validate(%__MODULE__{upstream_protocol: protocol} = config)
    when protocol in [:http2, :h2c] do
  case ManagedH2Envelope.validate_config(config) do
    :ok -> :ok
    {:error, :invalid_config} -> {:error, :unsupported_generation_endpoint}
  end
end

def generation_validate(_), do: :ok
```

This retains the unsupported error for malformed H2 configs and the existing
behavior for other endpoint profiles. Do not delete the callback or accept H2
unconditionally: both discard the compiled-config boundary. Do not add an owner
preflight, new handle, new process, new cap or dependency change: live identity
is already checked in the authorized selection path. Groups remain separately
unqualified; this slice neither advertises them nor adds a new group denial.

The pure validator checks the complete closed config schema, bounded canonical
URI/limits, explicit protocol/scheme/client, four-field T4 and absent direct
trust/address overrides. T4 contains provider/owner/epoch/resource only. Pure
validation does not attest liveness, protocol, authority or instance of the
owner resource. Fabricated/stale T4 fails existing live baseline acquisition;
a genuine mismatched T4 can acquire a baseline but must fail existing immutable
endpoint identity binding before child pin, checkout or Fetch. Preserve this
distinction. Relabeling a struct as another protocol is not a new H1 validator
contract introduced by this change.

## Existing ownership path retained

1. `Generation.prepare`, public activation, direct Store activation and initial
   `routes:`/`router:` paths run compiled endpoint validation and exact
   route/resource-sidecar consistency before new baseline pins. CAS/deadline
   failures leave the current snapshot unchanged.
2. The native listener installs
   `{Generation, {store, accounting: ManagedGenerationAccounting}}`. The real
   native actor reserves checked capture B in its original Gate lease before
   Store/provider effects. Store acquires authentic snapshot request pins in
   its serialized current-router callback; checked append passes those actual
   pins in the original Exchange to Router. No manually injected source pin.
3. ProxyHTTP constructs the existing one-use handoff. The real native actor
   holds original T8. After real Service cleanup activation, it authorizes
   exactly one derived T8 held by the distinct Session. Owner authenticates
   holder, original public pin, operation, deadline, protocol/authority/instance
   and capacity before checkout. Session binds the original public completion
   before ready. No current-router refetch or fallback acquisition.
4. CAS acquires replacement baseline and swaps the snapshot, then releases old
   baseline. After preparation pins disappear, old admission becomes closed.
   Ordinary fresh pin acquisition fails. Authentic pre-CAS source delegation
   and checkout intentionally remain allowed; adding admission-open checks
   there would break the authorized old request.
5. Original completion is retained through Fetch -> Session -> owner token.
   Public cleanup precedes token finish, child-pin release, Service receipt and
   Session normal DOWN. The native endpoint returns only after actual Session
   join; checked Generation then releases its original source T8. Last holds
   disappearing triggers normal per-resource retirement and real custodian
   join. Whole-owner explicit retire remains a separate cancellation operation.

## Accounting and constructor boundary

No charged production constructor, lifetime, multiplicity or public API changes
were introduced. The guard is transient pure validation with no retained operand.
The existing fixed endpoint already charges one source-pin handoff and child;
checked capture already accepts T4/T8 independent of upstream protocol. Native
H2 W measures the complete actual initialized endpoint and Exchange, including
this test wrapper's actual bytes. Preserve native95 roles, P/N/W equations,
H/Q=65,536, fixed9,444,956, group16,478,862 and startup5,963,776.

Readiness traced this reuse; final source review must independently confirm it. If
implementation or repair introduces a charged operand/lifetime, reopen the
relevant independent constructor SPEC then CODE checkpoint before consuming
changed accounting. A different test wrapper does not authorize a guessed W.
There is no physical-memory-bound claim.

## Acceptance contracts

### Configuration and genuine admission

Use real prepared T handles and independent peers for positive prepare,
public compiled activation, raw Store activation and both initial-start paths.
Observe behavioral RED from the intentional unsupported denial before guard
change, separately for prepare/public/direct activation and both protocols.
All failed-run actors must still be joined. Fixture/compile errors are failures,
not intended RED. Existing shaped fake handles remain shape-only fixtures.

Replace the old blanket exclusion test explicitly: pure canonical H2 validation
passes without upstream effects; nil/extra-key/wrong-client/scheme/non-root/
noncanonical/oversized/invalid-limits configs retain the unsupported error.
Missing/extra/substituted sidecars fail `:invalid_endpoint_resources` before
baseline acquisition across public/direct/start paths. Keep H1 and generic
callback/sidecar tests intact. Valid activation legitimately contacts the owner.

### Four real socket cells

For downstream H1/H2 times upstream h2c/TLS-H2:

- Two independent manual peers, real transport owner, real Store and checked
  listener. Test wrapper forwards `init`, `resources` and `generation_validate`
  on the exact initialized ProxyHTTP config. It forwards the original Exchange
  and endpoint result unchanged. Finite dispatch/return barriers live in the
  real native actor after Store replied; they never suspend Store across CAS.
- At the original owner request-pin input, observe real Gate precharge using
  independently calculated B and original lease. Release this input before
  capture. At capture require exactly one authentic T8, native holder, Store
  acquirer, exact T4/epoch/operation/ref and no Session/token/peer request.
- CAS new candidate, release holder-correct preparation, prove old baseline
  gone/admission closed and original T8/custodian alive. Fresh old admission
  fails; releasing old dispatch still reaches its exact old peer.
- Correlate each upstream identity by peer collector/ready identity/port plus
  connection and stream. Different peer processes may both number connection1.
  Require original raw target, authority and TLS h2 ALPN/SNI when applicable.
- Inspect original public completion and genuine child T8: holder Session,
  acquirer native, same old T4, distinct ref; completion exactly equals Session
  original-request completion and owner token completion, pending at peer hold.
  New request reaches only new peer and completes while old remains pending.
- After old response, hold native at return barrier. Original completion is
  successful, Session normal DOWN, child/token gone, but source T8 and old
  custodian remain. Only releasing return permits old retirement, physical
  EOF/reset, original custodian normal DOWN and record removal.
- Close downstream; require complete actual native actor joins, Gate active0/
  bytes0, cleanup pending0/failed nil, Store stop, owner all-zero, genuine
  custodians/owner/instance joins, peer joined forced0/live0/failedfalse/exact
  requests and actual Python exit0. Verify the stopped listener address rebinds.

### Failure and authority cases

For each upstream protocol, cover stale CAS and rejected candidate release,
invalid preparation/abandonment/coordinator death, Store death with an already
captured old right, cancellation before original delegation, genuine mismatched
protocol/authority/instance before checkout/Fetch, and finite late-cleanup
failure with the original failed receipt retained after eventual cleanup.
Keep exact errors, original operation cancellation, no repeated outer acquire,
no premature pin/token/cleanup refund and final peer counts/real joins.
Missing-source refusal means a nonempty captured manifest with no matching
selected T4, alongside forged-ref and wrong-holder negative mutations of a
genuine Store source. An empty `resource_pins` list is the intentional standalone
embedding; it has no Generation provenance marker. The actual checked Store
path never deletes its receipts. This slice does not invent empty-list
provenance or change that existing standalone contract.
Partial multi-owner rollback and arbitrary multi-resource routing are outside
this singleton profile; existing generic/H1 tests remain compatibility evidence.
Use causal barriers/bounded polling; mailbox silence alone is not no-effect proof.

### Browser and preservation gates

Create a narrowly adapted fixed-Generation host/runner in stage evidence.
Reuse frozen predecessor Cohort unchanged and latest Actor/CDP custody logic.
Four rows: Chrome TLS downstream h2 and clear downstream http/1.1, each to
upstream h2c and TLS-H2. Each row performs genuine old capture -> CAS -> old
document -> new navigation, exact visible labels/URL/title/status/protocol,
screenshots and console checks. Preserve complete cohort accounting, native95
W+B, actual request-clean/live-before-close, explicit browser close, all actual
terminals/normal joins, Gate0, profile removal and listener rebind. Fixed T-only
means one provider effect and one source T8, not the old group pair. Independent
fixture SPEC then CODE must pass before browser execution. Root views images.

Final full-stage SPEC then CODE uses a frozen candidate. After both pass, run
fresh exact scoped tests, strict forced compile, changed-source format, both
isolated core and HTTP consumers, and actual browser four rows. Require nonzero
tests, actual exits, source/loaded identity stability and no hidden exclusions.
Then independent document/custody audit and local conventional commit.

## Boundaries and counters

Do not modify HTTP0.21.10/lock or deps. No third Astra: cumulative recovery2/2
is exhausted. Historical successor kickoff was group failedGREEN41/root54;
the later static premature report read was root55, with successor failedGREEN0
and runtime NOT RUN at that cutoff. Current counters are group44/root60,
successor failedGREEN3/fixtureRepair3/productionRepair0/orchestrationRepair2.
Root60 records a static backup-basename collision repaired using full relative
paths; no runtime/source failure follows. Initial GREEN5/6 each83/0 and browser
four-row PASS do not replace the required final reviews and fresh gates. Keep
intended RED, failed review, diagnostic and failed GREEN distinct.

Do not revive dismissed97. Preserve all historical failures/UNKNOWN and
unrelated user files. Group Generation, complete streaming matrix, trust/IP
rotation, H2 twenty reloads, standalone/load and H3 worker accounting remain
separate planned slices. No new push/release/deployment, production/Vault/public
management/operational certificates or disabled release-artifact E2E authority.
