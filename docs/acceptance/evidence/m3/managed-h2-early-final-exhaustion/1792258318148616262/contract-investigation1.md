# Early-final at exhausted upload credit: source contract

DONE — direct read-only investigation at `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, HEAD `ceb3c0c953d930768023da85875a95672876ce39`.

**Finding:** the managed pooled H2 path supports completing an early final response while request DATA credit is zero. For the locally unfinished original stream, normal response completion releases it with peer-visible RST_STREAM **code 8**, derived from the pinned runtime serializer. The combined full-native-body/trailers submission case remains **NOT RUN**.

## native_pump — SOURCE_SUPPORTED

The native pump submits bounded body chunks with a finite write timeout. A non-timeout upload error marks upload_stopped and exchange.close, then waits for the final head rather than manufacturing 502. A final head also stops further upload; response chunks/end are delivered and Session.consumed is called. Response and upstream reset can be observed before the test initiates downstream close. No promise is made that an incomplete-request native connection remains reusable/open.

Source: `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:789-895`; `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:998-1055`.

## supported_adapter — SOURCE_SUPPORTED

The adapter uses supported HTTP.Stream chunk/finish and HTTP.fetch/Promise APIs, captures the original RequestCompletion immediately, and maps public Promise/stream messages into Session events. No private runtime inspection or opaque completion internals are required.

Source: `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex:55-86`; `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex:142-175`; `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex:294-312`; `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex:396-455`.

## early_stop — SOURCE_SUPPORTED

Noninformational ordinary final response headers stop upload in the runtime owner, discard pending_body and remove the stream from upload scheduling. SocketClient also invokes BodyBridge.early_response before returning the response. The bridge sends HTTP.Stream.error(:early_response), acknowledges any held source ref and clears buffered body/trailers. Stream.chunk has public error/down returns; Stream.finish submission is asynchronous and is not upstream receipt.

Source: `deps/http_runtime/lib/http/http2/connection_owner.ex:1242-1270`; `deps/http_runtime/lib/http/http2/connection_owner.ex:1636-1650`; `deps/http_fetch/lib/http/socket_client.ex:1093-1157`; `deps/http_fetch/lib/http/http2/body_bridge.ex:23-25`; `deps/http_fetch/lib/http/http2/body_bridge.ex:250-285`; `deps/http_fetch/lib/http/stream.ex:113-169`.

## terminal_oracle — SOURCE_SUPPORTED

For a pooled managed H2 request whose request HEADERS are committed and whose upload END_STREAM was not sent, completing the final response calls public release_stream. close_unfinished_upload emits cancel_headers unless the stream is already closed. Here an upstream response END_STREAM leaves an unfinished local upload half_closed_remote, so cancel_headers emits rst_stream :cancel, explicitly serialized as numeric code8. The correct witness is an actual peer StreamReset on the original connection/stream before the test closes downstream. Code8 is derived from these pinned sources, not assumed from HTTP convention. Zero DATA credit does not gate this control frame. EOF/connection_reset during final fixture close cannot replace this witness.

Source: `deps/http_fetch/lib/http/socket_client.ex:1304-1325`; `deps/http_runtime/lib/http/http2/connection_owner.ex:488-526`; `deps/http_runtime/lib/http/http2/connection_owner.ex:1653-1665`; `deps/http_core/lib/http/http2/connection.ex:289-292`; `deps/http_core/lib/http/http2/stream_state.ex:337-348`; `deps/http_runtime/lib/http/http2/connection_owner.ex:676-677`.

## completion_cleanup — SOURCE_SUPPORTED

The original public RequestCompletion must confirm release of tracked request resources/stream/reservation. It is not proof of peer receipt or physical connection shutdown. Session polls the original completion within its existing absolute cleanup deadline and releases transport/group/service only after consumed/cancelled. Fixture clean requires zero active/cleanup retained resources and expected resident connection pin; fixture close then stops embedding, joins actors, observes physical eof OR connection_reset and requires peer joined forced0/live0/failedfalse, expected requests and exit0.

Source: `deps/http_fetch/lib/http/request_completion.ex:1-23`; `apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex:1341-1435`; `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs:574-638`; `apps/gaoxy_proxy/test/support/managed_h2_group_fixture.exs:299-317`; `apps/gaoxy_proxy/test/support/managed_h2_group_fixture.exs:364-399`.

## qualification_boundary — NOT_RUN

The existing early-final test is headers-only with a declared incomplete content length; it proves a response before test downstream close but not full producer submission plus genuine zero stream credit. The held-credit peer currently proves one unpadded DATA byte, stream window0 and positive connection credit, rejects trailers/END before explicit release, and exposes actual StreamReset code. A bounded positive combined case can qualify full body/trailers submitted at the native socket boundary -> held barrier -> early final -> exact response and actual reset -> cleanup without release. Native submission is not proof all body/trailers were parsed by Gaoxy or delivered upstream. This does not close separate explicit cancellation/unsent-trailer, live-sibling or full Task6/matrix/load gates.

Source: `apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs:942-956`; `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py:312-355`; `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py:489-502`.

## Evidence and boundaries

16 exact source hashes are in the companion JSON. HEAD matched via `git rev-parse HEAD`; both E9 receipt SHA256 values matched. The custody receipt records 174 task files / 402 source pins / 565 union blobs; this investigation did not rerun that entire audit. Tests/build/browser/network were NOT RUN as assigned. No repository or dependency source changed. No private process runtime inspection or opaque completion implementation was used.

Own tooling delta relative E8counter9: +2 NEW investigation incidents, after previous FINAL DOC SPEC2 incidents already included in E8. Parent clarified E9counter1 root392/orchestration298/earlyTool3 contains writer incidents only and neither investigation incident; add2 without duplication. Both were guessed missing source paths, corrected by source content discovery; preserve these incidents despite a combined command exit0. Runtime/fixture/Sol repairs0; inherited Astra2/2 remains exhausted. See JSON for inherited counters.

All own commands have finished; no runtime processes were started. No protected artifacts accessed. Only these two assigned /tmp report files were written. No product decision is required; actual qualification remains for the next authorized stage.
