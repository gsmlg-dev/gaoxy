# Implementation status

This page does not repeat per-release detail, so it does not go stale.

- **Current version and changes:** the newest file in [releases/](releases/);
  the root [README](../README.md) names the version this source targets.
- **What is supported, and where each surface stops:**
  [capabilities.md](capabilities.md).
- **Known problems and review backlog:** [suggest.md](../suggest.md), with the
  status of each item.
- **Open upstream requests:** search the tree for `TODO(upstream)`.

Not yet done, and not claimed by any release:

- Slow-peer, pressure, disconnect and sustained-load qualification. It is
  deferred to a dedicated environment.
- Production deployment acceptance.
- HTTP/3 graceful drain with GOAWAY, and a default WebSocket frame or message
  ceiling; see [http3.md](http3.md) and [websocket-limits.md](websocket-limits.md).

Milestone history through v0.5.0 is archived in
[history/implementation-status-2026-10.md](history/implementation-status-2026-10.md).
