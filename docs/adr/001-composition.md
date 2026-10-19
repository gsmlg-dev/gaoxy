# ADR 001: Compose transport hosts

Backend update — 2026-10-19: current source replaces Thousand Island with Hell,
its fork, for TCP/TLS. The [dependency audit](../dependency-audit.md) records the
exact revision. This supersedes the original backend selection below; ownership
and composition remain unchanged. Published v0.4.0 retains Thousand Island.

## Original decision

Use Thousand Island for TCP/TLS and Abyss for UDP and later optional QUIC.
Keep source trees separate. Gaoxy owns validation, identities, lifecycle and
application contracts. This preserves backend ownership and tested public
operations; it leaves HTTP/3 application behavior outside Abyss.
