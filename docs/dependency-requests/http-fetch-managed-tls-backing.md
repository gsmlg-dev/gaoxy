# Bound retained TLS policy backing for managed scopes

## Current 0.21.3 disposition

The containing fix is present in the independently verified installed 0.21.3
cohort. [Installed verification](../acceptance/evidence/m3/upstream-transport/upstream-0.21.3/installed-cohort-verification.md)
binds all seven archives, 196 shipped files and 175 runtime sources.
Compatibility486/0 and finite managed39/39 with canonical capacity MATCH and39
joined cleanups pass. Supplemental TLS95 now passes five cases/five cleanups;
the isolated0.21.1 negative control preserves both exact registration mismatches
and both successful cleanups. H1 baseline20/0 and the separately admitted B21
pass on the final grouped source with all joins and unchanged finite deadlines.
These selected functional gates do not establish complete memory accounting.
Feature [#97](https://github.com/gsmlg-dev/http_fetch/issues/97) is still OPEN and
blocks the supported native control bound/frontier needed for numerical H1
accounting and production activation. Full H2 accounting/adversarial backlog,
managed integration/soaks and the complete proxy matrix remain unqualified.
See [current acceptance](../acceptance/m3.md) for the H2 supplement and final
review receipts. The 0.21.2 and older dispositions below are preserved history.

## Historical 0.21.2 disposition

The containing fix is present in independently verified installed 0.21.2.
[Source/API review](../acceptance/evidence/m3/upstream-transport/upstream-0.21.2/source-api-review.md)
and [installed verification](../acceptance/evidence/m3/upstream-transport/upstream-0.21.2/installed-cohort-verification.md)
bind the current artifacts. Compatibility 486/0 and finite managed driver39/39
with canonical MATCH and 39 successful joined cleanups pass. Supplemental TLS95
registration is blocked in local identity tooling before cases; complete memory
accounting is not established. Feature97 blocks H1 numerical accounting and
activation; full H2 accounting/backlog and managed integration/soaks remain open.
See [current acceptance](../acceptance/m3.md). The former 0.21.1 disposition
below is historical; its absent95/remote-state claims do not apply to 0.21.2.

## Historical 0.21.1 disposition

#88 is closed; independent
[source/API review](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/source-api-review.md)
confirms recursive owned binary copies after frozen policy validation. Independent
[installed verification](../acceptance/evidence/m3/upstream-transport/upstream-0.21.1/installed-cohort-verification.md)
binds that change to installed0.21.1. Historical0.21.0 shared-DER constructor/
copy facts do not qualify the added0.21.1 copies. Cold CA/file loading, snapshot
immutability, transient overlap and release still require complete P3 accounting.
TLS resource tracking remains BLOCKED95; this policy fix does not qualify TLS
turnover or whole-generation retirement and enables no managed activation.

## Historical 0.21.0 request

Upstream: [https://github.com/gsmlg-dev/http_fetch/issues/88](https://github.com/gsmlg-dev/http_fetch/issues/88).
Type Feature; label `internal request`; severity needed.

**Requesting repo:** gsmlg-opt/gaoxy on branch `codex/m3-gateway`

**Severity:** needed for a source-backed conservative managed transport policy
reservation. Future Gaoxy preparation can constrain compact owned file/DER
material; this broader public-input gap is not automatically an H1 activation
blocker. No local dependency patch or private process inspection is requested.

**Source:** actual immutable 0.21.0 tag
`9813c126dc8b48055b9ee941c693fc27fa691489`, installed seven-package cohort
with all196 shipped-file and175 runtime-blob matches. Two independent source
reviews confirm absence of explicit backing normalization/charge. The amount
actually retained on the current VM is **NOT MEASURED**. No runtime leak,
8MiB allocation by scope, or multiplication by reference count is claimed.

## Missing contract and finite public recipe

Policy48–103/187–211/289–293/310 onward checks logical binary sizes,
list/depth and1MiB `external_size({ssl,sockets})`; it preserves accepted
in-memory CA/cert/key binary values. No `:binary.copy` normalization or
`:binary.referenced_byte_size`-based charge is used. Facade193–214 and Scope
10/30/35 retain the policy through scope state, config ETS and request preparation.
A borrowed slice can have a much larger reference-counted backing than its
serialized/logical bytes. References may share one backing allocation.

**NOT RUN recipe:** with applications started and a compact valid CA DER
`der` having64<byte_size<=4096, create `backing = der <> :binary.copy(<<0>>, 8 * 1_048_576)`
and `slice = binary_part(backing, 0, byte_size(der))`. First confirm through the
public VM API that `:binary.referenced_byte_size(slice) > byte_size(slice)`;
if the VM compacts it, state that result rather than claiming retention.

Open public ManagedTransport with HTTPS H1, literal loopback, SSL/native_v1,
C2/R32/P0, idle30000, buffer/recbuf/sndbuf8192, send_timeout1000,
send_timeout_close true and `ssl: [verify: :verify_peer, cacerts: [slice]]`.
Opening creates scope policy/ETS without Fetch/dial. Keep the monitored creator
alive; let its helper return/drop original backing references and collect them.
Use only bounded public snapshot/VM-wide observations, then retire/await scope.
Do not inspect or suspend private scope/client processes. A VM-wide sample cannot
uniquely attribute backing and does not establish a hard bound.

## Expected behavior

Provide a supported documented bound connecting accepted frozen TLS material
to retained backing and preparation copies: compact owned material before
retention, charge referenced backing, or explicitly reject unsupported borrowed
representations. Preserve credential redaction, hostname/peer verification,
frozen policy identity and independent scopes. Document sharing/copy and
preparation-transient exclusions; test a verified finite subbinary-backed input.
Logical/ETF caps must not be advertised as a complete retained-memory envelope.
