# M4 final test-contract repair

Status: implemented and independently reviewed. The recorded 527/3 failure
remains immutable. Both complete test files pass
[44/0](../acceptance/evidence/m4/upstream-matrix/final-test-contract-green-1791855566615515224.json),
with [whole-candidate SPEC/CODE clearance](../acceptance/evidence/m4/upstream-matrix/review-m4-final-source-spec-code-preparation-1791856541203317954.json)
and fresh prescribed source verification at 530/0. The design below records the
reviewed repair contract; final M4 acceptance is recorded separately.

## Evidence and scope

The immutable [final source execution](../acceptance/evidence/m4/upstream-matrix/final-source-repair11-1791854360344382762.json)
and [log](../acceptance/evidence/m4/upstream-matrix/final-source-repair11-1791854360344382762.log)
record **527 tests, 3 failures, exit2**: two `Gaoxy.HTTP.HTTP3.ProxyTest`
tests miss `{:ready_held, worker}`, and the standalone H3 config test expects
`%{alpn: ["h3"]}` instead of the actual normalized
`%{alpn: ["h3"], poll_interval: 10}`. These are genuine failures; the receipt
remains FAIL. This bounded repair owns only the two test files and this
design/plan. Production, runtime, integration, versions and other documents are
outside its ownership. Root exclusively runs Mix, formatting, compilation and
live gates. The separate fresh UP2 matrix failure is not explained or repaired
by this assignment.

## Controlled ready barriers

The two tests intentionally hold or reorder the upstream ready notification to
exercise undeclared trailers and an early final response. Their fake transport
currently waits only the caller's `wait`, which is now zero at that poll. If
ready has not arrived, the fake returns; the production proxy pump then waits
up to5ms and can dispatch ready itself. The test's intended intervention never
happens and `ready_held` is missing. This explains the fixture contract mismatch,
without treating the failed behavioral assertions as passed.

Only the `hold_ready: true` and `reorder: true` fake branches will wait for their
first ready notification using `Gaoxy.Lifecycle.remaining(exchange.deadline)`.
Missing ready raises a branch-specific barrier error at that original deadline;
it must not silently return pending. After capture, retain the existing
`ready_held` notification, explicit release messages, same-session 413/end
ordering and one-shot flag clearing. The ordinary fake polling branch continues
to obey the supplied `wait` exactly. No sleeps, retries, additional processes,
new deadlines or timeout extensions are introduced.

Keep every existing test assertion: observed ready barrier, 502 for undeclared
trailers, 413 for early final response, no body read, no upload finish, exact
original response/result deadline, independent real H1 origin observations and
normal origin completion, plus active/retained/cleanup baselines. Retain the
existing2s request timeout,3s assertion timeout and5s proxy lifetime.

## Standalone normalized configuration

The previously reviewed public embedded QUIC option normalizes omission to
`poll_interval: 10` in `Gaoxy.Config.service/1`. Standalone H3 reaches that same
normalization through `HTTP3.service_spec/1`. Update the existing equality to
the complete normalized map, including the exact default10; do not replace it
with a subset match or loosen its ALPN assertion.

Standalone JSON continues to reject external `quic` input. Add a rejection-table
case containing both valid embedded ALPN and `poll_interval: 1`, proving that
the supported embedded selection remains unavailable through this data-only
schema. Keep the existing ALPN-only external rejection and owner-absence checks.
No schema, public option, default or production behavior changes.

## Acceptance and counters

The existing527/3 failure is the recorded RED before edits. After independent
SPEC clearance, root runs the two complete owned test files with nonzero test
counts, exact-file formatting and strict compilation. Independent CODE/evidence
review and a fresh affected run are required; root then repeats prescribed final
M4 checks. Only actual executed PASS evidence can close this repair. Full matrix,
M4, release and production acceptance remain separate.

This planning assignment adds zero Sol/Astra recovery rounds. Root records the
bounded test-contract repair's subsequent edit-and-validation outcome; retain
all prior counters, failed receipts and the exhausted two Astra recovery rounds.
