"""Independent hyper-h2 acceptance for persistent, flow-controlled WebSockets."""
import socket
import struct
import sys
import time

import h2.config
import h2.connection
import h2.events


class Peer:
    def __init__(self, port):
        self.socket = socket.create_connection(("127.0.0.1", port), timeout=2)
        self.socket.settimeout(0.05)
        self.h2 = h2.connection.H2Connection(
            config=h2.config.H2Configuration(client_side=True, header_encoding="utf-8"))
        self.h2.initiate_connection()
        self.bodies, self.statuses = {}, {}
        self.ended, self.reset = set(), set()
        self.flush()

    def flush(self):
        data = self.h2.data_to_send()
        if data:
            self.socket.sendall(data)

    def pump(self):
        try:
            data = self.socket.recv(65536)
        except socket.timeout:
            return
        assert data, "unexpected owner idle close"
        for event in self.h2.receive_data(data):
            if isinstance(event, h2.events.DataReceived):
                self.bodies[event.stream_id] = self.bodies.get(event.stream_id, b"") + event.data
                self.h2.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
            elif isinstance(event, h2.events.ResponseReceived):
                self.statuses[event.stream_id] = dict(event.headers)[":status"]
            elif isinstance(event, h2.events.StreamEnded):
                self.ended.add(event.stream_id)
            elif isinstance(event, h2.events.StreamReset):
                self.reset.add(event.stream_id)
            elif isinstance(event, h2.events.ConnectionTerminated):
                raise AssertionError(repr(event))
        self.flush()

    def wait(self, condition, timeout=5):
        deadline = time.monotonic() + timeout
        while not condition():
            assert time.monotonic() < deadline, "independent h2 deadline"
            self.pump()

    def open(self, stream, path="/persistent"):
        self.h2.send_headers(stream, [
            (":method", "CONNECT"), (":protocol", "websocket"), (":scheme", "http"),
            (":authority", "localhost"), (":path", path), ("sec-websocket-version", "13")])
        self.flush()
        self.wait(lambda: stream in self.statuses)
        assert self.statuses[stream] == "200"

    def send(self, stream, data):
        deadline = time.monotonic() + 10
        while data:
            assert time.monotonic() < deadline, "flow-control send deadline"
            count = min(len(data), self.h2.local_flow_control_window(stream),
                        self.h2.max_outbound_frame_size)
            if count:
                self.h2.send_data(stream, data[:count])
                data = data[count:]
                self.flush()
            else:
                self.pump()

    def expect(self, stream, expected):
        self.wait(lambda: len(self.bodies.get(stream, b"")) >= len(expected), timeout=10)
        assert self.bodies[stream][:len(expected)] == expected
        self.bodies[stream] = self.bodies[stream][len(expected):]

    def sibling(self, stream):
        self.h2.send_headers(stream, [(":method", "GET"), (":scheme", "http"),
                                    (":authority", "localhost"), (":path", "/sibling")],
                             end_stream=True)
        self.flush()
        self.wait(lambda: stream in self.ended)
        assert self.statuses[stream] == "200"
        assert self.bodies[stream] == b"/sibling"


def ws(opcode, data, masked=False):
    size = len(data)
    flag = 128 if masked else 0
    if size < 126:
        head = bytes([128 | opcode, flag | size])
    elif size < 65536:
        head = bytes([128 | opcode, flag | 126]) + struct.pack("!H", size)
    else:
        head = bytes([128 | opcode, flag | 127]) + struct.pack("!Q", size)
    if masked:
        mask = b"\x01\x02\x03\x04"
        return head + mask + bytes(byte ^ mask[i % 4] for i, byte in enumerate(data))
    return head + data


def persistence(peer):
    peer.open(1)
    peer.expect(1, ws(1, b"push"))
    # No network activity over three ordinary owner idle intervals.
    time.sleep(0.6)
    peer.send(1, ws(9, b"alive", True))
    peer.expect(1, ws(10, b"alive"))
    peer.sibling(3)
    for size in (300 * 1024, 2 * 1024 * 1024, 300 * 1024):
        data = (bytes(range(256)) * ((size + 255) // 256))[:size]
        peer.send(1, ws(2, data, True))
        peer.expect(1, ws(2, data))
        assert 1 not in peer.reset and 1 not in peer.ended
    peer.send(1, ws(8, struct.pack("!H", 1000), True))
    peer.expect(1, ws(8, struct.pack("!H", 1000)))
    peer.wait(lambda: 1 in peer.ended)
    peer.h2.end_stream(1)
    peer.flush()
    peer.sibling(5)
    # Drain any control frames, then prove original finite owner idle is restored.
    deadline = time.monotonic() + 2
    while True:
        assert time.monotonic() < deadline, "ordinary owner idle was not restored"
        try:
            data = peer.socket.recv(65536)
        except socket.timeout:
            continue
        if not data:
            break
    print("PASS quiet idle, ping, repeated large messages, live sibling, close, restored idle")


def control(peer, mode):
    peer.open(1, "/finite" if mode == "finite" else "/persistent")
    peer.expect(1, ws(1, b"push"))
    if mode == "finite":
        peer.wait(lambda: 1 in peer.ended or 1 in peer.reset, timeout=1)
        peer.sibling(3)
    else:
        # An incomplete H2 frame must retain its own assembly timeout while WS
        # ownership has disabled the ordinary owner read-idle timeout.
        peer.socket.sendall(b"\x00\x00")
        deadline = time.monotonic() + 1
        terminated = False
        while not terminated:
            assert time.monotonic() < deadline, "partial frame timeout did not fire"
            try:
                data = peer.socket.recv(65536)
            except socket.timeout:
                continue
            if not data:
                terminated = True
            else:
                terminated = any(isinstance(event, h2.events.ConnectionTerminated)
                                 and event.error_code == 1
                                 for event in peer.h2.receive_data(data))
    print("PASS " + mode)


peer = Peer(int(sys.argv[1]))
try:
    if len(sys.argv) > 2:
        control(peer, sys.argv[2])
    else:
        persistence(peer)
finally:
    peer.socket.close()
