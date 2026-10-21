# Release identity and Nix runtime precheck

Task: unified-listeners-embedded-gateway/core_lifecycle/release-identity-precheck.
Assignment: direct, read-only. Status: DONE for this precheck.
Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway`.
Initial HEAD was `2539b3c400231c079eda7ad60f1c343101227eca`; parent advanced it during inspection. Actual full identity comparison used current HEAD `fd39888412ac5092d63d8ccbba4f1ad51b10c7cc`.

## Package identity: PASS

All **157** entries in `docs/acceptance/evidence/unified-gateway/source-inputs-final.json` match their recorded SHA256 in the current worktree, current HEAD Git blobs, and original receipt-source `d206e55de1696a8801a1cd64d80c7b903671641a` Git blobs. No observed staged or unstaged task diff intersects those inputs. The tracked final manifest exactly equals `.audit/unified-package-final/source-inputs.json`.

All five final archives retain their recorded hashes. Every archive payload file equals its staged file, and every `lib/` or `priv/` payload equals current source, including the complete source file set.

| Distribution | All payload files | Runtime payload files | Archive/staging/current runtime |
| --- | --- | --- | --- |
| gaoxy_websock_adapter | 13 | 4 | PASS |
| gaoxy | 24 | 21 | PASS |
| gaoxy_http | 48 | 45 | PASS |
| gaoxy_http3 | 13 | 10 | PASS |
| gaoxy_proxy | 45 | 42 | PASS |
| Total | 143 | 122 | PASS |

Final source-input manifest SHA256: `4fa92bbe39c3f7e8ae74d6cd1c4438bb9f74f76fcab58f074c9675cc6ea3b793`.
Final package receipt SHA256: `b3bb366428072457dea6e00f67672177be97e526f70c7619d3fa8edb2e39449f`.
The final build log also matches its receipt digest. Archive identities and detailed command outputs are in the companion JSON. Tests and acceptance/evidence documentation added by the parent do not change the verified package inputs or staged bytes.

## Process-local Nix library path

The current environment has no `LD_LIBRARY_PATH`; `NIX_LD_LIBRARY_PATH` is `/run/current-system/sw/share/nix-ld/lib`. That directory supplies zlib, libstdc++, libgcc, OpenSSL and glibc, but lacks `libtinfo.so.6` and ncurses.

The already present downloaded 0.6.0 Linux archive was used as an offline representative. Its `./erts-16.4.0.7/bin/beam.smp` requires `libtinfo.so.6`. Without extracting or executing the application, the ELF bytes were passed through an in-memory file descriptor to the local glibc loader's `--list` mode:

- Inherited environment: exit **127**, `libtinfo.so.6: cannot open shared object file: No such file or directory`.
- Explicit loader library path below: exit **0**, with all direct BEAM dependencies resolved.

```text
/nix/store/49ma9vimj6wlsbrhqsra6g6fzvsj6shh-ncurses-6.6/lib:/run/current-system/sw/share/nix-ld/lib
```

The ncurses directory contains `libtinfo.so.6`, resolving to `libncursesw.so.6.6`. Prepend this directory and retain the existing nix-ld/library entries in **both process-local `LD_LIBRARY_PATH` and `NIX_LD_LIBRARY_PATH`** for the public-runtime verifier. This covers nix-ld's initial invocation and subsequent child/dlopen library lookup. No host configuration, global environment, archive modification, or binary patching is needed for this candidate.

The local `_build/prod/rel/gaoxy/erts-16.4.0.5/bin/beam.smp` has Nix-store interpreter and RUNPATH entries, including ncurses. Therefore its earlier successful runtime evidence does not establish that a downloaded conventional Linux release works with the current inherited environment.

## Public runtime verifier review

`.audit/unified-public-runtime.py` currently only copies the environment and sets scheduler flags. All three smoke commands inherit that copied environment, so the process-local library overrides can be added by its owner in one place. This review did not modify it.

The verifier accepts prior `verification.json` PASS and records the actual downloaded archive hash/source; its caller's asset verification must establish their mapping. It enforces child exit status and finite outer timeouts; its `expected_checks` fields are metadata, while each smoke script owns its actual assertions. The core, Gateway and H3 commands target the extracted release explicitly.

**Actual downloaded 0.8.0 ELF checks and startup are NOT RUN.** The offline representative proves the available library path resolves its BEAM dependencies; it does not qualify a future 0.8.0 asset, its NIFs/dlopen dependencies, or its runtime behavior. Those remain publication closeout checks after the actual asset is available.

## Commands and preservation

Only scoped Git reads, Python hashing/tar inspection, ELF inspection and loader `--list` were used. No remote request/download, extraction to disk, build, root Mix, release/application startup, publication, or source/verifier edit. An initial shell glob found no nix-ld libtinfo entry; Python directory inspection confirmed the missing file and the available ncurses path. The optional `file` utility was unavailable; `readelf` supplied the actual ELF evidence instead.

Only `.audit/unified-release-identity-precheck.json` and `.md` were written. Concurrent parent/test/docs/audit changes and untracked `deps` were preserved. All owned commands completed; no active sessions. Sol repair increment 0; Astra increment 0; parent counters unchanged. No decisions needed for identity; the owner must apply and validate the process-local environment before actual downloaded-runtime qualification.
