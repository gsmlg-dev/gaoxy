# Phoenix WebSocket compatibility implementation plan

1. Add direct regressions for accepted Phoenix `log`/`code_reloader` options
   and retained rejection of unknown or invalid wire settings. Capture red.
2. Add only the two application policy keys; rerun the scoped WebSocket suite.
3. Add actual Phoenix socket/channel and session-backed LiveView wire tests.
   Verify escaped 300KiB composer persistence, HTTP reload/rejoin, fragmented
   delivery, outbound render and configured oversize rejection.
4. Document supported configuration and acceptance scope. Obtain independent
   review, preserve red/green evidence and hand final filenames/counts to the
   release owner. Do not commit or publish from this worker.
