# HTTP consumer local Git transport recovery

The original Core consumer passed 1/0 within 533.602 seconds and needs no
recovery. The original HTTP command exited 1 after 308.664 seconds with zero
tests: GitHub Thousand Island fetch failed with curl56 unexpected TLS EOF,
early EOF and invalid index-pack output. Its immutable receipt remains FAIL;
this is an external transport failure, not a failed product assertion.

Rerun only the unchanged HTTP consumer script under its original600-second
deadline, using per-command supported Git configuration to redirect only the
canonical Thousand Island HTTPS URL to the verified local locked Git object
store. The script creates fresh temporary source/deps/build, copies the root
lock, runs deps.get --check-locked and compiles/tests with warnings as errors.
No prebuilt BEAM reuse, source/test/lock/cache edit, global/repository/account
setting change, new permissions or product dependency workaround is involved.
This local gate does not prove public GitHub fetch health or hosted CI.

Freeze candidate2, independently review SPEC then CODE, and have root check
source401, public input hashes, canonical origin/HEAD/locked commit/tree,
object connectivity and URL expansion before execution. Reject inherited
nonempty GIT_CONFIG_COUNT rather than silently overwriting it. Repeat the
source/cache checks afterward. Require nonzero executed tests, zero failures,
skips, exclusions and warnings, actual exit0 and nonforced joined groups.
Preserve all original raw child statuses and failure evidence. Core and the
unused candidate1 recovery commands are not rerun. Astra remains2/2.
