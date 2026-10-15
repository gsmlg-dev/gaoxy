# Native Generation constructor premises1

**DONE — SELECTED_ETF_CONSTRUCTOR_PREMISES_SOURCE_QUALIFIED.** Direct read-only prerequisite investigation, task `native_generation_constructor_premises`. The chosen default-ETF PID/reference inequalities are supported by the current OTP28.5.0.7 source and package provenance. No constructor repair or invented constant is required for this narrow C2 sub-premise. This does not qualify runtime B, actual pre-effect acquisition, native worker transfer, H2 Generation or protocol acceptance. Real public G/T boundary tests and all other runtime prerequisites remain separate.

R=`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline `48a71a70acbe9cb46f99b82e4062c6f5f25d9667`. At inspection start only root-owned worksheet evidence was untracked; all source/others' edits preserved. Author owns only this MD and companion JSON. Parent owns runtime/evidence/Git; another author owns pure worksheet tests. No implementation proposal or repository edit was made.

## Exact selected encoder/package identity

Parent's actual `/tmp/gaoxy-native-generation-toolchain-probe1.json` records OTP28, ERTS16.4.0.6, Elixir1.18.5 and loaded gen/gen_server from:

`/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang/lib/stdlib-7.3.0.3/ebin/`.

The installed Elixir wrapper `/nix/store/jc6g5l4a2qg89s3mng0p18r9dbijc28d-elixir-1.18.5/bin/elixir:20–26` prepends this exact OTP package's bin. Installed `releases/28/OTP_VERSION` is28.5.0.7. The earlier historical5y0714 package is not used as the current source identity. Parent's nodeETF16/pidETF29/refETF35 are corroborating examples only; none supplies a maximum.

Read-only `nix-store --query --deriver` binds installed output to `/nix/store/ckl72c9yq125214w0zdglh7cr5jycz9r-erlang-28.5.0.7.drv` (SHA256 `ffb0d6d1fdf5007be6b3d30510d6188391f7051d8b4d602c65a81a0cb8cadf02`). Its declared `patches` is empty; its only postPatch substitutes a shell path in `lib/os_mon/src/disksup.erl`, with no emulator changes. Source derivation `/nix/store/cwjiivr6af90pwh0hjhw9kggjkv5yr3p-source.drv` (SHA256 `fb39d06fc0f9ce063681fa8ecb2ba90ad7c810730fa56fd99ce619a1b90f78ad`) declares official OTP tag archive and fixed recursive NAR hash:

```
https://github.com/erlang/otp/archive/refs/tags/OTP-28.5.0.7.tar.gz
sha256-1XnZspWzU8gCaeJz6kFMonrY51EKL4r/6jBI6UdNu0g=
```

Installed emulator C sources and source output `/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source` are absent. No Nix build/realization/download mutation was attempted. Read-only official GitHub tag API resolves annotated tag object `ab11826977abf66742e25aadd5a1b5f434dac1f0` to immutable commit **`09fb046150ab94104e03ee816b95c8b7e6b04683`**. Public source below was fetched by immutable commit, SHA256-bound and read only in memory. Installed gen.erl/gen_server.erl bytes independently equal that immutable upstream commit exactly. This is source/package provenance, not a rebuilt emulator/binary reproducibility proof; full source NAR was not materialized or recomputed. No such broader proof is required by this assignment.

All public line references below use base:

`https://github.com/erlang/otp/blob/09fb046150ab94104e03ee816b95c8b7e6b04683/`

Companion JSON includes immutable raw URLs, exact bytes/hash/line counts and line-numbered evidence excerpts for each file.

## P1: default external_size/1 encoding has the required node syntax

`erts/emulator/beam/external.c:2216–2228` implements external_size/1 through `erts_encode_ext_size`. Lines740–751 call the size walker with `TERM_TO_BINARY_DFLAGS` and add one VERSION_MAGIC byte. `dist.h:135–137` defines these default flags as NEW_FLOATS|UTF8_ATOMS; no DFLAG_LOCAL_EXT, ETS_COMPRESSED or atom cache is selected. The same node atom therefore uses the same body syntax when encoded independently or inside a PID/ref; only its standalone version byte is removed inside the enclosing term.

The proof concerns the exact standalone default `:erlang.external_size/1` used by the worksheet. Do not substitute compressed, distribution-header atom-cache, ETS/local formats or assume all term_to_binary option sets have identical size.

## P2: default PID size equals node ETF+13

`external.c:5361–5377` returns `1+nlen+4+4+4` for BOTH internal and external PID body sizes. Default flags use actual node atom size, not the ETS/local NIL shortcut. Encoder lines2986–3048 corroborate NEW_PID_EXT plus32-bit ID/serial/creation for both PID kinds. Public external-term documentation `erts/doc/guides/erl_ext_dist.md:431–458` states that all PIDs, including old imported PID_EXT, are encoded with NEW_PID_EXT from OTP23 onward.

Let N=E(node(pid)) include its standalone version. Node body length=N−1, so:

```
E(pid) = 1(version)+1(tag)+(N−1)+4(ID)+4(serial)+4(creation)
       = N+13
```

This applies to an external owner PID measured by the selected receiving OTP too. No new local-owner-only restriction is needed.

## P3: actual native ordinary and alias references use no more than five words

`erl_term.h:747–754` defines ordinary references as3 32-bit numbers; PID references as3+2 onARCH64,3+1 onARCH32, maximum5. `erl_node_container_utils.h:261–263` chooses exactly PID_REF_NUMBERS versus REF_NUMBERS for an internal reference, so this is not a heap-word-size guess.

`erl_bif_unique.c:821–832` implements native make_ref/0 via the ordinary reference buffer. `erl_bif_unique.h:189–199` writes exactly ref[0],ref[1],ref[2]. Thus make_ref used by Store operations and G/T public refs has3 ID words.

For public aliases, `bif.c:5849–5889` calls `erts_make_pid_ref` at5878. That function (`erl_bif_unique.c:149–168`) allocates PID-reference layout and writes it. For the actual GenServer path, installed/source-identical `lib/stdlib/src/gen.erl:251–267` invokes `erlang:monitor(process,Process,[{alias,demonitor}])`; `bif.c:985–998` parses monitor options and lines767–769 select `erts_make_pid_ref` when alias flags are present. Hence the actual finite GenServer alias reference uses at most5 words, not an arbitrary-sized reference guessed from a sample.

`external.c:4750–4753` also rejects imported NEWER/NEW_REFERENCE terms with ref_words>ERTS_MAX_REF_NUMBERS=5 BEFORE local/foreign node branching. `erts/doc/guides/erl_ext_dist.md:585–614` documents Len<=5. Foreign ref receipt therefore does not introduce an unbounded ID array on this receiving encoder. Existing source provider authenticity/node correlation is still required; this does not authenticate arbitrary callback output.

## P4: exact reference formula and selected conservative cap

`external.c:5494–5509` calculates native reference body size as `1+2+nlen+4+4*i`. Encoder3651–3676 writes NEWER_REFERENCE_EXT,16-bit count, node,32-bit creation and exactly i32-bit numbers. Documentation585–614 corroborates this wire constructor.

```
E(ref) = 1(version)+1(tag)+2(len)+(E(node(ref))−1)+4(creation)+4*i
       = E(node(ref))+7+4*i
       <= E(node(ref))+27     because i<=5
```

For the actual ordinary make_ref branch i=3 gives node+19; keep the existing conservative node+27 envelope so one formula also pays GenServer aliases. No tightening or new constant is needed.

For a creator PID bounded by existing S=2,048:

```
E(node(creator)) = E(creator)−13 <= 2,035
E(new native ref from that node) <= 2,035+27 = 2,062
```

The future ref is not fabricated to compute this bound. The inequalities follow from the original creator PID and exact source constructors. The selected accepted pin grammar still separately requires referenceETF<=2,048; genuine future ref output that exceeded that accepted grammar would first fit its paid raw-output R role and then reject. Do not relabel Rf2,062 as an accepted scalar cap change.

This conclusion must rebind on selected encoder/source drift. It does not certify unsupported native extensions that manufacture private terms or arbitrary callback heap. Public current OTP imported references are covered by the decoder cap above.

## P5: map fields and exact acquisition provenance for genuine G/T pins

Source files are current baseline source, not a projection/mock:

* Resources28–43 groups complete validated handles by original `{provider,owner}`, creates operation=make_ref at36 BEFORE callback39, passes original holder/kind/operation/deadline. Future checked seam still must keep original provenance and precheck composition; current source does not do that.
* G `record`875–882 authenticates handle.owner==self(), handle.owner_epoch==state.epoch and exact recorded handle. Pin dispatch541–563 checks these records. `add_h1_pin`892–920 and `add_h2_pin`1376–1387 construct exactly seven public keys: provider,owner,owner_epoch,ref,operation,handles,kind. The new ref is make_ref on the owner itself, owner is self(), epoch is the same authenticated state epoch, operation/handles/kind are unchanged original arguments. Holder/acquirer/keys/monitor/timer remain owner-internal record fields, not extra public pin fields. G-H2 validates singleton1399 after constructing it; G-H1 has no Q singleton check.
* T `pin_many`108–127 validates holder/kind/operation and forwards original args; `handle_batch`852–878 bounds complete handles byH65,536/raw count64 and selected owner. `record`1357–1368 authenticates owner=self(), epoch=state.epoch and resource existence; pinnable880 onward uses it. `acquire_pins`901–945 constructs exactly eight public keys: G's seven plus original holder. New ref=make_ref on the same owner, operation/handles/kind/holder are unchanged. Its idempotent branch907–912 returns only the existing public pin whose original handles,holder,kind match, under the same original operation/acquirer lookup. No singleton Q check exists for normal T pin success.

Thus new pin.ref and public pin.owner share a source node; E(owner)<=S bounds its future ref byRf. Epoch<=S follows from the original selected authenticated batch handle. Original operation is a Store-native fresh ref; E(Store)<=S supplies the sameRf bound. Holder<=S is separately original requester context. G does not expose a holder field; future request correlation must require kind=:request and T.holder===actual original requester, not make up G.holder.

For complete map-size algebra `Map(pairs)=6+sum(keyE+valueE−2)` and actual complete handle batch E<=H:

```
G keys = provider owner owner_epoch ref operation handles kind
G values: E(G), S, S, Rf, Rf, H, E(:request)
R_G = 73,862

T adds key :holder and value S; actual provider atom is T
R_T = 75,921
```

These are conservative complete-constructor upper bounds, not claims all independent limits are jointly attainable. The source default atom-size formula `external.c:5326–5356` supplies exact ASCII atom headers for these actual module/key/kind atoms; independent Python field/syntax arithmetic matches the reviewed P2 values without constructing fake PID/ref terms or launching a BEAM.

Complete singleton/list and `{:ok,pin}` add6 under the selected current ASCII atom encoding; maximum alias Reply adds2,075 beyond the result. Therefore:

| Constructor | G bound | T bound |
| --- | ---: | ---: |
| complete public pin |73,862|75,921|
| complete singleton [pin] |73,868|75,927|
| complete {:ok,pin} payload |73,868|75,927|
| complete {alias_tag,{:ok,pin}} |75,943|78,002|

The genuine H1-G/T output larger than acceptedQ65,536 stays in this paid role and rejects before accumulator cons. It is not an arbitrary/malicious callback carveout. G-H2's post-construction Q gate permits smaller success but does not erase its constructed raw pin/singleton role. This investigation does not execute real owner boundary tests or change those constructors.

## Exact identities and evidence limits

| Immutable source | SHA256 |
| --- | --- |
| `erts/emulator/beam/external.c` | `149d2e94426e611f4b4028a5fca4f6fcfd0c77f1d56ec9ae405c01410b0e736d` |
| `erts/emulator/beam/erl_term.h` | `1b9d8b240ca04583fdf876baf77d9578cb4c3e91b89e8de434e29b783d240264` |
| `erts/emulator/beam/erl_node_container_utils.h` | `a7f0c4c49a3043042f4cd4c644f3d1ae6b70d9e49daf3a76e82d4509f0b3692d` |
| `erts/emulator/beam/erl_bif_unique.c` | `f1c178c2233b84705dc3f321763da0758c36cf85e9700cf02146f1b41c4eeb33` |
| `erts/emulator/beam/erl_bif_unique.h` | `2cd8cb50c5fde120f4d7319afcc3258ba2f06df0a6b4e79ba30f38cf6155f66d` |
| `erts/emulator/beam/bif.c` | `cb401cb0e18d0587bbf971f2e9f7a77d84f66ea0edb0133793a5433d8091d29a` |
| `erts/emulator/beam/dist.h` | `07645e06e2f2067a202e3934ca80d9ab634c68cea3950708bb5fcf1542441451` |
| `erts/doc/guides/erl_ext_dist.md` | `b5f4cccea8d0c667f451822f1302d5be28e8a9ec9110563fa0f0719299d7366e` |
| `lib/stdlib/src/gen.erl` | `b828697b055865df24aad48ec4cd7f23821fa54a7aa2baa0408a444a5d0d04be` |
| `lib/stdlib/src/gen_server.erl` | `66a4a649c8ed58f3c9ed317047f28ea2e2a61b38032cc467565fbad2c53a09db` |

| Current repository source | SHA256 |
| --- | --- |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex` | `b0330019d771b9f58f6f15eba555cd77ec0ce0fcf2843bd9e19619d65b2ae2c7` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex` | `f6f638d1f1f88b53c8282dc121466eb0614d241fe8ec56cc57a8a2a8b0d4096e` |
| `apps/gaoxy_http/lib/gaoxy/http/resources.ex` | `0e58a4f0badd2ba6d21b9f118c5b3f6c4d1070b4371e76e9dfc0656796f0907b` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex` | `933b07a056d3a80baa6ce9ff9df1c84d7b4fc24c49dde1770d16f8855a6ee92f` |

Installed/source-identical gen.erl SHA256b828697b055865df24aad48ec4cd7f23821fa54a7aa2baa0408a444a5d0d04be and gen_server.erl66a4a649c8ed58f3c9ed317047f28ea2e2a61b38032cc467565fbad2c53a09db tie the actual loaded package to the public source version. Companion JSON includes all evidence excerpts, provenance, arithmetic and per-premise source verdicts.

Remaining minimal autonomous action: parent archives these reports/source excerpts and obtains independent source review, then performs actual public G/T boundary tests in the separately released bounded runtime stage. No constructor implementation change or new constant is required for these selected ETF premises. Full C2 public receipt qualification remains NOT RUN here, and C1/C3/C4/C5 remain gated. Nothing here adopts a conditional B in Admission or enables native worker/H2 behavior.

Commands: only source/hash/Git read inspection, nix-store query/nix derivation show (no builds/evaluation/realization), official public HTTP GETs into memory, and source-derived Python integer arithmetic. No runtime/Elixir/mix/Nix develop/build/tests/formatter/Git mutation, issue creation or messages to external people. Initial guessed public filenames404 and absent installed source searches were corrected to actual immutable files; these were read-only lookup corrections, not runtime failedGREEN. No private dependency client internals, total-memory proof or dismissed97 work.

Status DONE for assigned investigation. This task runtime attempts0/Sol repairs0; inherited group failedGREEN24/root events27/Astra2of2 exhausted unchanged. All own commands completed; no background/runtime process started or touched. Only assigned MD/JSON written, no repository changes. No user decision or new external permission needed. Package provenance is trusted as the recorded immutable Nix derivation; no complete NAR recomputation or binary reproduction is claimed.
