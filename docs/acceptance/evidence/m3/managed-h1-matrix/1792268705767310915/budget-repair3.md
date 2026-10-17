# Managed-H1 matrix budget and causal-error repair3

DONE for the assigned direct source/static handoff. Runtime remains NOT RUN.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; parent-verified entry `1426657e65d726629d618dcf03880df718375dd1`. Only `apps/gaoxy_proxy/test/support/managed_h1_matrix_fixture.exs` changed. Its initial bytes exactly matched the archived candidate3/pre-repair fixture SHA256 `f1549e2d0493ac6f7481b57e64361d9b5635ecc4fd5b5e0e261e9fc40744ff1c`.

The native H2 reservation formula cannot fit16MiB even at its minimum supported settings. The parent explicitly authorized an H2-only64MiB fixture cap after this was surfaced. H1 remains16MiB. H2 now explicitly uses one stream,16KiB frames/window/read chunks,32KiB parser carry,8KiB HTTP headers,4KiB HPACK header blocks,1KiB dynamic table and1MiB body limit. All options are supported; no validation, assertion or protocol/case deadline was weakened.

Exact reservation from the current validator:

- Maximum delivery: `100*16384+18437 =1656837`.
- Decode: `2*4096*(1024+2)+512*4096+2*1024 =10504192`.
- Connection: `10504192+16777216+65535+4*32768+8*1656837 =40732711`.
- Stream: `2*8192+4*16384+65536 =147456`.
- Writer: `4*16384+1024 =66560`.
- Total: `40946727 <67108864`, leaving `26162137` bytes.
- Ingress also fits: `16384+9 <=32768`; read chunk `16384 <=32768`.

`run_case` now captures the original exception kind/reason/stacktrace, always attempts the existing isolated owned-group/fixture/Port cleanup, reports all cleanup errors with `IO.warn`, then reraises the original exception with its original stacktrace. A successful operation followed by any cleanup failure still raises and fails. Every forced/unjoined cleanup remains visible and failing.

Static baseline/diff, whitespace and literal budget arithmetic checks passed, exit0. No candidate code was imported or executed. Elixir syntax/format/compile, tests, runtime, browser and Git remain NOT RUN by this worker. Root owns those checks. No tooling or protected-file incident occurred; no repository evidence/counter files changed. All worker commands finished and no runtime/background process was launched.

Pre-format fixture SHA256: `94adbb8390513cdbc2a2a4e9d751b9db3a404ff82053ad104089782296aa628e`. Source ownership returned to parent. The separate H1 Content-Length repair belongs to the other worker. No further product decision needed.
