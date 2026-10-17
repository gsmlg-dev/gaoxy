# Cold-close bounded SPEC2

**PASS**, no findings. Direct independent bounded SPEC only, not implementation or CODE. Runtime acceptance remains NOT RUN.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, HEAD `8f6b884524d81d8defa7c5081230b8ab635e8107`. Frozen candidate `2132111b113cf00c7464293da6b711e6fce5d0cacdb4d13029eaf1315a76fab4`, group `69cf2ae42df3a3d2a25e4281c0bede8b065eb2bd8aea91f709b86b75c7de0986`, browser `8e785b529004167a1cd13302d541c87c53554cb33e4ad175e6e8e5b85eed99e0`, proposal `de16a02e52d64836ea8daa1ff1f38a3c68e9db00b80e3b290c217c5a59f08bd1` all match. All444 mapping entries match: cold3+group427(402+2+12+6+2+3)+browser14. All12 scalar links and three live/snapshot equalities match. Counts are mapping entries, not unique files.

Only peer changes against previously reviewed candidates: SHA `b6dfb66cb0e84a1525bd8bafe437a2d161273eeb862fbc92522eaabb916f26b5` → `74fd98974e3e584d38d88883d569c70559ea8cc1cfd179ed1b1806cfd0aad04e`; five unique literal replacements reconstruct exact adopted bytes,11insertions/1deletion. All tests, runners/hosts/cohorts, production, lock, documents and other frozen sources remain unchanged.

Peer210/258/386/408–421: `write_closed` is independent of `eof`, publishes true only after successful actual base SHUT_WR under the same existing RLock, before ACK. Sole completed `/health` and no-pending requirement and actual preflush remain. Shutdown/send/flush failures before transition propagate.

Peer260–262/360–365/388–389: after transition new requests fail before automatic application response creation, and per-connection commands fail before mutation. Since pending application output was forbidden and preflushed before transition, closed-side flush only drains unsendable control output via public `data_to_send()` and does not claim delivery. It cannot silently accept further application work. Unexpected events/protocol exceptions remain errors.

Peer251–257/309–317/419/426–451: original actual TLS reader, empty recv, SSL/reset classification, generic failure, finally-close and stop/forced/live/failed accounting remain unchanged; exact read/error/stop text comparisons pass. No catchBrokenPipe, retry, failure-to-EOF conversion, synthetic physical event, private SSL state, stopping/eof flag update or reader close is introduced. Actual recv BrokenPipe would still fail.

Hash continuity preserves original health completions/normal Probe DOWN/zero accounting, exact GOAWAY+halfclose ACK followed by real exact physical-close assertions and5000ms gates; fresh conn2/TLS and A reuse, standard4/warmed request_at/Arithmetic, original resource/source/custodian joins, native95/caps/counts/deadlines and browser health_closed ordering unchanged. Same complete group/fixed/defining-endpoint runtime argv and exact browser2fixed+2group rows remain required.

Historical group-green2 actual144/2, exit2 remains FAIL; safe receipt/log hashes match. Existing classification records joined/no-force/no-residue. The safe log lacks Python traceback: the missing write guard is source-supported, but no exact instruction or control frame is proven to be the previous failure. This PASS does not establish repair success.

Reviewer runtime/syntax/import/format/compile/tests/fixtures/browser/network: NOT RUN; tests0. No actual read errors, command failures or truncated outputs this review. All own commands finished, no background sessions, repository mutations, prohibited reads or old-report changes. Only this Markdown and assigned JSON were written. Cumulative Sol3/Astra2/2 unchanged; reviewer repair0. Dependent CODE and actual root-owned group-green3/startup/four browser rows/refreshed full-stage gates remain pending.
