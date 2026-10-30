# ARB-CORE-RELEASE-CODE

BLOCKED_ENV. Independent candidate acceptance is withheld. The coordinator has a selected-model capacity error, as reported by the implementation owner; no substitute coordinator/model or wider scope was assumed. All owned commands are terminal. This is not a numerical failure stop and does not reset the fixed deadline of2026-10-30T02:09:44Z.

Direct Sol read-only review, reviewer Sol0/Astra0. Underlying implementation remains Sol2/Astra11; next repair12 is pending. Astra11 is the passing14-case compatibility checkpoint, followed by actual round12 backing diagnostics and RED16/2, not a completed repair-and-validation round. No backing repair was made. Existing main at bc8a5ef5199293ada3b432c2e2741070d3b2d115, original goal baseline a6a35438c0a153cd53c87c6a55c19a70a11fb75a. Preserved adaptive/0.14.0 integration is dirty; no source/test/docs/manifest/dependency/Git changes were made by this reviewer. Only this report and sibling receipt were written.

## Findings

**R2 P1 OPEN: retained app state can keep unaccounted binary backing.** StreamBridge:71-75 passes input slices into callbacks; lines113,122,156 measure serialized app size, then restore delivery credit at idle. A returned app slice can retain an earlier larger backing after that delivery retires. This is concrete in round12-red-slices: both actual TCP and verified TLS first observations report prior backing8192 for a65-byte slice; the unchanged assertion requires65. Both cases fail there, so later distinct-delivery accumulation and drain steps in those new cases are not claimed executed. Source ownership and the adaptive design require a bounded normalization/accounting repair; no measured RSS leak or exact physical multiplication is claimed. This gap existed in legacy raw StreamBridge but remains relevant to the current adaptive backing invariant.

**R1 P2 RESOLVED at the Astra11 checkpoint:** the original candidate closed every raw-stream connection whose effective buffer exceeded16384, despite BackendOptions/docs permitting larger buffers. StreamBridge:147 now retains the finite1..2147483647 domain. D scales proportionally, and actual TCP/TLS32768 cases prove exact funded admission, repeated post-listener-barrier replies, terminal cleanup and floor-minus-one rejection. No documentation-only exception substitutes for this repaired behavior.

**R3 source concern, not a runtime-confirmed finding:** StreamBridge:81-89 measures output with iodata_length. Output aliasing current input is covered by the charged delivery; independently allocated large borrowed output backing still needs owner assessment. An app-state-only repair must explain output ownership. No output exposure diagnostic was run by this reviewer or claimed from the available evidence.

## Reviewed code and invariants

The narrow Service delta only appends raw-stream buffer/recbuf2048 defaults before accept/TLS handshake. Hell resolves options first-wins, so explicit user tuning remains ahead of those defaults. Native HTTP/UDP/QUIC setup and common Admission/Ledger were unchanged by this repair.

For the existing logical-size envelope, F=2D+2S+O with D=100B+18437 leaves at least oneD receive/copy floor at the D+oldS+newS+O callback/send peak. The full original input length remains charged throughout chunk recursion. Repartition preserves funded total, category allowance, membership and operation/deadline fencing; scalar begin/retain preserve temporary-credit and watchdog semantics. No blanket draining exemption, cap multiplier, per-chunk callback renewal or early owner refund was found. Existing max_state/max_output isolation and original drain-deadline controls remain asserted. This arithmetic does not resolve R2/R3 backing omitted by the logical sizes.

Hell arms active:once after the callback. Installed OTP SSL INTERNAL_ACTIVE_N100 and maximum ciphertext18432 plus header5 support the qualified default delivery profile. ssl_config permits an application-level internal_active_n override; independently altered profiles are unqualified, not certified here.

## Evidence independently inspected

Every listed raw-log SHA256 matches its JSON receipt, all source_changes arrays are empty and commands terminal. This reviewer ran read-only source/diff/hash/log commands, not Mix, tests, a VM or network/listeners. The sibling receipt records commands, source identities, exact raw hashes and which current task hashes each older run matches.

- round9-stream: PASS10/0; round9-release: strict production compile/release and original protected smoke PASS3transports. The smoke, ADR004 and StreamHandler are byte-identical to the original baseline. These are earlier-checkpoint evidence, not fresh current acceptance.
- scoped-compat: PASS72/0; final-scoped: strict format/compile/inventory and PASS10/0.
- round10-red: actual32768 compatibility RED14/4. round10-targeted and round11-targeted each execute14/0 but abort overall exit1 on new test warnings; later compatibility command is not reached. Failures remain preserved.
- round11-fixed: PASS exit0, strict format/compile/inventory,14/0 and compatibility72/0.
- round12-red-slices: FAIL exit2,16tests/2failures, first retained8192-versus65 observation as above. Current16-case source has no green backing repair.
- resource-proof: PASS actual ordinary-ETF exact value equality, crypto hash-update/final, shared atomics, ETS insert/lookup, closure-captured resource use and65-byte detached backing.
- resource-local-proof: FAIL exit1, invalid external representation; local-leaves diagnoses closure cases failing while ordinary leaves/mixed map succeed. The rejected local codec is not silently treated as compatible.

A prechecked uncompressed same-VM ETF normalization with an explicit identity check and truthfully funded copy overlap was discussed, but not implemented or accepted. Opaque resource usability must stay asserted, not replaced by equality alone. Normalization must not renew callback or service drain deadlines. Ordinary ETF identifier changes during a concurrent distribution-identity transition need fail-closed handling or an explicitly justified compatible approach.

## Handoff and remaining work

The terminal owner freeze is round11-blocked-handoff.json with round11-current-task.patch, task hashes and682input hashes. This reviewer independently verified all682current hashes and the patch SHA256 f7e13083eb35894551eba8ebef8645f35afdcc445b603976ab9fb6cde29997a4. Manifest16 is a sole additive14-to16 count update after the red diagnostic; full884inventory arithmetic is expected, not an executed884-test claim. Original candidate-task.patch/hashes describe the earlier Astra9 candidate and are not relabeled as current. A fresh owner freeze and verification are required after repair.

Coordinator recovery/decision and the bounded state/output repair remain unresolved. Parent owns serialized builds, fresh combined tests, source-built release smoke, final independent acceptance and any authorized delivery. No commit, push, publication or deployment occurred in this review. My long read-only search was terminated cleanly; no build/VM/network process was started.
