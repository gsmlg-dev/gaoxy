# Managed H2 group queued-terminal control acceptance

Status: DESIGN1 ADOPTED; readiness, tests-first behavioral RED, implementation, initial GREEN, FULL SPEC/CODE, fresh gates and local commit NOT RUN. Predecessor startup catalog DONE locally at `b30bdb0dcbdd3bc33b3b8e06a6f691e3584e42f1`.

Scope: existing-handler dispatch for one queued terminal event at BOTH Session group open/bind continuations. No activation/reserve/owner authority change; ACCOUNTING_NOT_READY/fixed9444956, all inherited counters/Astra2/2 remain. Test results/actual evidence will be recorded after execution; no future PASS is assumed.
