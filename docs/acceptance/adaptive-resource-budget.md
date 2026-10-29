# Adaptive resource budget acceptance

Status: implementation in progress. No publication or production acceptance is
claimed by this checkpoint. The objective is the complete adaptive budget,
dynamic H1/H2/H3 ownership, Phoenix integration and coordinated release.
Design and remaining tasks are recorded in
[the design](../designs/adaptive-resource-budget.md) and
[implementation plan](../plans/adaptive-resource-budget.md).

## Qualified foundation checkpoint

Source: local `main` commit `a0a05efe`, following memory foundation
`bf2b2865944d85c18917d00854a5c503ce3b443d`. Neither checkpoint has been pushed
or released as part of this objective.

The memory foundation passed 53 focused cases and a fresh qualification of
636 ordinary, 12 packaging and seven clean-consumer tests. The standalone
canonical owners and pure configuration then passed 120 recovery cases and a
fresh combined OWNER/MEM/CONFIG run of **147 tests, zero failures, exclusions
or skips**. Strict compilation, owned formatting and inventory checks passed.
The active inventory at that checkpoint is unit 351, component 242, protocol
137; these inventory counts are not a claim that all 730 tests were rerun after
the OWNER/CONFIG change.

Independent specification/code reviews accepted memory detection, policy,
standalone owners and normalized configuration after the recorded repairs.
The architecture review accepted the documented shared ownership, deadline,
deduplication, overlapping membership and safety-sampling contracts. Production
lifecycle and protocol code still require their own review and verification.

Evidence is retained under
[`evidence/adaptive-resource-budget/`](evidence/adaptive-resource-budget/).
Original failed runs and the passing candidate that subsequently received
review findings remain historical evidence. The OWNER final recovery and
147-case combined run are under `owner-final/`; they do not overwrite the
earlier candidate receipt. The staged checkpoint whitespace check reported an
extra terminal blank line in the immutable `owner-candidate/initial-green.log`;
the raw log was preserved byte-for-byte. Source whitespace checks passed.

## Requirement-to-evidence boundary

The next local checkpoint integrates production Service/Instance registration,
canonical Admission mutations, pre-spawn credit and activation, terminal pairs,
authenticated cleanup guardians and `Gaoxy.resource_budget(instance)`. CORE's
bounded recovery passed 241/0; independent parent review and a fresh combined
run passed **312 tests, zero failures, exclusions or skips**, with strict compile,
formatting, inventory and source whitespace checks. The combined run includes
CORE 241, configuration 45, Phoenix pure 11 and outer compatibility 15.

ListenerSet/Phoenix and Gateway now propagate one normalized top-level instance
policy. Gateway rejects explicit instance policies inside embedded ListenerSets.
Standalone JSON accepts the two public thresholds and three independent quotas
through fixed allowlists. These pure configuration paths passed review and the
combined run. The two prepared real Phoenix/ListenerSet cases are **NOT RUN**
pending H1 connection metadata. H1/H2/H3 dynamic integration remains in progress.
Receipts and immutable logs are under `core-candidate/`, `core-final/` and `entry/`.
The whole staged whitespace check reports the one-space context markers inside
archived raw unified diffs (exit 2); those evidence files remain byte-preserved.
The staged source/documentation check excluding raw evidence passes (exit 0).

| Requirement | Current evidence | Disposition |
| --- | --- | --- |
| Effective physical/cgroup capacity; nested v1/v2, unlimited, malformed and overflow handling | Focused SystemMemory tests, Linux execution | PASS for implemented detection; native macOS/Windows execution NOT RUN |
| Platform native probe ownership and bounded cancellation | Injected native facility and worker lifetime tests | PASS controlled cases; actual macOS/Windows native paths NOT RUN |
| 50% default, 256/512 MiB fallback, exact 100%/200% thresholds | Pure Policy and standalone OWNER boundary tests | PASS standalone |
| Shared VM and instance memory without listener multiplication | Canonical OWNER tests across registrations | PASS standalone; production integration NOT RUN |
| Atomic projected admission, release/recovery, refresh shrink | OWNER controlled concurrency and capacity tests | PASS standalone; protocol use NOT RUN |
| OOM headroom, process credits, stale/missing samples | Safety and OWNER tests | PASS standalone; production use NOT RUN |
| Authority recovery, permanent ledger-loss fencing | OWNER crash and reconstruction tests | PASS standalone |
| Explicit undoubled legacy caps, independent quotas, omission provenance | CONFIG/activation/provider tests and OWNER caps | PASS pure/standalone; integrated lifecycle NOT RUN |
| Authenticated cleanup receipts and gate-loss reconciliation | Canonical allocation paging/retirement tests | PASS standalone API; Service integration NOT RUN |
| Dynamic H1 accounting, independent connections and keep-alive request completion | Protocol implementation outstanding | NOT RUN |
| Dynamic H2 retained state, prepaid decoder peaks and independent connections/streams | Protocol implementation outstanding | NOT RUN |
| H2 local refusal with HPACK continuity and live siblings | Protocol implementation outstanding | NOT RUN |
| H3 admitted spawn, QUIC/operation/stream ownership and local rejection | Protocol implementation outstanding | NOT RUN |
| Phoenix LiveView/WebSockets and multiple Endpoint ownership | Phoenix/runtime implementation outstanding | NOT RUN |
| Mixed ListenerSet HTTP/HTTPS/H3 policy and lifecycle | Integration outstanding | NOT RUN |
| SSE, streaming responses and overlapping ordinary uploads | Fresh integrated clients outstanding | NOT RUN |
| Ordinary churn, cancellation and drain | Fresh integrated lifecycle checks outstanding | NOT RUN |
| Numeric telemetry, rate-limited warnings and public inspection | OWNER telemetry/warning tests | PASS standalone; public instance API NOT RUN |
| Exact-source package/consumer/runtime qualification | Must follow completed integration/review | NOT RUN for final publication source |
| Coordinated commit, push, release and public artifact verification | Local foundation commits only | Push/release NOT RUN |

The retained specialist pressure, slow-peer, sustained-load and historical
blocked-upload slices keep their existing disposition. This objective does
not reopen those slices or `http_fetch#97`. Ordinary concurrent protocol and
Phoenix cases remain required. Browser automation, deployment, production
data, operational certificates, Vault and public management are outside scope.

## Release boundary

The final version is selected only after checking current remote releases.
All affected public packages must use one version. The existing release
workflow takes the full already-versioned `expected_sha`, repeats qualification,
publishes six Hex packages, verifies public tarball bytes, tags that source and
creates the GitHub release. Final acceptance requires the actual workflow and
public consumer/artifact results; a prepared package or local commit alone
does not satisfy publication.
