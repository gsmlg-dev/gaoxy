# Standalone managed-upstream recovery

The existing supervision structure remains: Registry and generation stores survive
an internal runtime/owner/coordinator restart. Each store will retain the latest
accepted declarative router alongside its resolved active router. Publication of
both routers is one CAS-checked activation; rejected/stale candidates change
neither. Recovery reads this declaration and reconstructs instance-local handles
before reopening listeners, instead of reinstalling the startup declaration.
The declaration is bounded by the existing compiled-router limits.

Managed transport and group pins are metadata in a particular owner PID/epoch;
that metadata cannot outlive that PID. Only these providers may acknowledge an
obsolete pin after a monitor confirms that its local owner incarnation terminated.
This is distinct from interpreting arbitrary `:not_running` errors as successful
cleanup. Live-owner release errors remain errors and the generation retirement
activation guard remains intact. No baseline or pending pin is discarded by the
standalone coordinator.

Transport scope cleanup remains owned by the unlinked custodian, which monitors
the transport owner and independently joins public ManagedTransport retirement
receipts after owner death. Its failure state stays resident if cleanup cannot be
confirmed. Group pins do not own sockets: group/probe/request holder death triggers
transport holder monitors and independently monitored guardians/probes finish their
cleanup. Obsolete pin acknowledgement ends only the vanished owner's metadata
obligation; it does not claim a custodian's resource cleanup succeeded. The focused
regression monitors old custodians to their successful termination and verifies
new baseline resources continue serving after another activation.

Execution: record a deterministic fixed/group pre-fix runtime red; implement atomic
declaration publication and provider-specific incarnation terminality; rerun the
regression plus existing scoped activation/rollback/live-owner cleanup tests.
No pressure, disconnect, slow-peer, soak or protocol expansion is included.
