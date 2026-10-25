Released in [Gaoxy v0.13.0](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.13.0), publication source `bd325eb408d4566b807bcef9fdaf1a2b1ad83a2d`. All six coordinated Hex packages are public and independently verified.

H2 startup now checks supported socket metadata after bare or SSL-wrapped closure candidates from receive-option setup. A confirmed disconnected peer stops normally before admission/writer allocation; a live peer's genuine option failure retains its exact original error. The change applies narrowly to startup classification and does not suppress general logging.

Verification:

- Eight controlled cases cover bare/wrapped closures and live/error-preservation controls; a synchronized real TLS case covers orderly owner termination, no abnormal error log, cleanup and a healthy H2 follow-up.
- [Release run 40212587939](https://github.com/gsmlg-dev/gaoxy/actions/runs/40212587939) repeats all 568 ordinary cases, zero failures/excluded/skipped. All five exact-source workflows passed.
- A fresh Hex-only 0.13.0 consumer strictly compiled, matched published source to the commit and passed the synchronized real TLS regression: 1 test, 0 failures. It is part of 23/23 public issue regressions.
- Independent public verification passed for all six Hex packages, eight matching GitHub/Actions assets and seven payload checksums. Downloaded standalone passed 13/13 runtime checks; independent review has no actionable findings.

The original RED and setup/port failures retain their historical results in the [issue evidence](https://github.com/gsmlg-dev/gaoxy/blob/bd325eb408d4566b807bcef9fdaf1a2b1ad83a2d/docs/acceptance/internal-17-startup-peer-close.md). The reported timing-sensitive 20-connection observation remains requesting-repository evidence; no local rerun of that exact probe is claimed.
