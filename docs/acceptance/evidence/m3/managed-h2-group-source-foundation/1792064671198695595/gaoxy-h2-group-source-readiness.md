# H2 group source foundation readiness

Task `h2_group_source_readiness`: **DONE** for the read-only decision. The proposed three-function slice is a **sound actual first implementation dependency**. It does not establish R-GROUP-ACCOUNTING, accept a reserve, enable group Options/prepare, or independently accept unreviewed implementation. Accounting remains **ACCOUNTING_NOT_READY**.

The earlier investigation's larger closed-controls package can follow this smaller source prerequisite. This supersedes only the recommendation about which dependency to implement first; its startup/recovery/copy-count findings remain outstanding. No broad owner/health change is needed: narrowing the future probe startup member removes its unbounded health counters from transfer.

## Exact narrow ownership and API

One author owns only:

* `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex`: add the three internal functions and minimal private neutral-shape helper(s), reusing existing method/body/request_limits/field/binary/url syntax validators. Preserve all existing fixed-function behavior.
* `apps/gaoxy_proxy/test/managed_h2_group_source_test.exs`: new pure tests for source/binding contracts. Existing fixed envelope/reservation tests and assertions remain unchanged.

Root owns written design/plan changes and all commands. No new accounting framework/module is necessary for this slice. UpstreamGroups.Options/owner, GroupEndpoint, HTTP/Session, Probe and ManagedH2Reservation remain unchanged; no H2 group handle/profile acceptance or live prepare is added.

`prepare_group_source(source)` accepts exactly `target/method/fields/body_mode/request_limits/max_upload_bytes`, performs complete bounded source preflight, then copies target and every field name/value into an exact six-key compact source. It returns `{:ok, neutral}` or the existing finite invalid-request error convention. Do not retain caller extras or nested extra request_limits fields. There is no URL/protocol/selected-config/diagnostics key.

`validate_group_source(neutral)` applies the identical finite schema checks and requires target and each field name/value to be individually compact. It returns `:ok` or finite invalid-request error. A backing-bounded but noncompact caller source may be accepted and copied by prepare_group_source; it must be rejected as a retained neutral by validate_group_source.

`prepare_group_request(config, neutral)` revalidates compact neutral and complete fixed H2 config. Compute the selected root string only after config validation, check `byte_size(root)+byte_size(target)<=65536` **before** concatenation, then construct exactly seven keys by adding the joined URL. Delegate to unchanged `prepare(config, source7)`. That existing path validates actual protocol/scheme/origin, full raw URL, effective pseudoheaders/generated fields/request limits and max_upload_bytes<=selected config.max_chunk_bytes, and returns a compact exact eight-key envelope. Return finite errors; do not permit uncaught invalid-input exceptions or a synthetic member origin.

The root's proposed source function accepts any fixed config meeting this contract. Group compilation later independently retains its existing origin-size<=8192 requirement. If this helper is instead specified to enforce that group-only bound itself, say so explicitly in its tests; no synthetic 8192 assumption should substitute for the65536 joined-URL check.

## Validation hazards to close before implementing

1. **Leading `//` is a path.** Never URI.parse the neutral target into an authority or URI.merge it with selected root. Use the validated selected root plus the unchanged raw origin-form target. `/`, `//elsewhere/path`, `///p`, `/p?`, `/p??x`, escaped slashes and percent-triplet case preserve exact bytes. A target beginning `//elsewhere` must still use selected member authority.
2. **Keep the exact existing URL grammar.** Require nonempty slash-prefixed binary, valid percent triplets, visible ASCII excluding raw fragment marker/backslash. Reject absolute, authority-only and asterisk forms, raw space/control/DEL/non-ASCII and malformed `%`. Percent-encoded delimiters remain escaped; do not decode/re-encode or normalize dot segments/slashes. Existing private `url_text?/1` already admits `?` and rejects `#`/backslash, so a slash-prefix check plus that scanner can stay small.
3. **Reject large backing before copying or serialization.** target logical/backing<=65536; proper fields<=256 with aggregate logical/backing<=65536; target+fields aggregate<=131072. Use existing bounded pair traversal/token/value rules rather than Enum.map or external_size on unchecked input. Copy target/fields only after the whole source passes. Target emptiness/prefix must not cause an exception on nonbinary input. Method/body/range checks precede derived work.
4. **Retained-source compactness is per occurrence.** Validate every field name/value, not only sum, ETF or top-level map. Include tiny logical slices of larger backing, plus bounded noncompact slices. Validation rejects retained noncompact values; preparation copies bounded sources and its returned map passes validate_group_source. The nested request_limits map contains only four finite integers and needs no binary copy.
5. **Neutral validation is intentionally structural/bounded.** Method uses existing enum; body is :none/:chunked/{:length,uint64}; exact request_limits are max_headers1..256, max_header_bytes1..65536, max_trailers1..128 and max_trailer_bytes1..65536; upload1..65536. Do not claim that neutral success means upstream-request admissible. The actual selected authority affects pseudoheader bytes; generated user-agent/content-type/content-length and effective count may exceed the request's bound. Existing prepare/2 must decide with the actual selected config, and actual upload-PID preparation later retains its fixed qualification. No fake origin/policy proof belongs in the neutral stage.
6. **Selected binding checks are not optional even after prepare_source.** Test malformed or expanded compact neutral passed directly to prepare_group_request, changed config/client/protocol, over-limit joined URL, upload exceeding member chunk, effective header/pseudoheader count/bytes, and semantic-header rejection. Never trust an earlier validator call or merely tag the map as prepared.
7. **The complete205337 ceiling is a bounded upper limit.** After exact shape/ranges/logical/backing validation, measure complete neutral including wrappers and require ETF<=205337. Its six-key shape and target+field total may not attain205337 exactly. Construct actual maximizing valid values and prove the remaining constructor overhead fits; do not pad with extra keys to force equality. The parent alone runs ETF measurements.
8. **Source-stage purity does not resolve copy accounting.** Raw neutral, compact neutral, selected URL/source7, new envelope, fixed validation/preparation return can coexist in pure call frames. Do not assign them zero-cost aliases or claim five live slots already proved. Future runtime integration must provide the phase-release/slot table. This slice creates no Session/Probe/Fetch/transport token and adopts no reservation amount.

## Exact pure test matrix

| Area | Positive checks | Negative/limit checks |
| --- | --- | --- |
| Shape and finite values | Exact six keys; every supported method; none/chunked/length0/uint64 max; exact limits/upload endpoints | Missing/extra/protocol/url/struct keys; invalid map/scalar types; wrong method/body tuple, negative/uint64 overflow; request_limits missing/extra keys/range; upload0/65537/bignum |
| Target syntax | `/`, raw escapes with preserved case, `%2F/%3F/%23`, leading//, repeated slash, absent query versus empty`?`, several`?` | Empty/non-slash/absolute/authority/asterisk; malformed percent triplets; raw# and backslash; whitespace/NUL/DEL/non-ASCII |
| Fields | Proper finite list, token/value rules, max256 pairs and aggregate65536 logical/backing | Improper list/nonpair/nonbinary; pair257; logical or backing65537; empty/invalid token and newline value |
| Copy/compact | Bounded noncompact target/name/value source accepted by prepare and compacted; validate returned neutral; original bytes preserved | Backing-heavy source rejected before copy; retained noncompact neutral rejected by validate and by selected binding; no hidden source-map values retained |
| Complete source cap | Construct maximum valid source and assert complete ETF<=205337 plus exact keys/compactness | No arbitrary padding; first valid shape crossing a component bound rejects; report constructed maximum and wrappers separately |
| Binding | TLS H2 and h2c; exact selected origin/protocol; exact eight-key envelope; escaped, leading// and empty query byte equality | Invalid fixed config/client/protocol; invalid neutral direct call; joined root+target65537; upload>selected limit; actual effective head/count/pseudoheader caps; semantic headers invalid |
| Joined URL boundary | Exact65536 **only with an actually admissible fixed config/target/effective-fields fixture** | Do not expect a65536 target plus nonempty origin to pass; do not expect URL-size equality alone to prove effective-fields admissible |
| Compatibility/purity | Existing fixed envelope/reservation tests unchanged; pure source-only ExUnit | No Options.compile H2 activation, UpstreamGroups.prepare, owner calls/pins, DynamicSupervisor/Session/Probe start, HTTP.fetch, network or fabricated completion |

A maximum neutral target65536 or256 raw fields can legitimately pass structural neutral checks and fail actual selected request preparation. Tests must distinguish those stages rather than weakening selected validation or inventing a synthetic authority that makes the source appear fully admissible.

Parent's scoped verification after writing/source review:

```sh
nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer mix test apps/gaoxy_proxy/test/managed_h2_group_source_test.exs apps/gaoxy_proxy/test/managed_h2_envelope_test.exs apps/gaoxy_proxy/test/managed_h2_reservation_test.exs --warnings-as-errors --max-cases 1 --seed 33012
```

Also run scoped format/compile checks required by root's plan, and capture exact source/runtime hashes, nonzero executed tests, failure/skip/exclusion counts and exits. These commands and ETF measurements are **NOT RUN** by this investigation. Fresh independent implementation SPEC then CODE review is still required; this decision reviews proposed contracts only.

Worktree and report baseline/source hash are recorded in companion JSON. All inherited counters remain unchanged (fixedSol19, fixtureSol20 RED1/GREEN1, collectorSol17, full58 failed2, Astra2/2 exhausted); this follow-up used zero repair rounds. All read/report commands finished. Only the two requested fresh `/tmp` outputs were written; no repository/runtime/network/publication/deployment action occurred.
