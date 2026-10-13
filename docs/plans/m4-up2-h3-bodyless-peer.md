# M4 UP2 repair8 independent bodyless peer

Root owns `integration/http3/upstream/peer.py`, README and this design/plan, plus
all serial executions. Reviewers own only unique new receipts; preserve other
writers and freeze apps/integration during every recorded execution.

1. Preserve [repair7 FAIL47](../acceptance/evidence/m4/upstream-matrix/matrix-1791850003746638515/result.json)
   and [actual HEAD termination FAIL47](../acceptance/evidence/m4/upstream-matrix/matrix-1791850200066394763/result.json).
   Counters are live15, failed production5 and failed harness2. Independently
   review [the bounded peer design](../designs/m4-up2-h3-bodyless-peer.md).
2. Add only selected H3 HEAD/304 raw response parsing using the established
   independent codec/QUIC pattern. Preserve standard decoding for other rows,
   all original assertions/deadlines and actual FIN. Assert exact HEAD/304 length7
   metadata and204 length absence. Bound raw carry/frame bytes and reject partial
   FIN, dynamic QPACK and any bodyless DATA frame. Record the parser profile.
3. Check Python syntax, exact-file format and strict compilation; run affected
   H2/H1/H3/proxy tests. Resolve independent CODE/evidence findings before live.
   This harness correction has actual prior diagnostic FAILs; no production
   behavior or default limit changes are planned.
4. Run complete66+2 UP2 with `GAOXY_UP2_REPAIR=8 GAOXY_UP2_FAILED=15`. Retain any
   failure and diagnose without a third Astra recovery. After full PASS require
   independent actual-evidence review and a fresh full repeat, then the prescribed
   final M4 gates and conditional publication. Never reset counters.
