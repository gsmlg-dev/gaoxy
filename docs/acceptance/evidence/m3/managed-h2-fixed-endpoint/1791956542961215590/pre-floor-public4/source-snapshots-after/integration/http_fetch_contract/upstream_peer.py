#!/usr/bin/env python3
"""Finite independent H1/H2 server; JSON lines on stdin/stdout are control only."""
import argparse
import importlib.metadata
import json
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

import h2.config
import h2.connection
import h2.events
import h2.settings
from hyperframe.frame import ContinuationFrame, GoAwayFrame, HeadersFrame


class Peer:
    def __init__(self, protocol):
        self.protocol = protocol
        self.lock = threading.RLock()
        self.events = []
        self.connections = {}
        self.threads = []
        self.stopping = threading.Event()
        self.temp = tempfile.TemporaryDirectory(prefix="gaoxy-public-peer-")
        self.context = None
        self.ca = None
        if protocol == "tls":
            self.ca = str(Path(self.temp.name) / "ca.pem")
            ca_key = str(Path(self.temp.name) / "ca-key.pem")
            cert = str(Path(self.temp.name) / "server.pem")
            key = str(Path(self.temp.name) / "key.pem")
            csr = str(Path(self.temp.name) / "server.csr")
            extensions = Path(self.temp.name) / "server.ext"
            extensions.write_text(
                "basicConstraints=critical,CA:FALSE\n"
                "keyUsage=critical,digitalSignature,keyEncipherment\n"
                "extendedKeyUsage=serverAuth\nsubjectAltName=DNS:localhost\n"
                "subjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\n")
            commands = [
                ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                 "-keyout", ca_key, "-out", self.ca, "-days", "1",
                 "-subj", "/CN=Gaoxy disposable peer CA",
                 "-addext", "basicConstraints=critical,CA:TRUE",
                 "-addext", "keyUsage=critical,keyCertSign,cRLSign"],
                ["openssl", "req", "-new", "-newkey", "rsa:2048", "-nodes",
                 "-keyout", key, "-out", csr, "-subj", "/CN=localhost"],
                ["openssl", "x509", "-req", "-in", csr, "-CA", self.ca,
                 "-CAkey", ca_key, "-CAcreateserial", "-out", cert, "-days", "1",
                 "-extfile", str(extensions)],
                ["openssl", "verify", "-CAfile", self.ca, "-purpose", "sslserver",
                 "-verify_hostname", "localhost", cert],
            ]
            for command in commands:
                subprocess.run(command, check=True, stdout=subprocess.DEVNULL,
                               stderr=subprocess.PIPE, timeout=10)
            self.context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            self.context.load_cert_chain(cert, key)
            self.context.set_alpn_protocols(["h2"])
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(8)
        self.listener.settimeout(0.1)
        self.acceptor = threading.Thread(target=self.accept, daemon=True)
        self.acceptor.start()
        self.output({"event": "ready", "port": self.listener.getsockname()[1],
                     "protocol": protocol, "ca": self.ca,
                     "h2": importlib.metadata.version("h2"),
                     "hpack": importlib.metadata.version("hpack")})

    def output(self, event):
        with self.lock:
            print(json.dumps(event, separators=(",", ":")), flush=True)

    def record(self, event, **values):
        with self.lock:
            item = {"event": event, **values}
            self.events.append(item)
            self.output(item)

    def accept(self):
        while not self.stopping.is_set():
            try:
                raw, _ = self.listener.accept()
            except socket.timeout:
                continue
            except OSError:
                return
            with self.lock:
                cid = len(self.connections) + 1
                state = {"socket": raw, "h2": None, "paths": {}, "bytes": {},
                         "lock": threading.RLock(), "closed": False}
                self.connections[cid] = state
                self.record("accept", connection=cid)
            thread = threading.Thread(target=self.serve, args=(cid, state), daemon=True)
            self.threads.append(thread)
            thread.start()

    def serve(self, cid, state):
        try:
            raw = state["socket"]
            raw.settimeout(5)
            if self.context:
                raw = self.context.wrap_socket(raw, server_side=True)
                assert raw.selected_alpn_protocol() == "h2"
                state["socket"] = raw
                self.record("tls", connection=cid, alpn="h2")
            raw.settimeout(0.1)
            if self.protocol == "h1":
                self.h1(cid, state)
            else:
                self.h2(cid, state)
        except (OSError, EOFError) as error:
            if not self.stopping.is_set() and not state["closed"]:
                self.record("disconnect", connection=cid, reason=type(error).__name__)
        except Exception as error:
            self.record("failure", connection=cid, reason=repr(error))
        finally:
            state["socket"].close()
            state["closed"] = True
            self.record("closed", connection=cid)

    def read(self, state, count):
        data = bytearray()
        while len(data) < count and not self.stopping.is_set():
            try:
                chunk = state["socket"].recv(count - len(data))
            except socket.timeout:
                continue
            if not chunk:
                raise EOFError()
            data.extend(chunk)
        if len(data) != count:
            raise EOFError()
        return bytes(data)

    def line(self, state):
        result = bytearray()
        while not result.endswith(b"\r\n"):
            result.extend(self.read(state, 1))
            assert len(result) <= 65536, "line bound"
        return bytes(result)

    def h1(self, cid, state):
        while not self.stopping.is_set():
            line = self.line(state).decode().strip()
            path = line.split(" ")[1]
            headers = []
            while True:
                field = self.line(state)
                if field == b"\r\n":
                    break
                name, value = field.decode().strip().split(":", 1)
                headers.append([name.lower(), value.strip()])
            self.record("request", connection=cid, stream=0, path=path, headers=headers)
            state["paths"][0] = path
            body = bytearray()
            trailers = []
            if ["transfer-encoding", "chunked"] in headers:
                while True:
                    size = int(self.line(state).split(b";", 1)[0], 16)
                    if size == 0:
                        while True:
                            field = self.line(state)
                            if field == b"\r\n":
                                break
                            name, value = field.decode().strip().split(":", 1)
                            trailers.append([name.lower(), value.strip()])
                        break
                    body.extend(self.read(state, size))
                    assert self.read(state, 2) == b"\r\n"
                    assert len(body) <= 1048576
            self.record("upload_end", connection=cid, stream=0, path=path,
                        body=body.decode(), trailers=trailers, end_stream=True)
            if path == "/stall":
                state["socket"].sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 8\r\n\r\na")
                while self.read(state, 1):
                    raise AssertionError("unexpected bytes after stalled request")
            elif path == "/trailers":
                state["socket"].sendall(
                    b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n"
                    b"Trailer: x-result\r\n\r\n2\r\nok\r\n0\r\n"
                    b"x-result: first\r\nx-result: second\r\n\r\n")
            else:
                state["socket"].sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")

    def h2(self, cid, state):
        conn = h2.connection.H2Connection(config=h2.config.H2Configuration(
            client_side=False, header_encoding="utf-8"))
        state["h2"] = conn
        wire = bytearray()
        preface = True
        with state["lock"]:
            conn.initiate_connection()
            conn.update_settings({h2.settings.SettingCodes.INITIAL_WINDOW_SIZE: 16})
            state["socket"].sendall(conn.data_to_send())
        while not self.stopping.is_set():
            try:
                data = state["socket"].recv(65536)
            except socket.timeout:
                continue
            if not data:
                return
            with state["lock"]:
                wire.extend(data)
                if preface and len(wire) >= 24:
                    assert bytes(wire[:24]) == b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
                    del wire[:24]
                    preface = False
                while not preface and len(wire) >= 9:
                    size = int.from_bytes(wire[:3], "big")
                    if len(wire) < 9 + size:
                        break
                    kind, flags = wire[3], wire[4]
                    frame_sid = int.from_bytes(wire[5:9], "big") & 0x7fffffff
                    if kind in [1, 9]:
                        self.record("header_frame", connection=cid, stream=frame_sid,
                                    type=kind, flags=flags, payload_bytes=size)
                    del wire[:9 + size]
                for event in conn.receive_data(data):
                    sid = getattr(event, "stream_id", 0)
                    if isinstance(event, h2.events.RequestReceived):
                        path = dict(event.headers)[":path"]
                        state["paths"][sid] = path
                        state["bytes"][sid] = bytearray()
                        self.record("request", connection=cid, stream=sid, path=path,
                                    headers=event.headers)
                        if path == "/empty-continuation":
                            state["socket"].sendall(HeadersFrame(sid).serialize())
                            self.record("open_headers", connection=cid, stream=sid,
                                        payload_bytes=0)
                        elif path in ["/a", "/b", "/early", "/sibling"]:
                            if path != "/early":
                                conn.send_headers(sid, [(":status", "200")])
                    elif isinstance(event, h2.events.DataReceived):
                        state["bytes"][sid].extend(event.data)
                        assert len(state["bytes"][sid]) <= 1048576
                        path = state["paths"][sid]
                        self.record("data", connection=cid, stream=sid, path=path,
                                    bytes=len(state["bytes"][sid]))
                        if path != "/early":
                            conn.acknowledge_received_data(event.flow_controlled_length, sid)
                    elif isinstance(event, h2.events.TrailersReceived):
                        self.record("trailers", connection=cid, stream=sid,
                                    path=state["paths"][sid], headers=event.headers,
                                    end_stream=event.stream_ended is not None)
                    elif isinstance(event, h2.events.StreamEnded):
                        path = state["paths"][sid]
                        self.record("upload_end", connection=cid, stream=sid, path=path,
                                    body=state["bytes"][sid].decode(), end_stream=True)
                        if path not in ["/a", "/b", "/early", "/sibling", "/empty-continuation", "/goaway"]:
                            self.response(cid, state, sid, "ok", trailers=path.startswith("/upload"))
                    elif isinstance(event, h2.events.StreamReset):
                        self.record("reset", connection=cid, stream=sid,
                                    path=state["paths"].get(sid), code=event.error_code)
                outbound = conn.data_to_send()
                if outbound:
                    state["socket"].sendall(outbound)

    def response(self, cid, state, sid, body, trailers=False, early=False):
        conn = state["h2"]
        path = state["paths"][sid]
        if path not in ["/b", "/sibling"]:
            conn.send_headers(sid, [(":status", "413" if early else "200")])
        conn.send_data(sid, body.encode(), end_stream=not trailers)
        if trailers:
            conn.send_headers(sid, [("x-result", "first"), ("x-result", "second")], end_stream=True)
        self.record("response", connection=cid, stream=sid, path=path, body=body)

    def command(self, item):
        name = item["command"]
        if name == "snapshot":
            with self.lock:
                self.output({"event": "snapshot", "events": list(self.events)})
            return
        if name == "stop":
            self.stop()
            return
        cid = item.get("connection", 1)
        state = self.connections[cid]
        with state["lock"]:
            sid = next((sid for sid, path in state["paths"].items()
                        if path == item.get("path")), 0)
            if name == "close":
                state["closed"] = True
                state["socket"].shutdown(socket.SHUT_RDWR)
            elif name == "finish":
                self.response(cid, state, sid, item["body"], early=item.get("early", False))
                state["socket"].sendall(state["h2"].data_to_send())
            elif name == "goaway":
                frame = GoAwayFrame(0)
                frame.last_stream_id = 0
                state["socket"].sendall(frame.serialize())
                self.record("goaway", connection=cid, stream=sid, last_stream_id=0)
            elif name == "empty_batch":
                count = item["count"]
                assert 0 < count <= 20000
                state["socket"].sendall(ContinuationFrame(sid).serialize() * count)
                self.record("empty_batch", connection=cid, stream=sid, count=count,
                            payload_bytes=0, wire_bytes=count * 9)
            else:
                raise AssertionError("unknown command: " + name)
        self.output({"event": "command_done", "command": name})

    def stop(self):
        self.stopping.set()
        self.listener.close()
        for state in list(self.connections.values()):
            try:
                state["socket"].shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            state["socket"].close()
        self.acceptor.join(2)
        for thread in self.threads:
            thread.join(2)
        assert not self.acceptor.is_alive() and not any(t.is_alive() for t in self.threads)
        self.temp.cleanup()
        self.output({"event": "stopped", "connections": len(self.connections),
                     "live_threads": 0})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", choices=["h1", "h2c", "tls"], required=True)
    args = parser.parse_args()
    peer = Peer(args.protocol)
    try:
        # The control pipe, socket timeouts and parent timeout bound this fixture.
        for line in sys.stdin:
            command = json.loads(line)
            peer.command(command)
            if command["command"] == "stop":
                return
    finally:
        if not peer.stopping.is_set():
            peer.stop()


if __name__ == "__main__":
    main()
