# Backend options verification — 2026-10-22

Implementation is complete in the uncommitted working tree based on main
`946e850472e9c6e95c3f8914a65b58531c852287`. Feature checks and independent review
passed. The browser smoke check is **BLOCKED_ENV**, and the broader core suite
and repository-wide formatter retain the failures below. This is not a claim
that all repository checks pass. No commits, push, release or deployment occurred.
The user's `prompt.md` and the existing `gaoxy_test` source were preserved.

See [configuration and support matrix](../backend-options.md),
[design](../designs/backend-options.md) and [plan](../plans/backend-options.md).

## Implemented behavior

- Core TCP/TLS forwards validated acceptor and socket tuning to Hell. Acceptor
  connection quotas divide the existing `max_active` ceiling without multiplying
  the budget. Defaults remain unchanged.
- UDP forwards `udp_buffer_size` and IPv4 TOS/TTL to Abyss. Socket inspection
  verifies receive/send buffers and TOS/TTL; ineffective separate buffer keys
  are rejected.
- QUIC forwards event batch size and canonical polling interval to Abyss.QUIC.
  Independent aioquic requests pass through direct, ListenerSet and Phoenix
  startup paths with nondefault host settings.
- HTTP/HTTPS forwards the narrower supported socket subset through direct,
  ListenerSet and Phoenix startup. Protocol-owned receive buffers are rejected
  before endpoint initialization. Duplicate keywords, backend mismatch and
  ownership overrides fail explicitly.
- Deferred activation pins normalized backend configuration. Existing binding,
  credentials, admission, byte budgets, shutdown and cleanup ownership remain.

## Environment and fresh checks

macOS arm64; Elixir 1.20.1 / OTP 29; OpenSSL 3.5.9 selected explicitly;
aioquic 1.2.0 / h2 4.3.0 from the existing `.audit/h2peer` environment.
Dependency versions were inspected without modification: Hell git
`59eed42b019ca41413d1b8cd7a7dc3e344bb93ee`, Abyss 0.9.0,
elixir_quic 0.21.14. Logs and check metadata are retained in
[evidence/backend-options](evidence/backend-options/checks.json).

Fresh scoped command (seed 363445):

```sh
OPENSSL_BIN=/opt/homebrew/opt/openssl@3/bin/openssl mix test \
  apps/gaoxy/test/backend_options_test.exs \
  apps/gaoxy/test/config_test.exs \
  apps/gaoxy/test/runtime_test.exs \
  apps/gaoxy/test/tls_test.exs \
  apps/gaoxy/test/native_stream_test.exs \
  apps/gaoxy/test/staged_activation_test.exs \
  apps/gaoxy/test/datagram_dispatcher_test.exs \
  apps/gaoxy_test/test \
  apps/gaoxy_http/test/backend_options_test.exs \
  apps/gaoxy_http/test/phoenix_adapter_test.exs \
  apps/gaoxy_http/test/listener_set_test.exs \
  apps/gaoxy_http/test/http_protocol_defaults_test.exs \
  apps/gaoxy_http/test/mixed_http_network_test.exs \
  apps/gaoxy_http3/test/backend_options_test.exs \
  apps/gaoxy_http3/test/options_test.exs \
  apps/gaoxy_http3/test/service_test.exs \
  apps/gaoxy_http3/test/host_poll_profile_test.exs \
  apps/gaoxy_http3/test/listener_set_network_test.exs
```

**PASS, exit 0:** core 48, HTTP 36, HTTP3 30, gaoxy_test 69; **183 passed**.
Real sockets, acceptor counts/quotas, traffic, resource accounting, cleanup,
finite shutdown deadlines and socket rebinding are asserted. All three new
feature test files execute nonzero tests. Earlier worker verification also ran
the complete core suite successfully: 174 passed. These are separate runs.

**PASS, exit 0:** `mix compile --force --warnings-as-errors` (development),
and worker `MIX_ENV=test mix compile --warnings-as-errors`.
Existing optional umbrella dependency notices and dependency compiler warnings
remain visible in logs; strict application compilation passed.

**PASS, exit 0:** `mix format --check-formatted` with the explicit 11 changed
product Elixir source/test paths; `git diff --check`. Evidence probe scripts
are formatted separately.

## Broader failures and unavailable verification

**FAIL, exit 2:** replacing the seven selected core test files in the command
above with `apps/gaoxy/test` ran 309 tests: 308 passed and one failed, seed
153674. Repeating with that seed produced the same count. The unchanged
`Gaoxy.AdmittedSpawnTest` case at line 458 timed out waiting for a cancellation
reply. Its single-case rerun passed, and its complete 39-case file passed with
the same seed. No assertions or deadlines were changed.

For a baseline comparison, a separate VM loaded the three changed core modules
(`Config`, `Service`, `Activation`) directly from baseline git source and ran
all 165 original core tests, excluding the new feature test file. The same
cancellation case failed at its terminal-accounting barrier; registry recovery
also failed, yielding 163 passed / 2 failed. The exact baseline probe and logs
are retained. The admission implementation, bootstrap, lifecycle module and
admission test file have no diff against baseline. This establishes baseline
instability in that case; it does not establish a shared root cause for the
different observed assertions. No unrelated repair was attempted.

**FAIL, exit 1:** repository-wide `mix format --check-formatted` identifies five
untouched files: HTTP parser test, H2 connection, two managed H2 proxy tests and
the Phoenix example ownership test. Their baseline equality was verified.
They were preserved; see the global format log for exact paths/diffs.

**BLOCKED_ENV:** connected Chrome DevTools `list_pages` succeeded, but
`new_page` timed out after 30 seconds for both the localhost fixture and
`about:blank`. Computer-use fallback reported Chrome unavailable and an empty
browser inventory. No browser response, DOM, screenshot or console acceptance
is claimed. The temporary Phoenix-adapter fixture started successfully with
two acceptors, then stopped normally and rebound its socket; its bounded
script and logs are retained. Browser rendering remains **NOT RUN**.

The initial network baseline also failed fixture setup because PATH selected
OpenSSL 4.0.3; selecting installed OpenSSL 3 restored those fixture checks.

## Independent review and remaining boundaries

Separate Sol contributors independently reviewed each other's implementation
and tests; the core contributor also reviewed the design and HTTP docs. Both
actionable HTTP findings (duplicate keywords, overwritten receive buffers)
were resolved and re-reviewed before fresh coordinator verification. Core Sol
repair rounds: 0; HTTP Sol rounds: 2 (fixture reader, then review findings);
Astra rounds: 0.

No arbitrary backend passthrough or Thousand Island compatibility alias is
provided. QUIC socket tuning, UDP separate receive/send buffers and HTTP-owned
receive buffers remain explicitly unsupported. Acceptor division may leave
unused slots, and kernel buffer rounding/clamping remains platform dependent.
Standalone JSON configuration is outside this change. Hosted CI, release,
deployment, sustained-load qualification and historical excluded slices were
not run.

## Fresh v0.11.0 publication result — 2026-10-22

**PASS:** [v0.11.0](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.11.0)
was published at `2026-10-22T03:52:50Z` from immutable source/tag commit
`638906cce7546028db2e8f5ecc8076957e889c09`. This appended record is a later
documentation-only change: its documentation HEAD is separate from the tagged
release source. The earlier observations above retain their original status;
the fresh results below do not rewrite them or expand the supported feature
matrix. See the [publication evidence index](evidence/backend-options/release-0.11.0/INDEX.md)
and [structured receipt](evidence/backend-options/release-0.11.0/receipt.json).

All **10 exact-source prerequisite jobs passed**: static/build
[39715428935](https://github.com/gsmlg-dev/gaoxy/actions/runs/39715428935)
(3 jobs), unit
[39715428936](https://github.com/gsmlg-dev/gaoxy/actions/runs/39715428936)
(2 jobs), and foundation
[39715428933](https://github.com/gsmlg-dev/gaoxy/actions/runs/39715428933)
(5 jobs). Release workflow
[39717847092](https://github.com/gsmlg-dev/gaoxy/actions/runs/39717847092)
passed its packaging, ordinary compatibility, built-package consumer,
production-isolation, formatter, strict compilation and standalone smoke
checks before publication, and its fresh public Hex consumers afterward.
The mandatory ordinary repair/compatibility gate includes the 19 new backend
cases (core 9, HTTP 5, HTTP3 5), increasing its asserted count from 334 to 353.

The hosted Chromium 155 report records **PASS** for independent H1/H2/H3
requests, H2/H3 browser endpoints and WebSockets, code reload/restore, and
endpoint shutdown. This is fresh hosted verification; the earlier local
browser attempt remains **BLOCKED_ENV / NOT RUN**.

The six packages `gaoxy_websock_adapter`, `gaoxy`, `gaoxy_http`, `gaoxy_http3`,
`gaoxy_proxy` and `gaoxy_test` were published to Hex at **0.11.0**. Independent
public readback verified all eight GitHub asset digests, all seven published
`SHA256SUMS` entries, and six Hex API/version, archive-version and byte-equality
checks against the release tarballs. The Linux x86_64 standalone archive reports
version 0.11.0 and excludes `gaoxy_test` and `ex_unit`. Its Linux binary was
**NOT RUN locally on macOS**; the hosted Linux standalone smoke passed.

A separate fresh local public-install check used canonical Elixir 1.18.5 /
OTP 29, OpenSSL 3 and the existing independent H3 peer:

```sh
python3 scripts/test-consumers.py --published --version 0.11.0
```

**PASS, exit 0:** public Hex-only base 3, H3 2 and HTTPFetch 2: **7 tests,
zero failures, exclusions or skips**, plus manual mode (1), production
dependency isolation (1) and assembled-release isolation (1). No local source
dependency overrides were used.

The original CI attempt on `9e2326c4` remains **FAIL** for the Linux H2
consumer fixture, which received the complete response then closed TCP before
the callback recorded completion (`{:terminated, :killed}`). A deterministic
real-H2 probe reproduced that ordering and passed when verification preceded
closure. The original consumer and four relevant lifecycle modules have no
diff between v0.10.0 and `9e2326c4`; this was a pre-existing fixture race.
The independently approved fixture-only fix `638906cc` moves verification
before peer closure, retaining every protocol/body/verification assertion and
leaving product lifecycle code unchanged. Its repeated built-package check
passed base 30 + H3 2 + HTTPFetch 2 tests (34 total), plus the manual,
production and release-isolation checks. Sol repair rounds: **1 successful**;
Astra: **0**. The initial probe also retained a diagnostic-script cleanup-field
assertion error; the corrected probe passed both ordering cases. Separately,
the original macOS Rebar mirror
download failure remains **BLOCKED_ENV**; the fresh macOS prerequisite jobs
passed without a source workaround.

This release result adds no deployment, production-data/certificate,
sustained-load or historical excluded-slice qualification. Unsupported options
and all feature limitations above remain in force.
