# F3 real native service-stop test proposal1

SOURCE ONLY / NOT RUN. Ownership: only this Markdown and sibling `.exs`; no repository changes, test/runtime/browser/network/Git mutation. Root must integrate, format, review and execute. Counters40/52/10/Astra2/2 unchanged; no repair attempt consumed.

Insert sibling source into `Gaoxy.HTTP2WorkerStartupExtendedTest`, retaining all original assertions. It depends on the other author's integrated `retain_native_success3/1` and `assert_running_dispatch_wait!/2`, and existing seeded/native wire helpers. Three concrete real `Gaoxy.stop` cases start while a genuine child is committed pending activation, activated awaiting dispatch, or blocked in the endpoint.

Pending-activation hook consumes the actual queued activation and authentic service `{:drain,D}` call through public `:sys` debug, then requeues BOTH unchanged exactly once, drain first. This avoids holding the service's50ms Admission barrier while the test inspects state. It never invents a continuation/reply/deadline or calls a production handler manually. No extra production hook/API.

Dispatch-wait cancels client stream3 only AFTER actual drain transition; pending work would otherwise legitimately wait its original15s requestD and fail a3s stop budget. Endpoint-blocked test releases the existing endpoint only AFTER drain, consumes its full200 response with a separate strict GOAWAY-aware reader, then permits normal worker return. These are graceful service-stop acceptance cases; they do not claim an uncooperative endpoint can gracefully complete. No artificial timeout increase is proposed.

All cases require a genuine public Gate zero-status reply bound to the same `:sys` callback state (leases/spawns/cleanups empty,bytes0), actual service drain outcome`:completed`, actual stop`:ok`, normal stopper/instance/service/backend joins, exact native local-close/writer-normal and expected worker terminals, and joined original backend descendants. Original TCP listener/accepted ports are captured by real owner and address, must close, and original listener address must be bindable after stop. Gate disposal`:killed` is explicit normal Service implementation behavior after zero; it is never called an all-normal actor run.

Cleanup always releases the authentic continuation, removes live debug hook/detaches telemetry, closes fixture client, resumes Gate and kills only the test-owned stopper on failure; pre-existing seeded cleanup retains server ownership. Such fallback cleanup is not successful runtime evidence.

Risks for root source review: ExUnit dynamic test loop should match local `unquote(stage)` convention. GOAWAY reader intentionally leaves original responses/control helpers unchanged. Native local-close and Gate killed expected reasons are derived from current Handler/Service source and must remain strict when executed. These tests have NOT been formatted, compiled or run by author. All source reads completed synchronously.
