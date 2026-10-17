# Generation monitor repair1 proposal

DONE for the direct read-only diagnosis/proposal assignment only. No runtime repair or passing gate is claimed.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Six named source hashes match the immutable failed generation1 receipt. Git baseline was not queried under this assignment's restrictions.

## Evidence and causal limit

Generation1 actually ran 184 tests with 1 failure, exited 2, was nonforced and joined, had no remaining process group, and retained stable source. Outer elapsed time: 337.39819436000107s; ExUnit: 332.5s. At group-generation line 2434, the exact selected native and monitor received `:noproc` instead of `{:shutdown, :local_closed}`.

**Initiating cause UNKNOWN.** The available log does not discriminate a stale lease PID from the correct native exiting before monitor installation. It does establish that the selected process was already absent when monitoring took effect. The test's lease snapshot neither ties that PID to the fresh socket/current operation nor holds the actor through monitor installation. Do not claim a proven product/dependency defect or assert a particular actor identity.

The native-H1 listener is shared by both upstream-protocol variants. Its synchronous `begin_request` precedes parsing and endpoint execution; the admission handler validates the actual caller against the lease holder. The source path then supports the existing empty 500/close contract for an unset error response. None of this retroactively identifies the failed PID. Status does not create a lease, and cleanup records are separate from leases.

## Minimal candidate

Review `/tmp/gaoxy-early-final-generation-monitor-repair1.diff`. It changes only the single generated group Store-death test, covering its existing h2c/http2 instances. Retain `connect(f)` and its active-count check, then install a one-shot incoming `begin_request` debug barrier before sending GET. The uniquely tagged barrier reports the real native/from/lease, excludes the held old native, and holds the synchronous call before reply. Install the monitor, release/remove the hook, and retain the exact existing response and DOWN assertions. The original code after socket close is unchanged.

Both `try/after` and `on_exit` release the gate before removing the hook. Cleanup ignores only dead-gate `noproc`/`normal` exits; timeout remains a failure. The barrier uses the existing 5000ms timeout. No sleeps, widened reason matching, timeout increase, production/API/dependency changes, or expansion into the fixed-generation test.

The hypothesis depends on the test's existing sole fresh GET and held old request. The caller's own finite call deadline remains active. An actual regression must qualify this candidate; static assembly is not repair evidence.

## Required parent validation

1. Independently review the exact candidate and unchanged ownership/effect assertions.
2. After adoption, run both generated Store-death variants with the fixed-endpoint fixture loaded; require nonzero executed tests and record exits/source/cleanup.
3. Run fresh full cohort2: first62, all nine final gates, and browser. Keep immutable generation1 FAIL evidence unchanged.

The proposal itself was checked only by bounded source/evidence reads, original-block uniqueness, in-memory diff assembly, and SHA256 matching. No product command or candidate execution was performed.

## Counters and shutdown

This worker executed zero Sol repair rounds. Parent plans Sol repair1 after adoption; Astra recovery remains 2/2 exhausted. This assignment has one earlier oversized-search tooling incident (+1), already notified and retained by parent in counter6; it is not a runtime or fixture repair. No other new incident. All commands finished, no owned running process remains, and no runtime debug hook was installed.

## Artifacts and hashes

- Candidate diff SHA256: `55f63b2b964d22f10c0380c842f761dec182e30f39e5256e1f483cabcc0f119d`
- Generation1 receipt SHA256: `72dc60ec60865eca3f711cb6fff00df15b76aa5d8bb795f7eb88839ed049325e`
- Generation1 log SHA256: `5fa3ebfa3c3edc66c44e30379f7300d2b6fb5cbfa32d30898c701717656e6b7b`
- Full source hashes and machine-readable details: `/tmp/gaoxy-early-final-generation-monitor-repair1.json`

Remaining risks: initiating identity unknown; candidate unexecuted; full acceptance remains failed/unexecuted until fresh evidence. Parent adoption/review/execution is needed; no user product decision is requested.
