# Fixed H2 browser header diagnosis1

DONE read-only diagnosis and proposed experiment; runtime NOT RUN and repair NOT AUTHORED. Task: h2-browser-header-diagnosis1, direct follow-up. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, HEAD `8f6b884524d81d8defa7c5081230b8ab635e8107`. Root owns repository/evidence/Git/runtime; concurrent tracked and untracked changes were preserved. Only the two assigned /tmp artifacts were written for this follow-up. Systematic-debugging skill applied for hypothesis-before-repair.

## Evidence and bounded conclusion

- Current fixed runner1 line109 calls `Network.setExtraHTTPHeaders` with BOTH `Proxy-Authorization: Basic synthetic-proxy-old` and `Authorization: Bearer synthetic-origin-old`, followed by `Page.navigate` line110 and its unchanged error assertion. The returned header-setting command did not throw; the navigation assertion did.
- Safe fixed `h2-http2/browser.log` records Chrome `152.0.7977.64`, revision `506c834ecceaa943c5f41e6cfe7f68acb5c45346`, Node `v24.19.0`, then `AssertionError [ERR_ASSERTION]: net::ERR_INVALID_ARGUMENT` at extracted JavaScript line74. No probe PASS or captured event is established by this log. `joined.passed=false`, `close_requested=false` remains failure even though this Chrome process exited0.
- Root classification independently records outer `host.event(captured) -> queue.Empty`, one attempted nativeH2/TLS-H2 row, zero passed; forced inner cleanup and adopted signal10 remain actual failures/custody evidence. It explicitly says the header hypothesis requires differential reproduction.
- Working group runner4 uses the same encoded OLD/NEW path, direct loopback TLS/H2/SPKI mode and CDP navigation schedule without `setExtraHTTPHeaders`. Its safe `browser-green4/h2-http2/browser.log` has OLD+NEW PASS and graceful close on the SAME Chrome/Node version/revision. This is relevant historical comparison, not a fresh passing run of current sources.
- A read-only AST literal diff confirms pre-navigation functional delta: the extra-header call. Other differences are title/marker text, added crypto import, response-body verification AFTER navigation and removal of predecessor navigation-error metadata. These are not a controlled experiment, so correlation is not sufficient to prove root cause.

Leading hypothesis: Chromium rejects the `Proxy-Authorization` extra-header path during request creation. Alternatives: Authorization alone, their interaction, or a protocol-specific combination. The present safe log does NOT prove zero TCP/TLS traffic, nor identify a Chromium internal rejection function. Do not claim either without further evidence.

## Exact minimal independent local-browser experiment (root execution only)

Use a standalone Node builtin `http2.createSecureServer` bound strictly to `127.0.0.1:0`; no Gaoxy, Elixir, upstream peer, project-code import, account settings or external network. Four TLS/H2 cells are the minimum complete 2x2 header differential. Use one local server/actual port and immutable response for all cells; a fresh Chromium profile/process/page per cell prevents header/cookie/cache/auth contamination. Retain the actual failing Chrome binary/version and Node version. No operational credentials/certificates are involved.

Root generates a disposable loopback-only test certificate/key in its owned private temporary directory, with a localhost/127.0.0.1 SAN, using the ordinary existing test-certificate process. Keep private material outside repository/evidence and do not print or inspect it in this diagnosis. Pass only its computed SPKI pin via the already-used `--ignore-certificate-errors-spki-list` launch flag. Server negotiates H2, sends status200 `content-type:text/html`, `cache-control:no-store` and a tiny deterministic document for `/old%2Fpath?raw=%2F`, with a data favicon. Reject/log any unexpected authority/path separately.

Freeze this ordered matrix with literal synthetic inputs; do not use real credentials:

```js
const cells = [
 ['none', {}],
 ['origin', {'Authorization':'Bearer synthetic-origin-old'}],
 ['proxy', {'Proxy-Authorization':'Basic synthetic-proxy-old'}],
 ['both', {'Proxy-Authorization':'Basic synthetic-proxy-old',
           'Authorization':'Bearer synthetic-origin-old'}],
];
```

For EACH cell, using the predecessor's public CDP discovery/WebSocket request helper and the same browser flags other than netlog output:

1. Start fresh Chrome at about:blank. Keep existing startup/discovery/open5s/15s finite bounds, events2048 cap and actual stdout/stderr/exit custody. A single independent experiment must have an outer finite bound; do not run the Gaoxy host or wait on its capture queue.
2. Enable Page, Network, Runtime and block `*favicon.ico`. Record `Browser.getVersion` and Node version. Install an event observer before setting headers. Record safe bounded `requestWillBeSent` identity/path/method, `responseReceived` status/protocol, and `loadingFailed` error/canceled/type plus matching requestId. Never use raw netlogs or credential dumps. Server records actual session ALPN, method, target, authority and the two synthetic header values on each real document stream; count TCP connections, TLS sessions and document requests separately. TCP preconnects must not be misreported as document requests.
3. Call exactly `await request('Network.setExtraHTTPHeaders', {headers})`, even for none. Save actual CDP result or rejection. Then call exactly `await request('Page.navigate', {url: origin + '/old%2Fpath?raw=%2F'})`, recording actual `errorText`, requestId/loaderId and bounded matching events. Do not throw away the remaining cells on an EXPECTED header-policy failure; emit diagnostic status, preserve original error and continue after cleanup. A crashed/timeout probe is ERROR, not an expected policy result.
4. On success require actual server Document GET, negotiated h2, exact path/authority, received header subset matching that cell, response200/protocolh2, loadingFinished and deterministic response bytes/DOM. On rejected navigation require the matching loadingFailed terminal event OR record its absence explicitly as incomplete evidence; require no matching server Document stream at the terminal synchronization cut. Do not infer pre-TCP rejection from absence of a Document stream. Keep server session/connection counts separately.
5. After terminal observation send `Browser.close`, join actual Chrome code/signal, remove its profile, terminate/join that cell's request helpers, and leave original failure visible. If cleanup needs a signal, preserve forced=true and actual wait/signal; it does not become graceful. Only then start next cell.
6. After all4 cells close the independent server, join sessions/readers/processes and rebind its actual loopback port. Report 4 diagnostic cells separately from product tests/browser rows; no Gaoxy acceptance count increments.

Hypothesis is supported causally in this independent setting only if none+origin succeed, proxy+both fail with the same ERR_INVALID_ARGUMENT, and server sees no rejected Document requests. This proves the header path can reproduce independently of Gaoxy; it does not by itself qualify a repair. If none fails, the experiment is invalid as header isolation: diagnose its TLS/browser/server setup. If proxy succeeds or only the combination fails, retain those outcomes and revise the hypothesis; do not force the expected matrix.

If TLS/H2 setup is the only obstacle, a four-cell independent HTTP/1 loopback server may narrow the hypothesis, but label it HTTP/1 evidence and keep the TLS/H2 question open. Do not replace the failing TLS/H2 product gate with that result. If TLS/H2 gives a clean four-cell result, no broader protocol matrix is needed for this diagnosis.

## Repair decision after observed experiment

No repair is selected or authored yet. If the proxy-header hypothesis is confirmed, first test an alternative supported PUBLIC CDP request-interception mechanism in the independent endpoint. A bounded candidate is `Fetch.enable` at Request stage, then matching authentic `Fetch.requestPaused` and `Fetch.continueRequest` with the full existing request headers plus the same exact synthetic pair, once per real navigation. It may encounter the same restriction; do not claim support from API availability or silently ignore rejected headers. An actual independent server must observe BOTH exact header values on genuine H2 Document traffic before considering adoption. Disable unrelated Network extra-header injection for that differential only; change one injection mechanism at a time. Do not add proxy servers, special origin/header rewriting, Chromium security-disabling switches, synthetic captures or private browser/client mutation as an assumed repair.

Any adopted mechanism must then preserve the current host's authentic incoming proxy+origin exact-value assertions at lines1171–1178, current runner's upstream proxy-header ABSENCE and origin-header exact-value assertions at lines559–560, full exact response/body/visibility/OLD+NEW/custody/physical-close gates and finite limits. Never fix by dropping the proxy header or deleting its native-host assertion. Apply the same supported stimulus contract to fixed and group runners after root ownership/review; no production or dependency change is currently evidenced.

Before full rerun, freeze candidate source hashes, source SPEC then CODE, active syntax/static checks and runtime inventory using root's existing custody process. Keep the original first fixed browser failure immutable. Header reproduction or alternate-injection success is not identity acceptance. NativeH1/H2 fixed and required group rows, images and original lifecycle gates remain required. Improve runner fail-fast reporting only as a separately reviewed evidence-preserving diagnostic if necessary; queue.Empty is secondary and not the apparent first browser fault.

## Checks and limitations

Executed: read-only cwd/HEAD/status, bounded source/safe-log/classification reads, source SHA256s, Python standard-library AST literal extraction/diff, and /tmp artifact JSON/readback. No project-code imports, compile, syntax check, tests, browser, network or reproduction executed. One inspection command included a nonexistent historical snapshot filename (`browser-green4-runner-source.py`); `rg` reported missing file. Its actual runner4 and safe log were then read directly. This is one tooling/read-selection error, zero implementation/repair rounds. All own commands finished; no owned runtime process exists.

Latest numerical counters inherited from draft cutoff remain counter22 root169/orch92/tool32/Sol4/fixture4/group59/runtimefailed5/Astra2/2; parent has newer failure evidence, but this agent does not invent updated totals. This follow-up adds0 Sol/Astra repairs; Astra remains exhausted2/2. Remaining decision belongs to root after actual differential evidence. No external permissions requested.

## Newer parent steering after initial diagnosis

Parent reports independent Chromium contract review: IsRequestHeaderSafe rejects Proxy prefix; Fetch.continueRequest explicitly rejects unsafe headers. Earlier alternative Fetch injection is superseded and withdrawn; do not attempt it. Root owns a four-header independent H1 diagnostic. Proposed compatibility correction and exact security coverage are in `/tmp/gaoxy-h2-browser-header-compatibility-proposal1.{json,md}`; no need to grow the experiment into a new browser proxy flow or additional required TLS gate. This is parent-reported evidence, not a runtime claim by this agent.
