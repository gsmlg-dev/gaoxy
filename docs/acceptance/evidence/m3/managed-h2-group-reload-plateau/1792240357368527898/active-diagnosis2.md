# Active diagnostic causal review2

**DONE — confirmed fixture source-predicate defect.** Independent source/data review only; no implementation/runtime acceptance.

The T `sources` comprehension at current test line3647 selects all request pins containing an OLD handle. `UpstreamTransports.reserve_derived_pin` at1055–1098 constructs a child with `public.kind: :request`, `public.handles: [handle]`, `derived: true`, and `source_ref: source.public.ref`, then inserts both source and child in the same `state.pins`. The authentic last selected child therefore matches this supposed source-only query. The singleton equality cannot pass while that child exists.

At131ms the first two originals were settled and returned, but the last source, child, both tokens and Session remained, with public completion `{:error, :cleanup_pending}`. At4982ms the original last Session received `:opening_expired` and transitioned to cancelled/consumed with `:upstream_failure`. At4985ms the wait returned after child/tokens/Session disappeared; last original source remained and completion was `:ok`. The original pending assertion failed at4987ms. This is positive evidence of the observed fixture-induced delay and timer chain, not an inferred upstream bug.

## Smallest proposed repair

```elixir
sources =
  for {ref, p} <- t.pins,
      p.public.kind == :request and not Map.get(p, :derived, false) and
        Enum.any?(old.transports, &(&1 in p.public.handles)),
      do: ref
```

Immediately before the unchanged original pending assertion, explicitly verify the authentic last child:

```elixir
assert %{derived: true, source_ref: source_ref, public: child} =
         :sys.get_state(f.owner).pins[last.bound.child.ref]

assert source_ref === last.captured.tpin.ref and child === last.bound.child

assert {:error, :cleanup_pending} =
         HTTP.RequestCompletion.await(last.bound.completion, 0)
```

Keep the existing source singleton and G predicates, original pending assertion, response/action order, deadlines, clocks and limits. Exclude only derived pins; filtering straight to the expected ref would hide an extra surviving original source. No production/dependency change is justified by this finding.

Receipt:1executed/103excluded/1FAIL, exit2, source401stable, nonforced/joined;14phase and7Session rows. Exact input hashes and reduced last-call evidence are in JSON. Proposed repair efficacy is NOT RUN; fresh independent review and required runtime verification remain root-owned. Idle/other profiles remain separate. No private Fetch state inspected.

Only assigned `/tmp` reports written. Two tooling-only output truncations were promptly reported and resolved with scalar projections/exact source slices; added repair rounds0, Astra2/2 exhausted unchanged. All own commands completed; no runtime/background process started or touched. Root-running idle diagnostic was untouched. No decisions needed.
