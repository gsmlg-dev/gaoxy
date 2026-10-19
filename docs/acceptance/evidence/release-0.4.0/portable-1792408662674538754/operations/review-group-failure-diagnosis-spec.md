# Group failure diagnostic SPEC review — PASS

Source `9253b787b57b768682bb4d894f25ca82919c0a94`. This verdict covers static diagnosis and bounded diagnostic scope only. The third portable qualification remains FAIL: 24 ordinary network tests executed, two H2-to-group cases returned503 on their first target.

`HTTP2.Connection` copies boolean/map WebSocket metadata into every `Exchange.limits`; strict managed-group accounting permits only13/14 numeric HTTP fields. This is a definite schema incompatibility, but confirming the observed rejection branch requires the parent-owned diagnostic.

The existing `managed_h2_group_endpoint_test.exs:21` selector generates exactly four approved positive cases: two H1 controls and two H2 failures. Keep assertions, fixture budgets/deadlines, pins, cleanup and original results unchanged. Exclude later upload/early-final, exceptional, pressure and soak cases. Diagnostic instrumentation stays in an ignored disposable builder layer and emits bounded reason/limit-key/type information only.

Prefer normalizing ordinary HTTP Exchange limits at construction over widening the strict proxy schema. Preserve actual WebSocket limits: the successful H2 WebSocket worker consumes `final.limits.websocket_limits`. No repair is reviewed or authorized by this receipt; final repair direction awaits runtime diagnosis.

Validation: static source/spec/fixture/log review only. No Git, build/test/runtime/browser/network commands. All reviewer commands finished. Reviewer repair0; inherited release Sol2 and Astra2/2 unchanged. Harness/instrument CODE review and actual parent diagnostic remain pending.
