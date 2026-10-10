# H1 loaded-artifact identity checkpoint

This bounded P2/P3 identity investigation is part of Task3's existing
[qualification plan](../../../../../plans/m3-upstream-transport.md) and
[accounting design](h1-accounting-architecture.md). It changes no production
code. Worktree `.trees/m3-gateway`, branch `codex/m3-gateway`, baseline
`6ef8a3ad8e26e2f4992adeaf9558199aef8105a5`.

## Design and execution plan

Use one standalone Nix Elixir VM with the existing test BEAM directories on its
code path. Explicitly load a finite set of34 Elixir, HTTP, pure Gaoxy and OTP
modules. Compare each currently loaded module's public code MD5 with
`beam_lib:md5/1` for its resolved BEAM and independently hash that whole file.
Record compiler source/version/options without treating them as reconstructed
build inputs. Read and hash only this VM's `/proc/<own-pid>/exe` target; sample
runtime build/profile metadata and the public FetchOptions struct shape.

1. Recheck all429 executable input hashes against the existing immutable source
   snapshot and save the diagnostic-script identity.
2. Run the sole VM under a finite command timeout, with `ERL_FLAGS=+S 2:2`,
   without Mix, application startup, scopes, sockets or peers.
3. Require code-MD5 equality for every selected module, exact33 struct entries,
   no new HTTP/Gaoxy application, normal VM exit and unchanged source hashes.
4. Preserve any failed collector/run before a diagnostic correction. Independently
   review the receipt, reproduction material and limitations before local commit.

A passing checkpoint establishes point-in-time identities for the selected
modules and emulator only. It does not establish source-to-BEAM reproducibility,
native ABI offsets, all loaded modules, future hot-code exclusion, profile
enforcement over a scope lifetime or any complete P0-P6 obligation. TLS tracking
[#95](https://github.com/gsmlg-dev/http_fetch/issues/95) remains a separate gate.

## Executed checkpoint

[Final receipt](h1-loaded-identity.json) and [log](h1-loaded-identity.log)
record exit0 in3.176 seconds,34/34 code-MD5 matches and429 unchanged executable
input hashes. FetchOptions has33 entries including its struct key. No HTTP or
Gaoxy application was started. The VM exited; no peer or background job exists.
These are identity checks, not executed protocol tests.

The VM is Elixir1.18.5, OTP28/ERTS16.4.0.6, x86_64-pc-linux-gnu, word8,
`opt`/JIT. It reports GNU C15.3.0 and dynamic tracing `none`. Its own running
`beam.smp` is under the previously recorded Erlang28.5.0.7 installation;
SHA256 is `7d7cc767b20c28e26fe93a13d23d5daf688cbd83ed60523a5bdedd9cb6ee02e6`.
`internal_active_n` is unset in this VM. These public metadata do not certify
native offsets, emulator translation-unit definitions or later configuration.
Twenty-two recorded compile-source paths are presently readable; their hashes
are current file observations, not proof of the original compiler inputs.

The [initial run](h1-loaded-identity-initial.json) failed because CLI `-pa`
accepts one directory. Repair1 repeated the flag but then
[failed](h1-loaded-identity-repair1.json) on an incorrect match of the public
`beam_lib:md5/1` result. The pinned OTP source at
`lib/stdlib/src/beam_lib.erl:558-573` documents one `{module, digest}` tuple.
Repair2 corrected only that match and passed. Byte-exact historical logs are
saved as [initial log](h1-loaded-identity-initial.log) and
[repair1 log](h1-loaded-identity-repair1.log); the historical receipts retain
their originally generated log filename and hash. Neither failure altered
product/dependency code or the429 frozen inputs.

Counters: Sol2 diagnostic repair rounds, one unsuccessful validation, Astra0;
zero implementation repairs. The receipt embeds both the executed VM script
and collector, with their command arguments, timeout, source fingerprint and
output hashes. A reproduction must use a new evidence destination so the
historical observations remain intact. Independent review is pending.
