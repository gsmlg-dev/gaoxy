# TLS95 runtime tooling initial draft review

Task `m3_tls95_runtime_tooling_review`, direct independent Sol; worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `81b01bd3334fe4c90a739e1eebdee8bd29bf94f8`.

**FAIL for the initial builder/wrapper drafts, pending five alignment items.**
This is separate from the repaired specification PASS. The collector/sanitizer
and immutable fixture are not implemented/reviewed by this task. No runtime or
full native/collector gate is claimed. Original reports and other edits remain
preserved; only four assigned new review reports were written.

Reviewed builder `.audit/m3-tls95-baseline-materialize.py` SHA-256
`5c676d4775ce326831b77020055e802256aa6f362e40bccf05490346942b3f7f`;
wrapper `.audit/m3-tls95-identity-wrapper.exs` SHA-256
`1122d358d6a4f3d0159077f292f2709a6bdc2a40f2bf957e1e92e6763e821f50`.
The [JSON receipt](tls95-runtime-tooling-review.json) records exact inputs,
locations, findings and scope.

## Required draft alignment

1. **TLS95-TOOL-01 / P1 — separate acquisition from offline construction.**
   Builder lines36–39 download telemetry when absent, after old-source copies
   have already been created. The reviewed recipe treats missing archive as an
   offline-phase block. Standing authorization permits official public archive
   acquisition without a permission wait: first run a separately bounded,
   receipted acquisition with official URL, raw bytes, expected outer/inner
   checksums and shipped verification. Freeze that cache before the source-only
   materializer/build/run. Split the code phases or explicitly align plan and
   inventory with both phases; retain no resolver/substitution.

2. **TLS95-TOOL-02 / P1 — match the isolated layout and guard source ownership.**
   Builder lines18–23 follow existing symlinks; a matching symlink is silently
   accepted, and a dangling one can direct a write elsewhere. Existing unlisted
   source/build artifacts are ignored. Reject destination/ancestor leakage and
   stale/unlisted artifacts under the owned root; never alter parent files.
   Compare complete196 copied sets with old archive and collector freeze maps.
   Materialize the exact reviewed root manifest, minimal config, explicit empty
   lock and owned tool/deps/build layout. Copy/validate the exact telemetry `.hex`
   metadata identity: the draft currently copies shipped tar members only.
   Keep package manifests unchanged. Exact expected existing files may be reused
   only after containment and byte validation.

3. **TLS95-TOOL-03 / P1 — reconcile launcher, wrapper and startup.**
   The draft consumes `[driver | arguments]` and fetches `TLS95_COHORT_VERSION`
   and `TLS95_COHORT_ROOT`; the plan supplies only `--cases inventory` and
   `HTTP_FETCH_TLS95_DRIVER`, names a different wrapper file, and omits the two
   required variables from `env -i`. Synchronize one filename/driver interface,
   exact cohort/root values, fixture argv, CWD and sanitizer whitelist. Prefer
   the frozen driver environment variable while preserving case arguments.
   The plan says the wrapper starts `Application.ensure_all_started(:http_fetch)`;
   the draft only loads application metadata. Start the source-default declared
   closure before the identity baselines as specified. The future collector must
   actually enforce the sanitizer; that collector has not been reviewed.

4. **TLS95-TOOL-04 / P1 — bind real paths and all required module identities.**
   `Path.expand`/prefix tests are lexical and cannot reject symlink leakage.
   Current telemetry `_build/test/lib/telemetry/src` is a normal symlink into
   owned `deps/telemetry/src`; accept build-created links only after resolving
   their real target within the intended root. A baseline source/code target
   resolving into parent deps/build must fail.
   The wrapper accepts unloaded cohort modules and only visits `.app` entries.
   Require every listed seven-package/telemetry module loaded from its intended
   real BEAM origin, with disk/loaded MD5 equality. Check complete disk/`.app`
   module coverage and stale/unlisted loaded cohort origins, declared dependencies
   and required actual same-VM application/module closure.
   Its five native-app/nine-module records are a selected subset. Remaining
   compiler/config/native/Python/toolchain closure must have explicit collection
   and validation in the reviewed future collector; do not describe the selected
   map as complete native or collector proof.

5. **TLS95-TOOL-05 / P1 — preserve primary failure and require post evidence.**
   An exception in lines88–93 of `after` replaces the driver's original failure,
   losing the decisive RED reason. Capture primary result/error/stack separately;
   attempt and record post-identity outcome even on RED, then report/re-raise the
   primary with identity failure separate. Tell the fixture writer to return or
   raise after case reports, never `System.halt`: halt bypasses `after`. Freeze
   and check immutable driver/import bytes through an explicit wrapper/collector
   gate. Require both BEFORE and AFTER records for every invocation; missing AFTER,
   setup or identity failure cannot count as qualified RED.

## Static positives and finite limits

The builder correctly hashes196 old shipped bytes against old provenance and
retains package manifests. It never copies old BEAMs or replaces candidate deps.
Telemetry1.4.2 outer/inner digests are correctly pinned and extracted shipped bytes
are compared with actual installed source. There is no resolver invocation.

The wrapper already records eight application versions, each listed disk BEAM
hash/MD5/source and MD5 equality for actually loaded listed modules before/after
in the driver VM. Pinned OTP28 `beam_lib.md5` returns `{ok,{Module,MD5}}`, matching
its pattern; no tuple-shape bug is asserted. Current telemetry compile metadata
names the actual deps source, and the build src symlink is normal. These static
facts support targeted alignment; they do not qualify execution.

Fresh local checks exit0:63/63 inventory hashes,68 reviewed hashes and682/240
arithmetic pass; builder AST parses in memory without execution. Wrapper syntax/
VM, source materialization, acquisition, compilation and runtime are NOT RUN.
A receipt-generation Python quoting error occurred before execution/writes and
was corrected; no inspected input or tool implementation was changed.

Initial tooling Sol repair rounds0, unsuccessful0, Astra0; separate specification
chain remains Sol2/unsuccessful1/Astra0. `astra_gate: none`. Parent owns draft
alignment and changed-byte independent review, then collector implementation/review
and serialized execution. No user permission or product decision is needed for
the authorized bounded official acquisition. All own commands finished; no
background process, VM or peer was started. Four-report ownership released.
