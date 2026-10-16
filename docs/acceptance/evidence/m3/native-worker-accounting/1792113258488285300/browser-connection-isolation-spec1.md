# Browser connection isolation SPEC1

Task: `native_worker_constructor_spec/browser_connection_isolation_spec1`

**DONE — source-only investigation. No existing exposed supported option was established that independently caps this Gaoxy listener to one live native connection while preserving Gate configuration and the exact global three-lease assertion.** No runtime/browser qualification is claimed.

## Concrete mechanism and boundary

ThousandIsland provides the required mechanism: `num_connections` is a start-time per-acceptor concurrent-handler cap (`thousand_island.ex:130–141`). Its acceptor supervisor sets `DynamicSupervisor.max_children` from that value (`acceptor_supervisor.ex:51`). On a capacity rejection, `Connection.start/5` closes the already accepted raw socket and returns `:too_many_connections` before a native handler is started (`connection.ex:71–75`); the acceptor emits `[:thousand_island, :acceptor, :spawn_error]` and continues (`acceptor.ex:60–82`). With one acceptor and cap1, excess connection attempts can still reach TCP acceptance, but cannot produce concurrent additional native handlers/leases at this rejection branch. This does not guarantee which connection Chrome uses for navigation or that navigation succeeds. Fresh complete-response and lifecycle qualification remains required.

Gaoxy's existing public configuration cannot independently select that value. `Gaoxy.HTTP` permits only its listed HTTP options and rejects unknown keys (`http.ex:4–17,31–47`). Core service validation also rejects unknown keys and has no independent listener limit (`config.ex:14–29,61,119–123`). `Service.start_backend` hardcodes `num_acceptors: 1`, `num_connections: spec.limits.max_active`, and `max_connections_retry_count: 0` (`service.ex:941–962`). The reviewed public ThousandIsland exports contain no runtime cap setter. Its public `connection_pids/1` explicitly documents concurrency races; `suspend/1` closes the listening port while retaining existing connections (`thousand_island.ex:226–255`).

The actual host3 fixture sets only `limits.max_bytes` (`native-worker-browser-host3.exs:513–518`); Gate `max_active` therefore defaults to64 (`config.ex:3–12`). **Expected global active==3 is not configured max_active==3.** Lowering Gate max_active to1 changes admission and prevents the required connection/writer/requestworker combination. One acceptor alone does not mean one concurrent connection. Suspend-after-observation races already accepted connections, and Gaoxy pause also changes Gate mode (`service.ex:204–218`). Neither establishes the required independent deterministic cap.

No installed documented Chrome option reviewed guarantees one socket per listener. The installed Chrome152 package's manpage documents stable flags but no connection-count limiter, and explicitly says undocumented flags can change. No guessed `--max-connections-per-host`, preconnect, SPDY, or feature flag is recommended. This bounded source review does not prove no other Chromium API exists. No browser, protocol endpoint, external network, or binary was executed.

## Observed accounting and lifecycle

Only the safe redacted trace's lines1–6 were read. They show target C `#PID<0.339.0>`, R `#PID<0.345.0>`, worker `#PID<0.346.0>` and extra C `#PID<0.343.0>`, R `#PID<0.344.0>`. Each C holds173039655 bytes, each R66560, worker11468110. Thus global5/357680540 is exactly target3/184574325 plus extra2/173106215. The extra actors are genuine leases, not accounting noise. Target is live with settings_ack=true, closing/draining=false and no partial frame in this safe prefix.

The accepted extra C/R must remain visible globally until authentic teardown and cleanup. Do not subtract/filter actors, arbitrarily kill extras, change expected equality, or reinterpret global3 as target-only3. A future listener cap must retain rejection telemetry/lifecycle evidence; capacity-rejected sockets at TI's max_children branch produce no native handler lease and are materially different from an admitted extra C/R pair. Preserve exact byte/actor assertions and finite authentic join gates.

Diagnostic2's extra C/R explains **this run's global3 failure**. It does **not** establish the cause of the earlier target writer normalDOWN before browser-close authorization. That cause remains **UNKNOWN**; no causal link was observed here.

## Parent decision and review limit

The minimal necessary expansion, if listener isolation is required, is a separate validated listener connection-cap configuration propagated through Gaoxy-owned backend lifecycle while preserving existing Gate limits. No implementation or API design was performed here. Direct TI fixture ownership would bypass Gaoxy server lifecycle; private supervisor or sys-state mutation is not a supported substitute. This is a Gaoxy propagation gap, not a demonstrated upstream defect: the locked `mtrudel/thousand_island` ref6146e1bfdd1a85c5c16c3c92ad98ff5f11066820 already supplies the cap. No upstream issue is warranted by this finding.

## Evidence, counters and shutdown

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Git baseline was not independently inspected because this read-only assignment explicitly forbids Git; exact reviewed source hashes are in the companion JSON. Parent retains all repository/evidence/runtime ownership. No repository file changed. Only this MD and companion JSON were created under `/tmp`.

Source SHA256 identity includes host3 `21280c6be63e9bef1956fa5fb30002896a7bd25e36583d2f8af1ec3f340b7778`, service `740d69a364e52cda9d05a997136ce864e9ec464149adcc81045bc9c109ed4472`, and TI Connection `3b1b1f6f3a9eb82adab2d6c342b1bc461520c2692e99cbe596c068dae522f19c`. Safe trace lines1–6 prefix SHA256 `c444fea562e6171c194769c52129b120074a9b9c5a52be7101bbf2de8083d716`. Full source/hash manifest is in JSON. No raw trace or full sys.get_state reply was read.

Verification: read-only source, installed manpage and bounded file searches completed. Mix/tests/browser/runtime/network/Git: NOT RUN by assignment. Some read-only searches guessed missing filenames (connection_supervisor.ex/runner4.mjs), then corrected via bounded file lookup; these are search errors, not failedGREEN or test outcomes. All own commands have finished. Prior rg session42661 was stopped with exit130 per handoff.

Counters unchanged: group37/root47/stage7 failedGREEN; Astra2of2 exhausted; this assignment adds zero failedGREEN and zero Sol repairs. Current full browser/stage acceptance remains open.
