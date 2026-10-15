# Browser stopped group-status encoding repair — design and plan

The actual repaired browser4 ran normal navigation, complete real Service byte
checks, three original completions, clean and a real successful Chrome join.
It then joined FAIL exit1/zero completed cases because stopped JSON encoding
received {:error,:stale_group}. The preceding Service terminal observer is
fenced and records actual empty leases/cleanups/zero bytes; final group state
is not inferred from this failed emission.

The group_snapshot helper already reads actual raw owner ledgers independently
of Groups.status. Preserve valid public status maps and every raw ledger field;
serialize specifically stale_group as %{public_result: inspect(error)}. All
other public replies remain fail closed. Do not substitute zero, OWNER_DOWN,
cleanup success or arbitrary default evidence. Change no production, observer,
cleanup/fence order, caps, deadlines or canonical assertion.

1. Authenticate failed browser4 receipt/log/artifacts and source identity.
2. Independently SPEC/CODE review the exact proposed HOST-only patch and
   assert all197 other candidate sources/canonical browser remain unchanged.
3. Adopt exact patch and append ledger23 failed GREEN attempts/26 ordered
   root repair events, preserving all predecessors and Astra2/2 exhaustion.
4. Freeze source, explicitly retain original candidate3 command25 as reused
   unchanged-production/test evidence (1752 invocations, not rerun), then run
   the unchanged complete real Chrome/CDP three-case suite and all original
   completion/Service/G/T/negative/peer/physical-join assertions.
5. Diagnose actual failures, never downgrade them. After passing, synchronize
   final documentation, independent evidence/rebind closure and local source/
   index/commit custody. No publication/deployment or third Astra recovery.
