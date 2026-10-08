#!/usr/bin/env python3
"""Independent CPython/OpenSSL validating TLS peer; no Gaoxy or OTP client code."""
import socket
import ssl
import sys

# Shared CI runners may need longer than two seconds for a verified handshake.
# This finite peer I/O budget is independent of the tested lifecycle deadlines.
IO_TIMEOUT = 5

port, ca = int(sys.argv[1]), sys.argv[2]
context = ssl.create_default_context(cafile=ca)
context.set_alpn_protocols(["gaoxy-echo-v1"])
with socket.create_connection(("127.0.0.1", port), timeout=IO_TIMEOUT) as raw:
    with context.wrap_socket(raw, server_hostname="localhost") as connection:
        assert connection.selected_alpn_protocol() == "gaoxy-echo-v1"
        if len(sys.argv) > 3 and sys.argv[3] == "interactive":
            print("READY_TLS", flush=True)
            for command in sys.stdin:
                if command.strip() == "close":
                    break
                value = command.strip().encode()
                connection.sendall(value)
                received = b""
                while len(received) < len(value):
                    chunk = connection.recv(len(value) - len(received))
                    assert chunk, "TLS closed before admitted reply"
                    received += chunk
                assert received == value
                print("PASS " + command.strip(), flush=True)
            print("CLOSED_TLS", flush=True)
            raise SystemExit(0)
        connection.sendall(b"frag")
        connection.sendall(b"mented\n")
        received = b""
        while len(received) < len(b"fragmented\n"):
            received += connection.recv(1024)
        assert received == b"fragmented\n", received
for hostname, trusted in [("wrong.example", True), ("localhost", False)]:
    wrong_ca = sys.argv[3] if len(sys.argv) > 3 else None
    invalid = ssl.create_default_context(cafile=ca if trusted else wrong_ca)
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=IO_TIMEOUT) as raw:
            invalid.wrap_socket(raw, server_hostname=hostname)
    except ssl.SSLCertVerificationError:
        pass
    else:
        raise AssertionError("invalid trust/hostname unexpectedly succeeded")
print("PASS TLS exchange, ALPN, hostname rejection, CA rejection; " + ssl.OPENSSL_VERSION)
