# First GREEN: independent source and ETF diagnosis

Task `native_worksheet_tests_first_green_diagnosis`; direct read-only assignment. Status **DIAGNOSIS_COMPLETE_NOT_REVALIDATED**. The two failures come from my test expectations mixing integer body sizes with standalone ETF sizes. **No production modification is indicated.** Correct every affected equality and keep all coverage.

Repository/worktree R=`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline `48a71a70acbe9cb46f99b82e4062c6f5f25d9667`, from parent and archived collector before/after identities. No Git command was run for this diagnosis. Source inspected: production `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_generation_accounting.ex` SHA256 `73249ba0952f33cb7605d1ca8a5c7aecfe240d93456a3ad9f877ee9a9501636c`; current test `apps/gaoxy_proxy/test/managed_generation_accounting_test.exs` SHA256 `b2c2fca6313be718fd3375a309790a13f81d528e3d6fb7d51180d5ea2d319d65`. Line numbers below apply to this exact test.

## Formal derivation

The [official OTP-28.5.0.7 ETF guide](https://raw.githubusercontent.com/erlang/otp/OTP-28.5.0.7/erts/doc/guides/erl_ext_dist.md) was fetched read-only in this diagnosis. Lines42–46 define a standalone term as version131, tag, data. Lines351–365 specify SMALL_INTEGER_EXT tag97 plus one payload byte and INTEGER_EXT tag98 plus four payload bytes. Lines535–543 specify SMALL_BIG_EXT tag110, n, sign, n digit bytes.

Thus complete uncompressed standalone sizes are:

- SMALL_INTEGER_EXT: version1 + tag1 + payload1 = **3**, not2.
- INTEGER_EXT: version1 + tag1 + payload4 = **6**, not5.
- SMALL_BIG_EXT: version1 + tag1 + length1 + sign1 + digits n = **n+4**. Earlier big-int13/12/9/8 expectations already included the version correctly.

The parent-owned diagnostic independently shows exact bytes for these same cases, including `[131,97,0]` and `[131,98,0,0,1,0]`. Its result is PASS_DIAGNOSTIC_ONLY with0 ExUnit tests, not worksheet acceptance.

Production line78 uses `:erlang.external_size(term)`; tuple helper81 strips one version byte from each complete child. Context188, plan189 and update223 pass dynamic complete E(integer) values. The literal P2 ledger is already correct because its arithmetic used real E calls. Existing B0=2758572, context8213, plan53, update2063 and update-wire6198 must remain unchanged. Default M total8656812 and the34 role table also remain unchanged.

## All retained rows independently checked

For M65536 every listed B remains below signed-int32 maximum, so E(B)=6. Context changes by E(retained)-E(0)=E(retained)-3; two independently retained update roots change by E(retained+B)-E(B0)=E(retained+B)-6. No other row changes. Therefore:

`B = 2758572 + (E(retained)-3) + 2*(E(retained+B)-6)`.

| Retained | E(retained) | E(retained+B) | Old B | Correct B | Context | Plan | Update | Update wire |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 3 | 6 | 2758572 | 2758572 | 8213 | 53 | 2063 | 6198 |
| 255 | 3 | 6 | 2758572 | 2758572 | 8213 | 53 | 2063 | 6198 |
| 256 | 6 | 6 | 2758575 | 2758575 | 8216 | 53 | 2063 | 6198 |
| 2144725072 | 6 | 6 | 2758575 | 2758575 | 8216 | 53 | 2063 | 6198 |
| 2144725073 | 6 | 8 | 2758581 | 2758579 | 8216 | 53 | 2065 | 6200 |
| 2147483647 | 6 | 8 | 2758581 | 2758579 | 8216 | 53 | 2065 | 6200 |
| 2147483648 | 8 | 8 | 2758584 | 2758581 | 8218 | 53 | 2065 | 6200 |
| 4294967295 | 8 | 9 | 2758586 | 2758583 | 8218 | 53 | 2066 | 6201 |
| 4294967296 | 9 | 9 | 2758587 | 2758584 | 8219 | 53 | 2066 | 6201 |
| 18446744073709551615 | 12 | 13 | 2758598 | 2758595 | 8222 | 53 | 2070 | 6205 |
| 18446744073709551616 | 13 | 13 | 2758599 | 2758596 | 8223 | 53 | 2070 | 6205 |

The first four B values are correct and stay unchanged. In particular, E(256)-E(0)=6-3=3, so the context transition contributes3 as before. The signed-int32-to-big-int update transition contributes **2 per update root** (8-6), not3. This distinction corrects the later rows.

At retained2144725072, B2758575 gives sum2147483647 and remains the fixed point reached by production's start-at0 iteration. At retained2144725073, the same lower candidate would give sum2147483648; the two update roots add4 and B becomes2758579. Both boundary input values and the comment deriving `2147483647-(2758572+3)` remain unchanged. At the exact first boundary a larger mathematical fixed point can also exist; the prescribed iteration from0 selects the lower one. Do not derive the boundary by guessing a post-crossing total.

## Large M independently checked

M=2^64 and B near6*M both have9 base256 digits, so complete E(M)=E(B)=13. Baseline M65536 and B2758572 have complete size6. Each increase is7.

The three snapshot-containing roots still contribute6*M in total. Relative to the ledger specialization `6*M+2365356`, plan pays7 for M and7 for B, while update payload/wire each pay7 for B. Total extra is28:

`B = 6*M + 2365356 + 7 + 7 + 14 = 6*M + 2365384 = 110680464442259675080`.

Plan53+7+7=67; update2063+7=2070; wire6198+7=6205. The two equality assertions E(M)==13 and E(B)==13 remain correct.

## Exact proposed corrections

Only these17 current test lines need edits; no assertions are removed, relaxed, skipped or made approximate. The original frozen /tmp proposal and original failure evidence remain immutable.

| Current line | Old text | Correct text | Derivation |
| ---: | --- | --- | --- |
| 181 | `# E(M)=E(B)=13 rather than the baseline INTEGER_EXT size5. This` | `# E(M)=E(B)=13 rather than the complete baseline INTEGER_EXT size6. This` | standalone INTEGER_EXT = version1 + tag1 + payload4 = 6 |
| 182 | `# independently adds8 for M,8 for plan B and16 for the two update roots.` | `# independently adds7 for M,7 for plan B and14 for the two update roots.` | 13-6=7; four independently priced integer occurrences add28 |
| 183 | `assert report.total == 110_680_464_442_259_675_084` | `assert report.total == 110_680_464_442_259_675_080` | 6*M + 2365356 + (13-6) + (13-6) + 2*(13-6) |
| 184 | `assert report.total == 6 * m + 2_365_388` | `assert report.total == 6 * m + 2_365_384` | 2365356+28=2365384 |
| 186 | `assert rows.plan.cap == 69` | `assert rows.plan.cap == 67` | 53+(E(M)-6)+(E(B)-6)=53+7+7 |
| 187 | `assert rows.admission_update_payload.cap == 2071` | `assert rows.admission_update_payload.cap == 2070` | 2063+(E(B)-6)=2063+7 |
| 188 | `assert rows.admission_update_wire.cap == 6206` | `assert rows.admission_update_wire.cap == 6205` | 6198+(E(B)-6)=6198+7 |
| 202 | `{2_144_725_073, 2_758_581}` | `{2_144_725_073, 2_758_579}` | 2758572+(6-3)+2*(8-6) |
| 203 | `{2_147_483_647, 2_758_581}` | `{2_147_483_647, 2_758_579}` | 2758572+(6-3)+2*(8-6) |
| 204 | `{2_147_483_648, 2_758_584}` | `{2_147_483_648, 2_758_581}` | 2758572+(8-3)+2*(8-6) |
| 205 | `{4_294_967_295, 2_758_586}` | `{4_294_967_295, 2_758_583}` | 2758572+(8-3)+2*(9-6) |
| 206 | `{4_294_967_296, 2_758_587}` | `{4_294_967_296, 2_758_584}` | 2758572+(9-3)+2*(9-6) |
| 207 | `{18_446_744_073_709_551_615, 2_758_598}` | `{18_446_744_073_709_551_615, 2_758_595}` | 2758572+(12-3)+2*(13-6) |
| 208 | `{18_446_744_073_709_551_616, 2_758_599}` | `{18_446_744_073_709_551_616, 2_758_596}` | 2758572+(13-3)+2*(13-6) |
| 217 | `assert rows.context.cap == 8213 + e(retained) - 2` | `assert rows.context.cap == 8213 + e(retained) - 3` | 8213+E(retained)-E(0); complete E(0)=3 |
| 219 | `assert rows.admission_update_payload.cap == 2063 + e(retained + expected_total) - 5` | `assert rows.admission_update_payload.cap == 2063 + e(retained + expected_total) - 6` | 2063+E(retained+B)-E(B0); complete E(B0)=6 |
| 220 | `assert rows.admission_update_wire.cap == 6198 + e(retained + expected_total) - 5` | `assert rows.admission_update_wire.cap == 6198 + e(retained + expected_total) - 6` | 6198+E(retained+B)-E(B0); complete E(B0)=6 |

The retained test aborts at line217 for retained0, so original GREEN1 did not reach the later table entries or update equalities. Those are latent test-oracle errors established by formal arithmetic; they are not newly observed production failures. Large-M plan/update equalities similarly were not reached after its first failed total.

Optional additional regression strength: add exact `e(0)==3`, `e(255)==3`, `e(256)==6`, `e(2_758_572)==6` equalities inside the existing small actual ETF constructor test. These are new primitive syntax assertions, not replacements for any present equality. No additional test block or test-only production API is needed. This suggestion is optional; the17 corrections above are necessary.

The other ETF wrapper expectations use complete tuple3/map6/list7/NIL2 and version stripping explicitly, so they do not need the integer correction. The signed64 bound12 follows SMALL_BIG_EXT with8 digits and remains correct. No change is justified to fixed reservation9444956/16478862/5963776, Q/R, request-only schema, pre-construction capacity checks, actual fixtures, deadlines, finite normalization or H2 Generation exclusion.

## Immutable evidence and verification limits

E3=`docs/acceptance/evidence/m3/native-generation-accounting-worksheet/1792105443070191750/`.

| Original artifact | SHA256 | Actual outcome |
| --- | --- | --- |
| worksheet-green1.log | 9757612727c8eeace98280de88a00d25814581d643d4248a8a841d6b33e8e572 |24 tests,2 failures, exit2 |
| worksheet-green1.json | 8605d3763b42fe808676453b6fa6cb1114ceece354e799aa121e24cf7e407abb |FAIL, joined, source-stable, process group absent |
| etf-integer-diagnostic1.log | d48e15687bff0134e5d4bf49e6602ef93c16fd3ec2ff536879169bf35435d1d0 |Exact integer bytes, exit0 |
| etf-integer-diagnostic1.json | db3e36be87df97dfbea7ee63cb7e58732872cd041d1299679e132b2ffe6e92be |PASS_DIAGNOSTIC_ONLY,0 tests, joined/source-stable |

The original failures are retained as FAIL. The parent reports22 passing tests; this does not imply every equality in the two failing blocks was executed. This diagnosis does not turn that run green. Parent owns adoption, scoped formatting if needed, fresh24-test verification, collector receipts and independent review.

Author executed only source/evidence reads, read-only SHA inspection and read-only official documentation fetches. The initial installed OTP file-name search found no local ETF documentation; the exact tagged official source was then read successfully. No mix/Nix/Elixir/build/tests/formatter/Git command, production mutation or diagnostic runtime execution. Only the two assigned /tmp diagnosis outputs were written. All own commands finished; no background process started or touched.

Counters preserved: current slice failedGREEN1/production repair0; prior fixture compatibility correction1; inherited group failedGREEN24/root events27/Astra2/2 exhausted. This source-only diagnosis adds0 runtime attempts and0 production repair rounds. No Astra gate or new user decision is needed. Remaining risk: corrected expectations await parent adoption and fresh execution; whole-path runtime/accounting acceptance remains outside this pure diagnostic.

