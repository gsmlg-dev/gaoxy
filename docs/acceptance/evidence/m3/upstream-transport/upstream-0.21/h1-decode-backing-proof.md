# P1 managed H1 TLS decode and exposed backing proof

Date: 2026-10-11 Asia/Shanghai. Task: `m3_h1_decode_backing_proof`.
Assignment: direct Sol, bounded source investigation. Report: **DONE**.
Result: **conditional default-suite successful-data logical and referenced
payload-backing lemmas established in source**. Full P1, physical allocation
budget, reservation and managed H1/H2 activation: **NOT ESTABLISHED**.
Mix, VM, runtime/network probes and tests: **NOT RUN**.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `4cc7a1a967d1b90a62d42db438316b10a03a1e16`.
Only this new report and [its receipt](h1-decode-backing-proof.json) are owned.
Previous evidence and live pure implementation are preserved.

## Boundary and result

The exact direct runtime source input is
`/nix/store/fsxs6d6pmksq0366z1bz7zn7h8vxi7v1-source`, identified by the fixed
signed NAR in [OTP provenance](otp-source-provenance.json). Installed runtime:
OTP28.5.0.7 / ERTS16.4.0.6 / SSL11.6.0.6, 64-bit, under
`/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang`.
No Git URL/revision provenance is claimed. The HTTP0.21.0 cohort tag commit is
`9813c126dc8b48055b9ee941c693fc27fa691489`. OTP paths/line numbers below are
relative to that source input. Repository paths are relative to this worktree.

Retain the [credit report's](h1-credit-induction.md) controlled profile and all
its unverified effective-backend/buffer/N and sole-arming premises. TLS versions
are only1.2/1.3; cipher options use the exact defaults, with no caller overrides,
paused handshake, kTLS, distribution, custom transport, downgrade or packet-mode
changes. No compression expansion is admitted: ServerHello parsing accepts only
NO_COMPRESSION and rejects other values (`ssl_handshake.erl:941-976`); the
selected decode path has no decompression call. Admitted native code must be the
matching OTP implementation, without a replacement crypto NIF/provider that
violates its memory contract. Actual loaded native/backend provenance remains
an integration verification obligation; no native function was executed here.

Define B, N and M as in that report; D=`N*B+M`. Let K_raw be the conditional raw
referenced-payload ceiling `floor(4B/3)` proved in the
[delivery worksheet](h1-delivery-proof.md). Let L_max18432 be the conservative
ciphertext payload ceiling including initial parsing; TLS1.3's established
ceiling is16640 (`ssl_record.hrl:142-144`, `tls_record.erl:704-709`). Then:

- Each successful application fragment has logical length at most D.
- Each such fragment's referenced payload backing is at most
  `K_delivery = max(D, L_max, K_raw)`.
- In the intended B8192, positive-N profile, D is greater than L_max and
  K_raw10922, so the conditional formula reduces to `K_delivery <= D`.

These are source-derived formulas, **not** a numerical production delivery
certificate: effective N/backend/options and independent composition review
remain open. No default N is substituted; no eight-window/pipeline multiplier
or zero-cost failure term is introduced. These quantities are per public
fragment, not total private TLS queue size or all simultaneously retained roots.

## Actual default-suite mapping

`ssl_config.erl:1952-1960,1986-1989` selects the default suites and filters them
for crypto support. `ssl_cipher.erl:326-327` delegates to
`tls_v1:suites/1`; `tls_v1.erl:510-516` uses the TLS1.3 defaults followed by
TLS1.2 defaults for the two-version configuration. Crucially, the TLS1.2
**default** list is not `all_suites` plus older CBC suites. The latter is a
separate list used for explicitly supported configuration
(`ssl_cipher.erl:331-349`). Crypto filtering only removes suites
(`ssl_cipher.erl:400-427`); it cannot add CBC or RC4.

Static extraction of all24 default macro names and their exact
`ssl_cipher_format:suite_bin_to_map` clauses verified `mac=aead` for every entry.
The receipt contains every mapping; the counts before runtime support filtering
are:

| Version | AES128/256 GCM | AES128/256 CCM | AES128/256 CCM8 | ChaCha20-Poly1305 | Total |
| --- | --- | --- | --- | --- | --- |
| TLS1.2 | 12 | 2 | 2 | 3 | 19 |
| TLS1.3 | 2 | 1 | 1 | 1 | 5 |

Lists: `tls_v1.erl:522-551,556-564`. Mapping clauses:
`ssl_cipher_format.erl:696-715,843-933,981-1021`.
`ssl_cipher:security_parameters/3` maps the selected suite to bulk cipher/type
(`105-125`); all these cipher atoms map to AEAD (`806-813`). Server suite
validation checks membership in the offered/configured set for TLS1.2
(`ssl_handshake.erl:1609-1615,3693-3697`) and TLS1.3/HRR
(`tls_client_connection_1_3.erl:704,803,1101-1107`). Actual negotiated suites can
be a support-filtered subset; the source proof covers the full default superset.
Resumption or renegotiation does not authorize selecting an unoffered CBC suite.

## Native binary semantics

The distinction measured here is logical bytes versus referenced payload
capacity. It is explicitly separate from Binary/BinRef/subbinary headers,
heap-word rounding, CHICKEN_PAD, allocator blocks and allocator slack.

| Helper | Exact source consequence |
| --- | --- |
| `enif_make_new_binary` | `erl_nif.c:1454-1463` calls `erts_new_binary`; `erl_bits.c:2811-2844,2868-2871` creates an on-heap binary of the requested logical size or a fresh refcounted normal binary. `erl_binary.h:287-303` sets `orig_size=requested_size`. It is not the larger cached-driver allocation path. |
| `enif_alloc_binary` | `erl_nif.c:1402-1414` allocates a driver binary and records the requested size; `erl_binary.h:253-268` sets `orig_size` to that size even though physical allocation adds headers and possible CHICKEN_PAD (`242-260`). |
| `enif_realloc_binary` | The owned ref-binary branch calls `erts_bin_realloc_fnf` and updates the NIF size (`erl_nif.c:1417-1430`). Successful reallocation sets `orig_size` to the requested size (`erl_binary.h:321-347`). A realloc retaining the same physical allocator block is not proof that referenced payload remains the old size. |
| `enif_make_binary` | `erl_nif.c:1684-1742` wraps the allocated backing for larger outputs; small outputs are copied on heap with a dummy BinRef keeping the old allocation alive until TLS-process GC. That temporary root is excluded TLS-private retention, not backing referenced by the public small binary. The no-ref branch copies into a new binary. |
| Inspection and slices | `enif_inspect_binary` reports the term's logical length (`erl_nif.c:1336-1348`), even for a slice. `binary:referenced_byte_size` instead returns backing `orig_size` when a BinRef exists (`erl_bif_binary.c:2508-2533`). `erl_bits.c:2635-2668,2714-2741` copies small extracted bitstrings or preserves the original BinRef. No slice increases this ceiling. |

Thus none of these helpers permits replacing physical allocation accounting with
`byte_size` universally. The payload formulas are suitable inputs to P2's
separate wrapper/representation charge, not a completed physical memory budget.

## Successful AEAD output paths

**TLS1.2.** `tls_record.erl:201-225` dispatches AEAD to
`ssl_record:decipher_aead` (`ssl_record.erl:387-403`). The split at `492-501`
removes an eight-byte explicit nonce for AES-GCM/CCM/CCM8, then its tag; ChaCha
removes the tag without an explicit nonce. Tag lengths are16, except CCM8's8
(`ssl_cipher.erl:135-143`). `ssl_cipher.erl:189-212` selects the exact crypto
cipher and calls `crypto_one_time_aead/7`, which dispatches the NIF
(`crypto.erl:1826-1830`, `crypto.c:126`).

In the seven-argument decrypt NIF, the inspected input is only the CipherText
slice, with logical size q=`L-explicit_nonce_bytes-tag_bytes`
(`aead.c:163-207`). It creates a fresh output of exactly q through
`enif_make_new_binary` (`303-310`) and returns that same term only on successful
authentication (`346-362`). It does not append ciphertext backing or expose a
subslice of the original raw buffer. Whether libcrypto's update/final counters
change is not used to infer a larger return: the returned term was constructed
with q bytes before those calls. Logical output and referenced payload are q,
so q<=L<=L_max. The allocation requires the normal native AEAD memory contract;
source bounds are not a qualification of arbitrary native providers.

**TLS1.3.** Both cached and uncached record paths use the stateful four-argument
AEAD call (`tls_record_1_3.erl:109-172,369-386`, `crypto.erl:1890-1891`,
`crypto.c:127-128`). The NIF subtracts its state's tag length from inspected
ciphertext size before allocation (`aead.c:241-272`), then creates and returns
q=`L-tag_bytes` through the same allocation/authentication path. Tag lengths are
8 or16 (`tls_handshake_1_3.erl:1508-1517`). Padding and the inner type byte are
removed through successive binary slices (`tls_record_1_3.erl:388-410`).
Application logical bytes are at most q-1 and16384 after the overflow check,
but referenced backing may remain q, bounded by L_max. This is the precise
reason a short public application binary cannot be charged only by its length.
Early/trial-data paths either use the same decode/slice or return no_record/
alert (`tls_record_1_3.erl:152-172,235-278`); they do not produce larger backing.

**Compatibility/unsupported builds.** An older OpenSSL GCM compatibility branch
is compile guarded (`openssl_config.h:324-326`, `aead.c:226-230`); its own
successful output allocation is also `in.size` (`aes.c:130-143`). Stateful GCM
initialization in that configuration is explicitly unsupported
(`aead.c:124-126`), so it does not silently use a larger TLS1.3 output. Missing
AEAD algorithms/build support produce errors rather than new successful data
(`aead.c:217-235,374-376`). No claim about which compile guards or support
filters are active in the installed crypto NIF is made without verification.

## Initial null, CBC and stream distinctions

The initial record state uses TLS_NULL_WITH_NULL_NULL
(`ssl_record.erl:456-458`). Null decipher returns its input fragment unchanged
(`ssl_cipher.erl:251-252`); TLS1.3 also has a null-current-state pass-through
(`tls_record_1_3.erl:215-225`). Null is not one of the24 negotiated defaults.
It must nevertheless be covered as an initial record-decoding state.

The record assembler supplies that coverage. `tls_record:binary_from_front`
(`579-622`) returns a whole input binary or splits one when the record payload
fits in it. `binary.c:476-512` uses the same original BinRef for those split
results, with small-copy handling in the common extraction helper. Otherwise
it copies exactly the selected record bytes via a multi-element iolist. Each
raw term's referenced backing is at most K_raw, and a spanning record copy is
at most L_max. Hence a null pass-through payload has logical length<=L_max and
referenced backing<=`max(K_raw,L_max)`.

This conservative bound avoids assuming every pre-handshake callback rejects
application records: explicit rejection guards exist in ordinary hello/start/
wait_sh states, while TLS1.3 middlebox callbacks use generic protocol dispatch
(`tls_client_connection_1_3.erl:330-362`). This pass makes no acceptance,
security-vulnerability or reachable public null-data claim. Any null fragment
that reaches the common application queue is bounded without that assumption.
Handshake/current-read transitions install selected cipher state
(`tls_dtls_gen_connection.erl:303-346`,
`tls_client_connection_1_3.erl:841-846`, `ssl_record.erl:130-149`).

CBC/DES/3DES and RC4 are separate supported **non-default** paths. CBC uses
`crypto_one_time/5`; RC4 uses `crypto_update/2`
(`ssl_cipher.erl:253-288`, `crypto.erl:1635-1636,1744-1747`). Their common update
helper allocates input+block, successfully shrinks to returned out_len and
makes the binary (`api_ng.c:465-487`); one-shot processing then creates an
exact-sized sum of update and final outputs (`794-830`). The generic stream/
block decoders expose content/MAC/padding slices (`ssl_cipher.erl:1007-1038`).
Invalid CBC padding deliberately prefixes content with one byte (`299-308`),
introducing a separate Erlang construction/backing edge before MAC rejection.
These facts do not certify all CBC/stream/provider outputs: validating their
native length contracts and the failure construction would require another
admitted profile. They are excluded here by the proved default-suite mapping,
not by treating their allocation or failure cost as zero.

## Concatenation and public exposure

`tls_gen_connection.erl:734-827` aggregates the current consecutive application
records with `iolist_to_binary`. Its fresh accumulator and empty-ciphertext
activation gate give the preceding report's encoded contribution bound D.
Every admitted successful decoded record is logically non-expanding: AEAD
subtracts nonce/tag/padding; null preserves logical record length. Therefore
summing contributing application lengths also gives S<=D.

For an actual singleton list, `erl_iolist.c:881-885` returns the binary unchanged;
binary input also returns unchanged (`916-927`). Its backing is bounded by
L_max for AEAD, or `max(K_raw,L_max)` for initial null. For a real multi-element
list, the iolist engine sizes the output and creates a new binary of S bytes
(`719-737`). Empty fragments do not increase S; empty output does not introduce
a larger payload. Therefore retained payload capacity is at most
`max(D,L_max,K_raw)`. TLS1.3's non-application retry or alert boundary may flush
already accumulated successful application records (`769-779`); that fragment
uses the same formula and does not retain the later failed plaintext as data.

The common user queue retains separate fragment binaries
(`ssl_gen_statem.erl:939-950`), and raw active/recv(0) takes the first binary
intact (`1517-1528,1750-1755`). Binary/header0 formatting does not enlarge or
copy it (`1812-1831`). Consequently the decoded-fragment backing formula reaches
public `{ssl,Socket,Data}` delivery. Owner transfer and deferred delivery do not
change the original backing. The one-public-data-message result remains
conditional on the previous report's sole-arm and successful-handoff premises;
one message is not one total live allocation across parser/consumer stages.

## Failure/output retention

AEAD authentication failures return error rather than their allocated output
term (`aead.c:312-319,346-362`). The fresh failed-output term can remain in the
TLS process heap until GC, but is not a returned application-data slice.
Native allocation/support exceptions may carry input arguments through crypto's
error wrapper (`crypto.erl:752-765`); SSL catches them, logs Reason/stacktrace,
and constructs a fresh decryption_failed alert
(`ssl_record.erl:394-402`, `tls_record_1_3.erl:377-385`). Public decode alerts
contain fixed/scalar reasons such as decryption_failed, record_type_mismatch or
plain_text_too_long; they do not directly retain the failed output/input binary.
TLS1.3 overflow after slicing returns an alert instead of that application slice
(`403-406`). Successful preceding fragments can remain live during the failure.

Public alert reasons are converted to text lists by `ssl_alert:reason_code`
(`63-74`) and sent by `ssl_gen_statem:alert_user` (`1873-1885`). This is not a
zero-cost terminal event: text/list/tuple/message roots need P2/P4 charges.
Stacktrace/debug formatting and logger retention are distinct paths; this report
does not bound logger/process heaps or classify them silently as public data.
If the eventual ledger includes those roots, it must state their provenance,
retention and limits explicitly. Raw mode does not invoke the packet-decoder
invalid_packet branch that can concatenate the entire application queue
(`ssl_gen_statem.erl:1533-1578,1747-1765`).

## Remaining work and verification

No additional admitted default-suite **successful public payload** backing edge
was left unresolved by this source pass. The remaining local P1 edge is enforcing
and recording the actual live inet/raw/header0/binary/fixed-buffer backend,
per-connection N selection and default-suite/native identity before accepting
these conditional lemmas. Default filtering removes suites, but the actual
negotiated subset and loaded crypto/backend still need receipts. Effective
settings and reused sockets must remain within those premises. No global SSL
environment mutation is authorized or used.

Recommended next bounded source task: compose the now-available D/K_delivery
with exact parser append/slice allocation and old-carry/new-delivery roots,
including final/failure returns, followed by the P4/P5 phase/release table.
Independently review that composition and the profile enforcement before a
parent-serialized runtime qualification. No universal private TLS-queue bound
is required by this ledger. No demonstrated dependency defect or new upstream
request arises from this investigation; no user product decision is needed.
All P0-P6 activation gates stay unqualified.

Fresh static checks verified both preceding proof input receipts, all five
preserved report hashes, all24 suite-macro mappings, source identities and
Markdown links/fences/whitespace. Exact source/receipt hashes are in the new JSON.
Nonexistent guessed source filenames were corrected; no executable command or
runtime validation was attempted. Own commands finished; parent jobs untouched.
Current task Sol repair rounds0 / unsuccessful0 / Astra0; preceding credit task's
one successful evidence repair and zero unsuccessful rounds are retained.
