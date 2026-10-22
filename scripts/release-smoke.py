#!/usr/bin/env python3
"""Portable standalone release smoke. Isolated broadcast/multicast are separate required gates."""
import contextlib
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


def exchange(client, payload):
    client.sendall(payload)
    received = b""
    while len(received) < len(payload):
        chunk = client.recv(len(payload) - len(received))
        assert chunk, "admitted stream closed before its response"
        received += chunk
    assert received == payload


def wait_for_readiness(process, ready, output):
    deadline = time.monotonic() + 15
    while True:
        if process.poll() is not None or time.monotonic() >= deadline:
            output.seek(0)
            raise AssertionError("release readiness failed: " + output.read())
        try:
            return json.loads(ready.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            time.sleep(0.01)  # Wait for complete JSON within the same readiness deadline.


def wait_for_admission_barrier(process, addresses):
    pending = set(addresses)
    deadline = time.monotonic() + 2
    while pending:
        assert process.poll() is None, "release exited with admitted streams still open"
        assert time.monotonic() < deadline, f"listeners still accepting during shutdown: {pending}"
        for address in tuple(pending):
            try:
                socket.create_connection(address, timeout=0.1).close()
            except ConnectionRefusedError:
                pending.remove(address)
            except ConnectionResetError:
                pass
        if pending:
            time.sleep(0.01)  # Poll observed listener state, not an admission assumption.


def main():
    for app in ["gaoxy_test", "ex_unit"]:
        assert not list((release.parent.parent / "lib").glob(app + "-[0-9]*")), (
            f"test infrastructure leaked into standalone release: {app}"
        )
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
                bound = {item["id"]: (item["address"], item["port"]) for item in wait_for_readiness(process, ready, output)["services"]}
                assert all(port > 0 for _, port in bound.values())
                with contextlib.ExitStack() as admitted:
                    tcp = admitted.enter_context(socket.create_connection(bound["tcp"], timeout=2))
                    exchange(tcp, b"release")
                    context = ssl.create_default_context(cafile=str(fixture / "ca.pem"))
                    context.set_alpn_protocols(["gaoxy-echo-v1"])
                    raw = admitted.enter_context(socket.create_connection(bound["tls"], timeout=2))
                    tls = admitted.enter_context(context.wrap_socket(raw, server_hostname="localhost"))
                    assert tls.selected_alpn_protocol() == "gaoxy-echo-v1"
                    exchange(tls, b"release-tls")
                    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
                        client.settimeout(2)
                        for packet in [b"", b"release-udp"]:
                            client.sendto(packet, bound["udp"])
                            received, peer = client.recvfrom(65536)
                            assert received == packet and peer == bound["udp"]
                    # Successful responses above prove both handlers were admitted.
                    # SIGTERM exercises the standalone Application.prep_stop path.
                    process.terminate()
                    wait_for_admission_barrier(process, [bound["tcp"], bound["tls"]])
                    exchange(tcp, b"admitted-tcp-during-shutdown")
                    exchange(tls, b"admitted-tls-during-shutdown")
                    assert process.poll() is None, "release exited before admitted clients closed"
                assert process.wait(timeout=8) == 0
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as replacement:
                    replacement.bind(bound["udp"])
                for address in [bound["tcp"], bound["tls"]]:
                    try:
                        socket.create_connection(address, timeout=0.3).close()
                    except OSError:
                        pass
                    else:
                        raise AssertionError("listener leaked after shutdown")
                print("PASS portable release TCP/TLS/UDP startup, traffic, admitted TCP/TLS replies "
                      "after SIGTERM admission barrier, VM exit, UDP endpoint reuse; 3 transports")
            except BaseException:
                output.seek(0)
                print("Release diagnostic:\n" + output.read(), flush=True)
                raise
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)


if __name__ == "__main__":
    main()
