# Native worker initial candidate byte/evidence audit

Task `checked_browser_source_review`; direct parallel read-only evidence audit, **PASS** with no actionable findings. This is not an implementation SPEC/CODE review or final stage acceptance.

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, baseline `58307a7084298db309a93697b9102b2cc4c87eda`. Candidate `full-stage-candidate1.json` SHA256 `9ee11ab2c847c90ef64ce8c4766d116563380ee24a1c368d9e967d1c70766982`.

- All **245 source files / 3,848,401 bytes** and **409 evidence files / 12,590,126 bytes** matched exact frozen SHA256 and lengths; no missing/mismatched file. Both canonical manifest digests recompute correctly: source `ca914fb73c36c511c688c65d2f255941d85bddb1ca35d19e278fb2246a062c8c`, evidence `246d00d923803de160497a0486e3e8ccfca3b3c63499b0ae196a5ffd78cee977`.
- The constructor candidate hash and all listed source deltas match actual manifests. The only production-byte changes since that checkpoint are outer `HTTP.Connection` and `HTTP2.Transport`, exactly as declared. This audit does not independently recertify their source semantics.
- Both protected user files match the candidate's required hashes. No unrelated file was changed/staged.

All nine initial command receipts match their frozen receipt hashes and exact log hashes/lengths. Their before/after command snapshots are identical; actual exit0, direct-process joined, process-group absent, no timeout, zero unexpected compiler/test warnings, no skipped/excluded tests or exclusion declarations are recorded and corroborated by saved logs. The known dirty-tree environment warning stays separate. Collector script hashes resolve to retained frozen collector versions.

| Initial receipt | Executed tests | Source cutoff versus candidate application files |
| --- | ---: | --- |
| core-green2 | 68 | Before outer Connection, Transport and startup/proxy fixture updates |
| native-green5 | 94 | Current candidate application bytes |
| preserve-http-green1 | 230 | Before outer Connection and startup/proxy fixture updates |
| preserve-compat-green1 | 161 | Before outer Connection and startup/proxy fixture updates |
| metadata-close-green2 | 13 | Current candidate application bytes |
| core-consumer-green1 | 1 | Before later admitted-spawn test, Connection, Transport and startup/proxy fixture updates |
| http-consumer-green1 | 2 | Before outer Connection and startup fixture updates |
| compile-green1 | 0 (compile) | Before outer Connection and startup/proxy fixture updates |
| formatting9 | 0 (formatter) | Before outer Connection and startup fixture updates |

These are initial evidence cutoffs, not fresh final claims. In particular formatting9 ran `mix format`, not `--check-formatted`; compile-green1 was strict warnings-as-errors but did not use `--force`. Required fresh acceptance-union, strict compile/format and both isolated consumers remain pending exactly as the candidate states.

## Unique acceptance scope and counts

The saved argv lists exactly match scopedcollector4's four group definitions: core5 files, native7, preserve_http11, preserve_compat8. There are31 file occurrences and **30 unique files**. The only overlap is `managed_h2_generation_exclusion_test.exs`, included twice and containing three top-level tests. Therefore expected fresh union execution is **68+94+230+161−3 = 550 tests**, with per-app expectation core61 / HTTP302 / proxy178 / HTTP3 9. The separate13 metadata-close tests are already included in native94, not13 additional union tests. Consumer1+2 and browser2 remain separate gates.

The union includes admitted_spawn, admission timeout, native/cleanup compatibility, worker arithmetic, startup, stale-start, H2 capacity/independent/network, original checked Generation/resource/legacy HTTP and proxy/H3 preservation files. All three newly added metadata regressions are unfiltered tests in included `http2_worker_startup_test.exs` (current13 total). Original required group files remain in the set; no `--only`/skip/exclusion is used for acceptance.

## Browser and artifact custody

`browser-command5.json` matches frozen SHA `c79bb0c0b6045b5deab5270e91a6f62d48ad9d5ab29e1641dbfe5cddd239a47e`; exact command log hash matches. Command is actual PASS/exit0/joined/group absent/no timeout/no forced or remaining outer descendant. Linked `browser-green5/qualification.json` SHA `95f201d93c4199b7783aa98837a740cd023d493ca62e189ac8df0753dbcc40e4` matches; both H2 and H1 cases PASS, with real h2 and http/1.1 document records. All26 nested artifact hashes match. Source snapshots are equal and match candidate hashes for their intersection.

All **six primary Actors** report actual0/nonforced/readers joined/groups absent. **Fourteen adopted wait receipts** are explicit:12 exit0 and2 signal10 (decoded−10), with no remaining child. These internal statuses are not called14 normal primary exits. H2 records six and H1 three genuine native cohort joins and final Gate0. No failed historical browser receipt is upgraded.

No certificate/private-key file extension or actual PEM certificate/private-key block occurs among frozen evidence artifacts; browser certificate metadata retains fingerprints only and its recorded ephemeral certificate directory is absent. Quarantine metadata identifies the old raw trace strictly outside the repository. Original in-repo raw path is absent, no raw path is tracked or in the frozen manifest, and the retained redacted trace matches its recorded hash with unsafe system-state replies omitted. **The sensitive `/tmp` raw archive was never accessed**, including for hashing/stat. No contents from it are in this audit.

Old full-stage-freeze1/2 remain explicitly UNEXECUTED_SUPERSEDED. Independent full SPEC then CODE, fresh final gates, final byte custody and local commit intentionally remain pending; whole M3 remains incomplete. Counters unchanged group40/root52/stage10/Astra2/2 exhausted.

Commands were file reads/searches, read-only Git listing, and stdlib JSON/hash/AST/log analysis only; no project/runtime/test/browser/network process or Git mutation was run. Only assigned `/tmp` reports were written. All commands finished; no task-owned process remains.
