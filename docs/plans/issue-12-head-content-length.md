# Issue 12: HEAD representation Content-Length

The S3 and cluster blob handlers set a stored object's Content-Length and call
`Plug.Conn.send_resp(conn, 200, "")` for HEAD. The H1 renderer and shared H2/H3
renderer replace that metadata with the empty body's length before suppressing
the wire body.

Preserve a validated supplied Content-Length for HEAD. Infer the length from the
response body only when no length was supplied. Retain the existing precedence
for 204 (no length), 205 (zero), and 304 (supplied representation length), and
retain GET's length derived from the actual response body. Existing malformed
and duplicate length checks must run before this choice. Keep body suppression
and stream completion unchanged; no public API or dependency change is needed.

1. Add deterministic unit checks for metadata, body suppression, status precedence,
   and rejection of invalid/duplicate lengths. Confirm the supplied-length case
   fails before changing production code.
2. Add protocol tests using a real Plug listener and independent H1/H2/H3 peers.
   Each peer checks 16 HEAD/GET cases, including explicit, inferred, zero and
   empty-body lengths plus 204/205/304. Confirm the original issue fails on all
   three protocols before the repair.
3. Change only H1 and shared framed response header preparation. Run the new
   scoped tests and existing H2/H3 bodyless/framing compatibility tests.

The unit file belongs to `unit`; both listener files belong to `protocol` in
`scripts/check-repairs.py`. The H3 peer uses the existing independent raw
QUIC/QPACK decoder because the pinned aioquic H3 parser does not model HEAD's
Content-Length exception. It still checks exact headers, DATA bytes and FIN.

Validation on main based at `0b3f97fc08549649b4b367e3a85a8526e162f53f`:

- RED: the new protocol files executed 3 tests and failed all 3 on the expected
  `content-length: 0` versus `12345` assertion. The new unit file executed 4
  tests with 1 expected supplied-length failure.
- GREEN: with `ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test`,
  `python3 scripts/check-tests.py apps/gaoxy_http/test/head_content_length_test.exs apps/gaoxy_http/test/head_content_length_network_test.exs apps/gaoxy_http3/test/head_content_length_network_test.exs apps/gaoxy_http3/test/transport_test.exs --seed 0 --max-cases 1`
  passed 20 tests (6 HTTP, 14 HTTP3), including 48 independent protocol rows.
- Formatting checks passed for the changed Elixir files.
- Additional existing H1/H2 compatibility run executed 37 tests, with 1 failure
  in `http_network_test.exs:351`: `one large client write streams through a
  smaller parser buffer` returned 500 instead of a response body of `2000`.
  Its baseline status was not established. No unrelated repair was attempted;
  this failure remains visible for the parent release qualification.
