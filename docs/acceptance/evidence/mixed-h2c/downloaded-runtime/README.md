# Downloaded 0.7.0 standalone runtime

The exact verified GitHub archive, SHA-256
`b85128c90dd319563398dd6ab58c32fc32574d34fc27f84e6a9ae18210126283`,
was extracted into fresh audit directories without changing its files.
Both attempts bind the archive and publication receipt to release source
`14287f30b83ccec207ffc944867413043cb8f360`. All seven smoke/fixture helper
source files were checked against that immutable Git commit before execution.

The first attempt remains **FAIL**: `version` returned `gaoxy 0.7.0`, but
Erlang could not start because NixOS's default library path lacked
`libtinfo.so.6`. Gateway/H3 checks in that attempt were **NOT RUN**.
`tools/runtime-loader-diagnosis.json` records a successful direct BEAM `-V`
probe with existing host libraries supplied explicitly. No library, package,
release archive or system configuration was installed or changed.

The fresh final attempt is **PASS**: four commands exited zero, including
version, core TCP/TLS/UDP (3 transports), gateway (7 exchanges, including 5
mixed-port exchanges), and H3 compatibility (3 checks). It used the existing
NixOS nix-ld host libraries and the explicit `LD_LIBRARY_PATH` retained in
`final/verification.json`. This proves execution in that stated environment;
it does not certify a stock NixOS loader setup or another operating system.
The release workflow's Ubuntu artifact execution remains separate evidence.

From the worktree root, the final command was:

```sh
LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib:/nix/store/2iaawa9vbqas51lgpn4cjnnfdv74x8fn-ncurses-6.6/lib \
python3 .audit/mixed-h2c/publication/verify-runtime.py \
  --publication .audit/mixed-h2c/publication/run-1792563923297863898/verification.json
```

Exact audit helper copies live under `tools/`; reproduction requires the
original `.audit/mixed-h2c/publication/` placement. The final helper adds only
recording of selected loader environment variables compared with the initial
copy. Receipts/logs remain immutable; deterministic gzip preserves raw log
bytes. Extracted binaries and ephemeral TLS fixtures stay audit-only.
