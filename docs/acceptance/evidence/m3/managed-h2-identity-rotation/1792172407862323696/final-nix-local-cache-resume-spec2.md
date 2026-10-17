# Resume plan2/helper2 independent SPEC2: FAIL

Task `h2_identity_full_spec_nix_local_cache_resume_spec2`; status `BLOCKED_SPEC` (review complete). Read-only direct reviewer assignment in `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; inherited baseline `8f6b884524d81d8defa7c5081230b8ab635e8107`. No Git inspection or repository mutation was authorized or performed.

## Finding: SPEC2-BYTE-RECEIPT

`/tmp/gaoxy-nix-closure-resume2.py:124-141` uses `text=True`. `communicate()` can decode an invalid named-header byte before line132 records actual child exit/join and before lines133-134 record stdout length/hash. Its broad catch at164-165 then reports FAIL with unknown exit/unjoined state and no promised byte receipt, although the child has already been waited for. This violates plan2's explicit hash/length-only invalid-value rejection and actual lifecycle receipt contract. Text-mode newline normalization also precedes re-encoding for the claimed byte receipt.

This is a static source counterexample, not an observed transfer or server failure. The installed curl seam states that named header values preserve network contents except surrounding whitespace/newline trimming. Installed Python subprocess source waits at2180, joins bytes at2185-2189, then decodes at2193-2199 through `_translate_newlines` at1098-1100. Source SHA256: `594fa015cacada89eecd4f13a48664b17eb61dbb7eab77c851ef12f486beff91`.

Required narrow repair: binary stdout/stderr capture; record actual exit/join/forced and original stdout byte length/SHA before strict ASCII grammar parsing. Invalid stdout retains only raw-byte length/hash and fails. Parent directs stderr raw-byte length/hash plus UTF-8 backslashreplace display. Preserve all existing deadline, integrity, source-custody and retention guards. Parent accepted this finding and owns helper3/plan3 preparation; helper2/archive remain unchanged.

## Preserved and verified

- Plan2 SHA256: `a3f79e0e8b1f4ff0d51a69028667bca709fe9ada8f1b9b806bb78dcd4dba49c6`.
- Helper2 and archive SHA256: `0152c743903f12af0dc85cfe56eaa5b9385ccf1820fe8c03e3223a2fed1d94f5`; identical bytes.
- All named plan inputs and flake hashes match; all411 implementation pins match with0 mismatches.
- CODE1 raw-header-file finding is resolved in helper2 source: no `--dump-header` or persistent `.response-headers`; only three named fields are projected and grammar checked before stdout retention.
- Exact offsets,206/range/size/encoding/full-file integrity, old-cache immutability, exclusive cache2, two workers, no retry/fresh fallback,1680s work deadline and1800s collector remain. Native exact18/no-recursive copy and trusted signature/content verification remain separate300s gates;600s shell readiness is separate.

No candidate execution/import, tests, curl/network, Nix/store, browser/protocol, old-cache byte reads or protected-file reads. All source/hash commands completed exit0. An initial existence-only check exited2 because these new report paths did not exist. Only the two assigned `/tmp` reports were written; all reviewer commands are complete with no owned live process.

Frozen supplement43 remains root200/orchestration117/tooling48; environment helper repairs2; prior environment recovery failed SPEC1/CODE1; file preparation failure1/curl failures2. Protocol Sol5/production0/runtime failedGREEN7/Astra2of2 unchanged; no counter reset, reviewer increment or third Astra. Parent records this new environment/tooling SPEC failure and repair.

Identity remains NOT_ACCEPTED; fixed browser FAIL/UNKNOWN, group browser NOT_RUN, plateau NOT_STARTED. Candidate runtime/full-object/native/readiness acceptance remains NOT RUN. No publication/deployment/production/Vault/certificates/public-management/account/E2E change. No new product decision is needed: freeze repaired helper3/plan3, then fresh independent SPEC and dependent CODE.
