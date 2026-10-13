#!/usr/bin/env python3
"""Independent, finite raw H1 origin. Control and receipts are JSON lines.

Commands: release(connection, request), snapshot, stop. /hold* pauses a
partially sent response; /upload* pauses body accounting. Response bytes are
b"foundation:" + the raw request target, with x-foundation: done and x-bodysha
trailers identifying the exact response digest.
Only disposable localhost TLS fixture certificates are generated.
"""

import argparse
import hashlib
import json
import os
import select
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path


class PeerEOF(Exception):
    pass


class Stopped(Exception):
    pass


class Reader:
    def __init__(self, peer, sock):
        self.peer, self.sock = peer, sock
        self.buffer = bytearray()
        self.deadline = peer.deadline

    def receive(self):
        if self.peer.stopping.is_set():
            raise Stopped()
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("request deadline exceeded")
        self.sock.settimeout(remaining)
        data = self.sock.recv(8192)
        if not data:
            raise PeerEOF()
        self.buffer.extend(data)
        if len(self.buffer) > 1_048_576 + 16_384:
            raise ValueError("input buffer limit exceeded")

    def line(self, limit=4096):
        while True:
            end = self.buffer.find(b"\r\n")
            if end >= 0:
                if end > limit:
                    raise ValueError("line limit exceeded")
                result = bytes(self.buffer[:end])
                del self.buffer[:end + 2]
                return result
            if len(self.buffer) > limit:
                raise ValueError("line limit exceeded")
            self.receive()

    def take(self, count):
        while len(self.buffer) < count:
            self.receive()
        result = bytes(self.buffer[:count])
        del self.buffer[:count]
        return result

    def fields(self, count_limit, bytes_limit):
        fields, size = [], 0
        while True:
            line = self.line()
            size += len(line) + 2
            if size > bytes_limit:
                raise ValueError("header/trailer byte limit exceeded")
            if not line:
                return fields
            if len(fields) >= count_limit or line[:1] in (b" ", b"\t") or b":" not in line:
                raise ValueError("invalid or excess header/trailer fields")
            name, value = line.split(b":", 1)
            if not name or any(char not in b"!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
                               for char in name):
                raise ValueError("invalid field name")
            value = value.strip(b" \t")
            if any(char < 32 and char != 9 or char == 127 for char in value):
                raise ValueError("invalid field value")
            fields.append((name.lower(), value))

    def send(self, data):
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("response deadline exceeded")
        self.sock.settimeout(remaining)
        self.sock.sendall(data)

    def body(self, fields):
        lengths = [value for name, value in fields if name == b"content-length"]
        encodings = [value.lower() for name, value in fields if name == b"transfer-encoding"]
        if len(lengths) > 1 or len(encodings) > 1 or lengths and encodings:
            raise ValueError("ambiguous request framing")
        digest, size, trailers = hashlib.sha256(), 0, []
        if encodings:
            if encodings != [b"chunked"]:
                raise ValueError("unsupported transfer encoding")
            for _ in range(4096):
                line = self.line(128).split(b";", 1)[0]
                if not line or len(line) > 8 or any(char not in b"0123456789abcdefABCDEF" for char in line):
                    raise ValueError("invalid chunk length")
                length = int(line, 16)
                if not length:
                    trailers = self.fields(32, 8192)
                    if any(name in (b"content-length", b"transfer-encoding", b"host") for name, _ in trailers):
                        raise ValueError("forbidden request trailer")
                    break
                size += length
                if size > 1_048_576:
                    raise ValueError("request body limit exceeded")
                digest.update(self.take(length))
                if self.take(2) != b"\r\n":
                    raise ValueError("invalid chunk terminator")
            else:
                raise ValueError("request chunk count limit exceeded")
        elif lengths:
            value = lengths[0]
            if not value or len(value) > 7 or not value.isdigit():
                raise ValueError("invalid content length")
            size = int(value)
            if size > 1_048_576:
                raise ValueError("request body limit exceeded")
            left = size
            while left:
                part = self.take(min(left, 8192))
                digest.update(part)
                left -= len(part)
        return size, digest.hexdigest(), [[name.decode("ascii"), value.decode("latin1")]
                                          for name, value in trailers]


class Peer:
    def __init__(self, protocol):
        self.protocol = protocol
        self.deadline = time.monotonic() + 120
        self.lock = threading.RLock()
        self.stopping = threading.Event()
        self.listener = self.acceptor = self.temp = self.context = None
        self.connections, self.threads = {}, []
        self.accepts = self.requests = self.controls = self.events = 0
        self.failure = None
        self.reporting_error = None
        self.control_buffer = bytearray()
        os.set_blocking(sys.stdout.fileno(), False)

    def emit(self, event, **fields):
        with self.lock:
            data = json.dumps(dict(event=event, **fields), separators=(",", ":")).encode() + b"\n"
            if len(data) > 32_768 or self.events >= 2048 and event not in ("failure", "stopped"):
                raise ValueError("receipt limit exceeded")
            self.events += 1
            deadline = time.monotonic() + 2
            while data:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not select.select([], [sys.stdout.fileno()], [], remaining)[1]:
                    raise TimeoutError("receipt output deadline exceeded")
                try:
                    data = data[os.write(sys.stdout.fileno(), data):]
                except BlockingIOError:
                    continue

    def fail(self, error):
        with self.lock:
            self.stopping.set()
            if self.failure is None:
                self.failure = repr(error)[:512]
                try:
                    self.emit("failure", reason=self.failure)
                except Exception as reporting_error:
                    if self.reporting_error is None:
                        self.reporting_error = repr(reporting_error)[:512]

    def start(self):
        ca = None
        if self.protocol == "tls":
            self.temp = tempfile.TemporaryDirectory(prefix="gaoxy-h1-foundation-")
            root = Path(self.temp.name)
            ca, ca_key = str(root / "ca.pem"), str(root / "ca-key.pem")
            cert, key, csr = str(root / "server.pem"), str(root / "server-key.pem"), str(root / "server.csr")
            extensions = root / "server.ext"
            extensions.write_text("basicConstraints=critical,CA:FALSE\n"
                                  "keyUsage=critical,digitalSignature,keyEncipherment\n"
                                  "extendedKeyUsage=serverAuth\nsubjectAltName=DNS:localhost\n")
            commands = [
                ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", ca_key,
                 "-out", ca, "-days", "1", "-subj", "/CN=Gaoxy disposable foundation CA",
                 "-addext", "basicConstraints=critical,CA:TRUE", "-addext", "keyUsage=critical,keyCertSign,cRLSign"],
                ["openssl", "req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", key,
                 "-out", csr, "-subj", "/CN=localhost"],
                ["openssl", "x509", "-req", "-in", csr, "-CA", ca, "-CAkey", ca_key,
                 "-CAcreateserial", "-out", cert, "-days", "1", "-extfile", str(extensions)],
                ["openssl", "verify", "-CAfile", ca, "-purpose", "sslserver", "-verify_hostname", "localhost", cert],
            ]
            for command in commands:
                subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                               timeout=min(10, max(0.001, self.deadline - time.monotonic())))
            self.context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            self.context.load_cert_chain(cert, key)
            self.context.set_alpn_protocols(["http/1.1"])
        self.listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(64)
        self.listener.settimeout(0.25)
        self.acceptor = threading.Thread(target=self.accept, name="foundation-accept")
        self.acceptor.start()
        self.emit("ready", port=self.listener.getsockname()[1], address="127.0.0.1", hostname="localhost",
                  protocol=self.protocol, ca=ca, python=sys.version, python_openssl=ssl.OPENSSL_VERSION,
                  lifetime_seconds=120, request_timeout_seconds=30)

    def accept(self):
        try:
            while not self.stopping.is_set():
                if time.monotonic() >= self.deadline:
                    raise TimeoutError("peer lifetime deadline exceeded")
                try:
                    sock, _ = self.listener.accept()
                except socket.timeout:
                    continue
                with self.lock:
                    if self.stopping.is_set():
                        sock.close()
                        break
                    if self.accepts >= 64:
                        sock.close()
                        raise ValueError("connection count limit exceeded")
                    self.accepts += 1
                    connection = self.accepts
                    resources, state = [sock], None
                    try:
                        wake_read, wake_write = socket.socketpair()
                        resources.extend((wake_read, wake_write))
                        state = dict(socket=sock, wake_read=wake_read, wake_write=wake_write,
                                     closed=False, held=None, released=False)
                        self.connections[connection] = state
                        thread = threading.Thread(target=self.serve, args=(connection, state),
                                                  name="foundation-connection-" + str(connection))
                        self.emit("accepted", connection=connection)
                        thread.start()
                        self.threads.append(thread)
                    except Exception:
                        for resource in resources:
                            try:
                                resource.close()
                            except OSError:
                                pass
                        if state is not None:
                            state["closed"] = True
                        raise
        except Exception as error:
            if not self.stopping.is_set():
                self.fail(error)

    def hold(self, connection, request, state, reader, phase):
        with self.lock:
            state["held"], state["released"] = request, False
            self.emit("held", connection=connection, request=request, phase=phase)
        try:
            while not self.stopping.is_set():
                with self.lock:
                    if state["released"]:
                        return
                remaining = reader.deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError("held request deadline exceeded")
                readable, _, _ = select.select([reader.sock, state["wake_read"]], [], [], remaining)
                if not readable:
                    raise TimeoutError("held request deadline exceeded")
                if state["wake_read"] in readable:
                    state["wake_read"].recv(1)
                if reader.sock in readable:
                    # Preserve any pipelined/upload bytes while watching remote EOF.
                    reader.receive()
            raise Stopped()
        finally:
            with self.lock:
                state["held"] = None

    def serve(self, connection, state):
        reason, remote_eof = "owned_stop", False
        try:
            sock = state["socket"]
            if self.context:
                with self.lock:
                    sock = self.context.wrap_socket(sock, server_side=True, do_handshake_on_connect=False)
                    state["socket"] = sock
                sock.settimeout(min(10, max(0.001, self.deadline - time.monotonic())))
                sock.do_handshake()
            reader = Reader(self, sock)
            self.emit("connected", connection=connection,
                      alpn=sock.selected_alpn_protocol() if self.context else None)
            while not self.stopping.is_set():
                reader.deadline = self.deadline
                try:
                    line = reader.line(2048)
                except PeerEOF:
                    if reader.buffer:
                        raise ValueError("EOF during request head")
                    raise
                reader.deadline = min(self.deadline, time.monotonic() + 30)
                parts = line.split(b" ")
                if (len(parts) != 3 or parts[2] != b"HTTP/1.1" or not parts[1].startswith(b"/")
                        or any(char < 33 or char > 126 for char in parts[1])):
                    raise ValueError("invalid H1 request line")
                method, target = parts[:2]
                if not method or any(char not in b"ABCDEFGHIJKLMNOPQRSTUVWXYZ" for char in method):
                    raise ValueError("invalid request method")
                path = target.decode("ascii")
                fields = reader.fields(64, 16_384)
                hosts = [value for name, value in fields if name == b"host"]
                if len(hosts) != 1 or not hosts[0] or len(hosts[0]) > 512:
                    raise ValueError("invalid request authority")
                with self.lock:
                    if self.requests >= 256:
                        raise ValueError("request count limit exceeded")
                    self.requests += 1
                    request = self.requests
                identity = dict(connection=connection, request=request, method=method.decode("ascii"),
                                path=path, authority=hosts[0].decode("ascii"))
                self.emit("request_head", **identity)
                if any(name == b"expect" and value.lower() == b"100-continue" for name, value in fields):
                    reader.send(b"HTTP/1.1 100 Continue\r\n\r\n")
                if path.startswith("/upload"):
                    self.hold(connection, request, state, reader, "upload_body")
                body_bytes, body_sha256, trailers = reader.body(fields)
                self.emit("request", **identity, body_bytes=body_bytes, body_sha256=body_sha256,
                          upload_trailers=trailers)
                body = b"foundation:" + target
                response_sha256 = hashlib.sha256(body).hexdigest()
                if method == b"HEAD":
                    reader.send(b"HTTP/1.1 200 OK\r\nContent-Length: " + str(len(body)).encode() + b"\r\n\r\n")
                    self.emit("response", connection=connection, request=request, body_bytes=0,
                              body_sha256=hashlib.sha256(b"").hexdigest(), trailers=[])
                    continue
                reader.send(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n"
                             b"Trailer: x-foundation, x-bodysha\r\nConnection: keep-alive\r\n\r\n"
                             b"b\r\nfoundation:\r\n")
                self.emit("response_head", connection=connection, request=request,
                          expected_body_bytes=len(body), expected_body_sha256=response_sha256)
                if path.startswith("/hold"):
                    self.hold(connection, request, state, reader, "response_body")
                reader.send(format(len(target), "x").encode() + b"\r\n" + target +
                             b"\r\n0\r\nx-foundation: done\r\nx-bodysha: " +
                             response_sha256.encode("ascii") + b"\r\n\r\n")
                self.emit("response", connection=connection, request=request, body_bytes=len(body),
                          body_sha256=response_sha256,
                          trailers=[["x-foundation", "done"], ["x-bodysha", response_sha256]])
        except PeerEOF:
            if not self.stopping.is_set():
                reason, remote_eof = "remote_eof", True
        except (ConnectionResetError, BrokenPipeError, ssl.SSLEOFError):
            if not self.stopping.is_set():
                reason, remote_eof = "remote_abort", True
        except Stopped:
            pass
        except Exception as error:
            if not self.stopping.is_set():
                reason = "failure"
                self.fail(error)
        finally:
            with self.lock:
                for resource in (state["socket"], state["wake_read"], state["wake_write"]):
                    try:
                        resource.close()
                    except OSError as error:
                        self.fail(error)
                state["closed"], state["held"] = True, None
                if self.stopping.is_set() and reason != "failure":
                    reason, remote_eof = "owned_stop", False
                try:
                    self.emit("eof", connection=connection, remote_eof=remote_eof, reason=reason)
                except Exception as error:
                    if self.reporting_error is None:
                        self.reporting_error = repr(error)[:512]
                    self.fail(error)

    def read_control(self):
        while b"\n" not in self.control_buffer:
            if self.stopping.is_set():
                raise Stopped()
            remaining = self.deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("control lifetime deadline exceeded")
            if not select.select([sys.stdin.fileno()], [], [], min(0.25, remaining))[0]:
                continue
            data = os.read(sys.stdin.fileno(), 4096)
            if not data:
                raise ValueError("control EOF before stop")
            self.control_buffer.extend(data)
            if b"\n" not in self.control_buffer and len(self.control_buffer) > 4096:
                raise ValueError("control line limit exceeded")
        line, _, rest = self.control_buffer.partition(b"\n")
        self.control_buffer = bytearray(rest)
        if len(line) > 4096:
            raise ValueError("control line limit exceeded")
        item = json.loads(line)
        if not isinstance(item, dict):
            raise ValueError("invalid control object")
        return item

    def command(self, item):
        with self.lock:
            self.controls += 1
            if self.controls > 1024:
                raise ValueError("control count limit exceeded")
            command = item.get("command")
            if command in ("snapshot", "stop") and set(item) == {"command"}:
                if command == "snapshot":
                    self.emit("snapshot", accepts=self.accepts, requests=self.requests,
                              current_alive=sum(not state["closed"] for state in self.connections.values()),
                              holds=[dict(connection=connection, request=state["held"])
                                     for connection, state in self.connections.items() if state["held"] is not None],
                              failed=self.failure is not None)
                return command
            if command != "release" or set(item) != {"command", "connection", "request"}:
                raise ValueError("invalid control grammar")
            connection, request = item["connection"], item["request"]
            if type(connection) is not int or type(request) is not int:
                raise ValueError("release IDs must be integers")
            state = self.connections.get(connection)
            if state is None or state["closed"] or state["held"] != request or state["released"]:
                raise ValueError("release does not identify a current hold")
            state["released"] = True
            state["wake_write"].sendall(b"r")
            self.emit("released", connection=connection, request=request)
            return command

    def stop(self):
        deadline = time.monotonic() + 3
        with self.lock:
            self.stopping.set()
            resources = [self.listener] if self.listener else []
            resources += [state["socket"] for state in self.connections.values() if not state["closed"]]
            for resource in resources:
                try:
                    resource.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                try:
                    resource.close()
                except OSError as error:
                    self.fail(error)
            for state in self.connections.values():
                if not state["closed"]:
                    try:
                        state["wake_write"].sendall(b"s")
                    except OSError as error:
                        self.fail(error)
        threads = ([self.acceptor] if self.acceptor else []) + self.threads
        for thread in threads:
            if thread.ident is not None:
                thread.join(max(0, deadline - time.monotonic()))
        alive = sum(thread.is_alive() for thread in threads)
        if alive:
            self.fail(RuntimeError("owned thread shutdown deadline exceeded"))
        removed = self.temp is None
        if self.temp and not alive:
            root = self.temp.name
            try:
                self.temp.cleanup()
            except OSError as error:
                self.fail(error)
            removed = not Path(root).exists()
        try:
            self.emit("stopped", live_threads=alive, accepts=self.accepts, requests=self.requests,
                      current_alive=sum(not state["closed"] for state in self.connections.values()),
                      temp_removed=removed, failed=self.failure is not None, primary_failure=self.failure,
                      reporting_error=self.reporting_error)
        except Exception as error:
            if self.reporting_error is None:
                self.reporting_error = repr(error)[:512]
            self.fail(error)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", choices=("tcp", "tls"), required=True)
    peer = Peer(parser.parse_args().protocol)
    try:
        peer.start()
        while peer.command(peer.read_control()) != "stop":
            pass
    except Stopped:
        pass
    except Exception as error:
        peer.fail(error)
    finally:
        peer.stop()
    return 1 if peer.failure else 0


if __name__ == "__main__":
    sys.exit(main())
