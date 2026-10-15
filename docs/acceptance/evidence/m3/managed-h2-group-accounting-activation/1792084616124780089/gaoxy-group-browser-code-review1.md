# Independent CODE review — managed-H2 group browser drafts

Task `group_browser_code_review`: **DONE — PASS_BROWSER_DRAFT_CODE_READINESS**. Direct read-only assignment. No unresolved actionable CODE findings. Runtime qualification is NOT RUN (0 tests/cases executed by reviewer).

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline HEAD `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. Parent owns dirty/untracked implementation and all integration/runtime work. Exact reviewed drafts:

- `/tmp/managed-h2-browser-shared-qualification2.py` SHA256 `0054aae722003a32715aab0469aafe56579b14b7f318e399c7e2570ebea89f3c`
- `/tmp/managed-h2-group-browser-peer1.py` SHA256 `0b73127aa1f3cf3d7a9257526db158c40b3ec76913089c028397175e5bafd259`
- `/tmp/managed-h2-group-browser1.py` SHA256 `5c6544a5b3f70329f083ad2fb48b522b81fe7a990135136a12358dd436ef6dfa`

The runner uses the inherited isolated real Chrome CDP fixture. Its original exact positive navigation/loadingFinished, visible probe, streamed body, early413, h2 network, no-console and screenshot/event assertions remain. Negative navigation retains exact h2/502/Content-Length0, matching Page.navigate and loadingFailed `net::ERR_HTTP_RESPONSE_CODE_FAILURE`, same loader/request/frame, Chrome error document and HTTP ERROR502, exact network log and no-console/exception semantics. Test trust remains SPKI-only and isolated.

The new negative setup exercises real group selection rather than skipping initial health: actual /health HEAD with h2 ALPN/localhost SNI, healthy group, confirmed initial Probe completion, GOAWAY and same-connection physical EOF precede rotation. The peer checks exactly one initial health request/connection and joins its real worker before replacing only SSLContext on the existing listener. Wrong-name trusts both test CAs while rotating to wrong.invalid; wrong-ca retains only original trust. The browser must then produce a genuine post-health failed handshake and no extra application request.

G/T debug hooks capture actual original public bind/probe-bind/transport completion identities; observers retain finite ledger snapshots, exact accounting invariants and actual G/T original confirmation. Initial Probe carries full16,478,862; each Service request cleanup carries full16,478,862 attached to its actual active lease. Positive cleanup waits finitely for Writer readiness, takes a fresh exact Connection/Writer lease bijection, joins isolated Chrome before zero-native-ledger checks, and preserves originals through close.

The shared Service collector keeps both1024 caps and original first-distinct behavior. The added G/T collector bounds outstanding raw captures and retained rows to1024, fails on overflow, reconciles accepted counts, fences through real owners and requires actual normal owner DOWN and outstanding0 before observer join. Actual peer helpers and browser processes are joined on passing paths. Negative unconfirmed cleanup keeps the exact original failure, full live Service reserve timeline, failed terminal Admission snapshot, missing-Service public result, retained T original/payload, G original/control charge, genuine helper settlement and explicit test-owned disposal. Missing Service never becomes a zero ledger.

Read-only difflib comparison against canonical fixed qualification showed surgical group-mode additions and a reservation argument whose default remains9,444,956. Existing fixed rejection assertions,1024 caps, finite deadlines, Writer-readiness and exact native lease checks remain. Three drafts passed Python AST parsing without import/execution, and their exact hashes were rechecked. Supporting source hashes and per-contract references are recorded in the JSON report.

No runtime acceptance is claimed: parent must install at intended import paths, validate the embedded host, execute all three browser cases and preserve actual source/runtime/cleanup/join evidence. Same-listener GOAWAY/EOF and all finite observer/join assertions remain intentionally subject to real execution. Full stage acceptance remains outside this draft review.

Reviewer repository edits0; Sol repair rounds0; runtime attempts0. Parent counters remain in custody without reset or guessed aggregate; Astra2/2 is exhausted. One separately authorized preactivation toolchain documentary erratum preserves both original reports and distinguishes runtime OTP28/ERTS16.4.0.6/Elixir1.18.5 from the executable store-path component. No third Astra or publication/deployment scope is involved.

All reviewer commands have finished; no reviewer background/runtime process was started. Only the authorized browser report pair was written for this assignment. No product decision or new permission is needed.
