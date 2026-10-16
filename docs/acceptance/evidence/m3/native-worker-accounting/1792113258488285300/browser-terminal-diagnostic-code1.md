# Browser terminal diagnostic CODE1

FAIL — one required boundedness correction. DONE, direct source-only review. Do not start DIAGNOSTIC1 with this exact pair until corrected/reviewed. No acceptance claim.

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; archived baseline `58307a7084298db309a93697b9102b2cc4c87eda`. Diagnostic host1 SHA256 `2ca1e7b937d5f29fad92197ba2da09a28c427ee684356e85205ff82462669353`; runner1 SHA256 `f1a045bb0319262170157bde9da7ff184c459ad6fbec0887bc1c68fb729f7e7e`.

DIAGNOSTIC-CODE1-F1: `diagnostic_drain/4`1217-1257 checks the deadline only in receive-after. If mailbox messages remain available at expiry, each recursive receive still selects an event, so after0 is not chosen and draining can exceed the prescribed1s boundary. Check remaining(deadline)<=0 before each receive iteration and log finite_unknown/return immediately on expiry; retain existing marker/terminal handling and the original strict raise.

All other inspected changes match the bounded diagnostic proposal. Successful exact connection/writer traces and real socket/flag/timer/deadline/monitor snapshot precede dispatch. Full trace appends preserve messages; terminal marker regeneration and honest finite_unknown preserve uncertainty. Original strict early-DOWN and exact join/zero/custody/browser/peer/source95 assertions remain unchanged. Runner only changes host filename; Python AST parses. This run must be recorded only as diagnostic and cannot count as GREEN/acceptance.

Verified assigned hashes and complete baseline-to-diagnostic diff by read/hash/AST/source analysis only. No runtime/Mix/browser/tests/network/Git or repository/evidence edits. Only assigned two `/tmp` reports written. All commands finished synchronously; no background process or other process touched.

Counters preserved: group37/root45/stage7 failed GREENs/Astra2of2; source review adds0 repairs/failed GREENs. Actual runtime cause remains unknown. No design decision or escalation required.
