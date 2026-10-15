# Task E4 additive live-gap tests — independent SPEC draft review

**PASS draft source only:18/18 checks; no actionable findings.** Four executable cases (two templates × two actual upstream protocols). Runtime, format and compile NOT RUN.

Draft `/tmp/gaoxy-group-live-gap-tests1.exs` SHA `a5a4c666bbf084680a01cc187afc41490e5e809a0e346be4690b374543c65735` authenticates against author receipt. All18 source hashes match author handoff. Intended destination `apps/gaoxy_proxy/test/managed_h2_group_live_gap_test.exs`.

- **GL1 PASS:** Both templates execute for :http2 and :h2c with actual internal activation :ok, yielding4 additive test cases without bypass or production/shared-fixture changes.
- **GL2 PASS:** G.fixture applies real max_pins4. Existing sibling has3 actual T pins; new pump source adds fourth; supported public delegate_request_pin requires fifth and reserve_derived_pin returns exact {:error,{:capacity,:pins}} before monitor/pin mutation.
- **GL3 PASS:** First :sys barrier freezes actual T delegation before mutation; captured tuple original handle/source holder/manifest/instance/operation/deadline are checked. Selected Session is then read while T is blocked; Session is awaiting asynchronous handoff, not a T call.
- **GL4 PASS:** Second barrier freezes actual guardian receipt of matching real handoff ref and actual capacity error after T release. All subsequent reads inspect G/T/gate/Service, never blocked guardian. No fake owner reply or state replacement.
- **GL5 PASS:** Failed handoff explicitly asserts original group selection, genuine Service token, nil original_request/request/Tselection/pins before open. It does not fabricate a completion for work that never opened.
- **GL6 PASS:** While genuine failure receipt is held: G inflight2 and exact original sibling hold, failed selection completion nil, actual T tokens exact sibling original, pins4, full2x16478862 Service reserve and own original cleanup token. No upstream request for failed work or replay.
- **GL7 PASS:** After releasing receipt: real503, actual guardian normal DOWN, exact surviving sibling G/T holds, pins3, full1xreserve and failed cleanup token absent. Same sibling original remains pending, then returns actual healthy200/body and original completion confirms before clean/join.
- **GL8 PASS:** Partial write uses native H2 initial stream window1 before request, peer sends one actual "pq" DATA delivery, then wire assertion observes exact prefix "p" with END_STREAM clear. Native connection source uses min(write bytes, stream credit), so remainder cannot complete absent explicit added credit.
- **GL9 PASS:** The original G token, T token/hold, Session request and opaque completion are captured and compared exactly while delivery remains pending. Both actual Service cleanup token reserves and full2xreserve remain held, with G inflight2/Ttokens2/pins5.
- **GL10 PASS:** No ACK before reset; actual client sends wire RST_STREAM8 after physical prefix. Native receive/discard replies error:closed to pending write and kills stream worker, making remainder fail through real downstream path.
- **GL11 PASS:** After real reset: original completion confirms and guardian joins; no ACK for partial delivery; only exact sibling G/T hold remains, full sibling Service reserve remains and failed original token absent. No DATA/HEADERS/CONTINUATION success on failed stream during bounded post-reset observation.
- **GL12 PASS:** Concurrent sibling uses same actual upstream connection and different stream. It remains pending through failure/refund, then returns exact healthy body, genuine chunk/delivery/stream ref, exactly one ACK and original completion. Further original/sibling duplicate ACKs and extra upstream requests refused.
- **GL13 PASS:** Shared G.clean/G.close require real G/T/Service cleanup and physical peer/actor joins; tests do not silently dispose uncertainty. Barrier on_exit releases only owned barrier waiters.
- **GL14 PASS:** Barrier waits have explicit5s bound and actual caller monitor. Frame readers enforce finite monotonic deadline and max16384 frame; committed header block max65536; there is no :infinity. Clamped :gen_tcp.recv timeout0 is immediate timeout, not an infinite wait.
- **GL15 PASS:** Helpers consume only control frames around expected head/DATA; committed head forbids END_STREAM, partial observation exact prefix, and postfailure helper rejects DATA or response-header frames for failed stream. Fresh sibling socket has independent normal downstream credit.
- **GL16 PASS:** Author receipt draft SHA authenticates and every listed current source hash matches author handoff; source-only review does not substitute for formatting/compile/runtime.
- **GL17 PASS:** SPEC-LIVE-001 and SPEC-LIVE-002 have concrete executable source coverage in the draft. Runtime closure remains pending root integration, independent CODE review and fresh nonzero executed tests.
- **GL18 PASS:** Original assertions and earlier files remain untouched by this additive draft; no inherited failing gate or negative cleanup uncertainty reclassified. No new private proof or dismissed dependency requirement.

SPEC-LIVE-001 (genuine failed selected-group handoff) and SPEC-LIVE-002 (partial downstream write then failure) are covered by executable draft assertions. Both remain runtime-pending; this is not live/full SPEC or stage acceptance.

Repository unchanged; no formatter/build/runtime/Git/index actions. Only these two /tmp reports written. All reviewer commands finished; no reviewer process remains. Reviewer Sol repair0, author repair0, inherited Astra2/2 exhausted; parent cumulative counters preserved.

Root-reported fresh owner24/0 is separate runtime evidence, not certified here. Original owner FAIL24/1 cause remains UNPROVED.
