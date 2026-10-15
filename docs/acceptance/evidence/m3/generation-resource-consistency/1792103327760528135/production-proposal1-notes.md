# Generation resource consistency production proposal

Task: resource_consistency_implementation
Status: DONE (patch proposal only; runtime validation remains owned by root)
Assignment: direct, production proposal after root-confirmed intended RED
Repository/worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation
Baseline: 8160e8bb6d7f55dc836b1aed0403cc2304a539bf

## Evidence and root cause

Read router.ex and generation.ex. Confirmed HEAD matches the handoff and those two production files have no existing diff. Expected new test/docs/evidence were untracked; all are preserved. Store.compiled_bound currently validates only the supplied sidecar shape before generation endpoint hooks and size acceptance. Router's existing collector does not recursively verify static Router sidecars, so matching forged inner/outer sidecars can omit actual route handles.

Root supplied executed RED evidence: 61 tests, 47 assertion failures expecting invalid_endpoint_resources against accepted public results, exit 2, joined/stable, no fixture exceptions, skips, exclusions, or warnings. This worker did not independently execute that command.

## Proposed change

The unified patch owns only router.ex and generation.ex:

- Add @doc false Router.validate_resource_sidecar/1. Validate supplied handles using the existing Resources.validate contract, collect expected handles from compiled targets, and compare exact normalized MapSet membership without rewriting either router or sidecar. Arbitrary equivalent order and supported duplicate lists remain accepted.
- Extend the existing collector with a private mode whose default preserves the original compile callback behavior. Its compiled mode checks exact static Router targets recursively before using their resources; malformed static nested options return the bounded resource error. No nested generation-reference requirement is added, so empty static Routers remain valid.
- Other atom endpoint modules are ensured loaded, then their optional resources callback is read; endpoints without that callback contribute []. The dynamic Generation endpoint therefore contributes [] without initialization or Store access. Existing collector rescue/catch normalizes callback exceptions, throws, exits, malformed route targets, and malformed callback results to invalid_endpoint_resources.
- Insert the validator after generation_bound and before full-router size acceptance. Root/router guards, input bounds, supplied Resources validation, hook precedence, and original size result remain unchanged.

No Endpoint or Resources schema change, provider custody/freshness calls, initialization, recompilation, process, dependency, protocol qualification, or global cross-Generation bound is introduced.

## Validation and ownership

Commands completed: read-only git rev-parse HEAD, git status --short, git diff of the two production files; source reads; Python generation of this /tmp patch and notes. No repository file was written, no runtime/mix/Nix/build/formatter/test command was run, and no Git mutation occurred. All worker commands finished synchronously; no process remains.

NOT RUN: patch adoption, formatter, compilation, GREEN suites, compatibility gates, independent review. Root owns them. No claim of implementation acceptance is made here.

Repair counters: this initial proposal introduces zero repair-and-validation rounds. Preserve root's inherited historical 24 failed GREEN attempts / 27 ordered repair events; Astra recovery remains 2/2, exhausted. No escalation gate applies to this proposal.

Remaining risk: actual compilation and regression results are not known until root adopts and validates. No product decision or new permission is needed.
