# M4 UP2 H3 public host polling profile

Status: timing diagnosis recorded; compatibility implementation PROPOSED.
SPEC/CODE review and runtime qualification remain NOT RUN for this slice.

Preserve [repair8 FAIL52](../acceptance/evidence/m4/upstream-matrix/matrix-1791851211876179193/result.json)
and [timing-only FAIL52](../acceptance/evidence/m4/upstream-matrix/matrix-1791851519642121630/result.json).
The second run changed observation only. Its independent peer receives311,196
response bytes in304 DATA events, from1935.977ms to4974.185ms:303 intervals
average10.027ms. At the unchanged five-second deadline, response FIN, reset and
connection close are absent. The origin received the complete1MiB request,
SHA256 `8f990ba0b577b51cf009ea049368c16bbda1b21e1b93be07a824758bb253c39b`,
one request FIN and response FIN; the native owner was killed and guardian ended
normally. This cadence is consistent with the host's documented10ms polling
default. It is evidence for an explicit workload profile, not proof that every
delay or the complete matrix failure has been resolved.

The locked Abyss source is commit
`9b710e6480900e16e304f40e63623aff8c922e19`. Public `Abyss.QUIC.start_link/1`
already accepts `poll_interval`; its default is10ms. The public Handler contract
delivers `:tick` after each finite event batch, then starts the next poll after
the configured interval. Gaoxy currently accepts only `quic.alpn` and omits the
supported polling option when starting that host. A tiny response stream window
can therefore make progress on successive host polls while retaining a fixed
absolute request deadline.

Expose only `quic.poll_interval` in the trusted embedded service specification.
Accept integers1..1000 milliseconds, normalize omission to10, and return
`{:error, :invalid_quic_poll_interval}` for other values before runtime/listener
allocation. Retain strict unknown-key rejection and existing non-QUIC rejection
of nonempty QUIC options. Forward the normalized value as the public
`poll_interval:` option in `Gaoxy.Service`'s `Abyss.QUIC.start_link/1` call.
Normalization must be idempotent when a completed service specification is
validated again. This is a bounded service-host compatibility option; it adds
no wake protocol or mutable configuration process.

For each of the two UP2 H3 listeners, first obtain the existing public
`Gaoxy.HTTP.HTTP3.service_spec/1`, then change only its completed `quic` map and
revalidate using `Gaoxy.Config.service/1`:

```elixir
{:ok, completed} = Gaoxy.HTTP.HTTP3.service_spec(options)

{:ok, selected} =
  Gaoxy.Config.service(%{
    completed
    | quic: Map.put(completed.quic, :poll_interval, 1)
  })
```

Record both normalized QUIC maps in fixture startup metadata and assert listener
IDs `h3`/`h3_sibling`, ALPN `["h3"]` and interval1 in the matrix runner before
any row starts. Preserve endpoint initialization exactly once. Do not widen
H3 Options or the standalone data-only configuration flow. Their existing inputs
and effective10ms default remain unchanged. A pass qualifies the explicitly
selected1ms UP2 workload, never default10ms tiny-window burst throughput.

Keep operation CAS, pending-reference ownership, bytes/reservations, callback
budgets and absolute deadlines unchanged. Preserve all66 network+2 policy rows,
peer2KiB stream/4KiB H3 connection credit, origin16KiB window, exact1MiB
bytes/hash and actual FIN, original five-second row deadlines, error/reset,
cancellation, sibling and zero-admission/retained/cleanup assertions. Keep the
finite event batch and all parser/control limits; do not patch dependencies,
read private host state or introduce a private wake message.

Require pure boundary/default/idempotence/unknown-key rejection tests and real
public Gaoxy QUIC-host start/local/status/stop/normal-DOWN/UDP-rebind coverage for
default10 and selected1. Assert the normalized specification, with supported
public call arguments available to bounded test tracing if needed; avoid timing
threshold assertions on scheduler cadence. These tests validate configuration
and lifecycle. Only the unchanged independent full UP2 matrix establishes the
selected profile's protocol/workload acceptance.

Root owns all source/test execution. Independent SPEC/CODE review precedes the
live matrix; actual-evidence review and a fresh full repeat follow any complete
PASS. Counters remain seventeen unsuccessful live executions, five failed
production repairs and three failed harness repairs. The timing-only failure
remains a diagnostic under repair8; no counter reset or third Astra recovery.
