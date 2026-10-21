"""Independent h2 peer for finite/infinite response isolation; every wait is bounded."""
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
        self.socket.settimeout(0.1)
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
        self.flush()

    def flush(self):
        pending = self.h2.data_to_send()
        if pending:
            self.socket.sendall(pending)

    def request(self, stream, path, credit=False):
        self.h2.send_headers(stream, [(":method", "GET"), (":scheme", "http"),
                                     (":authority", "localhost"), (":path", path)], end_stream=True)
        if credit:
            self.h2.increment_flow_control_window(65535, stream_id=stream)
        self.flush()

    def wait(self, predicate, timeout=3):
        deadline = time.monotonic() + timeout
        while not predicate():
            assert time.monotonic() < deadline, "independent h2 predicate deadline"
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
                elif isinstance(event, h2.events.StreamEnded):
                    self.ended.add(event.stream_id)
                elif isinstance(event, h2.events.StreamReset):
                    self.reset.add(event.stream_id)
                elif isinstance(event, h2.events.ConnectionTerminated):
                    raise AssertionError(repr(event))
            self.flush()


port = int(sys.argv[1])
peer = Peer(port)
try:
    started = time.monotonic()
    peer.request(1, "/infinite")
    peer.request(3, "/finite")
    peer.wait(lambda: 3 in peer.reset and time.monotonic() - started > 0.8
              and len(peer.bodies.get(1, b"")) >= 200)
    assert 1 not in peer.reset and 1 not in peer.ended
    peer.request(5, "/ok")
    peer.wait(lambda: 5 in peer.ended)
    assert peer.statuses[5] == "200" and peer.bodies[5] == b"sibling-ok"
    peer.h2.reset_stream(1)
    peer.flush()
    peer.request(7, "/infinite")
    peer.request(9, "/cancel")
    peer.wait(lambda: 9 in peer.reset and len(peer.bodies.get(7, b"")) > 20)
    assert 7 not in peer.reset
    peer.request(11, "/ok")
    peer.wait(lambda: 11 in peer.ended)
    assert peer.bodies[11] == b"sibling-ok"
finally:
    peer.socket.close()

blocked = Peer(port, zero_window=True)
try:
    blocked.request(1, "/infinite")
    blocked.request(3, "/ok", credit=True)
    blocked.wait(lambda: 1 in blocked.reset and 3 in blocked.ended)
    assert blocked.bodies.get(1, b"") == b""
    assert blocked.bodies[3] == b"sibling-ok"
    blocked.request(5, "/ok", credit=True)
    blocked.wait(lambda: 5 in blocked.ended)
    assert blocked.bodies[5] == b"sibling-ok"
finally:
    blocked.socket.close()

print("PASS stream lifetime, finite sibling, peer reset, application cancel, zero-window deadline")
