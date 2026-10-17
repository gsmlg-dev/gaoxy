# Pending identity checkpoint dependent CODE review

**Verdict: FAIL_PENDING_CHECKPOINT_CODE_ONLY.** One P2 document finding. This remains a NOT ACCEPTED checkpoint; no stage or final-document acceptance is granted.

C1 — `docs/acceptance/m3-managed-h2-identity-rotation.md:13`: “each selected GET starts on a newly accepted TLS connection” overstates the witness. Design lines35–37 require a new connection for the first selected forward per old/new member and allow later selected-A reuse. A has HEAD+two GETs but only two accepts. State the first selected GET per member is cold, with later selected-A reuse allowed. No implementation or runtime defect is inferred.

The other scoped checks pass: current links resolve;940 scoped tests, consumers1+2 and Python11 remain separate; preliminary four rows do not replace final fixed FAIL/UNKNOWN or group NOT RUN; three TLS denials remain sticky and charged; environment-only setup and original guards/counters are distinct; successor execution and broader M3 remain open.

Binding: `7b13bda58346d711e254f7ccd869aa509697eaad9fb11c9f1af82e6d06db7571`; dependent SPEC: `f90f9e0d15e2d2cd374da6688c33b0115fdb03ffdff73861327363ae974e3f18`. All five bytes matched the frozen manifest at inspection. Original finding is against those frozen bytes even if root subsequently repairs them.

No runtime, fixture import, tests, build, browser, Git, repository write,411-source re-review, raw/protected access or image viewing. Only the assigned /tmp reports were written; all commands finished. Sol5/Astra2-of-2 exhausted preserved; root owns any new ledger event. Actual environment and final browser/custody/image/document/commit gates remain pending.
