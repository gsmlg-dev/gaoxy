# ADR 001: Compose transport hosts

Use Thousand Island for TCP/TLS and Abyss for UDP and later optional QUIC.
Keep source trees separate. Gaoxy owns validation, identities, lifecycle and
application contracts. This preserves backend ownership and tested public
operations; it leaves HTTP/3 application behavior outside Abyss.
