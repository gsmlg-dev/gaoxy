# M3 managed H1 compact preparation implementation plan

> For agentic workers: use executing-plans for bounded task execution. Sol owns
> implementation; the parent assigns independent specification/code reviews and
> serializes every Mix/network command. Continuing authorization in `AGENTS.md`
> replaces routine user approval. The active executable freeze must be explicitly
> released by the parent before implementation, tests or a local commit.

**Goal:** Construct bounded compact H1 policy/request inputs with scalar ownership
manifests, while production accounting/activation remain explicitly unqualified.

**Architecture:** Two pure internal modules; fixed-shape validation before copies,
fixed C2/R32/P0 options, DER-only trust, separate source/owned constructor facts.
The accounting module has no evaluator or caller proof inputs. See
[the complete contract](../designs/m3-managed-h1-preparation.md).

**Tech stack:** Existing Elixir1.18.5/OTP28.5.0.7/ERTS16.4.0.6 and0.21 HTTP
cohort at actual tag `9813c126dc8b48055b9ee941c693fc27fa691489`; ExUnit,
`:binary.copy/1`, `:binary.referenced_byte_size/1`, bounded `URI.parse/1`, public
pure `HTTP.Trailers.upload/2`. No new dependency or process.

**Checkout:** `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Initial counters: this pure task Sol unsuccessful0/Astra0. An expected TDD red
result does not consume a repair round; unexpected repair-and-validation attempts
carry the parent's cumulative counter across handoffs.

## Ownership and execution rules

Owned additions only:

- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_preparation.ex`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_accounting.ex`
- `apps/gaoxy_proxy/test/managed_h1_preparation_test.exs`
- `apps/gaoxy_proxy/test/managed_h1_accounting_test.exs`
- This plan and `docs/designs/m3-managed-h1-preparation.md`.

The parent owns adapters, existing shared docs, dependency/lock, fixture and
acceptance evidence. Preserve all existing modifications/untracked files.
Do not touch those files or any `deps/` source. No managed scope, service, peer,
file reader, core dependency, network, hidden option passthrough, fallback or
production activation. No child delegation by this implementation worker.

## Task 0: Release/check the boundary

- [x] Obtain the parent's explicit freeze release and serialized command slot.
- [x] Read the design, current `AGENTS.md` and current diff; verify branch/HEAD
  and record pre-existing changes. If another writer owns these additions,
  report BLOCKED_HANDOFF rather than overwrite them.
- [x] Parent arranges independent specification review of the written design
  and plan before executable changes. Resolve findings in the owned documents.
- [x] Read the Elixir/TDD/executing-plans skills. Use async ExUnit tests with
  no global state, clocks, HTTP application startup or network fixture.

Read-only commands from the assigned checkout:

```sh
git status --short
git rev-parse HEAD
git diff --stat
```

## Task 1: Test and implement fixed policy construction

Files: new preparation module and its test. Define these two nested structs;
the remaining functions are specified in the design and steps below.

```elixir
defmodule Gaoxy.Proxy.ManagedH1Preparation.Policy do
  @moduledoc false
  defstruct [:origin, :scheme, :host, :port, :connect_address, :open_options]
end

defmodule Gaoxy.Proxy.ManagedH1Preparation.Request do
  @moduledoc false
  defstruct [:url, :method, :fields, :body, :trailers, :timeout,
             :connect_timeout, :target]
end
```

- [x] Write a first behavior test with `use ExUnit.Case, async: true` and alias
  `Gaoxy.Proxy.ManagedH1Preparation, as: Preparation`:

```elixir
test "builds fixed numeric-pinned H1 options without opening a scope" do
  assert {:ok, policy, manifest} = Preparation.prepare_policy(%{
    origin: "http://example.test", connect_address: {127, 0, 0, 1}, trust: nil
  })
  assert %Preparation.Policy{origin: "http://example.test", scheme: :http,
    host: "example.test", port: 80, connect_address: {127, 0, 0, 1}} = policy
  assert [origin: "http://example.test", connect_address: {127, 0, 0, 1},
    http_version: :http1, tls_backend: :ssl, http2_profile: :native_v1,
    max_requests: 32, max_connections: 2, max_pending: 0, idle_timeout: 30_000,
    ssl: [], socket_opts: [buffer: 8192, recbuf: 8192, sndbuf: 8192,
      nodelay: true, send_timeout: 30_000, send_timeout_close: true]] = policy.open_options
  assert %{kind: :policy, source: %{backing_bytes: 19}} = manifest
end
```

- [x] Run the scoped preparation test command below and record expected red
  evidence (missing preparation module/API). Compile-error red is acceptable
  only when caused by the new missing API; syntax/environment errors are not.
- [x] Implement exact source-map matching:3 entries,3 required keys, no
  `:__struct__`. Check origin byte/backing caps and IP tuple size/ranges first.
  Validate trust shape/count/byte/backing totals before parsing or copying.
  Bounded URL scan rejects ASCII controls, whitespace, backslash, literal `#`,
  bad percent triplets; then parse and check scheme/host/port and root path.
- [x] For HTTP require nil trust. For HTTPS require nonempty DER list; construct
  compact DER leaves and generated SNI only after the preflight succeeds.
  Construct exactly the fixed keyword options in the design and the test above,
  with fixed HTTPS SSL options when applicable. Final ETF cap applies to
  `{ssl, socket_opts}`, after finite construction; no upstream private call.
- [x] Add paired boundary tests: origin byte/backing65536 versus65537 (the
  valid origin grammar can reject a logically long origin on host/path first;
  byte preflight must still reject an over-cap string); host253 versus254;
  ports1/65535 versus0/65536; IPv4/IPv6 and malformed tuple/components;
  timeout/profile overrides as unknown keys; root/absent path versus non-root,
  query/userinfo/fragment; URI/charlist/map forms and oversized-map rejection.
- [x] Add DER tests for per-cert65536 versus65537,128 versus129 entries,
  aggregate1048576 versus1048577, improper tails, zero-byte DER and HTTP trust.
  Test aggregate limit independently of final ETF:16 certificates of65536
  satisfy source aggregate exactly but reject `:policy_limit` due to ETF
  overhead;15 certificates pass the ETF cap. Payload validity as actual DER
  certificates is deliberately not asserted or decoded. Reject PEM/file options,
  path/default-CA/client-key input forms as unsupported shape. A PEM byte payload
  inside an accepted binary list is opaque and is not detected as PEM.
- [x] Re-run scoped tests to green. Do not weaken exact option or boundary checks.

Bounded list traversal must use heads/tails with a counter, never `length` on
source lists. The following complete traversal rule shows the first-excess-cell
ordering used for field/trailer/certificate walks; per-leaf semantic/budget work
is performed in the bounded `validate` callback:

```elixir
defp walk([], _cap, _count, state, _validate), do: {:ok, state}
defp walk([_ | _], cap, count, _state, _validate) when count == cap,
  do: {:error, :count_limit}
defp walk([value | rest], cap, count, state, validate) do
  with {:ok, state} <- validate.(value, state) do
    walk(rest, cap, count + 1, state, validate)
  end
end
defp walk(_, _cap, _count, _state, _validate), do: {:error, :invalid_shape}
```

Private callback functions are implementation code, not accepted input
callbacks. Map the internal count/shape errors to the design's public atom
categories. Do not create a generalized validation framework around this helper.

## Task 2: Test and implement request grammar, preservation and trailers

Files: same preparation module/test; no adapter change. Test fixtures:

```elixir
defp policy do
  {:ok, policy, _} = Preparation.prepare_policy(%{
    origin: "http://example.test", connect_address: {127, 0, 0, 1}, trust: nil
  })
  policy
end

defp request do
  %{url: "http://example.test/upload?", method: :post,
    fields: [{"X-Repeat", "first"}, {"x-repeat", "second"}], body: nil,
    trailers: [], timeout: 1_000, connect_timeout: 500}
end

test "preserves ordered fields, escaping and a present empty query" do
  assert {:ok, prepared, _} = Preparation.prepare_request(policy(), request())
  assert %Preparation.Request{url: "http://example.test/upload?",
    target: "/upload?", method: :post,
    fields: [{"X-Repeat", "first"}, {"x-repeat", "second"}], body: nil,
    trailers: [], timeout: 1_000, connect_timeout: 500} = prepared
end
```

- [x] Write/run expected red tests for request behavior before the new API.
- [x] Validate policy finite grammar/fixed options/compact leaves without a
  giant-tree equality walk. Check request exact7-key map shape, bounded method,
  PID-or-nil body, timeout integers, and URL byte/backing preflight.
  Walk complete field/trailer shapes with count and running independent logical
  and backing sums. No normalized/copy output until source preflight succeeds.
- [x] Parse bounded URL and verify matching parsed origin. Derive origin form
  with `/` for absent path and `?` whenever query is non-nil; preserve exact
  input URL. Validate token names and field-value byte grammar with bounded
  byte recursion. Charge target plus fields exactly as the design specifies.
- [x] Preflight declaration/Connection token lists with128-token ceilings per
  class. Then use public `HTTP.Trailers.upload/2` on already bounded pairs.
  Keep source pairs as output copy source; collapse helper errors to fixed
  `:invalid_trailers`. Nil body with nonempty trailers rejects.
- [x] Add successful PID-body declared duplicate-trailer test:

```elixir
test "permits a PID upload and ordered duplicate declared trailers" do
  source = %{request() | body: self(),
    fields: [{"Trailer", "x-end"}],
    trailers: [{"X-End", "one"}, {"x-end", "two"}]}
  assert {:ok, %Preparation.Request{body: pid,
    trailers: [{"X-End", "one"}, {"x-end", "two"}]}, _} =
      Preparation.prepare_request(policy(), source)
  assert pid == self()
end
```

- [x] Add exact-count tests256/257 fields and128/129 trailers with sufficient
  byte allowance and declarations. Add target-aware field-charge65536/+1
  tests: URL root target `/`, one `{"x", value}`, value length65502/+1.
  Add trailer-charge65536/+1 tests: `{"x", value}` length65529/+1, PID body,
  field `{"trailer", "x"}`. Counts/bytes/backing reject independently.
- [x] Add all method enums and reject binary/unsupported atom; timeouts1 and
  86400000 versus0/86400001/`:infinity`; buffered iodata, `""`, callback,
  URI/headers structs, convenience/extra option trees, malformed pairs and
  improper tails. Check static forbidden and Connection-nominated trailers,
  undeclared/empty declarations, bad name/control value,129 declaration tokens.
- [x] Test matching default port/case, IPv6, absent path, query ordering and
  `%2f` spelling; reject other origin/port/scheme, userinfo/fragment and forged
  out-of-grammar/inconsistent policies including giant `open_options` tails;
  accept structurally valid canonical copies without a provenance claim.
  Fixed errors retain no input.
- [x] Re-run request/preparation tests to green; record actual count and exit.

## Task 3: Test ownership, source aggregates and scalar manifests

Files: same preparation module/test. Constructor walk applies only to
validated source grammar and the bounded newly generated output, never rejected
caller trees. Count each binary reference occurrence conservatively; record
both logical/backing sums rather than deduplication by equality. Group tuple
and map counts by arity/entry count and include struct `:__struct__` entries.

- [x] Write/run red compact-copy and source-manifest tests. Build an8192-byte
  parent and take an80-byte value slice; assert its source backing exceeds80
  before calling preparation so the fixture proves sharing. A tiny≤64-byte
  slice alone may be eagerly copied by the VM and cannot prove compaction.

```elixir
test "copies bounded parent slices and records source plus owned backing" do
  parent = :binary.copy("v", 8_192)
  value = binary_part(parent, 20, 80)
  assert :binary.referenced_byte_size(value) == 8_192
  source = %{request() | fields: [{"x", value}]}
  assert {:ok, %Preparation.Request{fields: [{"x", owned}]} = output, manifest} =
    Preparation.prepare_request(policy(), source)
  assert owned == value
  assert :binary.referenced_byte_size(owned) == byte_size(owned)
  assert manifest.source.backing_bytes == byte_size(source.url) + 1 + 8_192
  assert manifest.transient.source_plus_owned_backing_upper ==
    manifest.source.backing_bytes + manifest.owned.backing_bytes
  assert output.target == "/upload?"
end
```

- [x] Implement second-pass copying of retained URL, parsed host, target,
  names/values and each certificate; no original source references in output
  or manifests. Construct fields/trailers by prepend then reverse and record
  the additional reverse cons ceiling. Trust copy walk is bounded recursion.
- [x] Count source map3 or7 entries, IP tuple4/8, field/trailer cons and
  pair tuples, DER cons/binary occurrences, atoms/PID/integers. Count complete
  owned Policy/Request structs and generated options/SNI list. Manifest has
  only fixed keys/atoms/integers and bounded integer-key count maps, no values.
- [x] Add equivalent80+-byte slice tests for request URL, policy origin
  (bounded valid long hostname), field name, trailer name/value and certificate.
  Every source-derived retained binary leaf must have compact backing.
- [x] Add oversized-parent rejection tests (parent65537 for URL/field/cert);
  aggregate backing tests with individually valid leaves whose sums exceed
  fields65536/trailers65536/trust1048576 despite low logical bytes. Include
  repeated references to one8192-byte backing: occurrence sum deliberately
  rejects9 field references. Assert exact `:source_backing_limit`.
- [x] Independently calculate a small fixture's entire source and owned
  constructor counts from the literal trees; do not use the production count
  helper in expected values. Verify errors from a valid maximum prefix with
  huge/malformed next tail are constant atoms. Verify no binary/PID/function
  exists anywhere in the manifest using a test-only bounded inspection walk.
- [x] Re-run scoped preparation tests to green. Record that source-plus-owned
  numbers cover backing coexistence, not parser/ETF/runtime metadata peaks.

## Task 4: Test and implement named facts and closed activation

Files: new accounting module and its test. No generic expression evaluator.

```elixir
test "reports named partial constructor facts and refuses activation" do
  facts = Gaoxy.Proxy.ManagedH1Accounting.facts()
  assert %{connections: 2, attempts: 32, pending: 0} = facts.profile
  assert facts.constructors.request_pair_skeleton_bytes == 256 * (2 + 3) * 8
  assert facts.constructors.trailer_pair_skeleton_bytes == 128 * (2 + 3) * 8
  assert facts.constructors.response_pair_skeleton_bytes == 16_384 * (2 + 3) * 8
  assert facts.constructors.max_upload_framing_bytes == byte_size("10000") + 4
  assert {:error, {:unqualified, [:p0, :p1, :p2, :p3, :p4, :p5, :p6]}} =
    Gaoxy.Proxy.ManagedH1Accounting.activation_status()
end
```

- [x] Run expected red before implementing accounting API.
- [x] Implement literal fixed profile/runtime/cohort identities and named
  derivations exactly from the design. Publish all7 open obligations with
  fixed reason atoms. `activation_status/0` always returns the exact error
  above. Add no argument accepting proof constants, profile override or
  synthetic-production mode; no byte total or success object exists.
- [x] Assert source caps/aggregate arithmetic, identities and response ceiling
  independent of request limits. Verify P4 explicitly names EOF/content-length
  delivery, one-byte event batches, long complete chunk-size integers and
  rejected heads as unresolved phase/copy coverage. Successful preparation
  does not change activation status; repeated calls yield the same result.
- [x] Run both scoped files to green. Pure arithmetic/manifest results are
  not network/production acceptance evidence.

## Task 5: Independent review, fresh verification and stop

- [x] Review owned diff against every design limit and API. Inspect that no
  forbidden owned PID/process, tree passthrough, proof constant, default-zero
  term or adapter/runtime call was introduced.
- [x] Parent assigns independent specification and code-quality reviews; resolve actionable findings with
  focused regression tests, preserving cumulative Sol repair counters.
- [x] Parent serializes formatter and fresh scoped tests. Record actual
  environment/source identity, command/exit, nonzero test count and findings.
- [x] Update only these design/plan execution status/checklist lines. Parent
  owns evidence receipts and shared acceptance documentation.
- [ ] After passing independent reviews/fresh verification, parent may authorize
  this worker's local conventional commit of only owned files. No commit runs
  during freeze or in this docs-only assignment. Suggested message:
  `feat(proxy): prepare bounded managed H1 inputs`.
- [x] Stop at pure preparation. H1 numeric activation bound stays NOT ESTABLISHED,
  P0-P6 open; no manager/adapter integration, network qualification or broader
  M3 completion claim. Preserve commands/processes owned by others.

Scoped commands after release, each in a separate serialized parent slot:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix test --no-start --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h1_preparation_test.exs'
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix test --no-start --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h1_preparation_test.exs apps/gaoxy_proxy/test/managed_h1_accounting_test.exs'
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; unbuffer mix format apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_preparation.ex apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_accounting.ex apps/gaoxy_proxy/test/managed_h1_preparation_test.exs apps/gaoxy_proxy/test/managed_h1_accounting_test.exs'
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; unbuffer mix format --check-formatted apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_preparation.ex apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_accounting.ex apps/gaoxy_proxy/test/managed_h1_preparation_test.exs apps/gaoxy_proxy/test/managed_h1_accounting_test.exs'
git diff --check
```

Expected final results: formatter exit0, both test files execute nonzero tests
with0 failures/exit0, independent specification/code review resolves findings,
only owned changes staged. Broader tests/network/soak and production activation
are NOT RUN in this slice. Environment or handoff failure is a blocker label,
never a passing test; two unsuccessful Sol repair rounds require parent-managed
bounded escalation rather than continued blind edits.


## Execution handoff, 2026-10-11

Tasks0-4 and final self-review are complete. Executable writes are stopped.
The parent completed canonical formatting of the four new files and the global
format check, exit0. Independent implementation specification and code-quality
reviews PASS. The fresh final test of those reviewed formatted bytes passes26/0,
exit0, seed21108026, with429 unchanged source fingerprints. Only local commit
delivery remains pending in Task5. There is no routine user design decision.

Final receipts: [specification review](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-preparation-implementation-spec-review.md),
[code-quality review](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-preparation-implementation-quality-review.md),
[formatter](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-preparation-format.json),
and [fresh final test](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-preparation-final.json).
Both reviews' four executable hashes match the final test map and current files.

Parent-run command for the pre-format strict implementation checkpoint:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; unbuffer mix test --no-start --warnings-as-errors --max-cases 1 --seed 21108026 apps/gaoxy_proxy/test/managed_h1_preparation_test.exs apps/gaoxy_proxy/test/managed_h1_accounting_test.exs'
```

Actual result:26 tests (22 preparation,4 accounting),0 failures, exit0,
seed21108026;429 source fingerprints unchanged across execution.
[Receipt](../acceptance/evidence/m3/upstream-transport/upstream-0.21/h1-preparation-accounting-green.json)
and raw log are parent-owned. Worker readback confirms the result; no worker
Mix or network job ran. Self-review checked exact source grammar, source backing
versus compact output, bounded rejection/declarations, complete constructor
counts, public pure trailer use and closed activation.

Preserve these prior results in the same evidence directory:

| Checkpoint | Actual result | Classification |
| --- | --- | --- |
| `h1-preparation-red-policy.json` | exit1, missing Policy struct | EXPECTED_RED |
| `h1-preparation-green-policy.json` | 1 test/1 failure, exit2, Enumerable on Policy | FAIL |
| `h1-preparation-policy-repair1.json` | 1 test/0 failures, exit0 | PASS |
| `h1-preparation-request-red.json` | exit1, missing Request struct | EXPECTED_RED |
| `h1-preparation-request-green.json` | 9 tests/1 failure, exit2, append fixture backing doubled | FAIL |
| `h1-preparation-request-repair2.json` | 9 tests/0 failures, exit0 | PASS |
| `h1-preparation-accounting-red.json` | 23 tests/3 failures, exit2, absent API plus two incorrect fixture counts | FAIL |
| `h1-preparation-accounting-red-repair3.json` | 23 tests/1 failure, exit2, only absent accounting API; all22 preparation tests pass | EXPECTED_RED |
| `h1-preparation-accounting-green.json` | 26 tests/0 failures, exit0 | PASS |

Root causes and corrections: struct traversal now uses `:maps.fold/3` and keeps
`__struct__` counts; append-based oversized-parent fixture is independently
compacted without weakening its exact backing assertion; HTTP/TLS integer
fixtures include the top-level port and are exactly17/30. Before the expanded
ExUnit run, a Python literal-size audit corrected the request byte fixture to
source54/owned62/coexistence116; that draft expectation was not an ExUnit result.
Cumulative counters:3 initial unexpected validation runs;3 actual Sol repair
validations successful,0 unsuccessful; Astra0. No escalation gate applies.

Worker owns only the four new executable files and these two documents. All
worker commands finished; shared source/docs/dependency/fixture files and others'
processes were preserved. No commit, process integration or activation occurred.
P0-P6 remain open. Independent implementation reviews, canonical formatting,
global format check and fresh tests of the formatted source have passed.
