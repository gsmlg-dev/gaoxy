# Browser initial health GOAWAY timing repair — design and plan

Browser5 actually joined FAIL exit1 with one complete positive case. The first
negative setup waited20s for physical EOF after the healthy Probe had already
released its stream. Public http_runtime0.21.10 then has an idle30s drain timer;
immediate EOF is not its GOAWAY contract. No new upstream defect is established.

Recommended bounded repair: the dedicated negative peer sends the same real
GOAWAY(last_stream equal to the actual health stream,code0) while that single
HEAD is active, before its normal response is completed. Reuse the base peer
command/wire implementation under its existing reentrant lock, then its normal
HEAD response. The managed owner can finish the accepted stream and close when
the real original releases while draining. The canonical driver consumes and
strictly binds the actual GOAWAY command to that health connection/stream;
keep original20s real physical EOF, worker join, exactly1 health request, actual
certificate rotation, wrong-CA/name browser, G/T/Service and no-replay assertions.
No timer extension, synthetic EOF, alternate browser, product change or new
close primitive. This is a changed fixture timing contract, not unchanged suite
bytes. All previous receipts remain tied to their original candidates.

1. Authenticate browser5 receipts/log/artifacts and the full198-source candidate5.
2. Obtain independent SPEC/CODE source review of health-GOAWAY ordering and the
   exact patch; retain any objections. Root alone adopts repository changes.
3. Record exact old/new source hashes, patch/reviews and one ordered root repair
   event, preserving24 failed GREEN attempts and exhausted Astra2/2.
4. Freeze a new198-source candidate, explicitly reuse candidate3's25 unchanged
   command gates/1752 test invocations, and freshly run the complete actual
   Chrome/CDP three-case suite with every original assertion/deadline retained.
5. Diagnose failures. On pass, aggregate evidence, synchronize stage/parent docs,
   independent closure, source/index/commit audit and local conventional commit.
   No release/deployment, production/Vault/public management or E2E changes.

The baseline native peername einval errors remain visible in browser5 host.log;
they predate the current patch and are not used to explain the GOAWAY failure.
