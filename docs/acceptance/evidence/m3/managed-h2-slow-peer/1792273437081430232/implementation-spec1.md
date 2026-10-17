# Managed-H2 slow-peer focused implementation/evidence SPEC1

**PASS_FOCUSED4_ONLY — actual4 executed/0 failures/0 skipped/0 excluded, exit0, no warnings; no findings.**

Command/cwd and403 before/after source pins match frozen candidate2 (`b4b66dfeeef36691a4f39ea5744702eb0dd295f787618995326876d73368ff24`). Current403 source/5 owned/8 docs/12 dependency pins also match. Raw first1.log hash matches its command receipt; audit SHA256 matches `641ec49be680f9dfd6daff40fba4efb51439f031f4b2fb5436bc88ebd97234d2`. Collector reports actual normal joined exit0, no force, remaining process group/descendants or exhausted reap deadline.

Independently parsed all four actual raw receipts, covering fixed/group × h2c/TLS-H2. Each has native streams1/3/5, distinct original request/completion/token/worker/guardian identities, distinct upstream streams on one accepted connection, exact65,537-byte upload and response digest `2deb0bd2129a9d3aed91e3cff58b3993752be549642890a3e853ec1065f9b617`, and exact one-byte healthy results. Uploadhold is actual1 byte/window0 with positive connection credit; responsehold is actual16,384 unconsumed/window0. At overlap3, native stream1 has49,151 queued+16,384 delivered wire bytes and stream3 has a16,384-byte pending DATA write with zero credit.

Actual order records healthy completion before either release, upload-only65,536 allowance release and completion while stream3 remains pending, then actual consumes16,384×4+1. Every consume records matching held-before, bytes, zero after and exact received prefix hash. Raw checkpoints record1→2→3→2→1→0 original token/cleanup/group counts; request0 occurs with native state still observable. Client/native joins and final peer1 accept/3 application requests (group plus1 health) are consistent. Executed source assertions additionally enforce original actor/pin and existing normal fixture cleanup; aggregate fixture receipts are not full actor traces.

All recorded normalized resource/token/pin/payload/Service capacities, parser/output/stream wire/pending-write/mailbox64 bounds hold. Sampled maxima are labelled sampled and kept distinct from persistent Service retained_high_water. Fixed minimum checkpoint remaining is9,875/9,624ms; group29,808/29,768ms, from actual original Exchange deadlines. Local5s barrier cap and unchanged write2s remain separate.

- group/h2c: raw first1.log:8; samples24, sampled retained223814653, persistent high-water229778429, Service cap1073741824.
- fixed/h2c: raw first1.log:12; samples21, sampled retained202712872, persistent high-water202712874, Service cap536870912.
- fixed/http2: raw first1.log:16; samples48, sampled retained202712899, persistent high-water202712901, Service cap536870912.
- group/http2: raw first1.log:20; samples38, sampled retained223814653, persistent high-water229778429, Service cap1073741824.

Fresh94, final static checks, Python11, ordinary browser2/four fresh root image opens, final review and local commit/custody remain **NOT RUN**. Task6/Task5/M3 remain OPEN. Reviewer ran no runtime/Git/imports or repository mutations; only static evidence parsing/hash checks and the two requested `/tmp` reports.

One new tool incident: initial metadata display truncated324 tokens; later compact projections and comprehensive assertions completed without truncation. Counter12/profile sourceSolrepair1/runtimefailed0/inherited H1Sol4/Astra2/2 preserved. All commands finished; ownership returned to root.
