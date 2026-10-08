#!/usr/bin/env python3
"""Gaoxy UDP ingress and membership gates in fixture-owned Linux namespaces.

Topology/peer helpers adapted from gsmlg-dev/abyss at 9b710e6480900e16e304f40e63623aff8c922e19.
See LICENSE.abyss for the retained MIT notice.

Only setup/teardown commands require sudo. Network participants drop to the
invoking uid/gid before running Python or BEAM. All packet assertions are hard
failures; missing namespace privilege is a separately reported BLOCKED gate.
"""
import argparse
import base64
import contextlib
import errno
import json
import os
import queue
import shutil
import socket
import struct
import subprocess
import sys
import threading
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GROUPS = {4: ("239.192.74.1", "239.192.74.2"), 6: ("ff02::114", "ff02::115")}
PORTS = {4: 38741, 6: 38742}
OBSERVER_PORTS = {4: 38743, 6: 38744}
PAYLOAD_SIZES = set()


def encode(payload):
    # A marker also represents empty payloads in the whitespace control protocol.
    return base64.b64encode(payload).decode() or "-"


def peer_worker():
    sockets = {}
    try:
        for line in sys.stdin:
            request = json.loads(line)
            operation = request["op"]
            try:
                label = request.get("label")
                if operation == "open":
                    family = request["family"]
                    endpoint = socket.socket(socket.AF_INET if family == 4 else socket.AF_INET6, socket.SOCK_DGRAM)
                    endpoint.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                    endpoint.settimeout(2)
                    interface = request.get("interface", "eth0")
                    index = socket.if_nametoindex(interface)
                    # Membership alone does not strictly filter IPv6 same-group
                    # traffic arriving/looping through another local interface.
                    # These independent observers explicitly select their device.
                    endpoint.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE,
                                        interface.encode() + b"\0")
                    if family == 4:
                        endpoint.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
                        endpoint.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(request["source"]))
                        endpoint.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, request.get("ttl", 1))
                        endpoint.setsockopt(socket.IPPROTO_IP, 12, 1)  # Linux IP_RECVTTL
                        endpoint.setsockopt(socket.IPPROTO_IP, 49, 0)  # Linux IP_MULTICAST_ALL
                        for group in request.get("groups", []):
                            endpoint.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP,
                                                socket.inet_aton(group) + socket.inet_aton(request["source"]))
                        bind = (request.get("bind", "0.0.0.0"), request.get("port", 0))
                    else:
                        endpoint.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
                        endpoint.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_IF, index)
                        endpoint.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_MULTICAST_HOPS, request.get("ttl", 1))
                        endpoint.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_RECVHOPLIMIT, 1)
                        try:
                            endpoint.setsockopt(socket.IPPROTO_IPV6, 29, 0)  # Linux IPV6_MULTICAST_ALL
                        except OSError as error:
                            if error.errno != errno.ENOPROTOOPT:
                                raise
                            # Kernels before 4.20 lack this observer option.
                            # SO_BINDTODEVICE above and wire isolation assertions
                            # still enforce interface selection on this platform.
                            print("PEER_CAP IPV6_MULTICAST_ALL unavailable; SO_BINDTODEVICE active",
                                  file=sys.stderr, flush=True)
                        for group in request.get("groups", []):
                            endpoint.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_JOIN_GROUP,
                                                socket.inet_pton(socket.AF_INET6, group) + struct.pack("@I", index))
                        bind = (request.get("bind", "::"), request.get("port", 0), 0, 0)
                    endpoint.bind(bind)
                    sockets[label] = (endpoint, family, index)
                    result = endpoint.getsockname()
                elif operation == "send":
                    endpoint, family, index = sockets[label]
                    payload = base64.b64decode(request["payload"]) if request["payload"] != "-" else b""
                    destination = (request["address"], request["port"])
                    if family == 6:
                        destination += (0, index)
                    result = endpoint.sendto(payload, destination)
                    assert result == len(payload), "partial datagram send"
                elif operation in ("recv", "none"):
                    endpoint, family, _ = sockets[label]
                    endpoint.settimeout(request.get("timeout", 2 if operation == "recv" else 0.15))
                    try:
                        payload, ancillary, flags, peer = endpoint.recvmsg(65536, 256)
                        assert not flags & socket.MSG_TRUNC, "truncated datagram"
                        ttl = None
                        for level, kind, value in ancillary:
                            if (level, kind) in ((socket.IPPROTO_IP, socket.IP_TTL),
                                                (socket.IPPROTO_IPV6, socket.IPV6_HOPLIMIT)):
                                ttl = struct.unpack("@i", value)[0]
                        assert operation != "none", f"unexpected packet {payload!r} from {peer!r}"
                        result = {"payload": encode(payload), "peer": peer, "ttl": ttl}
                    except socket.timeout:
                        assert operation == "none", "required packet was not delivered before deadline"
                        result = True
                elif operation == "close":
                    sockets.pop(label)[0].close()
                    result = True
                elif operation == "stop":
                    print(json.dumps({"ok": True}), flush=True)
                    return
                else:
                    raise AssertionError(f"unknown operation {operation}")
                print(json.dumps({"ok": result}), flush=True)
            except Exception as error:
                print(json.dumps({"error": repr(error)}), flush=True)
    finally:
        for endpoint, _, _ in sockets.values():
            endpoint.close()


class Child:
    def __init__(self, fixture, namespace, command, wire=False):
        drop = [shutil.which("setpriv"), f"--reuid={os.getuid()}", f"--regid={os.getgid()}", "--init-groups"]
        environment = [shutil.which("env"), f"PATH={os.environ['PATH']}", f"HOME={os.environ['HOME']}", "MIX_ENV=dev"]
        for key in ("MIX_HOME", "HEX_HOME", "MIX_BUILD_PATH", "ERL_FLAGS", "ELIXIR_ERL_OPTIONS", "GAOXY_UDP_BACKEND", "GAOXY_NETWORK_IPV6"):
            if key in os.environ:
                environment.append(f"{key}={os.environ[key]}")
        if os.environ.get("CI"):
            environment.append("CI=true")
        argv = fixture.privileged + ["ip", "netns", "exec", namespace] + drop + environment + command
        self.process = subprocess.Popen(argv, cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, bufsize=1)
        self.lines = queue.Queue()
        self.events = []
        self.wire = wire
        self.serial = 0
        self.thread = threading.Thread(target=self._read, daemon=True)
        self.thread.start()
        fixture.children.append(self)

    def _read(self):
        for line in self.process.stdout:
            self.lines.put(line.rstrip("\n"))
        self.lines.put(None)

    def wait(self, predicate, timeout=15):
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            assert remaining > 0, f"child deadline expired; output={self.events[-15:]}"
            try:
                line = self.lines.get(timeout=remaining)
            except queue.Empty:
                raise AssertionError(f"child deadline expired; output={self.events[-15:]}")
            assert line is not None, f"child exited {self.process.poll()}; output={self.events[-15:]}"
            self.events.append(line)
            if predicate(line):
                return line

    def rpc(self, **request):
        self.process.stdin.write(json.dumps(request) + "\n")
        self.process.stdin.flush()
        line = self.wait(lambda item: item.startswith('{"'), timeout=5)
        result = json.loads(line)
        assert "error" not in result, f"{request['op']} {request.get('label')}: {result.get('error')}"
        return result["ok"]

    def command(self, *arguments):
        if arguments[0] == "SEND":
            PAYLOAD_SIZES.add(len(base64.b64decode(arguments[-1])) if arguments[-1] != "-" else 0)
        self.serial += 1
        marker = str(self.serial)
        self.process.stdin.write(" ".join([marker] + [str(arg) for arg in arguments]) + "\n")
        self.process.stdin.flush()
        line = self.wait(lambda item: item.startswith(f"WIRE OK {marker}") or item.startswith(f"WIRE ERROR {marker}"))
        assert line == f"WIRE OK {marker}", line

    def received(self, family, payload, timeout=2):
        marker = f"WIRE RX{family} {encode(payload)}"
        if marker in self.events:
            self.events.remove(marker)
            return
        self.wait(lambda line: line == marker, timeout)
        self.events.remove(marker)

    def assert_no_received(self, family, payload, timeout=0.2):
        marker = f"WIRE RX{family} {encode(payload)}"
        assert marker not in self.events, f"unexpected Gaoxy delivery: {marker}"
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                line = self.lines.get(timeout=deadline - time.monotonic())
            except queue.Empty:
                return
            assert line is not None, "Gaoxy exited during negative delivery gate"
            self.events.append(line)
            assert line != marker, f"unexpected Gaoxy delivery: {marker}"

    def stop(self):
        if self.process.poll() is None:
            with contextlib.suppress(Exception):
                if self.wire:
                    self.command("STOP")
                else:
                    self.rpc(op="stop")
            with contextlib.suppress(subprocess.TimeoutExpired):
                self.process.wait(timeout=3)
        if self.process.poll() is None:
            self.process.terminate()
            with contextlib.suppress(subprocess.TimeoutExpired):
                self.process.wait(timeout=2)
        if self.process.poll() is None:
            self.process.kill()
            self.process.wait(timeout=2)


class Fixture:
    def __init__(self):
        self.prefix = "gaoxy-udp-" + uuid.uuid4().hex[:8]
        self.namespaces = []
        self.children = []
        self.privileged = [] if os.geteuid() == 0 else ["sudo", "-n"]
        self.server = self.prefix + "-server"
        self.peers = [self.prefix + "-peer1", self.prefix + "-peer2"]
        self.fabric = self.prefix + "-fabric"

    def setup_command(self, *arguments):
        subprocess.run(self.privileged + list(arguments), check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def setup(self):
        for name in [self.fabric, self.server] + self.peers:
            self.setup_command("ip", "netns", "add", name)
            self.namespaces.append(name)
            self.setup_command("ip", "-n", name, "link", "set", "lo", "up")
        for network in range(2):
            bridge = f"br{network}"
            self.setup_command("ip", "-n", self.fabric, "link", "add", bridge, "type", "bridge", "mcast_snooping", "0")
            self.setup_command("ip", "-n", self.fabric, "link", "set", bridge, "up")
            for endpoint, name in enumerate([self.server] + self.peers):
                fabric_end, node_end = f"f{network}{endpoint}", f"n{network}{endpoint}"
                interface = f"eth{network}"
                self.setup_command("ip", "-n", self.fabric, "link", "add", fabric_end, "type", "veth", "peer", "name", node_end)
                self.setup_command("ip", "-n", self.fabric, "link", "set", fabric_end, "master", bridge)
                self.setup_command("ip", "-n", self.fabric, "link", "set", fabric_end, "up")
                self.setup_command("ip", "-n", self.fabric, "link", "set", node_end, "netns", name)
                self.setup_command("ip", "-n", name, "link", "set", node_end, "name", interface)
                self.setup_command("ip", "-n", name, "link", "set", interface, "up")
                ipv4 = f"{'192.0.2' if network == 0 else '198.51.100'}.{10 + endpoint}"
                self.setup_command("ip", "-n", name, "addr", "add", ipv4 + "/24", "broadcast", "+", "dev", interface)
                self.setup_command("ip", "-n", name, "-6", "addr", "add", f"fd00:ab:74:{network}::{10 + endpoint}/64", "dev", interface, "nodad")
                if network == 0:
                    self.setup_command("ip", "-n", name, "route", "add", "224.0.0.0/4", "dev", interface)
                    self.setup_command("ip", "-n", name, "route", "add", "255.255.255.255/32", "dev", interface)
                    self.setup_command("ip", "-n", name, "-6", "route", "add", "ff00::/8", "dev", interface)

    def cleanup(self):
        for child in reversed(self.children):
            child.stop()
        for name in reversed(self.namespaces):
            with contextlib.suppress(subprocess.CalledProcessError):
                self.setup_command("ip", "netns", "del", name)


def open_peer(peer, label, family, endpoint, port=0, groups=(), network=0, bind=None):
    source = f"{'192.0.2' if network == 0 else '198.51.100'}.{endpoint}"
    options = dict(op="open", label=label, family=family, source=source, port=port,
                   groups=list(groups), interface=f"eth{network}")
    if bind is not None:
        options["bind"] = bind
    return peer.rpc(**options)


def send(peer, label, address, port, payload):
    PAYLOAD_SIZES.add(len(payload))
    return peer.rpc(op="send", label=label, address=address, port=port, payload=encode(payload))


def expect(peer, label, payload, source=None, source_port=None, ttl=None):
    PAYLOAD_SIZES.add(len(payload))
    packet = peer.rpc(op="recv", label=label)
    assert packet["payload"] == encode(payload), packet
    if source is not None:
        assert packet["peer"][0] == source, packet
    if source_port is not None:
        assert packet["peer"][1] == source_port, packet
    if ttl is not None:
        assert packet["ttl"] == ttl, packet
    return packet


def addressed(peer, label, family, port, destination, destination_port, payload, interface="eth0"):
    request = {"address": destination, "port": destination_port,
               "payload": base64.b64encode(payload).decode(), "interface": interface}
    trigger = b"SEND " + json.dumps(request).encode()
    local = "192.0.2.10" if family == 4 else "fd00:ab:74:0::10"
    send(peer, label, local, port, trigger)


def run_gates(fixture, ipv6):
    families = (4, 6) if ipv6 else (4,)
    os.environ["GAOXY_UDP_BACKEND"] = os.environ.get("GAOXY_UDP_BACKEND", "inet")
    os.environ["GAOXY_NETWORK_IPV6"] = "1" if ipv6 else "0"
    assert os.environ["GAOXY_UDP_BACKEND"] in ("inet", "socket")
    command = [sys.executable, str(Path(__file__).resolve()), "--peer"]
    peers = [Child(fixture, namespace, command) for namespace in fixture.peers]
    broadcast_port = 38740
    server = Child(fixture, fixture.server,
                   [shutil.which("mix"), "run", "--no-compile", "--no-deps-check",
                    "integration/network/server.exs", str(PORTS[4]), str(PORTS[6]),
                    str(broadcast_port)], wire=True)
    server.wait(lambda line: line == "WIRE READY", timeout=30)
    passes = []
    epoch = uuid.uuid4().hex.encode()

    def passed(name):
        passes.append(name)
        print("PASS " + name, flush=True)

    for number, peer in enumerate(peers, 11):
        open_peer(peer, "tx4", 4, number)
        for family in families:
            if family == 6:
                open_peer(peer, "tx6", 6, number, bind=f"fd00:ab:74:0::{number}")
            open_peer(peer, f"rx{family}", family, number, PORTS[family], GROUPS[family])

    for destination in ("255.255.255.255", "192.0.2.255"):
        for sender in peers:
            payload = b"broadcast:" + epoch + destination.encode()
            send(sender, "tx4", destination, broadcast_port, payload)
            server.received(4, payload)
            expect(sender, "tx4", b"reply:" + payload, source="192.0.2.10",
                   source_port=broadcast_port)
        passed("broadcast_" + destination + "_two_senders_original_port_reply")

    for family in families:
        for group in GROUPS[family]:
            payload = b"multicast:" + epoch + group.encode()
            send(peers[0], f"tx{family}", group, PORTS[family], payload)
            server.received(family, payload)
            expect(peers[0], f"tx{family}", b"reply:" + payload, source_port=PORTS[family])
            for peer in peers:
                expect(peer, f"rx{family}", payload)
        passed(f"ipv{family}_two_groups_two_independent_subscribers")

        group = GROUPS[family][0]
        server.command("LEAVE", family, group, "eth0")
        server.command("LEAVE", family, group, "eth0")
        removed = b"removed:" + epoch + bytes([family])
        send(peers[0], f"tx{family}", group, PORTS[family], removed)
        for peer in peers:
            expect(peer, f"rx{family}", removed)
        server.assert_no_received(family, removed)
        server.command("JOIN", family, group, "eth0")
        server.command("JOIN", family, group, "eth0")
        rejoined = b"rejoined:" + epoch + bytes([family])
        send(peers[0], f"tx{family}", group, PORTS[family], rejoined)
        server.received(family, rejoined)
        expect(peers[0], f"tx{family}", b"reply:" + rejoined, source_port=PORTS[family])
        for peer in peers:
            expect(peer, f"rx{family}", rejoined)
        passed(f"ipv{family}_duplicate_join_absent_leave_rejoin_delivery")

        server.command("LIMIT", family)
        server.command("ROLLBACK", family)
        passed(f"ipv{family}_membership_limit_and_failed_startup_rollback")

        server.command("JOIN", family, group, "eth1")
        open_peer(peers[0], f"alt_tx{family}", family, 11, network=1,
                  bind="fd00:ab:74:1::11" if family == 6 else None)
        second = b"second-interface:" + epoch + bytes([family])
        send(peers[0], f"alt_tx{family}", group, PORTS[family], second)
        server.received(family, second)
        expect(peers[0], f"alt_tx{family}", b"reply:" + second, source_port=PORTS[family])
        server.command("LEAVE", family, group, "eth1")
        passed(f"ipv{family}_same_group_membership_on_second_interface")

        server.command("PAUSE", family)
        paused = b"paused:" + epoch + bytes([family])
        send(peers[0], f"tx{family}", group, PORTS[family], paused)
        for peer in peers:
            expect(peer, f"rx{family}", paused)
        # Prove actual paused reception/drop before resume; kernel-queued packets
        # are otherwise allowed to survive withheld receive credit.
        server.command("DROPPED", family)
        server.assert_no_received(family, paused)
        server.command("RESUME", family)
        resumed = b"resumed:" + epoch + bytes([family])
        send(peers[0], f"tx{family}", group, PORTS[family], resumed)
        server.received(family, resumed)
        expect(peers[0], f"tx{family}", b"reply:" + resumed, source_port=PORTS[family])
        for peer in peers:
            expect(peer, f"rx{family}", resumed)
        passed(f"ipv{family}_pause_retains_membership_and_original_reply_port")

    send(peers[0], "tx4", "192.0.2.10", PORTS[4], b"")
    server.received(4, b"")
    expect(peers[0], "tx4", b"reply:", source="192.0.2.10", source_port=PORTS[4])
    passed("empty_datagram_and_independent_broadcast_multicast_listeners")

    for family in families:
        kept, removed = GROUPS[family]
        server.command("LEAVE", family, removed, "eth0")
        server.command("RESTART", family)
        payload = b"restarted-kept:" + epoch + bytes([family])
        send(peers[0], f"tx{family}", kept, PORTS[family], payload)
        server.received(family, payload)
        expect(peers[0], f"tx{family}", b"reply:" + payload, source_port=PORTS[family])
        for peer in peers:
            expect(peer, f"rx{family}", payload)
        payload = b"restarted-removed:" + epoch + bytes([family])
        send(peers[0], f"tx{family}", removed, PORTS[family], payload)
        for peer in peers:
            expect(peer, f"rx{family}", payload)
        server.assert_no_received(family, payload)
        server.command("JOIN", family, removed, "eth0")
        passed(f"ipv{family}_desired_membership_restart_wire_stale_handle_sibling_isolation")

    # All outgoing traffic uses handler actions through Gaoxy's existing socket.
    # Separate observer ports prevent multicast input from recursively replying.
    for number, peer in enumerate(peers, 11):
        open_peer(peer, "broadcast-out", 4, number, OBSERVER_PORTS[4] + 20)
    for destination in ("255.255.255.255", "192.0.2.255"):
        payload = b"outgoing-broadcast:" + epoch + destination.encode()
        addressed(peers[0], "tx4", 4, broadcast_port, destination,
                  OBSERVER_PORTS[4] + 20, payload)
        for peer in peers:
            expect(peer, "broadcast-out", payload, source="192.0.2.10",
                   source_port=broadcast_port)
        peers[0].rpc(op="none", label="tx4")
        passed("outgoing_broadcast_" + destination + "_source_port")

    local_observer = Child(fixture, fixture.server, command)
    for family in families:
        group = GROUPS[family][0]
        observer_port = OBSERVER_PORTS[family]
        for number, peer in enumerate(peers, 11):
            open_peer(peer, f"out{family}", family, number, observer_port, [group])
            open_peer(peer, f"alt_out{family}", family, number, observer_port,
                      [group], network=1)
        open_peer(local_observer, f"out{family}", family, 10, observer_port, [group])
        open_peer(local_observer, f"alt_out{family}", family, 10, observer_port,
                  [group], network=1)

        if family == 6 and os.environ["GAOXY_UDP_BACKEND"] == "socket":
            addressed(peers[0], "tx6", 6, PORTS[6], group, observer_port, b"scoped-negative")
            server.wait(lambda line: line == "WIRE SEND 6 {:error, {:unsupported_capability, :scoped_sockaddr_send, :socket}}")
            for peer in peers + [local_observer]:
                peer.rpc(op="none", label="out6")
            passed("ipv6_socket_scoped_send_explicit_unsupported")
            continue

        for payload in (b"", b"outgoing-multicast:" + epoch + bytes([family])):
            addressed(peers[0], f"tx{family}", family, PORTS[family], group,
                      observer_port, payload)
            for peer in peers + [local_observer]:
                expect(peer, f"out{family}", payload, source_port=PORTS[family], ttl=7)
                peer.rpc(op="none", label=f"alt_out{family}")
        passed(f"ipv{family}_outgoing_ttl_hops_loopback_enabled_first_interface_empty")

        payload = b"outgoing-second-interface:" + epoch + bytes([family])
        addressed(peers[0], f"tx{family}", family, PORTS[family] + 10, group,
                  observer_port, payload, interface="eth1")
        for peer in peers:
            expect(peer, f"alt_out{family}", payload, source_port=PORTS[family] + 10, ttl=9)
            peer.rpc(op="none", label=f"out{family}")
        local_observer.rpc(op="none", label=f"alt_out{family}")
        local_observer.rpc(op="none", label=f"out{family}")
        passed(f"ipv{family}_outgoing_second_interface_ttl_hops_loopback_disabled")

    server.command("STOP")
    assert server.process.wait(timeout=5) == 0
    assert passes, "zero executed gates"
    return passes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--peer", action="store_true")
    parser.add_argument("--allow-privileged", action="store_true")
    parser.add_argument("--ipv6", action="store_true")
    options = parser.parse_args()
    if options.peer:
        peer_worker()
        return 0
    if not options.allow_privileged:
        print("BLOCKED_ENV: explicit --allow-privileged fixture opt-in required", file=sys.stderr)
        return 77
    if sys.platform != "linux":
        print("BLOCKED_ENV: isolated Linux namespaces required", file=sys.stderr)
        return 77
    fixture = Fixture()
    try:
        for executable in ("ip", "setpriv", "mix"):
            if not shutil.which(executable):
                raise RuntimeError("missing prerequisite: " + executable)
        try:
            fixture.setup()
        except subprocess.CalledProcessError as error:
            print("BLOCKED_ENV: " + error.stderr.decode().strip(), file=sys.stderr)
            return 77
        passes = run_gates(fixture, options.ipv6)
        print(json.dumps({"result": "PASS", "suite": "ingress_membership_egress",
                          "gates": passes, "count": len(passes),
                          "backend": os.environ["GAOXY_UDP_BACKEND"],
                          "payload_sizes": sorted(PAYLOAD_SIZES),
                          "peer_capability_notices": sorted({event for child in fixture.children
                              for event in child.events if event.startswith("PEER_CAP ")}),
                          "scope_exclusions": ["blocked_uncertain_sends_in_core_loopback_suite"]}), flush=True)
        return 0
    except Exception as error:
        print("FAIL " + repr(error), file=sys.stderr)
        for child in fixture.children:
            if child.wire:
                print("Gaoxy output:\n" + "\n".join(child.events[-30:]), file=sys.stderr)
        return 1
    finally:
        fixture.cleanup()


if __name__ == "__main__":
    sys.exit(main())
