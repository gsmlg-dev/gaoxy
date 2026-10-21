# Internal request #6 implementation plan

1. Add failing public upgrade-configuration and actual Phoenix channel tests;
   verify that a 300 KiB message is rejected by the current 256 KiB message limit.
2. Derive the omitted message limit from the merged frame limit. Preserve explicit
   message limits, validation, and the existing admission clamp.
3. Run focused option, native WebSocket, and Phoenix channel regressions with
   nonzero executed counts; retain commands, exits, and logs under
   `.audit/internal-requests/6/`.
4. Obtain independent review and perform fresh final verification before the
   parent commits and publishes the coordinated package cohort.
