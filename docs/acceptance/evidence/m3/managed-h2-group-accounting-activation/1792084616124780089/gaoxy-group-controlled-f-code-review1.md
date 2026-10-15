# Independent CODE review — controlled F source/test changes

Task `group_controlled_f_code_review`: **DONE — PASS_CONTROLLED_F_SOURCE_TEST_REVIEW_ONLY**. Direct read-only assignment; no unresolved actionable CODE findings.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, baseline HEAD `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. Parent owns dirty/untracked implementation and running serial runtime39821. Reviewer did not run, poll or mutate runtime or repository sources.

Prerequisites authenticated: preactivation candidate SHA256 `2e4d6930874a9070b916fa84bcd9d02f75f85008a3babd8c2cd382a083593fdc`; preactivation review authentication `5a64912316de17f0143c5384a97b0b3396b379e859c5158424dacbf4a86f3626`; controlled activation `c78e3e29e74588aea82adc906020085ff1a2846d34ede40a0941a9c97be6256f`.

For each of the five paths I reversed only its visible F changes in memory and SHA256-matched the reconstructed bytes to the frozen preactivation source hash. Thus the reviewed diff is exact, including the owner-test formatter layout. Current hashes:

- `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_boundary.ex`: `a199ff7de93d1f695693d9125cd70514dfc41768d30fecc1b8928ba1361dfdf8`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex`: `52f17de068ec2746ae7eaaba69bb32614371396bee27f20d892cd69eaef63f04`
- `apps/gaoxy_proxy/test/managed_h2_group_preopen_control_test.exs`: `1fe88e47240cadfcf16ff89b02f550d14905fa758b97ac0c4d554f43a5276863`
- `apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs`: `4cba255e9c957b08fea039d676a0eae31112d73a5548068d0a0cd308b4c482c9`
- `apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_test.exs`: `d72b0b2f2982e9cc01b6338de2df19014c80f24c861932a42f9ba90338433874`

The sole executable production change enables the fixed internal `activation/0` gate; Session changes one comment only. No test-only bypass, caller-controlled callee/arguments, runtime toggle or profile marker was added. Existing source guards remain: Service cleanup attachment and reference token, real G/T owner/instance/pin/checkout paths, finite complete state/options validation, queued terminal and local deadline checks before effects, original completion binding T before G, and cleanup before ledger finishes. The reference shell remains necessary only, with authority supplied through the genuine production flow.

The preopen replacement explicitly proves nil Service token fails with the internal gate enabled, preserving exact unavailable/stopped-state/no-ready/no-extra-error assertions. Existing nil-token bind cases, queued-terminal counts and cleanup-state assertions are byte-identical. The pure boundary case keeps successful preparation then changes selected transport identity and requires exact invalid_group_opening, preserving group transport coherence. The owner case retains every existing config/control/byte/pin and cleanup assertion and adds actual invalid public checkout with exact invalid_checkout, complete G state/monitor equality and T status equality.

All read-only commands finished successfully; all five current hashes were rechecked. Reviewer runtime tests0, repository edits0 and Sol repair rounds0. Parent counters remain preserved without aggregation/reset; Astra2/2 is exhausted. Root runtime outcomes are parent-owned and unclaimed here.

This verdict covers only controlled-F source/test correctness. It does not certify live106, Session46, successful public admission/open/bind/cleanup, browser, full matrix/capacity/lifecycle, whole-stage review, fresh acceptance or any publication/deployment gate. Those require their own actual authenticated results. No new product decision or permission is needed for this bounded review. No reviewer background process was started; root processes were left untouched. Only the authorized /tmp report pair was written.
