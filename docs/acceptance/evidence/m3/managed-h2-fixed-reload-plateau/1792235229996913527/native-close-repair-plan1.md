# Fixed reload native H2 return ordering repair

Status: diagnostic source plan; repaired execution NOT RUN.

The immutable first qualification `fixed-plateau-first-scoped1.json` is FAIL:
94 actual tests, four failures, exit2, zero skipped/excluded/warnings. All four
new nativeH2 profiles fail the original normal native monitor assertion;
three exact expected monitor identities visibly exited `:killed`, while the
fourth exact terminal reason is absent from ExUnit truncated mailbox output.
All four nativeH1 profiles emitted finished ledgers. This does not make the
failed qualification pass. Preserve the complete first log and failure audit.

The additive reload helper sends the captured endpoint return and immediately
calls inherited close_native, which closes the client socket before awaiting
native DOWN. Endpoint return is asynchronous. NativeH2 stream work still must
return through checked Generation source release and Stream completion. Peer
closure can reach H2 connection close while the stream worker remains registered;
that production close intentionally kills outstanding workers. The fixture
introduced the race by requesting normal retirement while closing its parent
connection first. A stale monitor is excluded for the three exact killed receipts.

Recommended bounded correction: add private reload_return_endpoint(f,captured)
in the new additive block. Send the inherited return unchanged. Only for nativeH2,
use existing F.eventually with its unchanged five-second deadline to require the
actual native process is no longer alive before socket close. Do not consume or
rewrite the original monitor message. Use this helper at the two additive reload
return sites. Keep inherited close_native unchanged: it must still verify the exact
original monitor DOWN reason normal for H2, and its original connection actors.
A killed/crashed worker cannot pass that original normal assertion. H1 continues
to return and then close the socket with original peer_closed expectations.

No production/dependency/browser/prefix edit, deadline/cap increase, dropped
profile/reload/sample/byte assertion, arbitrary sleep, synthetic receipt or monitor
replacement is proposed. This is the first fixed-plateau fixture repair; cumulative
successor Sol6/fixture6/production0 will be recorded only upon adoption. Astra2/2
is exhausted and no extra Astra recovery is requested.

Root adopts exact proposal bytes, records old/new hashes and a fresh399-source
union plus immutable second command names. Independent SPEC then CODE must pass
before root reruns the complete same unfiltered two-file qualification. Only an
actual successful full run with all eight complete ledgers permits full implementation
review and the separate fresh final gates. The failed first receipt remains immutable.
