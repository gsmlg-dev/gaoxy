# H1 collector peer-inventory independent review

Task `m3_h1_collector_peer_review`: **DONE — SPEC PASS**, followed by **CODE QUALITY PASS**. No actionable findings within the assigned repair. This verdict accepts only the H1 parent collector process-name inventory correction.

Direct independent review in `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`, baseline `85c2284a035e0b4ecbf577279eee01142702b5a3`. Identity verified by reading worktree metadata and the branch ref directly. Applicable `AGENTS.md` read. No implementation edits or Git commands; only the two assigned review reports were created.

## SPEC review — PASS

The original `peers()` regex at line58 expands its two nonempty alternatives to `managed_h1_accountingpeer.py` and `managed_tls_trackingpeer.py`, missing the actual names `managed_h1_accounting_peer.py` and `managed_tls_tracking_peer.py`. Repair1 adds the missing trailing underscores while retaining historical `managed_peer.py`, escaped `.py`, and the existing start/path/space and trailing-space/end boundaries.

The diff is exactly two ASCII underscore insertions in one line: original zero-based byte offsets2426 and2439, repaired offsets2426 and2440. Original length5689 bytes; repaired length5691 bytes. Every other byte is unchanged. All sources parse as Python; ASTs are identical after normalizing only the regex constant. The current ignored collector and preserved repaired source are byte-identical.

Independent reviewer checks passed **15 regex probes / 0 failures**. Positive cases cover actual H1/TLS names, historical name, bare names, paths and arguments. Negative cases cover prefixed names, `.py.bak`, extended suffixes, an unescaped-dot lookalike, unrelated names, the obsolete missing-underscore spellings and a directory component that is not the executed filename. On the first six reviewer cases, the original pattern fails precisely the H1/TLS positives. These reviewer inputs are recorded in the JSON companion; parent receipts contain labels and booleans but omit their original input strings, so exact parent-input replay is not claimed.

The preserved parent red/green receipts are internally consistent:6 cases each,2/0 failures respectively, hashes and patterns match their bound source files, actual fixture cases0, VM/network NOT_RUN. The parent reported actual command exits1/0; the green receipt records prior_red_exit1 but does not carry its own green exit field. Its empty actual process inventory is parent-recorded evidence; reviewer did not run `ps` or independently verify live process state. Its historical independent_review=PENDING field remains untouched; this separate report supplies the verdict.

## CODE QUALITY review — PASS

Review followed SPEC PASS. The smallest repair corrects only the two alternatives of an existing regex. It preserves the inventory function, subprocess command, receipt gating, timeout handling, frozen inputs, APIs and dependency surface. No tests, assertions or runtime checks were removed or weakened. The exact-byte diff and normalized-AST equality establish that other collector behavior is unchanged. No unrelated fixture3 implementation was reviewed or changed.

| Artifact | SHA256 |
| --- | --- |
| `h1-collector-peer-red-source.py` | `faf24854bf2cfb35f99a33b8ac4a57259f38c28a21b7fc7b3ebd58d614bfbce8` |
| `h1-scoped-run-collector-repair1.py` and current `.audit/m3-h1-scoped-collector.py` | `8a2ce4c4993c15fffe88ee327c3d52f079427634a565a61a8e194af70387ef42` |
| `h1-collector-peer-red.json` | `2cfa6558c5d4547cf9669feb7b17b03413a298bce351ccd11b82a5c1f0c3df66` |
| `h1-collector-peer-repair1-green.json` | `afebafdcad211cf4a86bdf34c4649969fa62e16d928a7f05c895dddf217438fe` |

Reviewer verification used synchronous inline Python read/hash/AST/JSON/diff/regex checks, all exit0. Collector was never imported or executed; its top level would launch commands. No VM, Mix, formatter, Git, network or dependency operations. No actual H1 baseline or TLS cases ran. No H1 numerical accounting, native runtime, TLS runtime or M3 acceptance is implied. This remains filename selection under existing delimiters; it does not establish process ownership or general absence of leaks.

Cumulative H1 collector counters: **Sol1 / unsuccessful0 / Astra0**; reviewer repairs0, received Astra repairs0. Separate TLS chain remains **Sol2 / unsuccessful2 / Astra2, EXHAUSTED/BLOCKED**, unchanged. H1 fixture runtime, ignored TLS runtime wrapper, TLS driver/collector/recovery budget and native numerical accounting are outside this repair.

No new design decision or scope expansion is needed. Fresh parent post-review verification and separate runtime acceptance remain. All reviewer commands completed synchronously; no background process started. Source and receipt hashes were rechecked when preparing the reports. Only the two assigned reports were written; report ownership is released on completion.
