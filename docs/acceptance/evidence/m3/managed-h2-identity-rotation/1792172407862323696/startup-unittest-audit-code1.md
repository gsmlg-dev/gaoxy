# Startup11 evidence-audit CODE review

DONE — CHANGES_REQUIRED for unexecuted audit script SHA256 `bcd33af83bf02bb6644250d02665dfdba40b8fb53e75fba150f8d00aefeb16c0`.

1. Enforce the accepted candidate5 and inventory5 SHA256 values before using their expected argv/source pins. Recording those hashes only after PASS does not enforce frozen identity.
2. Record reviewer and reviewed report identity/hash alongside the driver hash, as required by the frozen audit-record contract. Bind the root-archived script bytes to the reviewed source.
3. Record available input hashes, parsed rows/counts and custody observations incrementally, so a failed assertion preserves actual evidence instead of only driver hash and traceback. Keep unverified values unknown.

The core parsing checks retain collectorstatic tests0, unique11 expected successful methods, Ran11/terminalOK, source/argv/custody checks and explicit failure exit. No test execution, source/assertion change, import or check execution was performed by this reviewer.

Only assigned `/tmp` reports written; all commands finished. Reviewer repair rounds0; inherited Sol5/Astra2/2 unchanged. Root should repair/freeze/re-review this bounded audit tool before executing it.
