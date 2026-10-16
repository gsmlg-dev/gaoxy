# Initial evidence audit1

DONE — PASS bounded evidence audit; RED1 remains FAIL_INVALID_REGRESSION.

Direct independent read-only preparatory audit in `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, parent-confirmed baseline `8131af39a846c292a022ccbfd32c53376cd57887`. No Git/runtime/build/browser/network/process operations or repository changes. Worker runtime tests:0. This is not full-stage SPEC/CODE acceptance.

| Run | Actual tests/failures/exit | Assertion disposition |
| --- | --- | --- |
| source-repair2-red1 |93/2/2|Invalid: KeyError :startups at649, before stream3.|
| source-repair2-red2 |93/2/2|Intended: fresh peer GET receipt at685 fails after actual-target/native accounting witnesses.|
| scoped-initial4 |93/0/0|PASS for this initial two-file scoped suite.|

All three commands are identical, unfiltered, under MIX_ENV=test and ERL_FLAGS=+S 2:2:

```text
nix develop --command env ERL_FLAGS=+S 2:2 MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs
```

Each receipt contains400 source entries, exactly stable before/after, source_changes[], no skipped/excluded tests and no recorded compiler/test warnings. Each log still has the Nix dirty-tree warning at line1; collector168-169 excludes that notice. Main processes joined without force/wait error/group residue.

Across all400 entries, RED1→RED2 changes only the test; exact snapshot diff replaces `state.startups == %{}` with `state.starting == nil`. RED2→GREEN changes only HTTP: strict raw retained validation/manual copies become `prepare_group_source(source)`. Snapshot/current inspected source bindings and classification/receipt/log/collector/restoration hashes all agree.

RED2 log160-169/183-192 reaches test685. Source-reviewed test643-684 requires old completion/native disappearance, same connection stream1→3, actual110-byte target equality/logical<backing<=65536, auxiliary noncompact-header witness, real capture/native accounting before dispatch. Old HTTP423-475 invokes strict compact retained validation before copy; envelope43-63/186-213/585 explains deterministic rejection. This is source reasoning combined with observed failure location, not a newly observed runtime return-value trace. RED1 log143/321 and stack307/485 instead prove fixture failure; collector intended-RED exit0 remains pending assertion audit.

Restoration JSON records exact candidate HTTP restoration and collector return0. Both planned red hashes/test hashes and immutable candidate snapshot match; subsequent GREEN source independently agrees. No separate executed swap/try-finally script was inspected, so mechanism execution itself remains root attestation.

Adopted cleanup receipts preserve literal waits: RED1 pid591882 status10; RED2 pid2644456 status10 and2641682 status0; GREEN pid1199326 status10. All were reaped before force, with no signal attempts, force, deadline exhaustion or residue. Linux status10 means signal10 (decoded exitcode-10), never exit0; GREEN main-command exit0 is separate.

Read-only inspection errors preserved:

- `ls -l` on both not-yet-created assigned reports exited2: `ls: cannot access ...: No such file or directory`. Reports were absent; only these assigned outputs were subsequently created.
- `rg` included mistaken `apps/gaoxy_proxy/test/support/managed_h2_fixed_endpoint_fixture.ex` and exited2: `rg: apps/gaoxy_proxy/test/support/managed_h2_fixed_endpoint_fixture.ex: No such file or directory (os error 2)`. `rg --files` recovered paths; actual fixture lives in `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs`; bounded follow-up reads exited0. Exact commands/errors are in JSON.

All other own reads/comparisons completed exit0. Initial broad JSON output was truncated and replaced by targeted reads. Final audit-pass before/after digests match for all29 inputs; hashes below and complete structured checks bind conclusions. No own background sessions. Own Sol source-repair rounds0; received Astra2/2 exhausted. Historical received counters group52/root107/orchestration36/stagefailed7/production2/fixture10/stageorchestration29/invalidRED1/validRED1 remain historical. Latest parent message: group52/root110/orchestration39/stagefailed7/production2/fixture10/stageorchestration32/invalidRED1/validRED1/Astra2of2, including both read errors and root docs snapshot basename-collision exit1. No source/runtime repair inferred.

Browser/full-stage/Task5/M3/release/production acceptance is outside this audit. Historical failures and assertions remain preserved. No decisions needed.

## Bound inputs

| Input | SHA256 before = after |
| --- | --- |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red-plan1.json` | `105f36911841388f9c58a6611234834b5232fdf1c8a2aa1cb0a99864d81d843f` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red-plan2.json` | `29cdf05cb58942350c9ce12f5e59098c0d4365b70094d2b8ae5681df8e9a2596` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red1.json` | `1289624b1d40af7e00f66a0dd9b19e02346dac16c492006e8b18fc601dd9669b` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red2.json` | `8fb0a812a8014a9827762e07bcdbbbecbb311217dee9515c2f1729f651b40f67` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red1-classification.json` | `ca8257cb6d21e8f80d6bcfcb5a3d588c0e4d4a437596a597adb4d2757940910f` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red2-classification.json` | `dacd885d0b3aaad787550845aa1b4ac093716340199fb579ed68748c453ca23e` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red-restoration1.json` | `0758587b2575278ce47210a2eac8868965d2f803f3b1c879256decf3ebb8fbc7` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red-restoration2.json` | `1d614d0ce16546bcce185694e28ad432ce32527724c268d39ad3b42996abd895` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/scoped-initial4.json` | `0ebf36af932b0ed03d513ffe7de34c9e7eb6b5f81f9a2e42ba51dda58d118cd4` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/scoped-initial4-classification.json` | `3f8333f79d27e42fdfb1c4486c842140d41b9610b531344e1725e3e7334e21ea` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red1.log` | `988530c684cf3b98a806b2aa57392702576db5a2490447474fe7b1a49513a8ac` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red2.log` | `7e31eff0a685693314636d3eb58ab541a520595e60a76b7ad59a4f7862014a14` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/scoped-initial4.log` | `3be55f62ae6f16d0028eabd7a73e46dd74b2f1fdcb8fe0b63599c1a0a6b6bd98` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-http-before.ex` | `76ec5ad7e9cf3c986b8da97be191fd7463a417cc0a4d5851f8bdf209004ddb98` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-http-reviewed.ex` | `dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-test-reviewed.exs` | `c9ec261257168ca66ec33872f7994855d6e570ab3c731b102b7c8283f495ad0b` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-test-reviewed3.exs` | `e80503bb68521d29fa3423a3c93c9059598d0602eec1858cd1c751aba759a2fa` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-test-before.exs` | `489ae6a6617e52c3c7d42a06a5b0cd8e8170ed0ba5b2fd53c6c6b91a298cc23b` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-test-proposal1.exs` | `d880b64ffa62644b2e939c1b66b806d76ad88ae92ba66be05b026c01e4d15408` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-proposal3.json` | `f3a43673aefdd9efc3093b5cabc2f05944e2bd3652b770fac91053019aef2c57` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-spec3.json` | `21f27a1371fae8d82774dc5d0494685757c419f7192da0c20fca833bba143828` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-code2.json` | `59d963ff8925c11fd38d131223a1114b828713a077c90a089edefd1bc1b9abc8` |
| `docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/command-collector3.py` | `aeff8b310f5f0a296ed79d915d9f8beb4f57b2e2d782a857de85779c298d27ee` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex` | `c8a63c08ce6852d73a094e9172d5ca61817d68744db949ce478c7aa656831947` |
| `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex` | `586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52` |
| `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs` | `e89adb9c7cefa1c64385e9a90962ece819d7dfb492807b42e7b77644f042c33a` |
| `apps/gaoxy_proxy/test/support/managed_h2_group_fixture.exs` | `4d5f70dcee198409fb481947ddfb24e9d65dc65b3b41c0a58e8f6627778b1c53` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex` | `dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31` |
| `apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs` | `e80503bb68521d29fa3423a3c93c9059598d0602eec1858cd1c751aba759a2fa` |
