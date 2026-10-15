#!/usr/bin/env python3
"""Independent managed-transport peer; historical peer helpers are read-only.

The inherited helper supplies disposable verified TLS, accept/close receipts and
joined shutdown. This file owns all managed-case request and response behavior.
"""
import argparse
import json
import select
import sys
import threading
import time

import h2.config
import h2.connection
import h2.events
from hyperframe.frame import ContinuationFrame, DataFrame, GoAwayFrame, HeadersFrame, PingFrame

from upstream_peer import Peer


class ManagedPeer(Peer):
    def __init__(self, protocol):
        self.accept_waiters = []
        super().__init__(protocol)

    def accept(self):
        try:
            while not self.stopping.is_set():
                try:
                    raw, _ = self.listener.accept()
                except TimeoutError:
                    with self.lock:
                        for waiter in self.accept_waiters:
                            waiter.set()
                        self.accept_waiters.clear()
                    continue
                except OSError:
                    return
                state = {"socket": raw, "h2": None, "paths": {}, "bytes": {},
                         "lock": threading.RLock(), "closed": False}
                self.init_wire(state)
                with self.lock:
                    cid = len(self.connections) + 1
                    self.connections[cid] = state
                    self.record("accept", connection=cid)
                thread = threading.Thread(target=self.serve, args=(cid, state), daemon=True)
                self.threads.append(thread)
                thread.start()
        finally:
            with self.lock:
                for waiter in self.accept_waiters:
                    waiter.set()
                self.accept_waiters.clear()

    def init_wire(self, state):
        state.setdefault("wire", {"h1_bytes": 0, "h1_partial_header_bytes": 0,
                                  "h2_headers": 0, "h2_continuations": 0,
                                  "h2_request_frame_bytes": 0})
        state.setdefault("wire_waiters", [])
        state.setdefault("raw_h2", bytearray())
        state.setdefault("raw_preface", True)
        state.setdefault("raw_frame", None)
        state.setdefault("h1_reading_head", True)

    def serve(self, cid, state):
        self.init_wire(state)
        try:
            super().serve(cid, state)
        finally:
            self.wire_drained(state)

    def wire_drained(self, state):
        # A reader signals only after recv observed no pending bytes, or EOF.
        with state["lock"]:
            for waiter in state["wire_waiters"]:
                waiter.set()
            state["wire_waiters"].clear()

    def read(self, state, count):
        result = bytearray()
        while len(result) < count and not self.stopping.is_set():
            try:
                data = state["socket"].recv(count - len(result))
            except TimeoutError:
                self.wire_drained(state)
                continue
            if not data:
                raise EOFError()
            with state["lock"]:
                state["wire"]["h1_bytes"] += len(data)
                if state["h1_reading_head"]:
                    state["wire"]["h1_partial_header_bytes"] += len(data)
            result.extend(data)
        if len(result) != count:
            raise EOFError()
        return bytes(result)

    def observe_h2(self, state, data):
        wire = state["raw_h2"]
        counters = state["wire"]
        wire.extend(data)
        if state["raw_preface"]:
            if len(wire) < 24:
                return
            assert bytes(wire[:24]) == b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
            del wire[:24]
            state["raw_preface"] = False
        while wire:
            frame = state["raw_frame"]
            if frame is None:
                if len(wire) < 9:
                    return
                size = int.from_bytes(wire[:3], "big")
                kind = wire[3]
                del wire[:9]
                if kind in [1, 9]:
                    key = "h2_headers" if kind == 1 else "h2_continuations"
                    counters[key] += 1
                    counters["h2_request_frame_bytes"] += 9
                state["raw_frame"] = frame = [kind, size]
            taken = min(len(wire), frame[1])
            if frame[0] in [1, 9]:
                counters["h2_request_frame_bytes"] += taken
            del wire[:taken]
            frame[1] -= taken
            if frame[1]:
                return
            state["raw_frame"] = None

    def wire_snapshot(self):
        deadline = time.monotonic() + 2
        accept_barrier = threading.Event()
        with self.lock:
            self.accept_waiters.append(accept_barrier)
        assert accept_barrier.wait(max(deadline - time.monotonic(), 0)), "accept drain barrier"
        # Include all sockets accepted before the listener's no-pending barrier.
        with self.lock:
            states = list(self.connections.values())
        waiters = []
        for state in states:
            waiter = threading.Event()
            with state["lock"]:
                self.init_wire(state)
                if state["closed"]:
                    waiter.set()
                else:
                    state["wire_waiters"].append(waiter)
            waiters.append(waiter)
        for waiter in waiters:
            assert waiter.wait(max(deadline - time.monotonic(), 0)), "wire drain barrier"
        counters = {"accepts": 0, "h1_bytes": 0, "h1_partial_header_bytes": 0,
                    "h2_headers": 0, "h2_continuations": 0,
                    "h2_request_frame_bytes": 0, "h2_partial_frame_bytes": 0}
        with self.lock:
            states = list(self.connections.values())
        counters["accepts"] = len(states)
        for state in states:
            with state["lock"]:
                self.init_wire(state)
                for key, value in state["wire"].items():
                    counters[key] += value
                # Even a prefix too short to identify its type cannot hide.
                counters["h2_partial_frame_bytes"] += len(state["raw_h2"])
        self.output({"event": "wire_snapshot", "counters": counters})

    def h1(self, cid, state):
        while not self.stopping.is_set():
            method, path, _ = self.line(state).decode().strip().split(" ")
            headers = []
            while True:
                field = self.line(state)
                if field == b"\r\n":
                    break
                name, value = field.decode().strip().split(":", 1)
                headers.append([name.lower(), value.strip()])
                assert len(headers) <= 256
            with state["lock"]:
                state["h1_reading_head"] = False
                state["wire"]["h1_partial_header_bytes"] = 0
            length = int(dict(headers).get("content-length", "0"))
            assert 0 <= length <= 1048576
            body = self.read(state, length)
            with state["lock"]:
                state["paths"][0] = path
                self.record("request", connection=cid, stream=0, path=path,
                            method=method, body=body.decode(), headers=headers)
                state["h1_reading_head"] = True
                if path == "/post-close":
                    return
                if path == "/deadline-short":
                    continue
                if path.startswith("/hold"):
                    state["socket"].sendall(
                        b"HTTP/1.1 200 OK\r\nContent-Length: 8\r\n\r\na")
                else:
                    state["socket"].sendall(
                        b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
                self.record("response_headers", connection=cid, stream=0, path=path)

    def h2(self, cid, state):
        conn = h2.connection.H2Connection(config=h2.config.H2Configuration(
            client_side=False, header_encoding="utf-8"))
        state["h2"] = conn
        with state["lock"]:
            conn.initiate_connection()
            state["socket"].sendall(conn.data_to_send())
        while not self.stopping.is_set():
            try:
                data = state["socket"].recv(65536)
            except TimeoutError:
                self.wire_drained(state)
                continue
            if not data:
                return
            with state["lock"]:
                # Account raw headers/continuations before h2 can decode or fail.
                self.observe_h2(state, data)
                for event in conn.receive_data(data):
                    sid = getattr(event, "stream_id", 0)
                    if isinstance(event, h2.events.RequestReceived):
                        path = dict(event.headers)[":path"]
                        state["paths"][sid] = path
                        state["bytes"][sid] = bytearray()
                        self.record("request", connection=cid, stream=sid, path=path,
                                    headers=event.headers)
                        if path.startswith("/hold"):
                            conn.send_headers(sid, [(":status", "200")])
                            self.record("response_headers", connection=cid,
                                        stream=sid, path=path)
                    elif isinstance(event, h2.events.DataReceived):
                        state["bytes"][sid].extend(event.data)
                        assert len(state["bytes"][sid]) <= 1048576
                        conn.acknowledge_received_data(event.flow_controlled_length, sid)
                    elif isinstance(event, h2.events.StreamEnded):
                        path = state["paths"][sid]
                        if not path.startswith(("/hold", "/fragment", "/deadline")):
                            conn.send_headers(sid, [(":status", "200")])
                            conn.send_data(sid, b"ok", end_stream=True)
                    elif isinstance(event, h2.events.StreamReset):
                        self.record("reset", connection=cid, stream=sid,
                                    path=state["paths"].get(sid), code=event.error_code)
                    elif isinstance(event, h2.events.PingAckReceived):
                        assert event.ping_data == b"managed!"
                        self.record("drain_ack", connection=cid)
                outbound = conn.data_to_send()
                if outbound:
                    state["socket"].sendall(outbound)

    def command(self, item):
        name = item["command"]
        if name == "wire_snapshot":
            return self.wire_snapshot()
        if name not in ["finish_hold", "fragments", "drain_connection"]:
            return super().command(item)
        cid = item["connection"]
        state = self.connections[cid]
        with state["lock"]:
            sid = next(sid for sid, path in state["paths"].items()
                       if path == item["path"])
            if name == "drain_connection":
                goaway = GoAwayFrame(0)
                goaway.last_stream_id = sid
                ping = PingFrame(0, opaque_data=b"managed!")
                # ACK proves owner-side wire processing of preceding GOAWAY;
                # pool-cast consumption is tested by the actual admission result.
                state["socket"].sendall(goaway.serialize() + ping.serialize())
                self.record("goaway", connection=cid, last_stream_id=sid)
            elif name == "finish_hold":
                if self.protocol == "h1":
                    state["socket"].sendall(b"bcdefgh")
                else:
                    state["h2"].send_data(sid, b"abcdefgh", end_stream=True)
                    state["socket"].sendall(state["h2"].data_to_send())
            else:
                count = item["count"]
                assert count in [256, 257]
                head = HeadersFrame(sid)
                frames = [head]
                if count == 256 and not item.get("body", False):
                    head.flags.add("END_STREAM")
                    frames += [ContinuationFrame(sid) for _ in range(253)]
                    frames.append(ContinuationFrame(sid, data=b"\x88"))
                    final = ContinuationFrame(sid)
                    final.flags.add("END_HEADERS")
                    frames.append(final)
                elif count == 256:
                    frames += [ContinuationFrame(sid) for _ in range(254)]
                    final = ContinuationFrame(sid, data=b"\x88")
                    final.flags.add("END_HEADERS")
                    frames.append(final)
                else:
                    frames += [ContinuationFrame(sid) for _ in range(255)]
                    final = ContinuationFrame(sid,
                                              data=b"\x88" if item["nonempty"] else b"")
                    if item["final"]:
                        final.flags.add("END_HEADERS")
                    frames.append(final)
                assert len(frames) == count
                wire = b"".join(frame.serialize() for frame in frames)
                if count == 256 and item.get("body", False):
                    end = DataFrame(sid, data=b"bounded")
                    end.flags.add("END_STREAM")
                    wire += end.serialize()
                state["socket"].sendall(wire)
                self.record("fragments", connection=cid, stream=sid,
                            count=count, wire_bytes=len(wire),
                            nonempty=item.get("nonempty"), final=item.get("final"))
        self.output({"event": "command_done", "command": name})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", choices=["h1", "h2c", "tls"], required=True)
    peer = ManagedPeer(parser.parse_args().protocol)
    deadline = time.monotonic() + 45
    try:
        while True:
            remaining = deadline - time.monotonic()
            assert remaining > 0, "peer lifetime deadline exceeded"
            ready, _, _ = select.select([sys.stdin], [], [], remaining)
            assert ready, "peer control deadline exceeded"
            line = sys.stdin.readline()
            if not line:
                return
            assert len(line) <= 65536, "control line bound"
            item = json.loads(line)
            peer.command(item)
            if item["command"] == "stop":
                return
    finally:
        if not peer.stopping.is_set():
            peer.stop()


if __name__ == "__main__":
    main()
