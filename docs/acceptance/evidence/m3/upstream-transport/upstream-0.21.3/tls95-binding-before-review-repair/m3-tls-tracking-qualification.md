# M3 TLS registration and release qualification plan

> Implement only after an independent Sol specification review of this plan and
> its source inventory. Parent owns execution, cohort selection and runtime receipts.

**Goal:** Demonstrate the published HTTP 0.21.3 containing fix for gsmlg-dev/http_fetch#95 through
exact public idle resource inventories and their release in bounded HTTPS H1 and
ALPN H2 scenarios, with an identical-assertion RED control on 0.21.1.

**Approach:** A separate executable fixture uses opaque managed scopes, original
request completions, public snapshots/retirement receipts and an independent owned
TLS peer. Persistent custodians hold scope creator lifetimes. Frozen source derives
all resource counts; runtime observations cannot choose the expected counts.

**Stack:** Elixir/OTP28.5.0.7, HTTP 0.21.3, Python ssl/h2 independent peer.

The source inventory is
[`tls-registration-inventory.json`](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/tls-registration-inventory.json).
It contains SHA-256 identities for every source/helper/receipt read for this
specification, source branches, root/copy ownership and release predicates.
Assignment `m3_tls95_fixture_design`; direct Sol; worktree `.trees/m3-gateway`,
branch `codex/m3-gateway`, baseline `81b01bd3334fe4c90a739e1eebdee8bd29bf94f8`.
Parent/peer edits in dependency pins, lock, other plans and receipts are preserved.

The original 0.21.2 qualification receipts and failed runs remain historical.
Current 0.21.3 tooling, fixture bindings and independent re-review are recorded
separately; earlier review verdicts do not qualify changed inputs. The source
branches below retain the same exact registration oracle. Sol4/unsuccessful2/
Astra2 tooling counters are cumulative; no third Astra recovery is authorized.

## Source-derived oracle and observation barrier

Candidate commit `ceecbf2df62ca80c361597c7303f65a153f2ce3c`, tree
`6a44b862e8a09fb2648e48f928e37c20b1c8109a`. These derivations use shipped bytes
in `.audit/m3-transport/upstream-0.21.3/packages/`, not mutable installed deps.
The containing source/API review has passed; this document executes no runtime.

1. `http_core/lib/http/request_lifecycle.ex:29–58` parses exactly the restricted
   legacy tuple or OTP28 eight-element `{:sslsocket, tcp, receiver, sender,
   :gen_tcp, _, _, _}`. The frozen OTP record has seven fields; its `socket/6`
   constructor assigns distinct receiver/sender and the TCP handle. The accepted
   tuple contributes TCP as `:socket` and two PIDs as `:tls`.
2. SSL TCP-first connect registers TCP before TLS setup. TLS registration repeats
   the same port, and both tracker and scope deduplicate by resource identity.
   `Scope.resources` holds `{resource, kind, original connector token}` per monitor.
   Two references to the same port do not contribute two resources.
3. H1 checkin transfers controlling ownership to its pool and requires successful
   handoff. H2 registers one persistent `ConnectionOwner` as `:connection` and
   requires handoff of owner plus TCP/TLS before pooled admission. Handoff removes
   those request monitors; it leaves scope monitors intact. H1 checkout restores
   request TLS tracking; scope dedup preserves the first connector token.
4. For these empty GETs there is no upload/body bridge/enumerable producer. The
   request task, request owner, dial worker, response stream, and any H1 send/H2
   delivery helper are temporary tracked resources. Original completion `:ok`
   requires sealed request tracking with no remaining request resource monitors;
   exact ACK/EOF consumption lets the response stream return. Scope separately
   processes their DOWN signals. The request tracker itself is in `Scope.requests`,
   not `Scope.resources`; scope creator, H1/H2 pools and H2 supervisor are separate
   creator/children monitors, not entries in the resource total.
5. Therefore, after original completion and joined producer, two consecutive
   public snapshots with `lifecycle: :open`, `active_requests: 0`,
   `preparing_requests: 0`, `pending: 0`, `connections: 1` must have exactly
   `resources: 3` for HTTPS H1 and `resources: 4` for ALPN H2. Zero requests is
   necessary because completion may become durable before the tracker DOWN is
   reconciled. The exact total also rejects leftover temporary resource entries.

The machine inventory enumerates source roots, including pool socket wrapper,
H2 owner socket, request/scope monitor maps, connector slots, frozen policy copies
and public handle/latch copies. Policy recursively copies accepted binaries and
materializes CA input. These are ownership facts, without a byte/native quota.
A public total does not expose resource kinds: frozen source reachability and
exact totals establish the selected registration behavior, not individual PID
observations or arbitrary TLS backing bounds.

On idle peer close, the pool/owner sees closure and closes its transport. Scope
removes TCP/TLS/connection entries only on matching DOWN. Connector pruning
requires `done?`, no socket, empty dial set, and no remaining resource with the
original token (`scope.ex:239–249`). Thus a surviving tracked sender/receiver
retains the slot. Scope retirement settles only with empty ingress, resources,
children and slots; confirmed `await_retired/2` additionally requires coordinator
termination. No private PID discovery, pool entry/scope field inspection,
`:sys`, `Process.info`, substitute tracker, direct TLS suspension/kill, or direct
socket tuple injection is allowed in the new fixture.

## Owned implementation files and read-only reuse

Create only:

- `integration/http_fetch_contract/managed_tls_tracking_probe.exs`: five cases,
  public oracle, deadline-aware stream reader, bounded ownership and cleanup.
- `integration/http_fetch_contract/managed_tls_tracking_peer.py`: small verified
  TLS H1/H2 adapter of the frozen `ManagedPeer` library.

The optional peer is necessary: current `upstream_peer.py` advertises only h2,
asserts negotiated h2, and dispatches TLS to H2. Public commands suffice for H2
idle close and holds, but cannot select verified TLS H1. Import `ManagedPeer`
without invoking its `main`; retain its request/response and command semantics.
Use inherited disposable CA/certificate generation, accept receipts and joined
shutdown. Construct the inherited verified TLS context first. For
`--protocol tls_h1`, before emitting ready or accepting commands set the inherited
protocol discriminator `self.protocol = "h1"`, clear the server ALPN offer with
`context.set_alpn_protocols([])`, and force inherited H1 framing/dispatch. Explicit
managed H1 sends no ALPN advertisement (`Dialer:390–395,450`); require actual
Python `selected_alpn_protocol() is None`, encoded exactly as JSON `null`.
The `self.protocol` change also selects the H1 `finish_hold` branch. For
`--protocol tls_h2`, retain TLS/H2 dispatch and require actual negotiated `h2`.
The tiny serve adapter checks this mode-specific ALPN, emits a `tls` event with
connection and ALPN, retains normal disconnect/closed handling, and runs the inherited wire-drained barrier in
`finally`. It adds no custom client/runtime tracking or timing approximation.
`finish_hold`, `close`, `snapshot`, `wire_snapshot` and `stop` remain inherited.
Freeze the final adapter source before execution; do not edit either historical
peer. CA generation uses the existing four checked OpenSSL commands, each capped
at ten seconds. Cap emitted control/event lines at128 per case; unexpected extra
accept/request/failure is a failed assertion, not dropped evidence.

Load only `pooled_completion_probe.exs` through its existing library guard:

```elixir
old_flag = System.get_env("HTTP_FETCH_PROBE_LIBRARY")
System.put_env("HTTP_FETCH_PROBE_LIBRARY", "1")
Code.require_file("pooled_completion_probe.exs", __DIR__)
if old_flag,
  do: System.put_env("HTTP_FETCH_PROBE_LIBRARY", old_flag),
  else: System.delete_env("HTTP_FETCH_PROBE_LIBRARY")
```

Reuse `HTTPFetchPublicProbe.command/2` and `event/3`, passing remaining original
deadline to `event/3`. Use command/event directly for snapshots. Its `response`,
`consume`, `complete`, `with_peer` and `fetch` helpers renew waits or select their
own peer/pool profile; do not use them here. Do not import the auto-running body
of `managed_transport_probe.exs`, or alter any assertion in its unchanged24/39
functional cases. Restoring the library flag must use `try/after` on load failure.

Open each scope from its persistent fixture custodian with the public options:

```elixir
HTTP.ManagedTransport.open(
  origin: "https://localhost:#{peer_port}",
  connect_address: {127, 0, 0, 1},
  http_version: version, # exactly :http1 or :http2 in a separate case
  tls_backend: :ssl,
  ssl: [verify: :verify_peer, cacertfile: ca_path],
  socket_opts: [send_timeout: 2_000, send_timeout_close: true],
  max_requests: 1, max_connections: 1, max_pending: 0,
  idle_timeout: 30_000, http2_profile: :native_v1
)
```

A producer starts one `HTTP.fetch/2` with `transport_scope`, `request_mode: :proxy`,
`redirect: :manual`, `stream_response: true`, `decode_body: false`,
`timeout: remaining(request_deadline)`, `connect_timeout: 2_000`, `telemetry: false`.
Capture `HTTP.Promise.completion(promise)` immediately and record it with exact
expected terminal result before waiting. A raw GET has no upload producer.
A deadline-aware ACK reader checks status200, all exact bytes (`"ok"` or
`"abcdefgh"`), no unexpected trailers, EOF and no error. It sends only documented
read/ACK messages to the public response body, retaining no private stream state.
It never renews its6,000-ms deadline per chunk/event. Producer reports original
completion, then exits normally; its result and DOWN must both be joined. Repeat
`RequestCompletion.await(original, 0)` after quiescence with exact `:ok`.

## Event table and assertions

Each row is one named executed case and one independently recorded cleanup.
Two inventory cases run in baseline mode; all five run in candidate mode.

| Case | Required ordered public/owned events | Decisive assertions |
| --- | --- | --- |
| `tls_h1_inventory_idle_close` | verified H1 ready; GET `/one` exact `ok` and original completion; joined producer; stable idle snapshot; GET `/two` same barriers; stable idle snapshot; peer `close` connection1; `command_done` and `closed`; stable zero snapshot | resources3 before/after reuse; requests exactly `/one`,`/two`, both connection1; accept1; ALPN JSON `null` (Python `None`); zero requests/connections/resources after close; every original completion remains `:ok`; teardown retirement confirmed |
| `tls_h2_inventory_idle_close` | same sequence with explicit H2 | resources4 before/after reuse; accept1; ALPN h2; the two distinct streams use connection1; exact bodies/completions; zero after close and confirmed teardown |
| `tls_h1_retire_isolation` | A GET `/one` completes and has exact idle inventory; B independent scope GET `/hold-live` gets headers on connection2; B open/active snapshot; retire A graceful and await; A peer `closed`; B open/active snapshot; command B `finish_hold`; exact `abcdefgh` EOF/original completion and join; exact B idle snapshot; B GET `/survivor` exact `ok`/completion/join and same inventory; teardown B | A await exact `:ok`, repeated original receipt await0 `:ok`, public A snapshot retired; B stays open with active1/preparing0/pending0/connections1 while A retires; B body/completion succeeds under its original request deadline; B resources3 after completion and reuse; total accept2, B never closed before its teardown; every request unique/no replay |
| `tls_h2_retire_isolation` | same independently scoped sequence | same isolation and receipt predicates, B resources4; actual h2 on both connections; B stream remains live through A retirement, then exact body/completion and reuse |
| `tls_failed_handshake_unconfirmed` | own valid TLS peer; scope with explicit public `ssl: [verify: :verify_peer, cacerts: []]`; one GET `/untrusted`; public TLS alert failure; original completion settles unconfirmed; peer disconnect/closed; durable retire receipt; public snapshot eventually retired; repeated receipt await | accept1, request0, no successful negotiated-TLS event; exact `{:error, {:tls_alert, {:unknown_ca, message}}}` with binary/list message; completion exact `{:error, :cleanup_unconfirmed}`; receipt exact same error, also await0 after public coordinator-retired snapshot; peer joined; no claim of TLS resource DOWN/reclamation |

For a hold, inherited H1 sends initial `a` then `bcdefgh`; H2 sends only headers
until `finish_hold` sends `abcdefgh` with END_STREAM. Require public B active1
before and after A retirement. Start B only after A's idle barrier; never replace
B's original timeout after A retirement. A and B have independent custodians,
scopes and connections even when their policy identity is equal. Match connection
IDs to request events, rather than assuming pool internals.

The fifth row is source-legally deterministic: empty explicit trust overrides
system trust (`Policy.freeze_ssl` uses `put_new`), and the disposable server CA
is untrusted. Assert the structured unknown_ca alert, not any arbitrary error;
if the fixed runtime/profile cannot produce this predicate, retain its actual
failure as BLOCKED_ENV or FAIL with the exact missing premise and keep the four
registration/release cases independent. Do not substitute a fake socket or demand
successful cleanup. Unsupported tracked socket shapes remain source-only because
there is no documented managed API injection point.

## Finite producers, polling and cleanup

Each case starts its original primary deadline at ready+18,000ms and cleanup end
at that same ready time+30,000ms. Each request records its own6,000ms absolute
deadline, capped by the primary deadline. Connect wait is2,000ms; pool idle30,000ms
prevents idle-expiry substitution for commanded close. Peer ready waits45,000ms;
peer control lifetime45s begins after construction. Total wrapper timeout450s
covers five cases including worst existing certificate-generation waits.

One orchestrator owns the peer port and saved control events. At most two
custodians and two request producers are live. Short-lived helper starts are
counted and capped at10 per case, including producers: inventory needs at most5,
retirement at most9, failed-handshake at most4. Cleanup/retirement callers run in
owned monitored helpers because `retire/2` may wait its documented internal5s;
join every result and DOWN within the original case cleanup end. Custodians remain
alive until all their public completions/receipts are checked. Do not recursively
spawn snapshot workers or retry callers without consuming the finite counter.

Each public polling window allows at most40 `ManagedTransport.snapshot/2` calls,
with timeout capped at50ms and25ms interval capped by the original phase deadline.
Require two consecutive exact selected-field maps, within the same window. Retry
only a successful mismatching snapshot or exact `{:error, :cleanup_pending}`;
unexpected error is failure. Do not reset time or call count on progress. Inventory
has three windows (idle1, idle2, zero); retirement has five (A idle, B active before,
B active after, B idle after hold, B idle after reuse); handshake has one window
for exact public `{:error, :transport_scope_retired}` after settled uncertainty.
That terminal window is a coordinator-retired barrier, not a zero-resource oracle.
After each of the two confirmed A retirements, make exactly one additional
public A snapshot call capped at50ms and the remaining primary deadline. Require
`{:error, :transport_scope_retired}` immediately; no retry or polling window is
added. These two single calls were omitted from the initial budget (TLS-SPEC-03).
Candidate total is at most682 calls (`2*3*40 + 2*5*40 + 40 + 2`); baseline at most240
(`2*3*40`). Hard-code run caps682/240 and case caps120/201/40 for inventory,
retirement and handshake respectively. A single orchestrator-owned
`budgeted_snapshot` entry point increments/checks global and case counters before
every public snapshot invocation, including diagnostics and cleanup. Every polling
window separately enforces40. Diagnostics consume the same remaining caps; there
is no extra diagnostic budget or implicit snapshot in a helper. At exhausted cap,
report failure without starting another call. Single retired-A checks consume both
case/global counters and are separate from the five polling windows. Peer
commands/barriers and stored lines are bounded by the128 emitted-line cap.

Always preserve primary errors separately from cleanup results. In `after`, try
every recorded scope, original completion and owned process even if a prior cleanup
fails: retire each scope with abort, await its receipt against remaining cleanup
end, abort-and-await each original completion with its pre-recorded exact terminal
expectation, stop peer, require `stopped/live_threads0` and exit0, then stop/join
custodians and any remaining fixture helper. Record both result and DOWN, never
only a sent stop command. On exhausted deadline, terminate only owned fixture
helpers/peer through bounded owned shutdown, join them and record cleanup FAIL;
do not inspect or kill client internals. Never reinterpret an unconfirmed healthy
completion as ok. Unknown early-failure results remain explicit cleanup failures.
The failed-handshake case alone pre-registers unconfirmed expectations. No case
counts as PASS unless all its owned cleanup joins and exact expectations succeed.

## Review, RED/GREEN and evidence tasks

- [ ] Independently review this complete specification and machine oracle before
  implementation. Recompute3/4 from the pinned paths; verify temporary ownership,
  handoff/recheckout, retained token, exact pruning and durable retirement; check
  all deadlines, total helper/snapshot counts and public-only observation surface.
  Resolve actionable findings in these documents; no new user approval is needed.
- [ ] Implement the two new fixture files with the ordered event table and bounded
  failure cleanup. Add `--cases inventory` selection for the two inventory rows;
  default runs all five. Accumulate exact inventory mismatches through both GETs
  and the idle-close barrier before reporting the case FAIL, so RED still provides
  clean successful teardown. Never change expected3/4 on baseline.
- [ ] Parent freezes the exact new driver/adapter and all imported helpers, peer
  Python executable and h2/hpack/hyperframe/ssl/OpenSSL inputs, current OTP/ERTS/SSL
  executable/loaded identities and all installed shipped/compiled HTTP identities.
  Candidate loaded code must match the verified0.21.2 cohort. Preserve these
  inputs/receipts alongside actual commands, logs, counts and exits; verify hashes
  before/after each invocation. Driver imports only the guarded helper library.
- [ ] Parent formats only the new Elixir fixture, checks Python syntax without
  leaving bytecode in historical directories, and runs the reviewed driver in the
  serialized collector. A candidate GREEN requires five distinct executed cases,
  five PASS cleanups, every table assertion and exit0. Driver output is executed
  case evidence, never claimed as ExUnit tests. Zero cases is always FAIL.

  Use the parent-owned reviewed identity wrapper and sanitized absolute-flake
  recipe below for qualification. The wrapper captures pre/post
  identities inside the actual same driver VM and starts the source-default
  application closure via `Application.ensure_all_started(:http_fetch)` (including
  declared dependencies). HTTPRuntime supplies the managed supervisor/pools;
  HTTPFetch needs no custom startup configuration. Gaoxy/Abyss are not required
  by the isolated baseline closure. Parent supplies the frozen existing Python
  executable path; never select a new environment between cohorts. The collector
  owns the450s external bound.
- [ ] Parent implements and independently reviews the ignored baseline builder
  and same-VM identity wrapper before compiling or executing them. No builder or
  wrapper is implemented by this document repair. The baseline root is exactly
  `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway/.audit/m3-transport/tls95-baseline-0.21.1/`.
  It contains new `packages/`, `deps/`, `_build/`, `.mix/`, `.hex/` directories,
  `mix.exs`, an empty `mix.lock` (`%{}`), and `config/config.exs` (`import Config`).
  This new consumer has no flake; select the absolute original Gaoxy flake.

  Copy all196 verified archived shipped0.21.1 files, with identical manifests,
  from `.audit/m3-transport/upstream-0.21.1/packages/` into its new `packages/`.
  Check every copied hash against the frozen old archive receipts and
  `.audit/m3-transport/upstream-0.21.2/installed-0.21.1-freeze.json`.
  Copy only shipped source: no `.beam`, old `_build`, old `deps`, parent source
  symlink or cached build. The34 preserved BEAMs remain historical evidence and
  cannot form this runnable baseline. Never modify preserved source/receipts or
  candidate pins/lock/deps/build to select baseline code.

  The finite dependency closure is all seven packages plus exact telemetry1.4.2.
  Telemetry's historical lock outer checksum is
  `928f6495066506077862c0d1646609eed891a4326bee3126ba54b60af61febb1`;
  inner checksum is `a0cb522801dffb1c49fe6e30561badffc7b6d0e180db1300df759faa22062855`.
  Before offline construction, standing authorization permits one separately
  bounded official acquisition from
  `https://repo.hex.pm/tarballs/telemetry-1.4.2.tar`. Preserve its raw archive and
  acquisition receipt, verify both checksums and every shipped byte against the
  reviewed installed inventory, then freeze the cache. The acquisition is a
  dependency-preparation phase and never runs inside the materializer/build/VM.
  Reuse this frozen offline archive, or an already archive-verified shipped
  inventory tied to these checksums.
  Copy its entire shipped source into `packages/telemetry/`, plus the exact verified
  installed `.hex` identity. Include all `src/*.erl`, `src/telemetry.hrl`,
  `src/telemetry.app.src`, `mix.exs`, `rebar.config`, `rebar.lock` and shipped
  metadata/docs/licences. Verify1.4.2 from both historical lock and app source.
  The current `deps/telemetry` source/.hex hashes are additional frozen inputs,
  not independent archive verification. An absent cached archive or missing
  shipped-file verification blocks the offline phase. Complete the separately
  receipted official acquisition first; never fetch during construction, invoke
  a resolver, substitute1.4.1, patch a manifest or reuse compiled dependency files.

  Write this root-only consumer manifest; keep every dependency manifest untouched:

  ```elixir
  defmodule TLS95Baseline.MixProject do
    use Mix.Project
    def project do
      [app: :tls95_baseline, version: "0.0.0", elixir: "~> 1.18",
       build_path: "_build", deps_path: "deps", config_path: "config/config.exs",
       deps: deps()]
    end
    def application, do: [extra_applications: []]
    defp deps do
      for app <- [:http_core, :http_runtime, :http_fetch, :http_web_socket,
                  :elixir_quic, :elixir_quic_http3, :ex_ssl, :telemetry] do
        {app, path: Path.expand("packages/#{app}", __DIR__), override: true, env: :prod}
      end
    end
  end
  ```

  Root `MIX_ENV=test` plus explicit dependency `env: :prod` compiles library paths
  without dependency dev/test-only tools. Root path overrides resolve every edge
  in this exact eight-package closure. Require the resolved dependency set to be
  exactly that set; no `mix deps.get`, resolver, substitution, custom dependency
  patch, network acquisition or unrelated umbrella config. Compile fresh through
  `mix deps.compile`, then `mix compile --warnings-as-errors` in this isolated root
  with the sanitized pinned shell. Hash/freeze all resulting compiler manifests,
  `.app` and `.beam` files; every source origin must resolve under this consumer's
  copied packages. Its own empty `deps/` and independent `_build/` remain owned
  directories; baseline resolution to parent `deps/` or `_build/` is failure.

  Both cohort commands use a reviewed env sanitizer after entering the pinned
  absolute flake. Start with `env -i`; retain only frozen shell/runtime essentials
  (PATH, original HOME, LANG/LC_ALL and required pinned native-library path), then
  set task-specific `ERL_FLAGS=+S 2:2`, `MIX_ENV=test`, explicit own `MIX_BUILD_PATH`,
  `MIX_DEPS_PATH`, `MIX_HOME`, `HEX_HOME`, `HEX_OFFLINE=1`, frozen Python path,
  `PYTHONNOUSERSITE=1`, `PYTHONPATH=` and the exact driver path. Do not inherit
  `ERL_LIBS`, `ERL_AFLAGS`, `ELIXIR_ERL_OPTIONS`, any other Erlang/Elixir launch
  options, ambient `MIX_*`/`HEX_*` redirection, injected `-pa`/`-pz`, or Python
  startup paths. Record the exact whitelist/values and command CWD. Native-library
  allowance is only the pinned shell's frozen `LD_LIBRARY_PATH` if required;
  freeze its actual loaded-library dependencies, not an ambient substitute.

  Parent's ignored wrapper is
  `.audit/m3-transport/tls95-runtime-identity.exs`. It runs the unchanged frozen
  driver via `Code.require_file(System.fetch_env!("HTTP_FETCH_TLS95_DRIVER"))` in
  that same VM, preserving `System.argv` (`--cases inventory` for baseline,
  default five for candidate). Capture identities before and in `after`, including
  a failed RED; preserve the driver's primary error/exit and separate identity
  failure. It may inspect public module/application metadata and its own code
  origin only; this adds no private client-process inspection to the fixture.
  Freeze this wrapper and builder themselves and independently review them.

  Baseline command recipe (execute only after all offline copy/freeze/review gates):

  ```sh
  cd /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway/.audit/m3-transport/tls95-baseline-0.21.1
  nix develop --offline /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway --command bash -c '
    set -eu
    tls95_root="$PWD"
    tls95_python=/tmp/gaoxy-m3-h2-soak-venv/bin/python
    test -x "$tls95_python"
    tls95_driver=/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway/integration/http_fetch_contract/managed_tls_tracking_probe.exs
    tls95_wrapper=/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway/.audit/m3-transport/tls95-runtime-identity.exs
    env -i PATH="$PATH" HOME="$HOME" LANG=C.UTF-8 LC_ALL=C.UTF-8 \
      LD_LIBRARY_PATH="${LD_LIBRARY_PATH-}" ERL_FLAGS="+S 2:2" MIX_ENV=test \
      MIX_BUILD_PATH="$tls95_root/_build/test" MIX_DEPS_PATH="$tls95_root/deps" \
      MIX_HOME="$tls95_root/.mix" HEX_HOME="$tls95_root/.hex" HEX_OFFLINE=1 \
      PYTHONNOUSERSITE=1 PYTHONPATH= PYTHONDONTWRITEBYTECODE=1 HTTP_FETCH_PEER_PYTHON="$tls95_python" \
      HTTP_FETCH_TLS95_DRIVER="$tls95_driver" \
      HTTP_FETCH_TLS95_INPUTS=/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway/.audit/m3-transport/tls95-fixture-inputs.json \
      TLS95_COHORT_VERSION=0.21.1 TLS95_COHORT_ROOT="$tls95_root" \
      TLS95_PARENT_ROOT=/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway \
      unbuffer mix run --no-compile --no-start "$tls95_wrapper" --cases inventory'
  ```

  The Python path is the existing parent qualification peer environment recorded
  in `MANAGED_README.md` and the current parent receipts. Freeze its actual real
  executable/venv/modules/native inputs before both runs; absence or drift is
  BLOCKED_ENV, not authority to create/download a substitute. The builder invokes
  the two fresh compile
  commands through the identical sanitizer/Nix/CWD recipe, replacing only the
  final `mix run` argument. Candidate uses the same pinned shell/sanitizer/wrapper/
  driver/peer/runtime, explicit candidate root/deps/build values and default five
  cases, with one separate fresh VM per cohort. Its inherited application config
  and compile inputs are frozen explicitly; baseline config remains the minimal
  root config above. Any request-affecting config must match the reviewed fixture
  profile; otherwise qualify neither comparison.

  Before/after the actual driver VM, freeze root Mix/config/lock/build manifests,
  complete shipped/compile inputs and resolved real source roots; all seven
  `.app` versions0.21.1 (candidate0.21.2), telemetry `.app` version1.4.2, declared
  dependencies and complete module lists. For every listed cohort/telemetry module,
  ensure it is loaded from the intended freshly built tree, record `:code.which`,
  real disk path, disk SHA-256, `:beam_lib.md5` and loaded
  `module_info(:md5)`, and require loaded/disk MD5 equality. Record the compiled
  module source origin via public compile metadata and bind it to copied source
  hashes; no baseline origin may resolve to parent deps/build. Check identities
  again in `after` and freeze the disk tree after process exit; no stale/unlisted
  cohort module or code path is accepted.

  Also freeze Elixir/Mix/compiler versions, resolved Nix flake/lock/store paths,
  OTP/ERTS executable and actual transitive application/module closure (kernel,
  stdlib, Elixir/logger, crypto/asn1/public_key/ssl plus every actually required
  application), public_key/SSL OTP loaded code and native crypto/SSL/system-library
  identities. Freeze Python real executable/version, its ssl module/OpenSSL and
  extension/native dependencies, h2/hpack/hyperframe versions and loaded source
  files, OpenSSL executable/version/native libraries, and all helper/peer/driver
  bytes before/after. Preserve historical input hashes and candidate parent input
  hashes before/after consumer construction and each invocation. Missing or
  mismatching provenance/source/config/native inputs is BLOCKED_ENV or FAIL;
  it cannot be repaired by resolver/network/path leakage.

  Same OTP/peer/input/profile, same oracle3/4. Shipped0.21.1 only recognizes the
  old three-element TLS form and returns ok for OTP28's eight-element form;
  cancellable connect still tracks TCP. Predict H1 resources1 and H2 resources2,
  missing exactly two TLS registrations. Require two executed inventory cases,
  exact count failures1-vs3 and2-vs4, both complete bodies/reuse/original completions,
  idle-close zero barriers, two successful cleanup joins/confirmed retirements and
  nonzero driver exit solely for those count failures. Compilation, timeout, peer
  failure, setup error or unconfirmed teardown does not qualify as the RED control.
- [ ] Preserve historical24/39 executable bytes and all old source/receipts. Run
  the unchanged39 functional gate separately under the parent cohort plan; no
  supplemental case is inserted into that driver and24 cannot substitute for39.
  Parent records this fixture's candidate/baseline receipts separately, resolves
  failures under retained Sol repair counters, and obtains independent final code
  and evidence review before updating any current gate status or committing.

## Self-review and exact claim boundary

This specification covers registration, H1 recheckout/H2 reservation reuse,
commanded idle release, per-scope confirmed retirement with a live independent
request, conservative real handshake uncertainty and all owned cleanup. Exact
resource predicates precede zero observations; stable public barriers cover
tracker reconciliation. All source/helper inputs have hashes in the machine
receipt. No private runtime premise, sampled oracle, unlimited caller/poll loop,
renewed request deadline, silent zero-case success or unchanged-driver mutation is
required. Independent specification review remains outstanding; implementation,
compilation, candidate GREEN and baseline RED are **NOT RUN** by this assignment.
Stage specification repair1 addresses TLS-SPEC-01, TLS-SPEC-02 and TLS-SPEC-03. Original reviewed
plan SHA-256 `9480b26726e4c7388fc5c1320346bd69861ed68d48d8220b5a7ae1ae47d96a3c`
and inventory `dff06052afd1fca7f5cff2d7d52601b83188c53742ad3024719e941512f30fd0`
remain in the unchanged `tls-qualification-spec-review.md/.json` reports.
The repaired document is pending independent re-review; no original FAIL is
rewritten as PASS. The first static validation failed because this history abbreviated TLS-SPEC-02
rather than spelling out its literal ID (the inventory retained the full finding).
This second repair expands all IDs and preserves that failed check. Cumulative
Sol repair rounds2, unsuccessful static repair rounds1, Astra rounds0. Independent
re-review remains pending; all own static commands completed.

Even a GREEN with a qualified RED proves only these selected registration/release
scenarios and the stated conservative failure behavior. It does not close TLS
native/backing/active-N accounting, delayed-sender exposure across arbitrary
histories, P5, full P0–P6, managed activation, production conformance/soaks, M3 or
M4. No guessed byte constants, quota resets, dependency workaround or publication
is proposed. Independent review and the parent-owned runtime gates remain next.

## Tooling alignment after specification review

The independent repaired offline specification passed in
`tls-qualification-spec-review-repair2.md/.json`; its historical FAIL and repair
counters above remain intact. Initial builder/wrapper review then found five
finite tooling gaps (`TLS95-TOOL-01` through `TLS95-TOOL-05`). Parent tooling
repair1 separates official acquisition, validates the complete destination before
copying, uses the exact wrapper/driver/argv interface above, resolves real code
origins and checks every app-listed module, and preserves the driver's primary
error separately from post-identity failure. The input map includes all driver,
wrapper and imported peer/helper bytes. The collector binds Python/native/tool
closure and all build/source/config identities before/after each fresh VM.

This tooling alignment is pending independent review. It changes no case oracle,
ALPN expectation, deadline, cleanup predicate, count or activation gate. Initial
tooling chain: Sol repair1 in progress, unsuccessful0, Astra0, separate from
specification Sol2/unsuccessful1/Astra0 and future fixture runtime repairs.

The parent launcher diagnostic (`tls95-wrapper-format-profile.json`) verified
that `MIX_BUILD_PATH` replaces the full build directory: setting it to `_build`
returns exactly `_build`, without an environment suffix. The sanitized recipe
therefore explicitly uses `<root>/_build/test`, matching the reviewed real BEAM
origin and keeping candidate and baseline fresh-build paths separate. This is
a tooling-path correction; no fixture result is supplied by that zero-test
diagnostic. The wrapper was canonically formatted; no baseline build or driver
was executed.

The collector also sets `PYTHONDONTWRITEBYTECODE=1` so source identity collection and the peer cannot create bytecode in the frozen imported-helper directories. Candidate compiler tools use owned `.audit/m3-transport/tls95-candidate-tools/` directories; baseline uses its own `.mix`/`.hex`. Both copy and freeze only the existing Hex2.4.2 cached archive tree as a compiler tool, never a cohort BEAM or another runtime dependency.

### Tooling repair2

The independent tooling repair1 review returned FAIL with five exact findings
(`TLS95-REPAIR1-01` through `TLS95-REPAIR1-05`). Parent repair2 verifies telemetry
`.hex` against both the acquisition receipt and frozen inventory before any
copy; validates the full owned Mix/Hex destination including ancestors and empty
unlisted directories; independently attempts every post-collection and preserves
the actual command exit with separate errors; verifies actual NAR hashes against
registered hashes for the complete transitive pinned launcher/compiler store
closure, including hidden unbuffer/Tcl/Expect inputs; and exclusively creates
every evidence sidecar while rejecting any reused partial name. The cached
Hex2.4.2 compiler archive's122 files are separately frozen and checked before
copying. Immutable historical failures remain unchanged.

Tooling Sol repairs2, unsuccessful1, Astra0 at this repair's static preparation;
changed-byte independent review is pending. Specification counters and fixture
repair counters are separate. NAR/file identity still establishes no native ABI,
retained-byte formula, control release or M3 acceptance.

### Fixture repair1

Independent fixture review found three failures (`TLS95-FIXTURE-01`,
`TLS95-FIXTURE-02`, `TLS95-FIXTURE-03`). The repaired owned event handler records
late successful opens immediately using each custodian's pre-recorded expected
terminal. Cleanup first reconciles pending open and retirement registrations
against its original deadline. Retirement helpers register and receive ACK for
the original receipt before awaiting; existing cleanup retirement callers sweep
every retained original receipt for that scope, continuing after individual
failures. Cleanup PASS also requires successful helper/open results and join
checks. These phases add no helper starts: healthy inventory/retirement/handshake
totals remain5/9/4 under cap10, with all original deadlines and snapshot/oracle
assertions retained. Fixture Sol repair1/unsuccessful0/Astra0 is pending independent
changed-byte review and runtime, separate from the tooling/specification chains.
