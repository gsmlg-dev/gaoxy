# GT-CORE round 3 handoff

Task GT-CORE, implementation/recovery, astra_gate=SOL_REPEATED_FAILURE.
ROUTE task=GT-CORE agent=astra_worker reason=SOL_REPEATED_FAILURE (existing allocation).
Counters: Sol repairs=2; Astra repairs=3 used of user-authorized maximum 4.
Round 4 has NOT started. Original escalation and task identity retained.
Source: 044e1cd90ddf4cc1550df99411f2906209387f5f plus preserved uncommitted task edits.
No remote integration, commits, publication, dependency patches, permission or network changes.

## Changes made in this round

- apps/gaoxy_test/test/protocol_test.exs: three dynamic private profile predicates replace literal module-attribute membership expressions (four callsites). Identical profile sets, assertions and deadlines; no warning suppression.
- integration/phoenix_native/unified.py: optional GAOXY_CHROMIUM_EXECUTABLE override; preserve system chromium then Playwright discovery by default; record actual executable/version in report.json.
- integration/phoenix_native/README.md: document the override/report and precise observed browser comparison.
- Diagnostic scripts, NetLogs and this report under ignored .audit/gaoxy-test only.

NO production source changes in this round. Existing Service/Lifecycle recovery edits were preserved. Parent's isolated source-consumer production snapshot is unaffected.

## Diagnosis

Canonical Elixir1.18.5 warns on the generated tests' constant profile comparisons against list elements. Dynamic helper arguments preserve the comparisons while avoiding the compile-time distinct-type warnings. Fresh warnings-as-errors execution passes.

Downloaded Playwright Chromium141.0.7390.37 on this macOS host loads the document and scripts over H3, then attempts the LiveView WebSocket over TCP and gets ERR_CONNECTION_REFUSED at the UDP-only H3 port. NetLog records document jobs using_quic=true and all wss jobs using_quic=false. No corresponding H3 websocket request reaches the server. Selecting installed Chrome156.0.8078.48 passes the same assertions, including native HTTP/3 upgraded receipts for both /live/websocket and /socket/websocket. This establishes the observed browser-selection difference, not a general unsupported-browser or macOS product conclusion. Assertions, timeout values and required transports are unchanged.

Evidence:

- round3-browser-diagnosis.log / round3-browser-diagnosis/report.json: instrumented original suite, Chromium141, exit1; independent H1/H2/H3 and H2 browser/reload pass, H3 WS fails.
- round3-browser-netlog.log / round3-browser-netlog/h3-netlog.json: same failure, exit1; QUIC page vs TCP websocket evidence.
- round3-browser-chrome156.log / round3-browser-chrome156/report.json: diagnostic executable selection only, all 8 checks pass, exit0.
- round3-unified-browser/report.json: final real suite, explicit browser version/path, all8 PASS, exit0, fixture process_exit0 and source_restored=true.

## Exact validation commands and exits

All commands run from repository root. Canonical PATH selects Elixir1.18.5 on local OTP29; no OTP28 claim. Separate canonical Hex archive is used.

Expanded scoped run (44 core +12 HTTP +1 H3 +69 fixture =126), seed0/max-cases1, exit0:

```sh
PATH="$PWD/.audit/canonical-elixir/distribution/bin:$PATH" MIX_ARCHIVES="$PWD/.audit/gaoxy-test-canonical-archives" ELIXIR_ERL_OPTIONS='+S 2:2' OPENSSL_BIN=/opt/homebrew/opt/openssl@3/bin/openssl GAOXY_QUIC_PYTHON="$PWD/.audit/h2peer/bin/python" MIX_ENV=test mix test apps/gaoxy/test/lifecycle_fault_test.exs apps/gaoxy/test/lifecycle_ownership_test.exs apps/gaoxy/test/shutdown_hardening_test.exs apps/gaoxy/test/lifecycle_acceptance_test.exs apps/gaoxy/test/lifecycle_participant_test.exs apps/gaoxy_http/test/http_lifecycle_test.exs apps/gaoxy_http/test/stream_lifetime_generation_test.exs apps/gaoxy_http3/test/stream_lifetime_boundary_test.exs apps/gaoxy_test/test --seed 0 --max-cases 1 --warnings-as-errors > .audit/gaoxy-test/round3-canonical-package-lifecycle.log 2>&1
```

Required aggregate (44 core +5 HTTP +1 H3 +69 fixture =119), seed0/max-cases1, exit0:

```sh
PATH="$PWD/.audit/canonical-elixir/distribution/bin:$PATH" MIX_ARCHIVES="$PWD/.audit/gaoxy-test-canonical-archives" ELIXIR_ERL_OPTIONS='+S 2:2' OPENSSL_BIN=/opt/homebrew/opt/openssl@3/bin/openssl GAOXY_QUIC_PYTHON="$PWD/.audit/h2peer/bin/python" MIX_ENV=test mix test apps/gaoxy/test/lifecycle_fault_test.exs apps/gaoxy/test/lifecycle_ownership_test.exs apps/gaoxy/test/shutdown_hardening_test.exs apps/gaoxy/test/lifecycle_acceptance_test.exs apps/gaoxy/test/lifecycle_participant_test.exs apps/gaoxy_http/test/supervised_shutdown_budget_test.exs apps/gaoxy_http3/test/stream_lifetime_boundary_test.exs apps/gaoxy_test/test --seed 0 --max-cases 1 --warnings-as-errors > .audit/gaoxy-test/round3-canonical-required119.log 2>&1
```

Metadata-aware per-file package gate, 69 executed /0 failures /0 excluded /0 skipped, seed0/max-cases1, exit0:

```sh
PATH="$PWD/.audit/canonical-elixir/distribution/bin:$PATH" MIX_ARCHIVES="$PWD/.audit/gaoxy-test-canonical-archives" ELIXIR_ERL_OPTIONS='+S 2:2' OPENSSL_BIN=/opt/homebrew/opt/openssl@3/bin/openssl GAOXY_QUIC_PYTHON="$PWD/.audit/h2peer/bin/python" MIX_ENV=test python3 scripts/check-repairs.py test_helpers > .audit/gaoxy-test/round3-canonical-test-helpers.log 2>&1
```

Final established browser suite, 8/8 checks, exit0:

```sh
OPENSSL_BIN=/opt/homebrew/opt/openssl@3/bin/openssl GAOXY_CHROMIUM_EXECUTABLE='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' GAOXY_PHOENIX_EVIDENCE=.audit/gaoxy-test/round3-unified-browser .audit/gaoxy-test-browser/bin/python integration/phoenix_native/unified.py > .audit/gaoxy-test/round3-unified-browser.log 2>&1
```

Canonical full formatter, exit0:

```sh
PATH="$PWD/.audit/canonical-elixir/distribution/bin:$PATH" MIX_ARCHIVES="$PWD/.audit/gaoxy-test-canonical-archives" ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test mix format --check-formatted > .audit/gaoxy-test/round3-canonical-format.log 2>&1
```

## Exact per-file counts

Required core: lifecycle_fault14, lifecycle_ownership3, shutdown_hardening8, lifecycle_acceptance3, lifecycle_participant16 =44.
Required HTTP: supervised_shutdown_budget5. H3: stream_lifetime_boundary1.
Expanded HTTP additions: http_lifecycle3, stream_lifetime_generation9 =12.
Package per-file metadata verified: expectations6, core9, lifecycle12, subprocess8, protocol13, helper17, recovery4 =69. No CI count change needed.

## Limits and ownership

Existing in-umbrella optional-dependency notices remain visible in successful logs; no warning suppression was introduced. Historical failed logs remain untouched. Downloaded Chromium141 failure is preserved. Known separate mac127.0.0.2 WSS test and system1.20 composition results remain outside this scoped success. Latest remote source reconciliation, affected upstream gates, independent final Sol review, hosted/release/published acceptance remain parent-owned and are not claimed passed here.

All round3 commands finished. Browser fixture process exited0 and temporary controller bytes were restored. Recovery writes and root Mix build slot are released to parent after final read-only handoff verification. No round4 command launched.
