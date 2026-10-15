# M3 managed H2 group source foundation

Status: implemented under continuing authorization; non-live design readiness, intended tests-first RED, preliminary107/0 GREEN, scoped format and forced strict compile are recorded. Complete implementation SPEC1 found the missing feasible joined65536 regression; seven additive test lines repaired coverage and full107/0 GREEN plus format/strict compile passed again. Re-SPEC/CODE and fresh final gates are pending. This is the first non-live dependency of managed H2 groups/probes, after fixed-endpoint commit `bbbc50dc628d4d82fde7377b5bcff68bb35e1867` and evidence commit `5516ea1b398d7970e861cabdb2c2c3075be7eeae`.

## Goal and choice

Represent a bounded request before a group member is selected, then assemble the exact fixed H2 envelope for the selected member. Extend the existing pure `ManagedH2Envelope` module and reuse its private finite validators and `prepare/2`. This keeps the selected-member wire contract identical to the accepted fixed endpoint.

A synthetic origin during neutral preflight would mix member-dependent authority/pseudoheader limits with source validation. A new generic accounting framework would add an interface before the actual group controls and startup copies are proven. Choose the smaller source dependency first. Its successful result establishes finite source representation only; it is not authorization to open Fetch.

## Exact source and API

`prepare_group_source/1` accepts exactly six map keys: `target`, `method`, `fields`, `body_mode`, `request_limits`, `max_upload_bytes`. It returns `{:ok, compact_source}` or `{:error, :invalid_group_source}`. Validate the complete source before copying any retained binary or computing its external-term size.

The target begins with `/`, has1..65536 logical and referenced backing bytes, and uses the accepted fixed URL ASCII/percent grammar: reject malformed escapes, fragment, backslash, spaces, controls and non-ASCII bytes. Treat leading `//` as raw path; never pass the neutral target to URI.merge or parse it as an authority. Preserve raw percent case, repeated slashes and a present empty query.

Fields are a proper list of at most256 binary pairs, with the existing token/value grammar, total logical bytes<=65536 and total referenced backing<=65536. Target+fields logical/backing each stay<=131072. Method is one of the fixed seven methods. Body mode, unsigned64 length, exact four request limit keys/ranges and upload1..65536 use existing validators. Complete source external-term bytes must be<=205337. Unknown keys, struct tags, malformed lists and scalar types return the finite error. Copy target and every field name/value only after this complete preflight; the retained result must be compact.

`validate_group_source/1` validates the same exact schema plus compact target and field binaries, returning `:ok` or `{:error, :invalid_group_source}`. It does not silently copy a noncompact retained value. Neutral fields may still fail selected-member semantic validation (for example forbidden hop headers or effective pseudoheader overhead); neutral validation is not a complete request validator.

`prepare_group_request/2` accepts a validated fixed H2 HTTP config and compact neutral source. Revalidate both on each call. Build the raw root as `config.uri.scheme <> "://" <> config.uri.authority`, exactly as existing config validation reconstructs it; do not canonicalize it with URI.to_string. Require at most8192 raw origin bytes, and check origin+target<=65536 before concatenation. Compact the bounded joined URL, add only `url` to form the exact seven-key source and call existing `prepare/2`. Return its exact eight-key request or `{:error, :invalid_request}`. This preserves actual selected authority, H2/h2c protocol, raw target, effective field limits and max_upload<=selected max_chunk. No caller-supplied URL, arbitrary config sidecar or policy is accepted.

## Boundaries and accounting

No group Options, owner, GroupEndpoint, HTTP, Session, Probe, ManagedH2Reservation, dependency or fixed projector change enters this package. Existing H1/H3/fixed APIs and all assertions remain unchanged. Group prepare remains rejected by existing code. The only production path edited is `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex`; the only new test path is `apps/gaoxy_proxy/test/managed_h2_group_source_test.exs`.

The neutral representation occupies one request slot in a future ledger; this stage measures its complete ETF value without assigning a free marker or adopting any live reserve. R-GROUP-ACCOUNTING remains ACCOUNTING_NOT_READY. The extra2097152/total11542108 draft is PROPOSED_UNPROVED. Actual request/startup/recovery copy multiplicities, complete controls, pin manifests, boundary enforcement and real phase snapshots must pass subsequent independent SPEC then CODE before live group/probe prepare. In particular, a sixth simultaneous request/config copy or third checked policy cannot be hidden in existing five/two slots.

## Acceptance

Tests first must show missing-function RED, followed by complete pure GREEN with zero skips/exclusions; retain both actual results. Cover exact source shape/ranges/grammar, logical and backing caps, compacting versus retained validation, feasible boundary/over-bound values, maximum complete ETF construction, raw escaped/empty query/leading-double-slash preservation, both selected H2 protocols, invalid selected config/origin and semantic/effective-header/upload rejection through unchanged fixed preparation.

Run the complete new test file and existing managed_h2_envelope_test, managed_h2_activation_reservation_test, managed_h2_reservation_test, managed_h2_preparation_test without filtering; these are pure contracts. Run scoped format and forced warnings-as-errors compile. Independent complete SPEC then CODE review must pass before fresh final gates on unchanged source. Record runtime/toolchain/cohort, source hashes, nonzero counts and exact exits. This slice has no protocol/network/browser activation to qualify; the predecessor's recorded public63/fixed135/browser3 results remain scoped predecessor evidence, and the later group stage retains its real peer/browser gates.

Preserve all fixed/collector/fixture counters, historical failures and negative TLS cleanup uncertainty. Initialize a separate source-foundation repair counter, initially0. Astra2/2 remains exhausted. Root owns all repo/index/build/runtime/evidence writes; agents only read and write assigned /tmp artifacts. No push, release, deployment, production, certificate, Vault, public management or disabled E2E change is authorized.
