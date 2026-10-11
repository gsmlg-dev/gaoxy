# Independent H1 fixture repair2 review

Task `m3_h1_fixture_repair2_review`; direct bounded independent implementation
SPEC followed by CODE QUALITY. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`; current loose ref independently matches
`85c2284a035e0b4ecbf577279eee01142702b5a3`. Historical comparison baseline:
`b2ac78b518f459ec2c95b7823226640413f2ca95`.

## Implementation SPEC — PASS

Canonical plan remains unchanged at SHA256
`01acb850d85b90c2409092d7bf25c5400ad2e519d233858d9194dbce211e6720`.
The exact executable repair changes only fixture line147 to match the real
`:beam_lib.md5(binary)` return shape: `{:ok, {module, digest}}`, rather than
`{:ok, [{module, digest}]}`. Module pinning and loaded-module MD5 equality,
object/disk origin equality, object SHA256, cohort versions, runtime/source
identity and telemetry checks remain unchanged. No role, operation, deadline,
control, native-frontier or public interface changes.

The parent-created identity regression's original `native_origins != []`
assertion was independently diagnosed as TEST_CONTRACT_ERROR. This field
enumerates regular files under the seven cohort applications' `priv` paths;
it does not enumerate OTP/VM native mappings. Independent read/hash/archive
inspection verified205 installed identities and14 cached release archives;
all matched accepted provenance. Those archives contain no `priv` members.
All seven installed/built cohort `priv` paths have no entries; release manifests
declare no native compiler, and ex_ssl/elixir_quic have no `load_nif` call.
The exact supported complete cohort set is therefore `[]`, not a required
nonempty list. This establishes no native ABI/N8 qualification.

The NEW v2 regression independently `File.ls`-checks every declared build-app
priv root, requires the complete entry set to equal `[]`, then compares the
fixture's field against that exact set. Unexpected entries or other directory
errors fail. The complete diff retains every valid prior assertion, including
per-file regular-file/SHA checks, ten loaded/disk BEAM MD5/origin/SHA checks,
175 runtime sources, versions/cohort and telemetry. No accepted requirement
was weakened. Original faulty test and attempted GREEN failure remain
immutable; the correction is a separate parent test-contract repair.

## CODE QUALITY — PASS

Reused the initial full fixture/public-contract review and repair1 integration
review; independently audited the exact delta against preserved canonical
pre-repair2 bytes. F1/B17 confirmation and F2 ledger-refusal/cleanup/teardown
code are byte-identical to the accepted repair1. The source inventory changes
only the fixture:207/208 entries remain identical, including test, peer, plan,
model, dependencies and exhausted TLS inputs. The tuple fix preserves the
existing strict identity failure behavior and matches the observed OTP return.
No actionable findings remain in this bounded repair.

Canonical SHA256:

- Fixture:
  `937bdfd98d23a0045a2e685cca123bbde7492467bef43f85bcc3489c4a554735`
- Baseline test:
  `09cd6382d3158666db69de784e05dc55b76b42641a2437de278b779c4ee50ac0`
- Peer:
  `e997a5fcd0d7391cf56ba278e5dccf3d61b5e68fbb2bae4cbedf1c69f75e0fb2`
- Corrected identity v2 unit:
  `8011ac3ef541478a346a327f5b53d3ee7a02857dcb35ce15010b463c30fe6b4f`
- Original faulty identity unit:
  `7fb090d32b63d4298b60ae07bc4fb02190dcdcf742b83880e6ecdefa61aefcd0`

Frozen repair2 inventory SHA256:
`2183a347a13a306dfb23dd00b790204deb5cbe95dd749f7b3d9e5b443dc1e806`.
All208 source and28 helper/evidence/unit/artifact bindings match current
bytes. Original FAIL review, repair1 PASS review, first failed baseline-startup
and both original identity failures remain preserved and independently bound.

## Actual parent evidence and limits

The immutable corrected v2 RED used the exact previous canonical fixture
`caeb5fa1fb68b45fb7661577fb32f89a01a3029f3b6d3e60fa4f6d9bd10c9800`
at its original source path. It actually executed1 test/1 failure and exited1
on the line147 return-shape match. Parent restoration then returned the fixture
to the corrected canonical hash. Corrected v2 GREEN executed the same unit:
1 test/0 failures, skipped0/excluded0, seed21112026, child exit0. The RED and
GREEN1132-entry maps are unchanged within each invocation and differ between
invocations only in the intended fixture. All1132 GREEN identities match
current bytes; the receipts' log hashes match actual logs.

The captured GREEN identity contains ten BEAMs,175 runtime source identities,
seven exact0.21.2 versions, telemetry false and complete priv set `[]`.
All ten captured BEAM SHA256 values independently match current disk files;
the interpreter SHA matches its actual file. Actual loaded MD5/origin checks
were executed by the parent unit and fixture, not by this static reviewer.
Captured identity/artifact hashes and own source hashes match the inventory;
the preserved identity also matches the still-current identity artifact.
Fresh parent format-check exited0 with0 tests and unchanged1132 inputs.

First baseline startup failed with child exit1 and0 tests before any peer/test
allocation. Original identity RED was1/1. Attempted original identity GREEN
was also1/1, failing solely at the newly invented nonempty-priv assertion after
the preceding valid checks passed. These failed invocations remain failures;
the verified test-contract classification does not convert them to GREEN,
erase them, reset fixture counters or reopen the exhausted TLS chain.

Actual baseline network cases remain0 / NOT RUN. Startup identity1/0 is not
baseline20, cleanup integration, B17, native ABI, N8, TLS or M3 acceptance.
Implementation SPEC PASS then CODE QUALITY PASS satisfy the parent's review
prerequisite for a fresh baseline20 under this exact source/helper freeze.
B21 remains deferred/fail closed; Feature97/N8 and numerical accounting remain
blocked. No native refunds or production activation are claimed.

Reviewer used only synchronous local reads and standard-library hash/JSON/diff
inspection. A filename discovery read found the alternate suffix ordering and
was corrected; no file was changed by that read. No reviewer VM, Mix, parser,
formatter, Git, network, dependency or peer command ran. Only these NEW review
MD/JSON files were edited. All commands finished; no background process/job
exists, and ownership is released after final report/source binding checks.

Status DONE_REVIEW_ONLY. Fixture cumulative Sol2/unsuccessful1/Astra0; separate
parent test-contract correction1; model Sol2/unsuccessful1/Astra0; exhausted
TLS Sol2/unsuccessful2/Astra2. Reviewer implementation edits0; no escalation
gate asserted. Remaining action: parent fresh baseline20 and exact actual
runtime/cleanup receipts. No new user design decision is needed.
