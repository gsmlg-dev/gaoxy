# Unified listeners and embedded Gateway implementation

Source: Agent Note `c676efd4-a6a5-4157-879b-750f1563c0d2`, revision 1.
Baseline: `656dbf5bb84564adc6a4d68247c0ad2fe52c2625` (0.7.0), preserving
mixed cleartext H1/prior-knowledge H2 and all prior ordinary acceptance.
See the [design](../designs/unified-listeners-embedded-gateway.md).

## Agreed interfaces and ownership

- Core worker owns `apps/gaoxy`: `activation: :deferred`,
  `Gaoxy.activate(instance, services, timeout: finite, deadline: absolute,
  operation_id: id)`, and `Gaoxy.activation_status/2`. Complete planned
  services retain their shutdown cap. The instance owns late activation and rollback.
- HTTP worker owns ListenerSet/providers, prepared targets, Phoenix/H3 adapters,
  discovery, focused tests and guides. `ListenerSet.plan/1` is pure;
  `planned_services/1` uses an inert target with the final protocol/budget;
  `prepare(plan, target: target, instance: instance)` produces finalized services.
  The direct ListenerSet owner starts one core instance and activates the full set.
  New declarations never treat `initialized: true` as a caller bypass.
- Parent owns Gateway, standalone migration, and all Generation/Store edits.
  `Gateway.compile/1` accepts `listener_sets:` plus existing `services:`.
  Generation owns atomic accepted declaration/revision, runtime epoch, stop barrier,
  operation admission and bounded terminal receipts alongside the active router.
  Per-role Generation targets retain their existing protocol resource accounting.
- All writers share `.trees/unified-gateway`; mutation ownership is disjoint.
  Mix build/test commands serialize through `.audit/mix.lock`.
  User files, historical raw evidence, excluded specialist probes, and unrelated
  `.trees/mixed-h2c` work remain preserved.

## Checklist

- [x] Phase 0: read note, reconcile baseline, write design, freeze interfaces.
- [x] Phase 1: core deferred activation with budgets, ownership and rollback.
- [x] Phase 1: pure ListenerSet/provider/prepared-target composition.
- [x] Phase 1: reusable Gateway declarations; atomic Generation revision/epoch/receipts.
- [x] Phase 2: Gateway runtime extraction, reload, recovery, isolation, bounded stop.
- [x] Phase 3: unified Phoenix HTTP/HTTPS/H3 and transport inspection.
- [x] Phase 3: standalone v1 delegates to Gateway; legacy names/reload remain compatible.
- [x] Phase 3: opt-in readiness-aware Alt-Svc before response budget validation.
- [x] Phase 4: focused tests and finite independent network acceptance matrix.
- [x] Phase 4: external consumers demonstrate core, H1/H2, optional H3 and Gateway isolation.
- [x] Phase 4: independent specification/code reviews; resolve findings; fresh verification.
- [x] Phase 4: documentation/examples, conventional commits and authorized integration.
- [x] Phase 4: push, coordinated package/release workflow after its required gates.

Record commands, counts, outcomes and limits in
`docs/acceptance/unified-listeners-embedded-gateway.md`. Completion requires both
product outcomes and standalone delegation. Preserve PASS/FAIL/BLOCKED/NOT RUN.
