# Independent release preparation review

Task: unified-listeners-embedded-gateway / core_lifecycle release-preparation cross-review.
Assignment: direct, read-only; this audit report is the only edit.
Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway
Branch: codex/unified-gateway
Baseline: 656dbf5bb84564adc6a4d68247c0ad2fe52c2625, shared uncommitted task changes preserved.

## Verdict

PASS for release preparation; no remaining actionable mismatches in the reviewed documents, manifests, added workflow gates or consumer boundaries. This is approval of the prepared source and recorded local evidence, not a claim of hosted CI, publication or deployment. Parent owns the final source commit, evidence archive, checklist transitions and external publication receipts.

## Scope and resolved findings

Reviewed docs/embedded-gateway.md, docs/listener-sets.md, docs/phoenix.md, docs/releases/0.8.0.md, the current acceptance record and implementation checklist against actual ListenerSet/Phoenix/Gateway/Generation/upstream/standalone APIs, five application manifests plus root manifest, release/portable workflow additions, external-consumer scripts/projects and package staging.

Two documentation findings were sent to the parent and corrected before this verdict:

- The old Phoenix H3 paragraph incorrectly said the adapter owns only HTTP/HTTPS and H3 requires a separate service. It now leads with explicit adapter-owned H3 and describes a separate externally mounted service as supported compatibility, consistently requiring server:false for that mode.
- The runnable reference version now says Phoenix 1.8.16, matching its actual pinned dependency.

Reread both corrected passages. No production/source edits were made by this reviewer.

## API, package and compatibility assessment

The guides agree with current code: pure reusable Plans reject runtime capabilities; H3 is explicitly enabled through its optional provider; one ListenerSet shares one prepared target and direct core instance; Gateway uses one shared runtime and a stable store per declared logical set. HTTP has no Proxy/Server or reverse H3 Mix dependency, core has no HTTP dependency, and reusable Gateway code has no Server reference. The no-H3 consumer copies Core/HTTP/Proxy sources only, and the H3 consumer adds HTTP3 without Server source. Their real traffic/reload/stop and missing-module assertions establish their intended boundaries.

Gateway documentation matches expected_revision/finite timeout, optional shortening absolute deadline, bounded pending/latest-terminal receipt retention, reconcilable operation identity, immutable accepted trust, owner epoch recovery and whole-root stop with supervised pending cleanup. It states that bindings/certificates need restart and complete root/VM loss returns to startup configuration. Standard standalone names, JSON v1/readiness and file reload remain adapters to the same Gateway; legacy services are independent sets. The additive pending result is documented without changing the facade's successful generation-valued return.

Phoenix docs retain HTTP/HTTPS defaults and server_info shape, distinguish the logical owner PID from its core instance, include explicit H3 credentials/address and transport inspection, and preserve server:false/external duplicate ownership, exact socket paths and code reload. Discovery docs describe opt-in secure H1/H2 final-head insertion before header budgets, suppression on current unready state, independent ephemeral ports and client cache lifetime limits. Unsupported H3 capabilities and local-host cleanup remain explicit.

Root and five own app manifests contain exactly version 0.8.0; each manifest diff is only that version line. Vendored adapter version remains upstream 0.6.0. Unchanged staging emits the coordinated gaoxy_websock_adapter 0.8.0 distribution with app key websock_adapter, so the Phoenix guide's published override requirement is correct. Five Hex distributions exclude gaoxy_server; standalone app/release metadata is coordinated. mix.lock, vendor source/provenance and stage-hex-packages.exs have no task diff. Existing pinned dependency provenance and strict staging mapping remain intact.

The acceptance record preserves failed prior runs and reproduced baseline failures, reports overlap instead of adding test runs as unique cases, and separates local verification from NOT RUN hosted/publication/deployment states. Pending checklist/source-archive/publication transitions are intentionally parent-owned; this review does not advance them speculatively.

## Workflow assessment

New external Core/HTTP/H3/Gateway/Gateway-H3 consumers, exact nonempty ordinary gate and actual unified browser/peer acceptance run on the checked-out publication source before package uploads. Consumer scripts use temporary isolated projects, pinned lockfiles, strict compile/test and finite tests; only Core seeds its Hell cache so optional-directory isolation assertions remain meaningful. Global release MIX_ENV=prod is overridden to test inside consumer/gate commands and dev for the unified reload fixture. Python peer/browser requirements are pinned and provisioned before use; H3 peer paths reference the provisioned environment.

No new gate uses continue-on-error or an always condition permitting publication after failure. The browser script returns nonzero on failed assertions and restores its source mutation; package publication still requires exact committed version/SHA, unchanged source, all builds/smokes/archives, and the final remote branch SHA recheck. The existing sequential Hex publication, downloaded archive comparison, tag and GitHub release sequence is unchanged. Artifact upload with always only preserves evidence; it does not override later success gating. Existing disabled specialist sustained-load and release-artifact E2E boundaries remain intact. Hosted execution is NOT RUN at this review point.

## Verification actually performed or inspected

Static checks performed by this reviewer, all exit 0:

- Existing isolated .audit/workflow-yaml/bin/python parsed both YAML files; every portable35 and release20 run block passed bash -n.
- Explicit ordering/no-continue-on-error checks confirmed the new consumer/exact/browser and final source recheck gates precede Hex upload.
- All five external-consumer shell scripts passed bash -n.
- Regex validation confirmed exactly six own manifests each declare only 0.8.0.
- SHA256 validation matched all 10 vendor SOURCE.json files.
- SHA256 validation matched all 122 current runtime files to the five actual package receipt entries in .audit/unified-package/receipt.json.
- Scoped git diff --check passed on documents/workflows; git diff confirmed unchanged lockfile, vendor and staging provenance.

Fresh parent evidence inspected without rerunning Mix:

- .audit/unified-exact-final3.log ends REPAIR_PASS 265 executed, 0 failures, 0 excluded, 0 skipped.
- .audit/unified-phoenix-final2/report.json: PASS, all 8 individual checks PASS, process_exit 0, source_restored true. Includes independent TLS H1/H2/H3, browser H2/H3 sockets, reload/restoration and Endpoint shutdown.
- .audit/unified-prod-compile-final.log shows current affected apps compiling; final production compile/format/release exit 0 supplied by parent. Formatting log is empty on success.
- .audit/unified-package/receipt.json reports PASS, version 0.8.0, five archives and 122 runtime payloads; current payload hash verification above independently confirms no source drift for those files.
- Earlier consumer, targeted test and lifecycle followup evidence remains recorded in .audit/unified-final-gateway-review.md and the HTTP worker's independent review.

## Status and limits

DONE for this read-only release-preparation review. All reviewer commands finished; no Mix commands, commits, push, publication, deployment or permission changes performed. Sol repair increment 0; inherited whole-task counters remain parent-owned; no Astra gate/counter used here. No additional decisions needed. Final committed source/evidence links, hosted workflow outcome, external package/tag/release receipts and publication checklist completion must be recorded by the parent when they actually occur.
