# Gaoxy.Test development recovery evidence

These unchanged logs preserve failed development checks on the uncommitted
implementation over baseline `32933790457bcfa3533e40dc2ae4d51ad91aa86d` (0.8.0),
macOS arm64, Elixir 1.20.1/OTP29. They are historical failures and diagnostics,
not final acceptance or published-package evidence. Original copies remain under
`.audit/gaoxy-test/`.

| File | Result | SHA256 |
| --- | --- | --- |
| `protocol-helper-initial.log` | 21/26, exit 2 | `dac46aef111bb268448774931d0bbed2ede15de315c0df33841892988d6fd0b1` |
| `core-repair1.log` | 60/61, exit 2, seed 976307 | `a8b00341eebc9567f3659f426c26bd5251498115a8383761d99f7806e9ee2f0d` |
| `core-repair2.log` | 60/61, exit 2, seed 457284 | `2923b14e8d6310187e3b18b23ea6ff3b96a67d804478601b4db962806f86a5d6` |
| `astra-public-stop-probe2.log` | Public-stop diagnosis: TCP/TLS socket survived runtime exit, closed after 5001 ms | `dabb4fa81dd7d2890a98c5bcf28fc46646db5dda7390725021a07920893aeb6b` |
| `astra-regressions-red.log` | Expected pre-fix failure: 0/4 deterministic recovery regressions passed | `b824829ec5e525a57d059c7aa0f7458b12cdec99caae4fc03b6ffa0bbfa400d0` |
| `astra-repair1-package.log` | FAIL, 68/69, seed 457284; all eight added cases pass, transient reset fails final listener-refusal probe | `8c00c823c1b330c40853129a5c1208897e705477c173443bc9a62698195c6237` |
| `astra-repair1-production.log` | Setup prerequisite failure: OpenSSL4 selected, existing fixture script requires OpenSSL3; 41/44 core and 3/3 HTTP executed cases passed | `681013547d77da4fd6f27a2a19127a7c84b2e36027ee6e76fa367aa32e09c518` |
| `astra-repair2-package.log` | PASS, 69/69, exit0, seed457284, 0.8.0 baseline | `fbb930a1b06c352975fe5877c33c266041a37082e4f5ccb8d79ab3fae4f1fddf` |
| `astra-repair2-production.log` | PASS, 47/47, exit0, seed457284, OpenSSL3, 0.8.0 baseline | `4a84af39053a49bc8dadacede7e14d6878ff67741ea7f8ef5e9cbf0a2b9996a7` |

The initial check selected `protocol_test.exs` and `helper_test.exs`; the Sol
aggregate checks selected all six files under `apps/gaoxy_test/test/` with
`--warnings-as-errors`. Environment:

```sh
ELIXIR_ERL_OPTIONS='+S 2:2' MIX_ENV=test \
GAOXY_QUIC_PYTHON="$PWD/.audit/h2peer/bin/python" \
mix test apps/gaoxy_test/test --warnings-as-errors
```

The public-stop probe is diagnostic evidence, not a test-suite pass. It observed
an orphaned HTTP handler blocked in TLS handshake and a surviving TLS socket
after public `Gaoxy.stop/2` returned a cleanup deadline error. See the design and
acceptance records for cumulative routing counters and current disposition.

The production check's OpenSSL prerequisite failure is retained independently
from implementation results; reruns must select
`OPENSSL_BIN=/opt/homebrew/opt/openssl@3/bin/openssl`. The package probe correction
must still establish `:econnrefused` within the original finite deadline, even if
an earlier connect attempt observes a transient reset.

## Integrated 0.10.0 verification

The `final-*` logs retain the uncommitted integrated0.10.0 checks over baseline
`044e1cd90ddf4cc1550df99411f2906209387f5f`. Staging10, extracted consumers7,
internal-request regressions46 and canonical composition58 passed. The local
full curated run retains a macOS alternate-loopback failure; the Elixir1.20
composition log retains an unchanged baseline type warning. No failed gate is
reclassified as passing.

The canonical119-case aggregate passed every assertion but exited1 on task-owned
generated protocol-test type warnings. Its SHA256 is
`7ec16e19cbf21a9fddc6f566724b9376ae63afe06a6e78438858397ebe234643`.
The H3 browser LiveView gate also failed after five successful checks; its raw
report SHA256 is
`0df47b5b0b5c2259b73dd67ba9d0aaaa04de43e65e1efae9b503a83832d23337`.
See the acceptance handoff for exact failure scope and the historical exhausted
repair budget.

## Authorized round3 and final local qualification

The user extended the cumulative Astra maximum to four. Round3 completed with
Sol2/Astra3 used; round4 has not started. `round3-handoff.md` records exact commands,
counts, exits and diagnosis. Canonical119/119, expanded126/126, exact helper69/69,
formatting and all8 established browser checks passed on the same runtime/package
payload over `044e1cd9`. Browser success uses explicitly selected Chrome156;
Chromium141's failure remains preserved, including compressed H3 NetLog evidence.
No production source changed in round3 and no assertion/deadline was removed.

Final reconciliation to `6c82d5be` changes only upstream test contracts and0.9.0
evidence. The fresh internal46 gate, strict production compilation, actual release
isolation and13 standalone smoke checks pass. Final local logs and the H3 receipt
use the `reconciled-*` and `standalone-*` prefixes. These are local macOS arm64
results; hosted Linux/OTP28 and publication remain separate checks.
