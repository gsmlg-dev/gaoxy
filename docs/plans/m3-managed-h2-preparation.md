# M3 managed H2 preparation implementation plan

> **For agentic workers:** Use `subagent-driven-development` under the Sol
> coordinator. Parent owns serialized runtime/build/format/evidence and commits;
> disjoint writers freeze before every execution.

**Goal:** Prepare finite pure immutable H2/h2c inputs, qualify public0.21.4
behavior and record an explicit prospective payload worksheet for later activation.

**Architecture:** Add pure preparation and a closed worksheet without changing
H1 dispatch. Reuse public peers through a versioned collector, preserve historical
evidence, and advance to fixed-H2 activation after this package's gates pass.

**Tech stack:** Elixir/OTP, ExUnit, HTTP0.21.4 public managed/H2 APIs, Python h2,
OpenSSL, canonical Nix environment.

Status: **VERIFIED LOCALLY; COMPLETE SPEC/CODE PASS; FRESH COMPATIBILITY97/0 AND PUBLIC63/0; LOCAL COMMIT NEXT**. Generation predecessor
`cb619569c7a18568981d3425845954ad04908ffb` is accepted and locally committed.
[Design](../designs/m3-managed-h2-preparation.md) is normative and immutable for
the versioned collector. Parent records fresh readiness/ownership before writers. Continuing authorization replaces routine human
approval. Astra recovery2/2 is exhausted; architecture consumes zero rounds.

## Ownership and invariants

| Owner | Files |
| --- | --- |
| Sol pure preparation writer | New `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_preparation.ex` and `apps/gaoxy_proxy/test/managed_h2_preparation_test.exs` |
| Sol worksheet writer after manifest freeze | New `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_reservation.ex` and `apps/gaoxy_proxy/test/managed_h2_reservation_test.exs` |
| Sol qualification writer | New `integration/http_fetch_contract/h2_0214_functional_supplement.exs` and `integration/http_fetch_contract/h2_0214_qualification.py`; old peers/runners read-only |
| Parent | This design/plan, `docs/acceptance/m3-managed-h2-preparation.md`, new versioned evidence, all commands/reviews/commits |

Writers are not alone; preserve others' changes. Preparation and collector may
be written in parallel. Worksheet waits for manifest contract freeze. No writer
runs Mix, runtime, formatter, build, evidence collection or commits. No edits to
`deps/`, H1 runtime/Options, standalone, Vault/E2E or production. #97 is excluded;
no new runtime reservation facade or external proof requirement is introduced.

## Step0: Predecessor and independent readiness

- [x] Verify complete Generation SPEC/CODE/fresh scoped gates and local commit;
  record HEAD, source/cohort/diff/untracked inventory and cumulative counters.
- [x] Independently review this design/plan against architecture and public
  header/trailer/policy contracts. Resolve concrete findings before writing code.
- [x] Freeze manifest names from the design and assign writers. Capture current
  old supplement/peer hashes so later preservation is mechanically verifiable.
  The literal manifest schema is normative: common source/owned/transient/limits
  and complete sizes, policy-only policy_external_bytes, request-only projection
  and effective-field sizes. Policy does not invent a request projection.

## Step1: Pure policy RED then GREEN

Files: preparation writer scope. Write executable policy tests before production:

```elixir
assert {:ok, policy, manifest} = ManagedH2Preparation.prepare_policy(%{
  protocol: :h2c, origin: "http://localhost:8080",
  connect_address: {127, 0, 0, 1}, trust: nil
})
assert policy.protocol == :h2c
assert policy.open_options[:max_connections] == 2
assert policy.open_options[:max_requests] == 32
assert policy.open_options[:max_pending] == 0
assert manifest.policy_external_bytes == :erlang.external_size(policy)
assert {:error, :invalid_policy} =
  ManagedH2Preparation.prepare_policy(%{protocol: :http2})
```

- [x] Add TLS policy with explicit DER, protocol/scheme/trust mismatch, exact
  source-key shape, malformed root URL/port/numeric address and compact-output
  cases. At128 certificates/65,536 bytes and aggregate/backing1MiB test the
  individual gate separately from the complete SSL policy cap. Include improper
  list, empty DER,129 certificates,65,537 bytes and backing-over-limit cases.
- [x] Freeze tests; parent records nonzero missing-module/API RED with command:
  `nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_preparation_test.exs`.
- [x] Implement the exact four-key policy, finite traversal, strict pairing,
  copied canonical profile and source/owned manifests. Do not add managed SSL
  ALPN options. Revalidate forged Policy field set and bounded options on input.
- [x] Parent verifies policy tests without skipping failure; classify every
  failed GREEN, diagnose minimally and retain raw evidence/counters.

## Step2: Effective request RED then GREEN

Files: preparation writer scope. Independent expected-field test uses public
H2 encoder only after valid preparation:

```elixir
source = %{url: "http://localhost:8080/raw%2f?", method: :get,
  fields: [], body: nil, trailers: [], timeout: 5000, connect_timeout: 1000}
assert {:ok, request, manifest} =
  ManagedH2Preparation.prepare_request(policy, source)
assert request.target == "/raw%2f?"
assert request.fields == [{"user-agent", "gaoxy"}]
assert manifest.effective_field_count == 5
assert manifest.source_external_bytes == :erlang.external_size(source)
assert manifest.prepared_external_bytes == :erlang.external_size(request)
```

- [x] Add native-oracle equality for all methods, IPv4/IPv6 authority/default
  and explicit ports, raw path/query including empty query, nil/PID bodies,
  explicit/default UA/Content-Type, TE normalization, valid/invalid/duplicate
  Content-Length originally first/middle/last with explicit/default Content-Type,
  removed validated Trailer declaration and ordinary duplicate order. Oracle uses proxy mode, PID
  duplex half and `HTTP.HTTP2.request_headers/3` with `order?: false`.
- [x] Add exact effective256/65,536 and over-bound257/65,537 including generated
  pseudo/UA/Content-Type costs47/68. Enforce source/canonical projection
  logical196,608; test source admission boundaries with feasible composed inputs
  and independently verify the worksheet/projection arithmetic. Canonical exact
  196,608 success is unreachable under effective/trailer framing bounds and is
  not required. Add improper/over field and trailer lists, backing limits,
  declaration token128/129, forbidden/undeclared trailers and forged options.
- [x] Parent observes RED for missing request behavior. Implement bounded
  semantic normalization, projection checks, compact copies and actual complete/
  projection sizes only after validation. Pure production cannot call the
  runtime-derived User-Agent oracle or create a process/read a file/clock/env.
- [x] Parent runs unfiltered preparation tests; verify constructor/backing facts,
  transient upper bound and manifests without counting projections twice.

## Step3: Static prospective worksheet

Files: worksheet writer scope. Its public entry has no input or evaluator:

```elixir
worksheet = ManagedH2Reservation.worksheet()
assert worksheet.unit == :external_term_payload_bytes
assert worksheet.named_subtotal_per_request == 2_918_508
assert worksheet.fixed_response_upload_write_subtotal == 2_516_026
assert worksheet.named_subtotal_for_32_requests == 93_392_256
```

- [x] Write tests for every named formula/row, Q wrapper4633 and all subtotals.
  Assert profile C2/R32/P0, no runtime reserve claim, and explicit later adapter
  schema/multiplicity/release/enforcement requirements from the design.
- [x] Parent observes missing-module RED, then release minimal implementation:
  closed static map with named limits/formulas/numeric envelopes. No production
  `reservation_bytes/3`, generic term traversal, opaque serialization or zero
  charges for uninspected control/config projections.
- [x] Parent runs worksheet and preparation together; later finite local
  retained-schema work is an adapter obligation, not a new dependency blocker.

## Step4: Versioned public0.21.4 qualification

Files: qualification writer scope. Old0.21.3 supplement and peer remain intact.

- [x] Copy the historical supplement into the new named collector, change only
  module/version/current design binding and required source identity, retain all
  eight TLS4/h2c4 assertions, finite deadlines, original completion failures,
  public cleanup/EOF/peer joins. Bind the immutable design rather than mutable
  plan progress; parent freezes its final SHA before execution.
- [x] Add parent-invoked Python orchestration: canonical Nix environment,
  qualified Python/h2/OpenSSL identity, loaded seven-package0.21.4 BEAM/native
  identity, source snapshots before/after and actual command exits/log hashes.
  It executes unchanged public managed39, pooled completion16 and new supplement8
  serially in separate VMs. Reject zero/partial execution and preserve failures.
- [x] Parent freezes all writers and runs:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test python3 -B integration/http_fetch_contract/h2_0214_qualification.py --evidence docs/acceptance/evidence/m3/managed-h2-preparation/<fresh-run-id>
```

- [x] Read every failed raw log in full and repair only demonstrated scoped
  defects under Sol. Never weaken capacity/cleanup/EOF/no-replay/sibling assertions.
  A blocked or unexecuted runner stays BLOCKED/NOT RUN, never PASS. Current
  public ALPN exacth2 and h2c prior knowledge require real peer evidence.

## Step5: Complete independent review and fresh gates

- [x] Freeze exact source/tests/collector hashes. Independent SPEC maps every
  design obligation to executed tests and actual network evidence, then CODE
  reviews bounded traversal, pure defaults, Policy revalidation, canonical/native
  equality, manifest sizes, worksheet arithmetic and historical preservation.
- [x] Resolve actionable findings and rerun affected cases. Independent review
  must be fresh and cannot be replaced with self-review. Carry cumulative Sol
  counters; Astra recovery2/2 remains unchanged.
- [x] Execute fresh scoped format/strict compile and unfiltered tests:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix format --check-formatted apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_preparation.ex apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_reservation.ex apps/gaoxy_proxy/test/managed_h2_preparation_test.exs apps/gaoxy_proxy/test/managed_h2_reservation_test.exs integration/http_fetch_contract/h2_0214_functional_supplement.exs
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix compile --warnings-as-errors
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_preparation_test.exs apps/gaoxy_proxy/test/managed_h2_reservation_test.exs apps/gaoxy_proxy/test/managed_h1_preparation_test.exs apps/gaoxy_proxy/test/managed_h1_accounting_test.exs apps/gaoxy_proxy/test/upstream_transports_options_test.exs apps/gaoxy_proxy/test/http_fetch_completion_test.exs
```

- [x] Run fresh Step4 qualification after reviews. Record commands/environment/
  source/counts/exits and PASS/FAIL/BLOCKED/NOT RUN distinctly; zero skips required.
  Source/lock preservation and core isolation remain explicit.

## Step6: Documentation, local commit and successor

- [x] Close acceptance ledger/checklists from executed evidence, preserving all
  failed attempts and counters. Distinguish prospective payload worksheet from
  native limits/live reservations and preparation from activation/full M3.
- [ ] Check task-owned source/tests/docs/JSON whitespace and exact historical
  hashes; preserve raw log whitespace and unrelated user files. Stage only owned
  files and commit `feat(proxy): prepare bounded managed H2 policies and requests`.
- [ ] Automatically form fixed-H2 activation design/plan with complete Gaoxy
  retained-schema/reservation and enforcement work, then execute its prescribed
  readiness and gates under continuing authorization. No routine approve pause.
