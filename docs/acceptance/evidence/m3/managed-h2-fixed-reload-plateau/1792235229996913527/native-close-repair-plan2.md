# Fixed reload native H2 close-boundary repair

This supersedes native-close-repair-plan1.md for the active correction only.
Candidate2 remains NOT RUN. Its independent source SPEC2 is FAIL with one
P1 finding: waiting up to5s immediately after active source return can run
inside the unchanged2s retirement hold. Preserve the report, candidate2,
adoption1 and original first94/4 FAIL receipt without retrospective edits.

Root adopts private reload_close_native(f,socket,captured) in the additive block.
For nativeH2 only, existing F.eventually requires the actual native process to
have ended before calling inherited close_native. The original native monitor
is untouched and must still report normal; all inherited actor assertions remain.
For H1, the wrapper immediately delegates to unchanged close_native. Replace
only the two additive close callsites and restore both original return calls.
Thus active order is original return, capacity/no-delta transaction, unconditional
prefix release/continue, original retirement/helper/custodian/physical joins,
then native worker wait and socket close. There is no new multi-second wait
inside the2s hold. Seed return also precedes its native wait/socket close.

Keep all8profiles,22CAS/20samples, all numeric bytes, protocol/order assertions,
old prefix, production/dependencies/browser, caps,5s waits,2s hold,60s outer,
120s embedding and180s peers unchanged. A killed/crashed worker still fails
original normal monitor assertion. No synthetic monitor or timeout enlargement.

Record bounded source correction as successorSol7/fixture7/production0;
fixed-plateau fixture adoptions2, failedGREEN1 and failedsourceSPEC1 are separate.
Astra2/2 remains exhausted. Independent source SPEC3 then CODE2 must pass before
root executes the same unused fixed-plateau-first-scoped2 full two-file command.
Fresh full implementation review and final gates remain required afterward.
