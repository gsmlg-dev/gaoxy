# Native H1 pressure controller store author2

DONE. Sole test source correction for accepted SPEC9 findings.
Before SHA256 `f10077760305acf52bbe3a6f5b532783ae7be5097f71f6c7740d1352a7299948`.
After SHA256 `f3f1ebc4bd8b1307d4a2e08ee4695cc9287b01d2893b0a14c3373cb09b34025f`.

The event reader retains its first overflow guard, snapshots committed sorted events, repeats the same <=128 overflow guard and returns the local snapshot. No progress reservation/row equality is added.

An initially false quiescence flag becomes true only after successful run_probe return or failure_cleanup returns []. After detach, explicit event-table deletion requires that flag; failed/unconfirmed cleanup leaves controller-owned ETS alive until controller death. Observer table deletion, original exception/cleanup failures and all other flow remain.

Exact inverse restores complete baseline; preserved protocol/completeness/sampler/failure blocks compare equal. Formatter/parser/compiler/runtime/tests/browser/Git/review NOT RUN. Incidents0. Counter34 root643/orch530/tooling55 and Sol5/Astra2of2 unchanged. Fixture untouched. All synchronous commands finished; reports sealed/source immutable after DONE; custody returned to root. JSON contains exact diff.
