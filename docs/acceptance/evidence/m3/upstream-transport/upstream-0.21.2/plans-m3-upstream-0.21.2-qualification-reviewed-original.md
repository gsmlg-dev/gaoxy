# M3 published 0.21.2 qualification plan

> Agentic workers: use `subagent-driven-development` or `executing-plans`.
> Standing authorization in `AGENTS.md` applies; no routine approval pause.

**Goal:** Qualify the next published seven-package HTTP cohort and, only if it
contains the OTP28 tracking fix, reopen the blocked TLS functional gates.

**Architecture:** Preserve the reviewed 0.21.1 delivery, then bind the new
published archives, installed sources and fresh executions together. Keep
managed production integration disabled and every complete P0–P6 obligation
unqualified. Source containment and functional TLS tests are separate gates.

**Stack:** The existing Nix/OTP28/Elixir profile, HTTP Fetch family, ExUnit and
the existing independent Python transport peers. No toolchain refresh.

## Trigger and scope

Parent observed GitHub `v0.21.2`, published `2026-10-10T20:33:44Z`, and Hex
`0.21.2`, inserted `2026-10-10T20:30:41Z`, at `20:41:15Z`. This is publication
metadata, not proof that the fix is present or qualified. Installed inputs
remain 0.21.1 at this plan's initial checkpoint. The prior reviewed delivery is
local commit `81b01bd3334fe4c90a739e1eebdee8bd29bf94f8`; do not overwrite its
receipts, logs, reviews or source maps.

Packages are `http_core`, `http_runtime`, `http_fetch`, `http_web_socket`,
`ex_ssl`, `elixir_quic` and `elixir_quic_http3`. Update only the two existing
direct exact pins and these seven lock entries. Keep the 17 unrelated lock
entries identical. No dependency source patch, private process access or
substitute TLS tracker is allowed.

The source collector identifies commit
`f677ca49519a007a7a551a5a515127c0f29d8ae6`, tree
`664a2a0de2bd4820017599b2d25f62bc7dcf63b0`, 196 shipped files and 175 runtime
libraries. Its early delta includes seven runtime paths; the source review must
finish before these inputs are accepted. The new OTP28 socket branch is the
eight-element `{:sslsocket, tcp, receiver, sender, :gen_tcp, _, _, _}` form.
It and the restricted legacy form must be traced as actually shipped.

Parent owns dependency mutation, all Mix/VM/network execution, input freezes,
cohort fact/test updates, current-status documentation and local commits.
An independent source worker owns new provenance/source receipts under
`docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.2/` and its ignored
collection cache. A separate reviewer verifies installation and the final
delivered candidate. Writers have disjoint ownership and preserve peer edits.

## Task 1: Establish published source containment

- [ ] Collect seven actual archives, Hex metadata and GitHub asset/tag/tree
  identities into a new ignored `.audit/m3-transport/upstream-0.21.2/` cache.
  Verify inner and outer checksums, coordinated package requirements and all
  shipped bytes against immutable Git blobs. Preserve failed acquisitions.
- [ ] Independently review all source deltas against the published/installed
  0.21.1 cohort. Specifically trace `RequestLifecycle.track_tls/2` from the
  actual OTP28 socket shape through receiver/sender registration, monitor
  release and the scope retirement contract. Identify fix95 containment and
  any new costs/premises; issue closure alone cannot pass this step.
- [ ] Review this plan and the applicable existing public fixture assertions.
  Fix actionable specification findings before installing or running peers.
  If the containing artifact is absent, keep that task blocked and continue
  the independent pure-model/source work.

## Task 2: Preserve and install the coordinated cohort

- [ ] Save all 429 current frozen inputs and selected loaded/build BEAM files
  into a new ignored `installed-0.21.1-preserved/` directory. Verify every
  copied hash and bind the preservation receipt to commit `81b01bd`.
- [ ] Replace the two existing dependency strings in
  `apps/gaoxy_proxy/mix.exs` from `== 0.21.1` to `== 0.21.2`. Run parent-owned
  `nix develop --command unbuffer mix deps.get` with the existing bounded
  collector and `ERL_FLAGS='+S 2:2'`, `MIX_ENV=test`. Preserve any failed
  invocation and diagnose it under the normal Sol/Astra policy.
- [ ] Independently verify every installed shipped file, `.hex` identity,
  archive/lock inner and outer checksum, both exact pins, seven changed lock
  entries and 17 byte-identical unrelated entries. No runtime claim follows
  from this installation check.

## Task 3: Rebind cohort facts without qualifying old formulas

- [ ] Change the expected provenance in
  `apps/gaoxy_proxy/test/managed_h1_accounting_test.exs` to version `0.21.2`
  and the Task1-verified tag commit:

  ```elixir
  assert %{version: "0.21.2", packages: 7, tag: "f677ca49519a007a7a551a5a515127c0f29d8ae6"} =
           facts.cohort
  ```

  Run that file with
  `unbuffer mix test --no-start --warnings-as-errors --max-cases 1 --seed 21112026`;
  require one precise cohort-identity assertion failure and all other checks
  passing. This suite is pure; `--no-start` is appropriate only here.
- [ ] Change only `ManagedH1Accounting.facts/0`'s version/tag to those same
  verified identities. Rerun the pure file and require all four tests pass.
  Preserve activation refusal and all seven unqualified obligations. Old
  0.21.0/0.21.1 accounting lemmas stay bound to their original source.

## Task 4: Run fresh compatibility and public TLS qualification

- [ ] Freeze the installed/current executable inventory. Run sequentially
  through the parent collector:

  ```sh
  nix develop --command bash -c 'set -e
  unbuffer mix format --check-formatted
  unbuffer mix format --check-formatted integration/http_fetch_contract/managed_transport_probe.exs
  unbuffer mix compile --warnings-as-errors
  unbuffer mix test --warnings-as-errors --max-cases 1 --seed 21112026'
  ```

  Require actual nonzero counts, zero failures and unchanged inputs. The mixed
  application/network suite must start its applications; do not use
  `--no-start` here. Record any excluded platform/profile gates explicitly.
- [ ] After source/install/specification checks, run the unchanged default
  `managed_transport_probe.exs` through the parent collector, using the
  existing independent peer Python environment. Require exactly 39 distinct
  completed cases, 39 successful joined cleanups, the exact canonical capacity
  MATCH, all existing finite-deadline/wire/no-replay/retirement assertions,
  exit0, stable inputs and no remaining owned peer. Do not weaken expected
  abnormal-completion cases or replace this with the 24-case subset.
- [ ] Assess what the actual public snapshots/receipts and source tracking
  prove about TLS receiver/sender registration and termination. If the
  unchanged driver lacks a decisive95 regression observation, first write and
  independently review a bounded public-API supplemental fixture plan, then
  implement and execute it. Do not inspect private TLS/pool internals, invent
  a release acknowledgment, or label 39 functional cases as lifetime closure.

Held upstream preparing/connecting saturation, complete86 adversarial backlog,
TLS exposure/backing and active-N lifetime proof, complete accounting,
production conformance, managed soaks and M3 completion remain separate gates.
A functional full-driver PASS removes only its actual functional blocker.

## Task 5: Synchronize, review and commit locally

- [ ] Synchronize current cohort/fix/gate status in the transport design/plan,
  acceptance, affected dependency request and contract READMEs. Date historical
  observations; keep old receipts and all failure/repair counters intact.
  Update adapter comments only if the source/qualification evidence warrants
  it; preserve the dedicated adapter's runtime behavior.
- [ ] Freeze task-owned files and current executable inputs. Independently
  review source, tests, raw logs/counts, complete joined cleanup and gate claims.
  Resolve findings, run fresh scoped checks and verify exact frozen identities.
  Preserve raw-log bytes; check source/document whitespace separately when a
  raw execution log retains its original terminal blank line.
- [ ] Locally commit only the reviewed cohort delivery, then resume the
  independently specified qualification model/full-ledger work using the
  qualified installed cohort. No push, merge, release, deployment, Vault or
  production-data operation. M4 cannot start before M3's required gates close.

Serialize dependent steps and runtime commands. Parallelize independent source,
plan and evidence review. Counters start at Sol0/Astra0 for this new cohort
chain; retain earlier chains separately and escalate only under the existing
two-unsuccessful-repair or evidenced technical-impasse rule.
