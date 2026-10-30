# Raw state backing diagnosis before repair12

The new scheduled raw network regression executes16 tests/2 failures. TCP and
verified TLS both observe a logically65-byte init-state binary retaining8192
bytes of backing at the next callback. The fixture also prepares4096-byte frames
before slicing65 bytes, avoiding incidental transport delivery boundaries and
OTP small-slice copying. Source remains the Astra11 production checkpoint.

Public API proof: slice-proof PASS demonstrates32768->65 backing reduction and
value equality through ordinary uncompressed ETF. resource-proof PASS proves
crypto hash contexts, atomics and ETS references remain usable, including inside
closures, and structured/improper-list state remains equal after roundtrip.

The [:local] alternative is NOT adopted: resource-local-proof FAILS with
ArgumentError invalid external representation at binary_to_term. local-leaves
finishes the diagnostic loop and records binary, crypto, atomics, ETS, mixed
map success, but all local closure representations fail decode. This is a
codec profile limitation in the actual qualified runtime, not a production
repair attempt and not passing local-ETF support. Ordinary ETF must not be
claimed node-identity invariant without an explicit check/decision.

Parent is selecting the bounded next implementation. No backing repair edits,
OTP/dependency changes, publication or external messages occurred. All commands
are terminal. Historical Sol2/Astra11 remains; new failing tests are agreed RED.
