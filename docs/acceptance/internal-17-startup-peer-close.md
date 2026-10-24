# HTTP/2 TLS startup peer-close classification

Date: 2026-10-25, Asia/Shanghai. Branch: `main`. Baseline:
`90e75ed5809bc3d94ba71d9eaddee4f1da56de6e`.
Issue: [#17](https://github.com/gsmlg-dev/gaoxy/issues/17).
Status: locally repaired; focused regressions, independent review and affected
canonical gates pass. Publication remains blocked by the
separate H2 persistence dependency in #16.

## Problem and bounded repair

An ALPN `h2` client may disconnect after TLS metadata collection but before
Gaoxy sets the H2 receive options. OTP SSL can return the inet failure as
`{:options, {:socket_options, options, :einval}}`. H2 startup currently returns
that reason as an abnormal handler failure. Existing common startup handling
covers bare closure errors during earlier metadata calls, so it misses this
later boundary.

The requesting repository reports 9 abnormal logs in 20 successful serial
TLS connect/ALPN/close operations and no request-delivery failure. That is
reported upstream evidence, not a locally executed 20-connection result.
Hell documents arbitrary SSL setopts errors and delegates to OTP; this repair
belongs in Gaoxy's startup classification and requires no dependency patch.

The repair is limited to H2 receive-option setup: recognize closure
candidates, verify closure with supported `Hell.Socket` metadata APIs and return
an orderly close. Preserve the exact original error while the socket remains
live, including real invalid-option failures. Resource admission and writer
startup must not occur on this early closure path. This changes no general
logging policy or ordinary H2 request behavior.

## Verification plan

- Controlled component cases cover bare and wrapped `:closed`, `:enotconn` and
  `:einval` after initial metadata succeeds; closed sockets finish normally
  without admission/writer allocation. Live-socket failures retain their reason.
- A synchronized real TLS peer completes ALPN and metadata, then closes at the
  receive-option boundary. Execute supported generated connection callbacks;
  require normal owner termination, no abnormal failure log, no leaked leases
  or writer, and a healthy H2 follow-up with finite cleanup.
- Capture actual RED and GREEN executions with exact counts. Classify new files
  in `scripts/check-repairs.py`; keep real sockets in the protocol suite.
- Obtain independent specification/code review, scoped formatting, inventory
  and strict compile; rerun affected H2/common compatibility when the change
  warrants it. Preserve unrelated and specialist evidence.

## Executed evidence

The new regression files executed **9 tests, 7 failures** against the unchanged
baseline: six controlled bare/wrapped closure cases and the real TLS boundary
failed the required orderly stop. Two live/error preservation controls passed.
Earlier missing fixture fields and invalid fixture configuration were corrected
before this semantic RED. `.audit/internal-17/worker-red.txt` explicitly records
those setup failures separately and is a transcribed execution receipt, not a
complete raw RED log.

After the repair and scoped formatting, the same command executed **9 tests,
0 failures**, exit 0. The component file has **8 tests** and the real TLS file
**1 test**. Raw passing outputs are retained as `worker-green.txt` and
`worker-green-final.txt`. The TLS case observes actual SSL EOF after successful
ALPN/metadata, requires the generated handler's orderly stop, captures no error
log, checks zero admission usage and verifies an actual healthy H2 response
with finite cleanup. This supplements the exact wrapped-error component
coverage; it does not assert that a timing-sensitive 20-connection reproduction
was rerun locally.

Independent specification and code/ownership review found no actionable issues.
The review verified the public API use, narrow error handling, resource ordering,
test boundaries and preservation of #16's changes and Hell #2 TODOs. Scoped
formatting and whitespace checks passed. Source was frozen for final gates.

Root commands use `ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test`:

```sh
python3 scripts/check-tests.py apps/gaoxy_http/test/http2_startup_peer_close_test.exs apps/gaoxy_http/test/http2_startup_peer_close_network_test.exs --seed 0 --max-cases 1
python3 scripts/check-test-inventory.py
mix format --check-formatted
mix compile --warnings-as-errors
python3 scripts/check-repairs.py component
python3 scripts/check-repairs.py protocol
```

| Gate | Disposition |
| --- | --- |
| Focused component/protocol | PASS, 9 tests, 0 failures, exit 0 |
| Independent specification/code review | PASS, no actionable findings |
| Inventory | PASS, 254 unit / 175 component / 131 protocol, 97 active files / 145 retained |
| Full formatter and strict compile | PASS, both exit 0 |
| Canonical component | PASS, 175 executed, 0 failures, 0 excluded/skipped, exit 0 |
| First canonical protocol attempt | FAIL, stopped at H3 listener setup `:eaddrinuse`; that file executed 8 tests, 1 failure; gate exit 1 |
| Unchanged H3 listener file, isolated recheck | PASS, 8 tests, 0 failures, exit 0 |
| Fresh complete canonical protocol repeat | PASS, 131 executed, 0 failures, 0 excluded/skipped, exit 0 |
| Direct Hex dependency freshness | PASS, all current, `mix hex.outdated` exit 0 |
| New-version publication/downstream read-back | NOT RUN; complete contract blocked by hell#2 |

Final command/exits are saved in `final-gates.json` with `final-*.log`. The four
changed non-document source/manifest/test paths and hashes are saved in
`source-files.json`; unchanged dependency/native WS qualification is recorded
at the preceding `90e75ed5` implementation in #16's acceptance. Its 95-file,
254/167/130 ledger remains historical evidence of that frozen source. The two
new #17 files add 8 component cases and 1 protocol case to the current manifest.

The first final protocol attempt passed the new TLS case and the native/H3 WS
cases, then failed while starting the existing explicit shared-port listener
test. It received `{:failed_to_start_child, :listener, :eaddrinuse}` before any
connection callback. That fixture probes a free UDP port, closes the probe and
uses the number for both TCP and UDP; it does not reserve or establish that TCP
is free. The failed log does not identify a competing socket or establish a
product leak. The remaining files were not run in that attempt. Its failure
is retained in `final-protocol.log` and `final-gates.json`, separately from the
unchanged file's passing `listener-port-recheck.log` and the complete
`final-protocol-rerun.log`/`protocol-rerun.json`. No listener source, fixture or
assertion was changed for this recheck.

The frozen four-file source receipt has combined SHA-256
`3afb3ed58d425ca4d217d9f3e42cc42bd2e3eed52609a25af250585ad3c02a4b`;
each file still matches immediately before the local commit. The latest direct
dependency check is retained in `latest-dependencies.log`. Hell upstream main
still points at `59eed42b019ca41413d1b8cd7a7dc3e344bb93ee`, and its issue #2
remains OPEN at final closeout.

## Current disposition

This issue remains open until qualified publication. The broader native WS
contract in [#16's acceptance](internal-16-default-capacity.md) still depends on
[hell#2](https://github.com/gsmlg-dev/hell/issues/2); completing this independent
repair does not remove that release blocker. No version bump, publication or
deployment is included in this local repair result.
