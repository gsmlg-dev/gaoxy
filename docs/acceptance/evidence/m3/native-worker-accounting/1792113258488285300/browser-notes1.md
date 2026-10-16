# E5 native-worker browser source proposals

Task: native_worker_browser_fixtures. Direct source-only assignment. DONE for the
source proposal; syntax/compile/format/runtime/browser/network qualification is
NOT RUN. Repository R=/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation,
parent baseline 58307a7084298db309a93697b9102b2cc4c87eda. Root owns integration,
all processes, constructor SPEC/CODE, fresh pure gates and eventual execution.
This worker wrote only the four assigned /tmp files and ran read-only source/hash
commands. No repository write, Git, application/build/test/browser/network command.

Adopt these proposals under the canonical E5 evidence root as:

* /tmp/gaoxy-native-worker-browser-host-proposal1.exs -> native-worker-browser-host1.exs
* /tmp/gaoxy-native-worker-browser-runner-proposal1.py -> native-worker-browser-runner1.py

Host SHA256 1a5585e8e4aea33beddb59ea430737a05397ce90016989bc3c693c8317d3a28d

Runner SHA256 bdc115c83a33baaf88d3ae8e9e5d8e6b1c55861b67d9fec91b4522a10bbd1440

Canonical Task5 source:
docs/plans/m3-native-worker-startup-accounting.md,
SHA256 99e96bae648aaf82a595f37eeb21b91eb63c6dd690925d9e0bcc28825f7d69c2.
E4 predecessor host SHA256 a0f0931fa3bc05091d1df103b31726ed964bd1efd0ed897085f0b338c844762e;
runner2 SHA256 929c5a16f20900d61b73ea3ca719f553440f5f317e214d004bb46f83992b3c90.

The runner performs two completely joined cases sequentially: actual Chrome TLS
H2 first, then native H1 on the same immutable repository source. Each case owns
its own independent raw-H1 peer process, Mix host, Chrome/profile and log readers.
H2 uses the existing canonical network-test max_bytes 536870912 for default H2
connection reserve; H1 retains E4 max_bytes 67108864. These are fixture service
limits, not production Service/group/startup constants or new accounting ceilings.

Only scripts/generate-fixtures.sh issues ephemeral TEST certificates. The private
key lives in TemporaryDirectory, never an evidence artifact. Chrome's fresh
profile gets only that test certificate SPKI allowlist; there is no general
certificate-error bypass. The host independently reads real negotiated ALPN h2
from the actual native socket and checks secure state. Chrome must report exact
response.protocol h2 plus TLS securityDetails for the HTTPS document; the H1 case
must report http/1.1. Both preserve /checked, status200, exact predecessor title
and visible marker text, document URL and viewport PNG screenshot. DOM dimensions
and visibility are asserted, not only textContent. Browser/version/CDP events
and stderr remain artifacts. No h2c inference can satisfy this fixture.

Independent arithmetic is evidence-only NativeWorkerBrowserArithmetic embedded
in the host. It refactors the 95 raw complete actual-constructor expectations
from /tmp/gaoxy-native-worker-accounting-test-proposal1.exs (SHA256
0e74b92bde9ef75dcdaf9775a7e9c36f202e9afea2fff31e8926301a806dc144).
It instantiates raw terms and uses complete default external_size, adjusts only
specifically newly generated refs to E(node())+27, and keeps all original operand
refs/terms intact. It independently iterates A/J/N/W from zero to a whole
post-fixed point, returns every row cap/count/subtotal, and never calls production
WorkerAccounting.reservation/describe/sum as its expectation. It uses the original
native owner PID, not the host self(), and the actual captured native-worker PID.
Deprecated Tuple.append is absent; numeric summary closure uses insert_at.

At the H2 capture barrier exchange.transport_state gives actual owner/id/token.
sys.get_state(owner) gives {socket,state}; the exact stream must have real captured
worker, same token/lease/request/original D and startup:nil. Child Admission
correlation must be running with original owner/parentlease, cleared from/secret,
and neither terminal flag. The independent N must equal exchange.protocol_bytes,
independent W must equal retained bytes before B, and W=N+2*head_bytes. Predecessor
independent B equation remains unchanged, with retained=W at H2 and original
H1 retained computation at H1. Calling ManagedGenerationAccounting.reservation
only cross-checks the independently computed B; it never supplies expected B.

The Gate exact identity set at H2 capture is three distinct ordinary leases:
native connection lease with independently computed existing C, separate lease
owned by the actual writer PID with independent R, and actual native-worker lease
with W+B. Exact public active3/cleanup0/bytes=C+R+W+B must match, including the
public service status observed BEFORE each genuine G7/T8 owner acquisition effect.
There is no overlapping/unrelated sum or inferred custody migration. H1 keeps its
one ordinary native lease and predecessor independent B check.

Both genuine original public G7/T8 receipts and complete field counts are checked.
A raw peer barrier waits after complete GET parsing and before sending ANY reply.
This retains a deterministic live Session/pin interval: a traced real derived T8
receipt is checked against the actual transport ledger's derived:true/source_ref/
native acquirer and exact selected handle. A Gate sys debug hook observes the real
Service attach_cleanup call; its guardian/token/native original lease/bytes/D
must match the current cleanup record. This avoids querying a possibly blocking
Session callback or guessing private public-pin fields. Public T8 has eight
fields; derived/source_ref belong to its actual internal owner hold.

Only after session_custody is reported does the runner release the complete peer
response. Existing peer policy stays strict: complete headers/request grammar,
exact HEAD /health + GET /checked, complete sendall response; only a reset on an
empty idle connection AFTER a completed response is accepted. Partial request,
response-send failure, unexpected request, actor deadline or force cleanup fails.

After browser completion the fixture requires original request pins/token/helper
release and actual normal Session DOWN, cleanup0. H2 additionally joins actual
native worker normally and observes its lease gone, exactly the original two
connection/writer PID leases, active2 and bytes=C+R. Browser close must be normal
exit0 with profile removal. Then actual native connection/writer normal DOWN and
Gate/service active0/bytes0/cleanup0 are required. Store/group/transports, stdin
helper, host, raw peer workers/control, Chrome and actor log readers must join;
every owned process group must disappear. Forced fallback is cleanup only and
sets FAIL; it cannot qualify a case. Disposal attempts every actor even if one
cleanup fails. Ephemeral cert directory must also disappear.

Source inventory covers apps/config/root mix/lock/fixture scripts/generate script.
Before/after actual source/object-code/loaded MD5 bindings are preserved from E4;
the new host/Captured/arithmetic script modules add their own source/loaded MD5
identity rows. Global source inventory must remain equal across BOTH cases.

Source snapshot read during proposal finalization (root may still format/edit;
this is NOT a frozen constructor receipt):

* worker_accounting.ex 3ee7f96df0c1394d25354280f77bba71ae59defd6fd252702f1847fcf58b78a7
* connection.ex 586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52
* stream.ex 2276f9bfb14053ff853a13b564397ba82e5ad685a1451619dde89e398980a581
* admission.ex 81c96e55e56d514f4bd93cecb7af906a55279927d3f100f7b2045181f1eaf107
* worker_bootstrap.ex e24ec80af091bef950964dedd5a2dcc61cc35dcc71e5e8bc99f77de9cd303236

Required root work: review/format/adopt fixture source only; bind the independent
95-row helper against the actual frozen calculator constructors and all source
changes; pass actual constructor SPEC then CODE and fresh pure gate before any W
runtime. Reopen that checkpoint if any charged constructor changes. Fixture
syntax/compile/runtime remains unexecuted. Chrome making an extra connection will
correctly fail the exact lease set rather than silently summing it; diagnose from
actual evidence. No precise source blocker or new product decision was found.

All own commands finished. No actor was launched. This source-only task adds zero
runtime attempts/repair rounds and preserves inherited counters (entry
group30/root35/Astra2of2); parent concurrent execution counters remain parent-owned.
No publication/deployment/production/certificates/Vault/public management or
disabled release-artifact E2E restriction is expanded.
