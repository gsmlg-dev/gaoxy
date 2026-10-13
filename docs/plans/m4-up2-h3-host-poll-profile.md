# M4 UP2 H3 Host Polling Profile Implementation Plan

> For agentic workers: use `subagent-driven-development` or `executing-plans`.
> Root owns source changes and all serialized tests/live executions. Independent
> reviewers own unique receipts. Preserve other writers and freeze apps,
> integration and scripts during recorded runtime executions.

**Goal:** qualify the unchanged tiny-window UP2 workload using the existing
public host's explicitly selected1ms polling profile, retaining default10ms.

**Architecture:** [bounded public-host design](../designs/m4-up2-h3-host-poll-profile.md).
Normalize one generic QUIC service option, forward the supported public Abyss
option, then revalidate completed H3 fixture specifications. No H3 Options,
standalone schema, operation-state or dependency changes.

**Tech stack:** locked Elixir/OTP umbrella, public Abyss QUIC host at
`9b710e6480900e16e304f40e63623aff8c922e19`, independent aioquic1.2.0 peer.

Status: actual timing diagnosis recorded; implementation PROPOSED. This document
does not claim SPEC/CODE review, new tests or selected-profile runtime PASS.

## Ownership and source identity

This writer owns only this plan and its paired design; both freeze after handoff.
Root owns these implementation paths:

- `apps/gaoxy/lib/gaoxy/config.ex`: strict option validation and default10
  normalization in the completed public service specification.
- `apps/gaoxy/lib/gaoxy/service.ex`: forward normalized `poll_interval`.
- New `apps/gaoxy_http3/test/host_poll_profile_test.exs`: pure core-configuration
  cases with the optional engine present and real public host lifecycle cases.
- `integration/http3/upstream/fixture.exs`: select1 on both completed H3 specs;
  emit normalized selected QUIC maps, preserving single endpoint initialization.
- `integration/http3/upstream/run.py`: assert both selected maps before network
  rows and capture the three public Abyss source identities below.
- `integration/http3/upstream/README.md`: document the explicit profile and
  default-throughput qualification limit.

No edits to `deps/`, H3 Options, standalone configuration, operation CAS,
pending-reference handling, peer windows or row manifests are planned. Root
records exact source/lock hashes before and after every execution, including
`deps/abyss/lib/abyss/quic.ex`, `deps/abyss/lib/abyss/quic/handler.ex` and
`deps/abyss/lib/abyss/quic/service.ex`. Their reviewed SHA256 values are
`440cb155d37d6f374cee704b8cc5c35a09dbb0759366116c8220d4cde3f3c9e2`,
`a0e1bc27356c3144db0b3651a524d9712b30a5890a3383be78d7bf78e0b762ed`, and
`ecd853982f39301c88fd174d81978deeca28c21e6800797647fbd30b268d8b42`.

## 1. Establish diagnosis and review the specification

- [ ] Preserve both FAIL52 records linked in the design, including timing-only
  `peer.log`. Confirm311,196 bytes/304 events and303 average10.027ms intervals
  alongside full independent origin1MiB hash/request FIN/response FIN.
- [ ] Obtain independent SPEC review of bounds1..1000/default10, public forwarding,
  completed-spec revalidation, workload-only claim and unchanged invariants.
  Resolve actionable findings without requesting routine human approval.
- [ ] Retain cumulative live17/production5/harness3. Timing-only diagnostic stays
  under repair8; root records the next attempted repair as9 and preserves failure
  counters in each new receipt. Third Astra recovery remains prohibited.

## 2. Red tests, then minimum compatibility implementation

- [ ] Add tests using completed public H3 specs. Assert omission normalizes to10,
  explicit1/10/1000 are accepted, and revalidation preserves the entire selected
  spec and emits no second endpoint initialization. Assert0/-1/1001/1.0/true/
  `nil`/`"1"`/`:infinity` return `:invalid_quic_poll_interval`; an unknown QUIC
  key still returns `{:unknown_options, [key]}`. Invalid values passed to
  `Gaoxy.start_link/1` must fail validation before a listener is allocated.
- [ ] Add real default10/selected1 host lifecycle cases with generated disposable
  credentials: public `Gaoxy.start_link`, actual loopback UDP local address,
  zero admission/retained/cleanup state, successful `Gaoxy.stop`, normal runtime
  DOWN and one immediate UDP rebind. Preserve finite deadlines. Do not mock the
  production host, inspect private state or assert exact scheduler timings.
- [ ] Run expected RED with the canonical prefix below and
  `python scripts/check-tests.py apps/gaoxy_http3/test/host_poll_profile_test.exs`.
  Record actual nonzero failing tests; do not treat agreed TDD RED as a repair
  failure. An environment failure is distinct from the intended assertion RED.
- [ ] Extend only `Config`'s known QUIC keys to `[:alpn, :poll_interval]`, validate
  `is_integer(value) and value in 1..1000` using omission10, and include that
  normalized value in successful completed QUIC specs. Keep non-QUIC maps empty.
  Forward `poll_interval: spec.quic.poll_interval` in the public host call.
- [ ] Run the new test again for actual GREEN, then affected configuration,
  lifecycle, H3/proxy suites and core-only consumer isolation. Use the canonical
  prefix for every command:

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python scripts/check-tests.py apps/gaoxy_http3/test/host_poll_profile_test.exs
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python scripts/check-tests.py apps/gaoxy/test/config_test.exs apps/gaoxy/test/runtime_test.exs apps/gaoxy/test/lifecycle_acceptance_test.exs apps/gaoxy/test/shutdown_hardening_test.exs apps/gaoxy_http3/test apps/gaoxy_proxy/test/http3_session_client_test.exs apps/gaoxy_proxy/test/http3_guardian_test.exs
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' bash scripts/external-consumer.sh
```

## 3. Select, record and independently review the fixture profile

- [ ] For the two H3 services only, revalidate the completed public spec with
  `quic: Map.put(completed.quic, :poll_interval, 1)` as shown in the design.
  Emit `quic` metadata keyed by `h3` and `h3_sibling`. Assert exactly those keys,
  each map's `alpn == ["h3"]` and `poll_interval == 1` in the runner. Retain H2
  receive16KiB/control-rate2048 and all other fixture budgets unchanged.
- [ ] Capture the public host/Handler/Service hashes in before/after identity
  collections. Document profile selection in README without qualifying default10
  burst throughput. Preserve all68 manifests, finite windows and deadlines.
- [ ] Format the exact changed Elixir files, strict compile, check changed Python
  syntax, and obtain independent CODE/evidence review before live execution:

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' mix format --check-formatted apps/gaoxy/lib/gaoxy/config.ex apps/gaoxy/lib/gaoxy/service.ex apps/gaoxy_http3/test/host_poll_profile_test.exs integration/http3/upstream/fixture.exs
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' mix compile --warnings-as-errors
python3 -c 'import ast; from pathlib import Path; ast.parse(Path("integration/http3/upstream/run.py").read_text())'
```

## 4. Qualify the unchanged complete workload

- [ ] Root runs the entire matrix into a new evidence root, recording actual
  source identities, selected normalized profile,68 executed checks,1MiB
  byte/hash/FIN, error/sibling/zero-baseline oracles and owned-process shutdown:

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' GAOXY_UP2_REPAIR=9 GAOXY_UP2_FAILED=17 python integration/http3/upstream/run.py --gate matrix --evidence docs/acceptance/evidence/m4/upstream-matrix
```

- [ ] Preserve and diagnose any FAIL, with actual cumulative counter updates.
  Never lengthen the five-second row deadline, lower bytes/windows, substitute
  FIN or call a partial matrix PASS. After complete PASS, obtain independent
  actual-evidence review and run a fresh entire68-check repeat at the same frozen
  source/profile with current counters. Only then complete prescribed final M4
  affected gates and conditional release qualification.

No build, packaged-runtime, publication or deployment acceptance follows from
this design/plan or scoped test success. Existing Vault, release-artifact E2E,
production data/certificates and public-management restrictions remain intact.
