# TLS95 repaired parent tooling review

**FAIL: five finite actionable findings.** Independent static review of parent-authored tooling only, performed in specification-compliance then code-quality order. No independent fixture conclusion is supplied by its author.

Task `m3_tls95_repaired_tooling_review`, direct Sol; worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`, reconciled baseline `b2ac78b518f459ec2c95b7823226640413f2ca95`. Both review-report files are new; all inspected inputs and historical reports are preserved.

## Specification compliance

### TLS95-REPAIR1-01 / P1 — Verify installed telemetry .hex before any destination writes

Location: `.audit/m3-tls95-baseline-materialize.py:66-68`.

The materializer copies deps/telemetry/.hex and computes its new hash without comparing it to the reviewed acquisition receipt or frozen inventory. Shipped telemetry bytes and archive checksums are verified, but .hex is not archive-shipped and is outside those checks. The current .hex hash passes an independent read-only check; the script itself does not enforce that identity.

Required change: Before the first preserve call, require a PASS acquisition receipt and compare the installed .hex hash to its reviewed installed_hex_sha256 or the independently frozen inventory value. Fail before writing if it differs.

### TLS95-REPAIR1-02 / P1 — Validate the complete owned Hex/tool destination inventory before copying

Location: `.audit/m3-tls95-collector.py:51-78,125-128`.

install_tools validates existing files under MIX_HOME and source/archive symlinks, but HEX_HOME is only mkdir(exist_ok=True). An existing candidate .hex directory symlink is accepted and supplied to the VM; stale/unlisted .hex contents are neither rejected nor frozen. Existing unlisted empty MIX_HOME directories are also accepted. The collector lacks the materializer complete-destination prevalidation for its separately owned candidate tool root.

Required change: Before any tool destination writes, reject symlinked target/HEX_HOME/ancestors and stale or unlisted files/directories in the complete owned tool root. Bind HEX_HOME to its intended real owned root and include its inventory in before/after receipts. Preserve mismatching existing bytes and stop rather than deleting them.

### TLS95-REPAIR1-03 / P1 — Always preserve the actual command exit and post-identity failures

Location: `.audit/m3-tls95-collector.py:170-194; protected():30-45`.

After process.wait returns an actual exit, outer calls protected(), source/build scanning and JSON parsing before creating the final receipt. protected validates frozen inputs while reading them; a changed/missing input raises immediately. That failure path preserves the raw log but loses the final receipt containing the actual exit and distinct identity error. The wrapper primary/post separation is repaired, but the outer collector can still replace the command outcome with a post-collection exception.

Required change: Capture the actual process exit/timing immediately. Attempt each post collection independently, retain its raw data or explicit failure, and always write a final receipt containing primary exit plus separate post-identity/collection errors. Fail qualification on any missing/mismatching post evidence while preserving the driver failure.

### TLS95-REPAIR1-04 / P1 — Native profiler omits transitive launcher/interpreter inputs

Location: `.audit/m3-tls95-native-profile.py:41-71`.

The profiler hashes each selected tool entry point and follows ldd dependencies only for ELF files. It does not follow shell/Tcl scripts, executable wrapper targets, interpreter/package inputs, or non-ELF launcher dependencies. Installed expect layouts have an ELF bin/unbuffer and a separate bin/.unbuffer-wrapped script that executes tclsh and package require Expect. The collector launches unbuffer, but none of that hidden script/interpreter/package closure is added by this profiler. The profiler does not launch unbuffer, so its Python /proc maps cannot supply that missing closure. ELF linkage of the wrapper alone does not include executables/scripts it later launches.

Required change: Freeze and validate the actual selected unbuffer wrapper target, Tcl interpreter and required Expect/Tcl package inputs, and equivalent transitive inputs for the other selected script/wrapper launchers and compiler tools. Keep file-identity claims separate from ABI/lifetime qualification.

## Code quality

### TLS95-REPAIR1-05 / P2 — Partial failure receipts can be overwritten on a same-name retry

Location: `.audit/m3-tls95-collector.py:18,86,112,120,128-131,160,173-194`.

The only initial evidence-preservation guard checks name.json. All sidecar JSON writes use write_text. A failed attempt before the final name.json can leave environment/source/tool/inner receipts; retrying that name overwrites those sidecars before the later exclusive log open fails. The raw log guard therefore does not protect the already written partial receipts.

Required change: Reserve every output name before any mutation or use exclusive creation for all evidence files. Reject a reused name if any corresponding log/sidecar/final receipt exists, including incomplete attempts. Never replace prior failure evidence.

## Repaired portions and verification limits

TLS95-TOOL-01 and TLS95-TOOL-03 are statically closed. The materializer validates the complete pre-existing baseline destination inventory before writes, retains all 196 old shipped bytes/manifests, and matches the reviewed consumer manifest/config/empty lock. The wrapper synchronizes env/argv/startup, checks all eight applications and complete disk/listed module sets, resolves actual BEAM/source origins, requires loaded/disk MD5 equality, collects same-VM application/module/native-file identities, and preserves primary errors separately from post errors. TLS95-TOOL-02/04/05 remain partial for the concrete gaps above.

Fresh checks pass: 14/14 frozen hashes, four in-memory Python AST parses, 10/10 fixture/helper/tool hashes (identity only), telemetry outer/inner archive checksums, all 16 shipped source hashes, all 63 protected hashes, and the installed .hex receipt hash. Reviewed input hashes and verification details are in [the JSON receipt](tls95-repaired-tooling-review.json). No inspected tooling was executed or imported.

Source materialization, build, wrapper VM, baseline RED and candidate GREEN are **NOT RUN** by this review. Native/file identity does not qualify ABI, bytes, lifetime or M3. The fixture needs a separate independent reviewer; this report does not assess its implementation.

Tooling Sol repair1 is unsuccessful after this FAIL: cumulative Sol repairs1, unsuccessful1, Astra0. The separate specification chain remains Sol2/unsuccessful1/Astra0; fixture chain remains Sol0/Astra0. `astra_gate: none`. Parent owns tooling repair2 and changed-byte independent review; no user/product decision is needed.

Only these two reports were written. All own commands completed or were stopped safely; no owned background process, VM or peer remains. Review-report ownership is released on delivery.
