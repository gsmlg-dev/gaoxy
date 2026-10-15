# Browser request-clean observer emission repair — design and plan

Actual canonical browser3 joined exit1 with zero completed cases after positive
navigation and three original RequestCompletion :ok results. The request_clean
HOST event omitted admission_receipts even though wait_request_clean, the
existing finite observer fence and collect_originals had collected actual data.
The unchanged exact_reservations consumer correctly refused the missing field.

Use the existing status/observe/stop serialization convention: add the actual
state.admission_receipts field to request_clean. Change no production source,
observer/fence/cleanup order, deadline, cap or assertion. Preserve original
Service/G/T records and all failure/cleanup distinctions.

1. Authenticate original receipt/log, exact old HOST and patch hashes. Preserve
   candidate3 command25 as its actual source evidence (1752 repeated-fixture
   invocations), browser3 FAIL/zero completed and inherited counters.
2. Independently SPEC/CODE-review the exact one-line producer repair; bind all
   unchanged197 sources and unchanged canonical browser assertion bytes.
3. Freeze the repaired candidate and run the original complete Chrome/CDP
   three-case suite with actual exit, joins, original completions, actual full
   Service16,478,862/G/T ledgers, negative cleanup and source identity checks.
   No default/synthetic receipt or missing-Service-as-zero is allowed.
4. Authenticate the command-source rebind explicitly: unchanged production and
   command-test bytes justify carrying candidate3 command25, not claiming those
   commands executed the new HOST. Only the actual browser exercises the changed
   emission. Resolve failures; then synchronize final docs, independent closure
   and local source/index/commit custody. No publication/deployment.

This repair is ordered root event25; the failed browser adds failed GREEN
attempt22. These are separate from global Sol repair rounds. All preceding
ledgers and Astra2/2 exhaustion remain; no third Astra recovery.
