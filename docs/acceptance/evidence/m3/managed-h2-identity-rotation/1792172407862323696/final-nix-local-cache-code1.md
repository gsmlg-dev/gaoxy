# Signed local-cache dependent CODE1

**PASS_SOURCE_TOOLING; findings none.** This is static source tooling approval only, not actual transfer, signature/content verification, shell readiness or protocol acceptance.

Plan2 `18b7c996258e3b7c7b8b2e3e30521892ebf0d365c22f3b96790035ccb745de5f`, SPEC2 `a64df6a982a2f6965202fb97dd12095c486ecbc01f3bc7ecfb94d88fb393f3f6`, manifest1 `c0863863f89bdfd6d9a552e897d70839826dfaef480a895e94b9bef0032bb808` and helper2 `e151f146260677e59b6c86523911aaa7da2c6f6a2d7b378f83be11e77575b9d5` match frozen inputs. Original18 metadata/FileHash conversions,147external refs, totals and native target order match; none of18 narinfos is CA.

- **frozen_dependent_inputs — PASS**: SPEC2 is PASS/findings[] on exact plan2/helper2/manifest1. All8 plan input hashes match; tmp helper and archive are byte-identical; collector and both flake hashes match. Prior SPEC1 FAIL/helper1 remain retained.

- **exact18_signed_metadata_provenance — PASS**: All18 entries equal original frozen investigation narinfo text/hash/StorePath/URL/Compression/FileHash/FileSize/NarHash/NarSize and installed-Nix converted FileHash hex. Original Sig and References bytes are preserved; cache-info matches official51byte hash.147external refs and dependency order match;18distinct object URLs prevent worker collision. No CA fields occur in these18 narinfos.

- **validation_and_filesystem_scope — PASS**: Helper28-58 requires pinned manifest, unique store paths, <=18entries, total<=1288490188, each<=400000000, zstd URL grammar, exact metadata fields/signature presence, free compressed-total+1GiB, deadline not expired and exclusive new nonsymlink /tmp child. It creates0700 cache/nar and writes original metadata via exclusive file creation. Frozen exact manifest contains18 and maximum318767911-byte object.

- **real_full_response_and_file_integrity — PASS**: Helper75-106 passes bounded argv list to curl, no shell. Each max-time<=840 and remaining work budget, connect30, HTTPS-only/protocol redirect, <=3redirects, max-filesize exact, retry0. Requires actual exit0/nonforced and exact HTTP200/size_download, regular nonsymlink .part exact stat FileSize, SHA256 of every1MiB chunk and matching pinned FileHash hex. Full986177930 compressed bytes are required across18; metadata sizes are not runtime completion.

- **partial_publication — PASS**: Helper107-111 requires absent final name and live work deadline before rename; verifies deadline again after rename before row PASS. Partial .part files remain unpublished on ordinary failure and are not deleted. A publication crossing deadline can leave a complete failed-evidence file but cannot pass row/aggregate. Native preconditions require revalidation of every file/metadata and preparation receipt.

- **worker_and_curl_custody — PASS_SOURCE_ONLY**: Executor max_workers4 joins all futures at context exit. communicate obtains actual child returncode; timeout marks forced before kill then bounded5s communicate. Row PASS requires joined/nonforced/actualexit0. Any exception preserves FAIL and cannot enter aggregate PASS. Outer unchanged collector starts its own process group, is a subreaper, owns bounded TERM/KILL/waits and descendant raw statuses/remaining; nonjoined/forced/residue is FAIL. No normal/failure runtime path was executed by reviewer.

- **corrected_work_deadline — PASS_SOURCE_ONLY**: Helper21 starts monotonic1680s work deadline at main entry; validation/queued transfer admission/hash chunks/hash completion/publication checks and119-121 aggregate elapsed<=1680 gate cover intended work. communicate cleanup may extend beyond work deadline but is not accepted work;1800s collector plus unchanged bounded cleanup retains terminal custody. Old3600/host120/peer180/diagnostic600/finalbrowser600/readiness600 are unchanged.

- **native_gate_and_dependency_trust — PASS_CONDITIONAL_PLAN**: Plan requires actual old5204 terminal/join/no owned residue/no relevant competition, exact input/411source and full-file revalidation, individual147external refs all registered valid, individual18target refresh, enough target NarSize+1GiB disk and unchanged public client require-sigs/key. Client observation is not daemon proof. In-set dependencies are included in exact18 native copy set; already-valid targets are separately reported and never counted as newly copied.

- **native_argv_and_postverify — PASS_SOURCE_PLAN**: Exact collector300s native copy --no-recursive --from file:///tmp/gaoxy-h2-identity-nix-closure-cache1 targets equal frozen18dependency order. No no-check-sigs/trusted=true/require-sigs=false/source rebuild/custom import/settings mutation. Exact collector300s native store verify --sigs-needed1 covers same18 with contents enabled. None of18 is CA, so signature verification does not use CA shortcut. Actual signatures/registration/contents remain NOT RUN.

- **failure_readiness_stage_boundaries — PASS**: Any metadata/partial/hash/timeout/forced/ref/signature/copy/contents/custody failure remains FAIL/BLOCKED_ENV; no retry/normalization. Old materialization already PASS skips preparation; all18already-valid skips copy but retains verify/readiness. Original600s exact-version readiness and separately reviewed missing derivation handling precede diagnostic2.0protocoltests, final browser FAIL/UNKNOWN/group NOT RUN, no stage/publication/deployment acceptance and Sol5/Astra2of2 exhausted remain explicit.

No helper import/execution, Nix invocation, download, tests/build/store/browser/Git/repo writes or411 implementation re-review/rehash. AST parse only; all reviewer commands finished. Only assigned /tmp reports written.

Root must establish actual preparation conditions, rebind inputs/files, preserve original setup terminal/forced/custody outcome, recheck all147 external refs and18target registrations, keep native signature checks and actual verify1, then original600s exact-version readiness before diagnostic2. Existing final browser FAIL/UNKNOWN/group NOT RUN and broader acceptance remain open.

Counters39/root194/orchestration113/tool45/environmentfailedSPEC1/helperrepair1; fixtureSol5/production0/Astra2-of-2 exhausted preserved. No reviewer repair. Reports freeze on SHA handoff.
