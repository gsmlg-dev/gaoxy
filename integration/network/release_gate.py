#!/usr/bin/env python3
"""Five-transport production release acceptance in fixture-owned namespaces."""
import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile

from fixture import Child, Fixture, ROOT


def receive(client, expected):
    received = b""
    while len(received) < len(expected):
        chunk = client.recv(len(expected) - len(received))
        assert chunk, "stream closed before all bytes arrived"
        received += chunk
    assert received == expected, received


def peer_gate(bound, credentials):
    server = "192.0.2.10"
    for name in ("tcp", "tls"):
        with socket.create_connection((server, bound[name]["port"]), timeout=2) as raw:
            client = raw
            if name == "tls":
                context = ssl.create_default_context(cafile=str(credentials / "ca.pem"))
                context.set_alpn_protocols(["gaoxy-echo-v1"])
                client = context.wrap_socket(raw, server_hostname="localhost")
                assert client.selected_alpn_protocol() == "gaoxy-echo-v1"
            try:
                for chunk in (b"production-", b"release-", name.encode()):
                    client.sendall(chunk)
                receive(client, b"production-release-" + name.encode())
            finally:
                if client is not raw:
                    client.close()
        print("PASS release_" + name + "_fragmented_verified_echo", flush=True)

    for name, destinations in (("udp", [server]),
                               ("broadcast", ["255.255.255.255", "192.0.2.255"]),
                               ("multicast", ["239.192.74.1", "239.192.74.2"])):
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
            client.settimeout(2)
            client.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            client.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, b"eth0\0")
            local = subprocess.check_output(["ip", "-j", "addr", "show", "dev", "eth0"])
            address = next(info["local"] for info in json.loads(local)[0]["addr_info"]
                           if info["family"] == "inet")
            client.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(address))
            client.bind((address, 0))
            for destination in destinations:
                for payload in (b"", b"production-release-" + name.encode()):
                    client.sendto(payload, (destination, bound[name]["port"]))
                    received, peer = client.recvfrom(65536)
                    assert received == payload and peer == (server, bound[name]["port"]), (received, peer)
        print("PASS release_" + name + "_empty_nonempty_original_port", flush=True)


def shutdown_gate(bound):
    for name, endpoint in bound.items():
        kind = socket.SOCK_STREAM if name in ("tcp", "tls") else socket.SOCK_DGRAM
        with socket.socket(socket.AF_INET, kind) as probe:
            if kind == socket.SOCK_STREAM:
                probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            probe.bind((endpoint["address"], endpoint["port"]))
    print("PASS release_all_five_bindings_reusable_after_shutdown", flush=True)


def run_release(fixture):
    release = ROOT / "_build/prod/rel/gaoxy/bin/gaoxy"
    assert release.is_file(), "required production release has not been built"
    command = [sys.executable, str(Path(__file__).resolve())]
    with tempfile.TemporaryDirectory(prefix="gaoxy-five-release-") as directory:
        credentials = Path(directory)
        subprocess.run(["bash", str(ROOT / "scripts/generate-fixtures.sh"), directory], check=True)
        services = [
            {"id": "tcp", "transport": "tcp", "handler": "stream_echo", "ip": "192.0.2.10"},
            {"id": "tls", "transport": "tls", "handler": "stream_echo", "ip": "192.0.2.10",
             "tls": {"provider": "otp", "certfile": str(credentials / "cert.pem"),
                     "keyfile": str(credentials / "key.pem"), "alpn": ["gaoxy-echo-v1"]}},
            {"id": "udp", "transport": "udp", "handler": "datagram_echo", "ip": "192.0.2.10"},
            {"id": "broadcast", "transport": "udp", "mode": "broadcast",
             "handler": "datagram_echo", "ip": "0.0.0.0"},
            {"id": "multicast", "transport": "udp", "mode": "multicast",
             "handler": "datagram_echo", "ip": "0.0.0.0", "udp": {
                 "multicast_if": "eth0", "multicast_ttl": 1, "multicast_loop": True,
                 "memberships": [{"group": group, "interface": "eth0"}
                                 for group in ("239.192.74.1", "239.192.74.2")]}}
        ]
        config = credentials / "config.json"
        config.write_text(json.dumps({"version": 1, "services": services}))
        server = Child(fixture, fixture.server,
                       ["env", "GAOXY_CONFIG=" + str(config), str(release), "start"])
        line = server.wait(lambda item: item.startswith("GAOXY_READY "), timeout=15)
        ready = json.loads(line.removeprefix("GAOXY_READY "))
        bound = {endpoint["id"]: endpoint for endpoint in ready["services"]}
        assert set(bound) == {"tcp", "tls", "udp", "broadcast", "multicast"}, bound
        assert all(endpoint["port"] > 0 for endpoint in bound.values()), bound
        endpoints = credentials / "bound.json"
        endpoints.write_text(json.dumps(bound))
        count = 0
        for namespace in fixture.peers:
            peer = Child(fixture, namespace, command + ["--peer", str(endpoints), directory])
            for _ in range(5):
                print(peer.wait(lambda item: item.startswith("PASS "), timeout=15), flush=True)
                count += 1
            assert peer.process.wait(timeout=5) == 0
        server.process.terminate()
        assert server.process.wait(timeout=8) == 0, server.events
        probe = Child(fixture, fixture.server, command + ["--probe", str(endpoints)])
        print(probe.wait(lambda item: item.startswith("PASS "), timeout=5), flush=True)
        assert probe.process.wait(timeout=5) == 0
        count += 1
        print(json.dumps({"result": "PASS", "suite": "five_transport_release",
                          "count": count, "transports": 5, "independent_peers": 2}), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-privileged", action="store_true")
    parser.add_argument("--peer", nargs=2)
    parser.add_argument("--probe")
    options = parser.parse_args()
    if options.peer:
        endpoints, credentials = options.peer
        peer_gate(json.loads(Path(endpoints).read_text()), Path(credentials))
        return 0
    if options.probe:
        shutdown_gate(json.loads(Path(options.probe).read_text()))
        return 0
    if sys.platform != "linux" or not options.allow_privileged:
        print("BLOCKED_ENV: Linux and explicit --allow-privileged required", file=sys.stderr)
        return 77
    fixture = Fixture()
    try:
        for executable in ("ip", "nsenter", "setpriv", "openssl", "bash"):
            assert shutil.which(executable), "missing prerequisite: " + executable
        fixture.setup()
        run_release(fixture)
        return 0
    except Exception as error:
        print("FAIL " + repr(error), file=sys.stderr)
        for child in fixture.children:
            print("Child output:\n" + "\n".join(child.events[-20:]), file=sys.stderr)
        return 1
    finally:
        fixture.cleanup()


if __name__ == "__main__":
    sys.exit(main())
