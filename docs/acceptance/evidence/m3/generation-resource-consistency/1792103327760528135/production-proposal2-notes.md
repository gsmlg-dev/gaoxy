# Generation resource consistency production proposal 2

Task: resource_consistency_implementation
Status: DONE (pre-adoption proposal correction only)
Assignment: direct follow-up; baseline remains the previously verified 8160e8bb6d7f55dc836b1aed0403cc2304a539bf in /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation.

The original proposal1 patch and notes are preserved byte-for-byte. Proposal2 makes exactly one source correction: MapSet.equal?(MapSet.new(supplied), MapSet.new(expected)) replaces structural == so resource membership comparison explicitly uses the public MapSet API required by the normative algorithm. All other patch bytes are unchanged.

Unavailable endpoint modules: compiled_resources/2 currently uses Code.ensure_loaded?(module) and function_exported?(module, :resources, 1). If loading returns false, the optional callback cannot be exported, so the endpoint contributes []. This preserves the stated collector boundary: ordinary atom endpoints are ensured loaded and optional resources/1 is read when available; absent callbacks contribute []. The consistency validator does not introduce endpoint availability validation or reinitialize/recompile targets. Existing compile_route validates endpoint loadability for compiled routes, while Store generation endpoint checks retain their existing behavior and precedence. No new unavailable-module policy is added in this correction.

Verification: Python confirmed exactly one replacement in proposal1 and wrote only the two assigned /tmp proposal2 artifacts. No repository access/write, runtime/test/mix/Nix/formatter/build command, or Git command occurred in this follow-up. Adoption, compilation, GREEN verification, and independent review remain NOT RUN by this worker and owned by root. All commands finished synchronously.

Counters: this is pre-adoption source review correction, not a failed GREEN or runtime repair-and-validation round. New runtime repair rounds remain 0. Preserve inherited 24 failed GREEN attempts / 27 ordered repair events and exhausted Astra 2/2 counters. No escalation or external decision is required.
