# Native H1 pressure mailbox syntax author1

DONE. Sole source syntax correction adds parentheses around the full if expression as assert second argument; count<=64 and all diagnostic content remain exact. Two source lines changed, two characters added.

Before SHA256 `0ca3fd32b2204cc02825311f3e1ec53e1bb90ca2a6051bdffe8ec725f1a62555`.
After SHA256 `547616fd845193b8688d97cf9a9740a93105c4539f7242bdabfbfaa21590e892`.

Exact inverse restores the whole source. Formatter/compiler/runtime/tests/browser/Git/review NOT RUN. One tooling incident: pre-edit guard expected three trailing newlines, actual formatted block had two; original SHA preserved before corrected guard/edit. No new runtime/Solround, same diagnostic repair3. All synchronous commands finished; source immutable after DONE; custody returned to root. Exact diff is in the JSON report.
