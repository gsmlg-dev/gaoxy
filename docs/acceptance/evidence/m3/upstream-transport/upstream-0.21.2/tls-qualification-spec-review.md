# TLS registration qualification specification review

Task `m3_tls_qualification_spec_review`; direct independent Sol review.
Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `81b01bd3334fe4c90a739e1eebdee8bd29bf94f8`.
Only this report and its [JSON receipt](tls-qualification-spec-review.json) are
owned. Parent and peer changes are preserved.

**Specification FAIL pending three document corrections.** The exact source
oracle H1=3/H2=4 is supported. Implementation must wait for the corrected plan
and machine inventory to pass re-review. No runtime, VM, Mix, formatter, network,
dependency or Git mutation was executed; parent runtime evidence is outside this
review.

Reviewed complete [plan](../../../../../plans/m3-tls-tracking-qualification.md)
SHA-256 `9480b26726e4c7388fc5c1320346bd69861ed68d48d8220b5a7ae1ae47d96a3c`,
and [inventory](tls-registration-inventory.json)
SHA-256 `dff06052afd1fca7f5cff2d7d52601b83188c53742ad3024719e941512f30fd0`.
All29 declared inventory hashes match. JSON freezes49 inspected inputs.

## Required corrections

1. **TLS-SPEC-01 / P1: H1 negotiated ALPN contradicts the specified client.**
   Plan lines93–98 and156 require `http/1.1`, but pinned
   `http_runtime/lib/http/runtime/dialer.ex:390–395` chooses explicit H1 with
   `alpn_protocols: []`. `put_alpn/2` at450 leaves SSL options unchanged for
   that list, and `Policy.@tls_options` excludes a caller ALPN override.
   Therefore the owned peer sees Python `None` / JSON `null`, not negotiated
   `http/1.1`. Require exactly absent ALPN for H1 with forced H1 framing,
   retaining verified TLS and resources3; retain exact negotiated h2 for H2.
   Specify the adapter's inherited protocol discriminator as `h1` after TLS
   context construction and before ready/commands: inherited `finish_hold`
   branches on `self.protocol == "h1"`, otherwise it accesses H2 state.
   No dependency API expansion is needed.

2. **TLS-SPEC-02 / P1: the isolated RED reconstruction lacks an executable
   dependency and code-origin recipe.** Plan lines252–260 correctly prohibit
   mixing cohorts, but leave the new consumer layout, full dependency closure,
   build/path/config control and pinned Nix entry unspecified. The34 copied
   old BEAMs are selected disk artifacts, not a complete runnable cohort.
   The196 verified shipped old files cover all seven package sources. Their
   only additional non-OTP runtime dependency is telemetry **1.4.2**, established
   by the preserved lock line22 and actual `telemetry.app.src`; the parent's
   suggested1.4.1 would violate the original dependency identity.

   Specify a root-only consumer with separate copies of all seven complete old
   packages and exact telemetry1.4.2, root path overrides for this finite closure,
   dependency compilation environment `:prod`, unique build/deps directories,
   byte-identical package manifests, no parent source/build symlink, no old BEAM
   reuse and no dependency resolution/substitution. Copy/freeze telemetry's
   Erlang sources, header, `telemetry.app.src`, build manifests and exact `.hex`.
   Root `MIX_ENV=test` does not require Fetch/SSL test-only dependencies when
   these remain normal dependency projects in their default production env.

   Select the original pinned Gaoxy flake explicitly while the command CWD is
   the consumer; the new consumer has no specified `flake.nix`. Control ambient
   Erlang/Mix/code/deps/build paths and config. Freshly compile the whole closure
   and freeze source maps/roots, compile inputs, `.app` versions/module lists,
   every resolved cohort/telemetry module path, disk hashes and loaded identity.
   Run one fresh VM per cohort with unchanged driver/helpers/peer/OTP profile;
   check parent inputs before/after. Missing inputs remain BLOCKED_ENV.

   `HTTPFetch.Application` needs no custom config in its source default startup.
   Explicit application startup must include its declared dependencies;
   `HTTPRuntime.Application` supplies the managed supervisor/pools. Include the
   same actual OTP closure (`kernel`, `stdlib`, Elixir/logger, crypto/asn1/
   public_key/ssl and any actual transitive applications), frozen peer Python/
   h2/hpack/hyperframe/ssl/OpenSSL and guarded helper. Gaoxy and Abyss are not
   required by this minimal HTTP closure. Freeze or exclude ambient application
   config rather than importing an unrelated parent umbrella.

3. **TLS-SPEC-03 / P2: the stated snapshot budget omits retired-A checks.**
   Plan lines199–205 derive680 calls from two inventory cases with3 windows,
   two isolation cases with5 windows, and one failure case with1 window.
   Both isolation rows at158–159 additionally require public A retired snapshots;
   those calls are outside the listed windows. Specify two bounded single calls
   after confirmed retirement, yielding maximum682, or add two40-call terminal
   windows, yielding760. Synchronize plan and JSON. Count diagnostic/cleanup
   snapshots too; retain the finite limit and original deadlines.

## Supported source premises and limits

- OTP's frozen seven-field `sslsocket` record and `tls_socket.socket/6`
  constructor support the eight-element form. Candidate `track_tls/2` registers
  raw TCP once and distinct receiver/sender PIDs. H2 additionally registers its
  persistent connection owner: H1=1+2=3, H2=1+2+1=4.
- TCP-first registration and scope dedup prevent a double port count. Request
  handoff removes request monitors while scope monitors retain identity and the
  original connector token. H1 checkout restores request TLS registration;
  H2 reuse retains its persistent owner. Pools/supervisor and creator have
  separate child/creator monitors, not scope resource entries.
- Joined request producer, exact ACK/EOF, original completion `:ok` and stable
  public active/preparing/pending zero are required reconciliation barriers.
  Completion may precede tracker DOWN; neither a body nor merely positive or
  zero aggregate resources substitutes for these conditions. Public totals do
  not expose individual resource kinds, so the claim remains source-bound.
- Matching resource DOWN removes scope entries. Slot pruning requires done,
  no socket, empty dials and no remaining resource with the original token.
  Settled retirement requires empty ingress/resources/children/slots; confirmed
  public await additionally waits for coordinator death.
- Explicit empty trust is accepted and overrides system trust. Candidate failed
  setup marks sticky uncertainty and closes TCP; exact unknown_ca is a legal
  planned assertion, not an executed fact. Unconfirmed completion/retirement
  never establishes untracked TLS-process termination. Unsupported tracked
  representations remain source-only; there is no documented public injection.
- Case/request absolute deadlines, finite request/connection admission,
  at most10 counted helper starts,128 control lines, two custodians/producers,
  separate primary/cleanup failures and result+DOWN joins are suitable structural
  constraints. The implementation must enforce them; none has run here.
- Old0.21.1 recognizes only the three-element TLS form. The same source-bound
  oracle predicts H1 observed1 and H2 observed2 against unchanged expected3/4.
  A qualifying RED must still execute both complete/reused bodies, exact original
  completions, idle-close zero barriers and confirmed joined teardown. A compile,
  setup, timeout, peer or cleanup failure is not the requested RED.

## Static evidence and handoff

Fresh standard-library Python hash/receipt checks exit0:49 reviewed inputs,
29/29 inventory hashes,429 preserved source copies,34 preserved BEAM hashes,
196 preserved old shipped hashes, zero hash mismatches. Read-only source/Git
checks bind the assigned baseline, source predicates and telemetry1.4.2.
Normal absent guessed application-file lookups were corrected to discovered
`http_fetch.ex`/`http_runtime.ex`; no edit or implementation repair resulted.

Review completed; **specification FAIL**, candidate/baseline runtime NOT RUN.
TLS lifecycle, bytes, arbitrary-history accounting and complete P0–P6 remain
unqualified; activation remains disabled. No product decision is required.
Parent should repair only the plan/inventory, preserve finding IDs, then request
re-review. This reviewer made no plan/source repair: inherited Sol rounds0,
unsuccessful0, received Astra0, consumed0; `astra_gate: none`.
All own commands finished synchronously; no background process/VM/peer started.
Ownership of these two reports is released on completion.
