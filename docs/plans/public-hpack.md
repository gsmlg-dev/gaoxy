# Public http_core HPACK migration implementation plan

> For agentic workers: execute the assigned independent file groups in parallel,
> preserve concurrent changes, and complete independent specification and code
> review before final fresh verification. Continuing project authorization
> covers execution without further routine approval.

**Goal:** Remove Gaoxy's HPAX dependency and use the documented public
`HTTP.HTTP2.HPACK` codec from HTTP Fetch 0.21.16 or later.

**Architecture:** Direct shared-codec reuse, with Gaoxy retaining its native
server runtime and existing admission and header limits. See
[`../designs/public-hpack.md`](../designs/public-hpack.md).

**Tech stack:** Elixir 1.18 / OTP 28, HTTP Fetch 0.21.16, ExUnit, Python h2 peers
and existing package/consumer harnesses.

## Tasks

- [x] Confirm the published upstream fix and update the coordinated package
  cohort; preserve the earlier requested `~> 0.21` dependency changes.
- [x] HTTP worker: migrate `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex`,
  any necessary decoder-option mapping in `http2/limits.ex`, and HTTP test peers
  under `apps/gaoxy_http/test/`. Preserve the existing RFC/malformed corpus,
  dynamic-table/expansion assertions and network assertions. Add focused
  regressions before production changes where needed; classify any new app
  file in the sole manifest and inventory through the parent.
- [x] Peer worker: migrate HPAX calls under `apps/gaoxy_proxy/test/`,
  `apps/gaoxy_server/test/`, and `integration/` using the public constructors,
  encode/decode return order and size-update API. Preserve every assertion and
  keep specialist cases unexecuted.
- [x] Parent: replace the `gaoxy_http` HPAX dependency with
  `{:http_core, "~> 0.21 and >= 0.21.16"}`, update package metadata expectations,
  remove unused HPAX lock entries and qualify affected consumer locks. Preserve
  unrelated workspace files and all historical evidence.
- [x] Complete independent specification and code-quality review; resolve
  actionable findings without loosening assertions.
- [x] Run fresh scoped verification and record counts/results below.

## API mapping and retained contracts

```elixir
alias HTTP.HTTP2.HPACK

decoder = HPACK.new_decoder(max_dynamic_size: table_size)
{:ok, decoder, fields} = HPACK.decode(decoder, complete_block)

encoder = HPACK.set_max_dynamic_size(HPACK.new_encoder(), 0)
{encoder, bytes} =
  HPACK.encode_headers(encoder, fields, indexing: :never, huffman: :never)
```

Production decoder options additionally derive maximum block bytes, decoded
name/value bytes, individual-field bytes and field count from the existing
Gaoxy expansion bound. No private codec fields or client processes are used.

## Verification commands

- `mix deps.get --check-locked && mix compile --warnings-as-errors`
- `python3 scripts/check-repairs.py unit`
- `python3 scripts/check-tests.py apps/gaoxy_http/test/http2_codec_test.exs`
- Scoped existing ordinary network files for H2, extended CONNECT/WebSocket,
  mixed HTTP routing and response rendering, using the appropriate existing
  non-unit harness; do not run deferred specialist suites.
- Select only the ordinary decoder-state and renderer cases at
  `http2_network_test.exs:719`, `:779` and `:873`; retain all other cases'
  unscheduled disposition.
- `.audit/h2peer/bin/python integration/h2_rfc/run.py --evidence <temporary-directory>`
- `python3 scripts/test-stage-hex-packages.py`
- Scoped HTTP/core and built-package consumer checks; verify the resolved
  runtime/package graphs contain `http_core` and exclude HPAX.
- `python3 scripts/check-test-inventory.py` and scoped `git diff --check`.

## Results

Completed locally on 2026-10-22, on `main` based on
`4ed1a506f87cd56d1908e6fffbd57e57e03bb6b1` plus this migration. Environment:
Linux 6.18.48 x86_64, Elixir 1.18.5, OTP 28 / ERTS 16.4.0.5, Python 3.13.15.
Mix commands used two BEAM schedulers. Independent peers were h2 4.3.0,
hpack 4.1.0, hyperframe 6.1.0 and aioquic 1.2.0.

The published HTTP Fetch cohort resolves to 0.21.16. Upstream
[http_fetch#141](https://github.com/gsmlg-dev/http_fetch/issues/141) is closed;
the installed HPACK module has public `@moduledoc`. Root and Phoenix example
locks no longer contain HPAX. Effective root dependencies and the compiled
`gaoxy_http.app` require `http_core` and exclude HPAX. Clean HTTP consumers
positively assert the presence and startup of `http_core`, `elixir_quic` and
`ex_ssl`; the core-only consumer still excludes all HTTP/QUIC dependencies.

| Check | Result, all exits 0 | Local evidence |
| --- | --- | --- |
| Root `mix deps.get --check-locked`; `mix compile --warnings-as-errors` | PASS, no umbrella optional warning | `/tmp/gaoxy-public-hpack-resolve.log`, `/tmp/gaoxy-public-hpack-compile.log` |
| `python3 scripts/check-repairs.py unit` | PASS, 198 executed, 0 failures/excluded/skipped across 37 files | `/tmp/gaoxy-public-hpack-unit.log` |
| Ordinary mixed HTTP, defaults, H2 WebSocket, H2 stream lifetime and proxy WebSocket rejection files through `scripts/check-tests.py --seed 0 --max-cases 1` | PASS, 14 executed, 0 failures/excluded/skipped | `/tmp/gaoxy-public-hpack-protocol.log` |
| Three location selectors above through `scripts/check-tests.py --seed 0 --max-cases 1` | PASS, 5 executed, 0 failures/skipped; 31 other cases deselected by location | `/tmp/gaoxy-public-hpack-selected-state-rendering.log` |
| `.audit/h2peer/bin/python integration/h2_rfc/run.py --evidence /tmp/gaoxy-public-hpack-rfc` | PASS, 40 selected RFC checks; runtime stopped and port rebound | `/tmp/gaoxy-public-hpack-rfc/results.json` |
| `python3 scripts/test-stage-hex-packages.py` | PASS, 12 tests, exact metadata for all six packages | `/tmp/gaoxy-public-hpack-packages.log` |
| `python3 scripts/test-consumers.py` | PASS, base 3, H3 2 and HTTPFetch 2 ExUnit cases; manual, production and release-isolation checks each 1 | `/tmp/gaoxy-public-hpack-consumers.log` |
| `bash scripts/external-consumer.sh`; `bash scripts/http-consumer.sh` | PASS, fresh source consumers: core 1 and HTTP 4 cases | `/tmp/gaoxy-public-hpack-source-consumers.log` |
| Phoenix example with `PHOENIX_NATIVE_H3=1`: locked resolution and strict test-environment compilation | PASS | `/tmp/gaoxy-public-hpack-phoenix-resolve.log`, `/tmp/gaoxy-public-hpack-phoenix-compile.log` |
| `mix format --check-formatted` on the 37 changed Elixir sources; `git diff --check` | PASS | Current diff |
| `python3 scripts/check-test-inventory.py` | PASS, unit=198, component=137, protocol=122; active files=83, retained files=149 | Current manifest and inventory |

The five selected migration cases exercise decoder state after closed and
rejected streams, 256 response fields, 128 ordered duplicate trailers and an
empty trailer block with its table-size update. The independent RFC harness
is selected h2c interoperability and error-scope evidence, not complete
protocol conformance.

Independent specification and code-quality reviews both returned no actionable
findings before final runtime qualification. Source assertions were preserved;
the codec suite grew from 3 to 5 cases and moved from retained coverage into
the unit manifest, raising its scheduled total from 193 to 198 cases.
The codec red run had 5 cases and 3 expected missing-option-mapping failures;
the final codec run passed all 5. Package metadata also failed before the HPAX
requirement was replaced. An initial stale test build still referenced HPAX and
ran zero tests; forced warning-free test compilation regenerated its application
metadata, followed by the passing runs above. No dependency sources were patched.

Exact tested source fingerprints are recorded by the RFC report and
`/tmp/gaoxy-public-hpack-source-sha256.json`; all 43 changed source/config files
were unchanged through qualification. Key SHA-256 values:

```text
connection.ex 99e85097308c489f7fb5965286b5f8148504365bba5bc479eb8dc111de3112e6
limits.ex     659a88751c909a9973c51141a2de7982b76d6f2653fec22b1096fab852278e75
mix.lock      0d83e0a01adcdf093cd53e2fb985b5bc100cda46ff8dee6e0b36bc14dda9fdfd
```

Specialist pressure, slow-peer, disconnect and sustained-load qualification,
hosted CI, publication and deployment were NOT RUN. Historical evidence and
retained test dispositions remain unchanged.
