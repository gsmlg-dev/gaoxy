# Managed H2 group queued-terminal control acceptance

Status: IMPLEMENTED, original FULL SPEC47/47 and CODE48/48 PASS. Retained fresh compatibility603/1 led to fixture repairSol1; all repaired initial gates PASS: Python11/0, fixture97/0, format/forced strict compile, pure452/0 and compatibility603/0 on99 stable inputs. Renewed independent review, fresh gates and local commit pending. Predecessor startup catalog DONE locally at `b30bdb0dcbdd3bc33b3b8e06a6f691e3584e42f1`.

Scope: existing-handler dispatch for one queued terminal event at BOTH Session group open/bind continuations. No activation/reserve/owner authority change; ACCOUNTING_NOT_READY/fixed9444956, all inherited counters/Astra2/2 remain. Test results/actual evidence will be recorded after execution; no future PASS is assumed.

Evidence: `docs/acceptance/evidence/m3/managed-h2-group-preopen-control/1792078806655905470/`; readiness candidate SHA2560fa22c9162117ae55c124b032c0c2ac45076f6aab9e64761d440094df5be7d8b, independent readiness report SHA2568e1df7bbc30d4bf84872b64c42b47f32882ad0f1be045d7562a5ed3fe8432fcb. Complete RED root authentication SHA2566e7c5c762592a3cc9fd16c8546e97aff3f100628fab05c5a2a9913f418191d4a identifies all146 assertion failures by their predicted names. All93 frozen sources and47 baseline tests were unchanged; no fixture/syntax/self-call exception or zero-test outcome is used as RED. Test author static-checker failure1 (expected13 macroblocks, actual12) is retained separately; test assertions/source did not change.

Complete initial gates PASS on identical94 source inputs: scoped format and forced warnings-as-errors compile exit0; complete nine-file pure452/0 and36-file compatibility603/0, zero skips/exclusions. All47 pre-existing test files remain byte-identical to baseline/HEAD. `initial-complete-green1.json` binds actual commands/logs/counts/exits/source and authenticated RED. Actual behavior is QUEUED_PREOPEN_CONTROL_IMPLEMENTED_GATED; live group activation remains ACCOUNTING_NOT_READY, fixed reservation9,444,956 unchanged.

One root command-sequencing error is preserved: an initial format check was launched before the preceding formatter was joined. Both actually passed on unchanged bytes; the overlapping check is explicitly NONACCEPTED and a later serial format check passed after both joined. It is not substituted for the prescribed gate. Counters: implementation1/repairSol0/expectedRED1/failedInitialGate0/failedReview0; authorStaticCheckerFailure1; rootCommandOverlap1/repair1. Inherited predecessor implementation1/repairSol2/unsuccessfulGREEN1/metadataFailed1/initialCompleteGateFailures2/expectedRED1/readinessFailedSPEC1/authorCheckerFailure1/documentationRevision1/finalizationAuditFailure1/repair1 and all earlier counters remain; Astra2/2 exhausted. No assertions weakened, no old evidence modified.

Fresh failed gate `fresh-compatibility-1792080874178616116.json` is retained:
603 executed,1 failure,exit2,zero skips/exclusions,stable source and joined CLI.
`ManagedH2FixedReleaseOrderTest` fails before `F.fixture(:h2c,...)` returns:
the independent peer did not report ready. This is neither Session acceptance
nor evidence of peer-process joining. Source diagnosis and controlled runtime
reproduction establish unnecessary PKI on h2c, a20s preparation/5s ready mismatch
and partial-start cleanup defects. The controlled key-operation barrier yields
ready at5.4627s, after its release beyond the original5s deadline; h2c without
OpenSSL exits1 and exposes partial-stop AttributeError. The original failed
run's timing attribution remains UNPROVED. See `peer-startup-runtime-diagnosis1.json`
and `compatibility-repair-kickoff1.json`; failedFreshGate1 is cumulative.

The necessary fixture-only repair passed the complete initial gates above;
`compatibility-repair-red-authentication1.json` binds tests-first Python11/10
and ExUnit41/1 intended assertion failures. The retained first root draft's
two diagnostic-format failures were corrected with exact strings before that
RED; no assertion weakening. RepairSol1 leaves Session/198 tests,46 other
existing test files and the fixed fixture's entire no_event-through-tests suffix
unchanged. Python11 real-peer tests verify h2c/TLS responses, preparation/start
separation, stop/EOF/timeout/error diagnostics, recorded owned child disappearance,
peer exit and temporary-directory cleanup. This is fixture startup evidence;
it does not change the retained negative TLS/browser cleanup disposition
UNCONFIRMED_WITH_RETAINED_FAILURE or establish live group cleanup/activation.

Current additions: fixtureExpectedRED2, repairReadinessChanges2,
rootTestDiagnosticContractFailure1, authorPreAdoptionCorrection1; original
failedFreshGate1, authorStaticCheckerFailure1, rootCommandOverlap1/repair1 and
all predecessor counters remain, Astra2/2 exhausted. No historical failure or
unexecuted gate is treated as PASS. Independent repair review and fresh complete
gates remain required before local commit.
