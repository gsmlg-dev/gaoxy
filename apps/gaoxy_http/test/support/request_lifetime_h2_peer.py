"""Bounded independent H2 storage-transfer acceptance for issue 13."""
import socket
import sys
import time

import h2.config
import h2.connection
import h2.events
import h2.settings


class Peer:
    def __init__(self, port, zero_window=False):
        self.socket = socket.create_connection(("127.0.0.1", port), timeout=2)
        self.socket.settimeout(0.05)
        self.h2 = h2.connection.H2Connection(
            config=h2.config.H2Configuration(client_side=True, header_encoding="utf-8")
        )
        self.h2.initiate_connection()
        if zero_window:
            self.h2.update_settings({h2.settings.SettingCodes.INITIAL_WINDOW_SIZE: 0})
        self.bodies = {}
        self.statuses = {}
        self.ended = set()
        self.reset = set()
        self.informed = set()
        self.flush()

    def flush(self):
        pending = self.h2.data_to_send()
        if pending:
            self.socket.sendall(pending)

    def request(self, stream, method, path):
        headers = [(":method", method), (":scheme", "http"),
                   (":authority", "localhost"), (":path", path)]
        if method == "PUT":
            headers.append(("content-length", "128"))
        self.h2.send_headers(stream, headers, end_stream=method != "PUT")
        self.flush()

    def wait(self, predicate, timeout=3):
        deadline = time.monotonic() + timeout
        while not predicate():
            assert time.monotonic() < deadline, "independent H2 acceptance deadline"
            try:
                data = self.socket.recv(65536)
            except socket.timeout:
                continue
            assert data, "unexpected connection close"
            for event in self.h2.receive_data(data):
                if isinstance(event, h2.events.DataReceived):
                    self.bodies[event.stream_id] = self.bodies.get(event.stream_id, b"") + event.data
                    self.h2.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                elif isinstance(event, h2.events.ResponseReceived):
                    self.statuses[event.stream_id] = dict(event.headers)[":status"]
                elif isinstance(event, h2.events.InformationalResponseReceived):
                    self.informed.add(event.stream_id)
                elif isinstance(event, h2.events.StreamEnded):
                    self.ended.add(event.stream_id)
                elif isinstance(event, h2.events.StreamReset):
                    self.reset.add(event.stream_id)
                elif isinstance(event, h2.events.ConnectionTerminated):
                    raise AssertionError(repr(event))
            self.flush()


port = int(sys.argv[1])
peer = Peer(port)
if len(sys.argv) > 2 and sys.argv[2] == "finite":
    try:
        peer.request(1, "PUT", "/upload")
        peer.h2.send_data(1, b"x" * 16)
        peer.flush()
        time.sleep(0.08)
        peer.h2.send_data(1, b"y" * 16)
        peer.flush()
        peer.wait(lambda: 1 in peer.reset)
        assert 1 not in peer.ended
    finally:
        peer.socket.close()
    print("PASS finite request deadline")
    sys.exit(0)

try:
    peer.request(1, "PUT", "/upload")
    started = time.monotonic()
    for index in range(8):
        time.sleep(0.08)
        peer.h2.send_data(1, bytes([index]) * 16, end_stream=index == 7)
        peer.flush()
    peer.wait(lambda: 1 in peer.ended)
    assert time.monotonic() - started >= 0.6
    assert peer.statuses[1] == "200" and peer.bodies[1] == b"128"

    peer.request(3, "PUT", "/upload")
    peer.wait(lambda: 3 in peer.ended)
    assert peer.statuses[3] == "408" and peer.bodies[3] == b"idle body"

    peer.request(5, "GET", "/download")
    peer.wait(lambda: 5 in peer.ended)
    assert peer.statuses[5] == "200" and peer.bodies[5] == b"s" * 131072

    peer.request(7, "PUT", "/reset")
    peer.h2.send_data(7, b"x" * 16)
    peer.flush()
    peer.wait(lambda: 7 in peer.informed)
    peer.h2.reset_stream(7)
    peer.flush()
    peer.request(9, "GET", "/ok")
    peer.wait(lambda: 9 in peer.ended)
    assert peer.statuses[9] == "200" and peer.bodies[9] == b"sibling-ok"
finally:
    peer.socket.close()

file_peer = Peer(port, zero_window=True)
try:
    file_peer.request(1, "GET", "/download")
    # Outlive the finite 150ms startup, below the 300ms write inactivity bound.
    time.sleep(0.2)
    file_peer.h2.increment_flow_control_window(131072, stream_id=1)
    file_peer.flush()
    file_peer.wait(lambda: 1 in file_peer.ended)
    assert file_peer.statuses[1] == "200" and file_peer.bodies[1] == b"s" * 131072
finally:
    file_peer.socket.close()

blocked = Peer(port, zero_window=True)
try:
    blocked.request(1, "GET", "/download")
    blocked.request(3, "GET", "/ok")
    blocked.h2.increment_flow_control_window(65535, stream_id=3)
    blocked.flush()
    blocked.wait(lambda: 1 in blocked.reset and 3 in blocked.ended)
    assert blocked.bodies.get(1, b"") == b""
    assert blocked.statuses[3] == "200" and blocked.bodies[3] == b"sibling-ok"
finally:
    blocked.socket.close()

print("PASS upload, file, idle, reset, sibling, write deadline")
