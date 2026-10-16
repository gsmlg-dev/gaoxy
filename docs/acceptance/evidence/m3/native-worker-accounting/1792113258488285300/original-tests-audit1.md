# Original test assertion preservation audit

Task `checked_browser_source_review`, direct read-only bounded audit: **PASS**.

Candidate2 `5636329b6df387b33cf5277633210e81f261c1f6bb8a13ac2377ad410a3343ca` was checked against candidate1. All245 current source and430 frozen evidence hashes/lengths match before/after. All 90 production-file manifest entries are unchanged candidate1 to candidate2; all original409 evidence entries remain byte-identical.

The assigned script removes only explicit new regions in memory and restores the single original committed_barrier receive branch. It writes no reconstructed source. Both original files reconstruct **exactly**, without whitespace normalization:

- Core: 32791 bytes, SHA256 `9e92fba219c68829a36b24a5245e4d582a0313fc79e83149d802f9720b9da5ac`.
- Native startup: 42202 bytes, SHA256 `a7a9b40eff405c91ada7b705fcc1535496000f4d19b295e95f9cff8843f7ae89`.

These hashes and lengths equal candidate1's original entries, proving every original test/assertion/helper byte is retained outside the specified default-unchanged helper extension. No boundary blankline adjustment or approximate match was needed. No report_activation option remains after reconstruction; its uses are confined to the additions and helper extension. Full semantic/compliance review is outside this audit.

The immutable failed native-green6 remains **100 executed/1 failure/12 warnings, actual exit2/join/source stable**. Native-green7 is **100/0**, core-green3 **73/0**, both actual0/join/source stable/0 warnings/skips/exclusions; corresponding logs match retained hashes. The new acceptance union is **73+100+230+161−3 =561 tests across30 unique files**. Three duplicate exclusion tests are counted once; metadata13 remains inside native100, not added again. This is11 more than candidate1's550, matching five core and six native cases.

Only the assigned `/tmp` audit script/report files were written. The first audit attempt stopped before writes on a substring-uniqueness guard that also saw a nested tag; exact line anchoring corrected the audit only, and the final static audit exited0. No project runtime/test/browser/network/Git mutation or repository/evidence write ran; sensitive raw `/tmp` trace was never accessed. All static audit commands finished with no actor launched. Counters remain41/53/11/Astra2/2. Full SPEC/CODE, fresh final gates and local commit remain pending.
