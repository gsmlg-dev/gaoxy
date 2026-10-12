# HTTP Fetch H3 request trailers

## Current disposition — 2026-10-12

**Requesting repo:** `gsmlg-opt/gaoxy` on branch `codex/m4-http3`.

**Status:** BLOCKED DEPENDENCY —
[gsmlg-dev/http_fetch#101](https://github.com/gsmlg-dev/http_fetch/issues/101)
is OPEN, type Feature, label `internal request`.

**Severity:** blocker for required upstream-H3 request-trailer preservation.
Independent downstream H3 and standalone static/H1-origin routes can continue.

Gaoxy must preserve ordered repeated request trailers when translating an
H1/H2/H3 downstream request to an explicitly selected fixed H3 origin. The root
Fetch/runtime/core and QUIC/H3/TLS cohort remains **0.21.3**. Root `mix.lock`
SHA256 remains
`16542ddd554f9b78139ddf456288450a12da5781cf3900576edd7e83f159dc25`.
Both installed `http_fetch` and `elixir_quic_http3` package manifests identify
`gsmlg-dev/http_fetch` as their source.

## Executed public reproduction

The [source-bound run](../acceptance/evidence/m4/upstream-contract/run-1791811050964927834/result.json)
executed against independent aioquic **1.2.0** loopback origins with distinct
disposable P-256 CA/leaf identities. Fetch used explicit `verify_peer`, CA trust,
localhost hostname verification, H3 selection and `http3_reuse: false`. The
environment was Elixir **1.18.5**, OTP **28**, HTTP Fetch **0.21.3**; Gaoxy HEAD
was `29d79f95b78d112a1d8e1661d108b788f7780f3f`. Exact uncommitted source hashes
and wire events are retained in that run.

| Diagnostic rows | Result |
| --- | --- |
| Ordinary streamed response and ordered repeated response trailers, origin A | PASS |
| Ordinary streamed response and ordered repeated response trailers, origin B | PASS |
| Progressive upload observed before request FIN, exact `abcdef` response | PASS |
| Ordered repeated request trailers after exact `abc` DATA | BLOCKED |
| Ordered repeated request trailers after zero DATA | BLOCKED |
| Public abort before response headers | PASS |
| Public abort with an unacknowledged response chunk | PASS |

The **7 executed rows comprise 5 PASS and 2 BLOCKED**, not a passing full UP0
gate. In both blocked rows, `HTTP.Stream.finish/2` returned `:ok`, followed by
the public Promise result `{:error, :request_trailers_unsupported}`. The origin
observed exactly one request per case, the expected DATA bytes, no trailing
HEADERS and no request FIN. The `abc` SHA256 is
`ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`;
the other body is empty. Both public upload streams and Promise tasks terminated.

The probe waits for the independent origin's HEADERS/DATA barrier before calling
`finish/2`. A declaration-free request is valid H3 and reaches the actual upload
gap; this diagnostic does not enable a production workaround.

```elixir
{:ok, upload} = HTTP.Stream.start_link(0)
promise = HTTP.fetch(url <> "/echo-three",
  method: :post, body: upload, duplex: :half,
  http_version: :http3, http3_reuse: false, redirect: :manual,
  request_mode: :proxy, stream_response: true, decode_body: false,
  ssl: [cacertfile: ca, verify: :verify_peer], timeout: 3_000)
:ok = HTTP.Stream.chunk(upload, "abc", 1_000)
# Wait for independent origin: exact abc received, request FIN false.
:ok = HTTP.Stream.finish(upload, [{"x-check", "one"}, {"x-check", "two"}])
HTTP.Promise.await(promise, 4_000)
# => {:error, :request_trailers_unsupported}
```

Omit `chunk/3` and use `/echo-zero` for the zero-DATA case. The installed public
Stream documentation explicitly describes H3 request trailers as unsupported;
the H3 BodyBridge emits that error asynchronously. Its supported public Session
exports include `request/4` and `send_data/5`, with no request-trailer operation
in this cohort. The Session export audit is not another executed wire row.

The two abort rows observed `:aborted`, normal public process DOWN and independent
origin RESET `0x10c` on the corresponding request. The unsupported H3
`HTTP.RequestCompletion` result remains a diagnostic; successful public
AbortController/Promise/Stream alternatives are recorded separately. Both owned
children exited **0** and both origin UDP ports rebound.

## Historical failures and review

[run-1791792452444772174](../acceptance/evidence/m4/upstream-contract/run-1791792452444772174/result.json)
remains FAIL: supplying `headers: [{"trailer", "x-check"}]` produced
`ArgumentError: Trailer request headers are not supported` before origin request
HEADERS. Its original assertions and logs remain preserved.
[run-1791792280345799441](../acceptance/evidence/m4/upstream-contract/run-1791792280345799441/result.json)
remains FAIL with `certificate_signature_scheme_not_allowed` for the original
RSA PKCS#1 fixture. Separate P-256 ephemeral credentials resolved that fixture
problem without changing dependency sources or weakening trust assertions.

The [functional disposition](../acceptance/evidence/m4/upstream-contract/functional-disposition.json)
corrects the earlier environment-block wording to a functional dependency block.
[Independent source/evidence review](../acceptance/evidence/m4/upstream-contract/review-up0.json)
passed without actionable findings. All 180 captured before/after source hashes
match; 179 also match the current checkout exactly. Removing only
`# TODO(upstream): gsmlg-dev/http_fetch#101` from the probe recreates the captured
hash for the remaining file. Live issue review confirmed its type, label,
requesting repo/branch, reproduction and severity.

The [fresh post-review diagnostic](../acceptance/evidence/m4/upstream-contract/run-1791815367697333596/result.json)
returned exit2 and the same5PASS/2BLOCKED. All180 source hashes now match before,
after and the current checkout, including the TODO. [Fresh independent review](../acceptance/evidence/m4/upstream-contract/review-up0-fresh.json)
passed; [the state check](../acceptance/evidence/m4/upstream-contract/dependency-state-1791814663418733829.json)
still found #101 OPEN and Hex latest0.21.3. Historical receipts remain unchanged.

## Required upstream behavior and remaining work

A supported public upload operation must preserve ordered repeated permitted
trailing fields after DATA or zero DATA, send terminal HEADERS/FIN and expose
asynchronous failures. Valid H3 trailer declarations should be accepted. Preserve
finite deadlines, cancellation and no replay.

The production H3 upstream adapter **UP1** and upstream matrix **UP2** remain
unimplemented and blocked pending a compatible published fix, dependency update
and prescribed qualification. Wrong-CA/hostname, absent-trust and
`connect_address` negative probes, plus blocked-upload and owner-loss cancellation
alternatives, remain **NOT RUN**. No dependency patch, private transport access or
trailer-dropping production workaround is used. The reviewed exclusion of
`http_fetch#97` remains in force and adds no requirement here.
