# Independent review of H1 loaded-artifact identity checkpoint

Date: 2026-10-11 Asia/Shanghai. Task `m3_loaded_identity_review`; direct Sol
independent source/specification and evidence-quality review. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, reviewed baseline
`6ef8a3ad8e26e2f4992adeaf9558199aef8105a5`.
Only this new report is owned. Existing untracked identity/native-layout
receipts, logs and worksheets were preserved; the tracked diff was empty.

**DONE — PASS_POINT_IN_TIME_IDENTITY_REVIEW.** No actionable correctness or
evidence-quality finding was identified within the checkpoint's explicit
point-in-time scope. The public API match, final receipt and preserved failures
agree with the inspected sources and independently checked artifact bytes.
M3 and P0-P6 remain unqualified. TLS tracking issue95 remains a separate blocker.
No VM or executable runtime gate was rerun by this reviewer.

## Frozen reviewed inputs

| Input | SHA-256 |
| --- | --- |
| [Checkpoint worksheet](h1-loaded-identity.md) | `e9cd0c102642998fab65aa0e6d6a7dd2c1491381a21f3ed7fb4a27a81caa888c` |
| [Final receipt](h1-loaded-identity.json) | `3cf98823d20cc263ed9ef785e5ee5b39c55b1a46d654d199ff80822029cb5df3` |
| [Final VM log](h1-loaded-identity.log) | `e80cf353671d70e9d9894908e2e3b25072f4675826df3dd71343ac9d388f2482` |

The receipt's nine input-file hashes, source-snapshot hash, VM-script hash and
pinned `beam_lib.erl` hash all matched independent SHA-256 rereads. All429
source files named in the immutable snapshot match their recorded hashes now.
The embedded final VM script and collector exactly match the readable `.audit`
files; the retained `.audit` metadata equals the final receipt's metadata.
Historical embedded script hashes also match their receipts.

Pinned OTP source root:
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`.
Installed runtime root:
`/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang`.

## Semantic review

`lib/stdlib/src/beam_lib.erl:558-573` specifies and returns
`{ok, {Module, MD5}}`. Its documentation explicitly excludes compilation date
and other attributes from the code digest. The final pinned Elixir match
`{:ok, {^mod, disk_md5}}` is correct. The initial list-shaped match is incorrect,
and repair1's saved MatchError reproduces the actual tuple-shaped result.

`lib/kernel/src/code.erl:2109-2133` independently supports the chosen comparison:
OTP's own change-detection path compares `erlang:get_module_info(Module, md5)`
with the digest returned by `beam_lib:md5/1`. The final script checks both the
returned module identity and digest equality before recording a successful
module entry. `code:is_loaded/1` normally returns the load filename, as documented
at `code.erl:727-747`; every recorded selected module has an ordinary file path,
and all34 recorded load filenames resolve to their respective hashed BEAM paths.
Preloaded/Cover/in-memory-only modules would require another representation;
the report does not claim to cover them.

The script explicitly loads34 distinct selected modules, obtains each resolved
BEAM, hashes the whole file and compares code digests. It samples compiler
metadata but appropriately labels22 readable source hashes as current file
observations. Code digest equality excludes non-code chunks, so it is not proof
that the loaded compiler metadata originated in precisely those currently
hashed source files or that the full BEAM can be rebuilt from them. The whole-file
SHA-256 separately fingerprints the disk artifact, not all bytes loaded into
memory or every module dependency.

The own-emulator check reads `/proc/` plus `System.pid()` plus `/exe`, resolves
its symlink and checks equality between that running-file view and its target's
full-file hash. The recorded target is inside the stated runtime installation,
and its current SHA-256 independently matches
`7d7cc767b20c28e26fe93a13d23d5daf688cbd83ed60523a5bdedd9cb6ee02e6`.
This is a useful executable fingerprint. It neither reconstructs native compiler
inputs/defines nor measures ABI field offsets. It also does not fingerprint all
loaded shared libraries, NIFs or other native dependencies.

`erlang.erl`'s public `system_info/1` contract distinguishes the sampled
`dynamic_trace` framework (`none | dtrace | systemtap`) from
`dynamic_trace_probes`; `none` is retained as metadata and is not promoted into
an ABI/probe-layout certificate. Compiler identity, word size and unset
`internal_active_n` likewise do not establish effective settings throughout a
future managed scope. Hot code, later path/configuration changes and concurrent
replacement would invalidate an attempted lifetime interpretation. The checkpoint
explicitly makes only a point-in-time claim.

The34-entry selection is finite and contains two pure Gaoxy preparation/accounting
modules, HTTP and OTP modules. It is not a complete loaded-module inventory.
The script calls module loading/metadata functions and the public struct
constructor, without application startup, managed opening, HTTP operations,
socket creation or peers. Recorded application lists are identical before/after
and contain only compiler/elixir/kernel/logger/stdlib; no HTTP/Gaoxy application
appeared. That check corroborates the declared probe's scope, rather than proving
arbitrary loaded modules could never have side effects. No such broad claim is
needed here.

FetchOptions has33 entries including `__struct__`. Independent source inspection
of its32 declared fields agrees exactly with the sorted receipt field list.
This identifies a struct shape, not every constructor/accounting cost.

The collector uses repeated `-pa` arguments, `ERL_FLAGS=+S 2:2` and a finite45s
subprocess timeout. It checks the immutable source snapshot before the VM,
rechecks hashes afterward, records exit/log/metadata, and asserts the module
count. The script itself enforces digest equality, struct33 and no new
HTTP/Gaoxy application. No assertion was removed to obtain the final pass.
Reproduction requires new script/output/evidence destinations as the worksheet
instructs, because the embedded historical collector intentionally names its
original evidence files. The embedded collector parses as Python; its receipt
suffix is a real newline and yields valid JSON. A preliminary suspected literal
backslash-n issue was disproved by AST literal inspection.

## Historical failures are retained correctly

| Run | Saved observation | Disposition |
| --- | --- | --- |
| [Initial receipt](h1-loaded-identity-initial.json) / [log](h1-loaded-identity-initial.log) | Exit1, `No file named _build/test/lib/earmark_parser/ebin`, metadata null; one `-pa` followed by many directories | FAIL remains visible; the later repeated-flag command corrects argument consumption. |
| [Repair1 receipt](h1-loaded-identity-repair1.json) / [log](h1-loaded-identity-repair1.log) | Exit1, MatchError on `{ok, {String, digest}}`, metadata null | FAIL remains visible; repair2 corrects only the public API result match. |
| Final receipt/log | Exit0,3.176s,34 modules, FetchOptions33 and no HTTP/Gaoxy app start | PASS for the stated identity checkpoint only. |

The two historical receipts keep their originally generated
`log: h1-loaded-identity.log`; their stored hashes match the renamed historical
log copies byte for byte, rather than the overwritten final log. The worksheet
explicitly explains this mapping. All three source snapshots have the same
fingerprint,429 files, unchanged=true and no changed-file entries. Historical
FAIL results are neither relabelled PASS nor counted as protocol tests.
Final counters correctly preserve Sol2 diagnostic repairs with1 unsuccessful
repair validation, Astra0 and no implementation repairs. Historical receipts
remain original observations of their generation stage, including their older
counter values.

## Independent checks and limits

Read-only `git status --short`, `git rev-parse HEAD`, `git branch --show-current`
and scoped SHA/source reads established the assigned checkout and frozen inputs.
The main read-only Python checker exited0 with:

```text
PASS reviewed hashes, input9, logs3, snapshot429, beam SHA34+independent significant-chunk MD5 34, current source22, native executable1, script/collector/metadata equality, FetchOptions33, failed receipts2, collector syntax/newline
```

The independent code-MD5 check parsed every BEAM's FOR1/BEAM header and aligned
chunks, then followed pinned `beam_lib.erl:853-883,1380-1381`: concatenate present
Atom/AtU8/Code/StrT/ImpT/ExpT/FunT/LitT/Meta chunk data in that order, replacing
each FunT entry's four-byte old-unique field after its20 significant bytes with
zeros, preserving the leading count. Python MD5 matched each recorded disk and
loaded digest (34/34), while whole-file SHA-256 independently matched34/34.
This is an independent disk recomputation and receipt consistency check; loaded
MD5 values remain observations from the parent's completed VM probe.

Additional source contract reads used `beam_lib.erl` from its recorded hash and
`code.erl`/`erlang.erl` in the same pinned source tree. Markdown links, fences,
whitespace, exact authored hashes and report hash were rechecked before handoff.
No source memory from earlier tasks was used as acceptance evidence.

| Additional pinned source | SHA-256 |
| --- | --- |
| `lib/kernel/src/code.erl` | `8d291bb6b9327b00a82e96fc3d825721fd06c14f97269ecd76965fef994ab061` |
| `erts/preloaded/src/erlang.erl` | `eef4e95a8a0fc09b0eaaab18e777b0f9f32c36f5890f114476a14000f488cad0` |

Open obligations are unchanged: original compile-input/rebuild proof, native
translation-unit configuration and ABI, broader object classes, complete
selected-path dependencies, hot-load/configuration enforcement, retained-object
multiplicity/release and P0-P6 composition. No checkpoint correction or new
product decision is required. This report does not mutate the authored receipt's
pending-review field or imply resolution of TLS95.

Review-only diagnostics: a source-read command used an OTP-root-relative
dependency path (exit2), then the correct worktree path passed; an AST helper
initially tried literal evaluation of the log-write expression (exit1), then a
constant-only filter passed. Two successful diagnostic corrections, zero
unsuccessful repair validations, zero implementation repairs and Astra0. A
separate Elixir CLI source-path lookup returned missing-file exit2; the installed
CLI source was not available at that OTP path, and no CLI-source verification
is claimed. The historical argv/error log and final argv were inspected instead.
These review counters are separate from the preserved parent probe Sol2/1.

All own commands finished. No background session, VM, Mix, C compiler, network,
upstream action, agent, product/dependency mutation, staging, commit, push or
peer-process action was started. Only this report was written. Runtime and
protocol gates remain NOT RUN by this reviewer. No escalation gate applies.
