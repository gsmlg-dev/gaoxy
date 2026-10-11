#!/usr/bin/env python3
"""Finite independent peer for the eight public H2 error-retention cases."""
import argparse
import hashlib
import importlib.metadata
import json
import os
import select
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

try:
    import h2.config
    import h2.connection
    import h2.events
except ImportError as error:
    print(json.dumps({"event": "failure", "reason": "BLOCKED_ENV: " + str(error)}), flush=True)
    sys.exit(2)


def frame(kind, flags, stream, payload):
    return len(payload).to_bytes(3, "big") + bytes([kind, flags]) + stream.to_bytes(4, "big") + payload


class Peer:
    def __init__(self, protocol):
        self.protocol = protocol
        self.lock = threading.RLock()
        self.stopping = threading.Event()
        self.listener = self.socket = self.conn = self.acceptor = self.worker = None
        self.temp = None
        self.stream = None
        self.accepts = self.requests = self.resets = self.lines = self.controls = 0
        self.commands = set()
        self.failed = False
        self.buffer = bytearray()
        self.deadline = time.monotonic() + 60

    def output(self, event, **values):
        with self.lock:
            line = json.dumps(dict(event=event, **values), separators=(",", ":")).encode() + b"\n"
            if self.lines >= 128 or len(line) > 4096:
                raise RuntimeError("peer event/line cap exceeded")
            self.lines += 1
            sys.stdout.buffer.write(line)
            sys.stdout.buffer.flush()

    def fail(self, error):
        self.failed = True
        self.output("failure", reason=repr(error)[:512])

    def start(self):
        versions = {name: importlib.metadata.version(name) for name in ("h2", "hpack", "hyperframe")}
        if versions != {"h2": "4.3.0", "hpack": "4.1.0", "hyperframe": "6.1.0"}:
            raise RuntimeError("BLOCKED_ENV: Python package versions do not match pinned requirements")
        executable = Path(sys.executable).resolve()
        identity = dict(python=str(executable), python_sha256=hashlib.sha256(executable.read_bytes()).hexdigest(),
                        python_version=sys.version, packages=versions, python_openssl=ssl.OPENSSL_VERSION)
        self.context = None
        ca = None
        if self.protocol == "tls":
            if shutil.which("openssl") is None:
                raise RuntimeError("BLOCKED_ENV: OpenSSL executable unavailable")
            self.temp = tempfile.TemporaryDirectory(prefix="gaoxy-h2-functional-")
            root = Path(self.temp.name)
            ca, ca_key = str(root / "ca.pem"), str(root / "ca-key.pem")
            cert, key, csr = str(root / "server.pem"), str(root / "server-key.pem"), str(root / "server.csr")
            extensions = root / "server.ext"
            extensions.write_text("basicConstraints=critical,CA:FALSE\n"
                                  "keyUsage=critical,digitalSignature,keyEncipherment\n"
                                  "extendedKeyUsage=serverAuth\nsubjectAltName=IP:127.0.0.1\n")
            commands = [
                ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", ca_key,
                 "-out", ca, "-days", "1", "-subj", "/CN=Gaoxy functional CA",
                 "-addext", "basicConstraints=critical,CA:TRUE", "-addext", "keyUsage=critical,keyCertSign,cRLSign"],
                ["openssl", "req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", key,
                 "-out", csr, "-subj", "/CN=127.0.0.1"],
                ["openssl", "x509", "-req", "-in", csr, "-CA", ca, "-CAkey", ca_key,
                 "-CAcreateserial", "-out", cert, "-days", "1", "-extfile", str(extensions)],
                ["openssl", "verify", "-CAfile", ca, "-purpose", "sslserver", "-verify_ip", "127.0.0.1", cert],
            ]
            for command in commands:
                subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=10)
            identity["openssl"] = subprocess.run(["openssl", "version"], check=True, capture_output=True,
                                                  text=True, timeout=2).stdout.strip()
            for name, path in (("ca", ca), ("server", cert)):
                der = ssl.PEM_cert_to_DER_cert(Path(path).read_text())
                identity[name + "_certificate_sha256"] = hashlib.sha256(der).hexdigest()
            self.context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            self.context.load_cert_chain(cert, key)
            self.context.set_alpn_protocols(["h2"])
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(1)
        self.listener.settimeout(0.1)
        self.port = self.listener.getsockname()[1]
        self.acceptor = threading.Thread(target=self.accept)
        self.acceptor.start()
        self.output("ready", protocol=self.protocol, port=self.port, ca=ca, identity=identity)

    def accept(self):
        try:
            while not self.stopping.is_set():
                try:
                    raw, _ = self.listener.accept()
                except socket.timeout:
                    continue
                with self.lock:
                    self.accepts += 1
                    if self.accepts != 1:
                        raw.close()
                        raise RuntimeError("unexpected second connection")
                    self.socket = raw
                    self.output("accept", connection=1)
                    self.worker = threading.Thread(target=self.serve)
                    self.worker.start()
        except Exception as error:
            if not self.stopping.is_set():
                self.fail(error)

    def serve(self):
        try:
            if self.context:
                wrapped = self.context.wrap_socket(self.socket, server_side=True, do_handshake_on_connect=False)
                self.socket = wrapped
                wrapped.settimeout(2)
                wrapped.do_handshake()
                if wrapped.selected_alpn_protocol() != "h2":
                    raise RuntimeError("TLS ALPN was not h2")
                self.output("tls", connection=1, alpn="h2")
            self.socket.settimeout(0.1)
            with self.lock:
                self.conn = h2.connection.H2Connection(config=h2.config.H2Configuration(
                    client_side=False, header_encoding="utf-8"))
                self.conn.initiate_connection()
                self.socket.sendall(self.conn.data_to_send())
            while not self.stopping.is_set():
                try:
                    data = self.socket.recv(4096)
                except socket.timeout:
                    continue
                if not data:
                    if not self.stopping.is_set():
                        raise RuntimeError("unexpected client connection closure")
                    break
                with self.lock:
                    for event in self.conn.receive_data(data):
                        if isinstance(event, h2.events.RequestReceived):
                            self.requests += 1
                            headers = dict(event.headers)
                            expected = {":method": "GET", ":path": "/target",
                                        ":scheme": "https" if self.context else "http",
                                        ":authority": "127.0.0.1:" + str(self.port)}
                            if self.requests != 1 or event.stream_ended is None or any(
                                    headers.get(key) != value for key, value in expected.items()):
                                raise RuntimeError("unexpected request grammar")
                            self.stream = event.stream_id
                            self.output("request", connection=1, stream=self.stream, headers=event.headers,
                                        end_stream=True, upload_bytes=0)
                        elif isinstance(event, h2.events.StreamReset):
                            self.resets += 1
                            expected = 1 if "malformed_trailers" in self.commands else 8
                            if self.resets != 1 or event.stream_id != self.stream or event.error_code != expected:
                                raise RuntimeError("unexpected reset scope/code/count")
                            self.output("reset", connection=1, stream=self.stream, code=int(event.error_code))
                        elif isinstance(event, (h2.events.RemoteSettingsChanged, h2.events.SettingsAcknowledged,
                                                h2.events.StreamEnded, h2.events.WindowUpdated)):
                            self.output("control", kind=type(event).__name__)
                        else:
                            raise RuntimeError("unexpected client event: " + repr(event))
                    outbound = self.conn.data_to_send()
                    if outbound:
                        self.socket.sendall(outbound)
        except Exception as error:
            if not self.stopping.is_set():
                self.fail(error)
        finally:
            if self.socket:
                self.socket.close()
            self.output("closed", connection=1, owned_shutdown=self.stopping.is_set())

    def read_control(self):
        while b"\n" not in self.buffer:
            remaining = self.deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError("peer original lifetime deadline exceeded")
            ready, _, _ = select.select([sys.stdin.buffer], [], [], remaining)
            if not ready:
                raise RuntimeError("peer control deadline exceeded")
            data = os.read(sys.stdin.fileno(), 4097)
            if not data:
                if self.buffer:
                    raise RuntimeError("nonterminated control line")
                return None
            self.buffer.extend(data)
            if b"\n" not in self.buffer and len(self.buffer) > 4096:
                raise RuntimeError("oversized control line")
        line, _, rest = self.buffer.partition(b"\n")
        self.buffer = bytearray(rest)
        if len(line) + 1 > 4096:
            raise RuntimeError("oversized control line")
        item = json.loads(line)
        if not isinstance(item, dict) or set(item) != {"command"}:
            raise RuntimeError("unexpected control grammar")
        return item["command"]

    def command(self, name):
        with self.lock:
            self.controls += 1
            if self.controls > 3 or name in self.commands or name not in (
                    "reader_sentinel", "malformed_trailers", "stop"):
                raise RuntimeError("duplicate, unknown or excess control command")
            self.commands.add(name)
            if name == "stop":
                return
            if self.stream is None or self.resets or (name == "reader_sentinel" and
                                                     "malformed_trailers" in self.commands):
                raise RuntimeError("control command at wrong phase")
            if name == "reader_sentinel":
                self.conn.send_data(self.stream, b"r", end_stream=False)
                wire = self.conn.data_to_send()
                if wire != frame(0, 0, self.stream, b"r"):
                    raise RuntimeError("sentinel frame mismatch")
            else:
                wire = frame(1, 4, self.stream, bytes.fromhex("0001780176"))
            self.socket.sendall(wire)
            self.output(name, connection=1, stream=self.stream, wire_hex=wire.hex(), successful_send=True)

    def stop(self):
        deadline = time.monotonic() + 2
        self.stopping.set()
        for resource in (self.listener, self.socket):
            if resource:
                try:
                    resource.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                resource.close()
        for thread in (self.acceptor, self.worker):
            if thread:
                thread.join(max(deadline - time.monotonic(), 0))
        if any(thread and thread.is_alive() for thread in (self.acceptor, self.worker)):
            raise RuntimeError("owned peer thread shutdown deadline exceeded")
        if self.temp:
            self.temp.cleanup()
        self.output("stopped", live_threads=0, accepts=self.accepts, requests=self.requests,
                    resets=self.resets, controls=self.controls, failed=self.failed)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", choices=["tls", "h2c"], required=True)
    peer = Peer(parser.parse_args().protocol)
    try:
        peer.start()
        while True:
            name = peer.read_control()
            if name is None:
                raise RuntimeError("control EOF before stop")
            peer.command(name)
            if name == "stop":
                break
    except Exception as error:
        peer.fail(error)
    finally:
        peer.stop()
    return 1 if peer.failed else 0


if __name__ == "__main__":
    sys.exit(main())
