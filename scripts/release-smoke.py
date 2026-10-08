#!/usr/bin/env python3
"""Portable standalone release smoke. Isolated broadcast/multicast are separate required gates."""
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
release = ROOT / "_build/prod/rel/gaoxy/bin/gaoxy"
with tempfile.TemporaryDirectory(prefix="gaoxy-release-") as directory:
    fixture = Path(directory)
    subprocess.run(["bash", str(ROOT / "scripts/generate-fixtures.sh"), directory], check=True)
    services = [
        {"id": "tcp", "transport": "tcp", "handler": "stream_echo"},
        {"id": "tls", "transport": "tls", "handler": "stream_echo", "tls": {
            "provider": "otp", "certfile": str(fixture / "cert.pem"),
            "keyfile": str(fixture / "key.pem"), "alpn": ["gaoxy-echo-v1"]}},
        {"id": "udp", "transport": "udp", "handler": "datagram_echo"},
    ]
    config = fixture / "config.json"
    ready = fixture / "ready.json"
    config.write_text(json.dumps({"version": 1, "services": services}))
    environment = dict(os.environ, GAOXY_CONFIG=str(config), GAOXY_READY_FILE=str(ready))
    with (fixture / "release.log").open("w+") as output:
        process = subprocess.Popen([str(release), "start"], env=environment, stdout=output, stderr=output)
        try:
            deadline = time.monotonic() + 15
            while not ready.exists():
                if process.poll() is not None or time.monotonic() >= deadline:
                    output.seek(0)
                    raise AssertionError("release readiness failed: " + output.read())
                time.sleep(0.01)  # Poll an actual child and its readiness artifact against one deadline.
            bound = {item["id"]: (item["address"], item["port"]) for item in json.loads(ready.read_text())["services"]}
            assert all(port > 0 for _, port in bound.values())
            with socket.create_connection(bound["tcp"], timeout=2) as client:
                client.sendall(b"release")
                assert client.recv(1024) == b"release"
            context = ssl.create_default_context(cafile=str(fixture / "ca.pem"))
            context.set_alpn_protocols(["gaoxy-echo-v1"])
            with socket.create_connection(bound["tls"], timeout=2) as raw:
                with context.wrap_socket(raw, server_hostname="localhost") as client:
                    assert client.selected_alpn_protocol() == "gaoxy-echo-v1"
                    client.sendall(b"release-tls")
                    assert client.recv(1024) == b"release-tls"
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
                client.settimeout(2)
                for packet in [b"", b"release-udp"]:
                    client.sendto(packet, bound["udp"])
                    received, peer = client.recvfrom(65536)
                    assert received == packet and peer == bound["udp"]
            process.terminate()
            assert process.wait(timeout=8) == 0
            for address in [bound["tcp"], bound["tls"]]:
                try:
                    socket.create_connection(address, timeout=0.3).close()
                except OSError:
                    pass
                else:
                    raise AssertionError("listener leaked after shutdown")
            print("PASS portable release TCP/TLS/UDP startup, traffic, shutdown; 3 transports")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
