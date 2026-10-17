#!/usr/bin/env python3
"""Independent bounded TLS-H2/h2c fixture controlled through JSON lines."""
import argparse
import base64
import gzip
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import select
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import traceback

import h2.config
import h2.connection
import h2.events
import h2.settings


class Commands:
    """One bounded stdin buffer shared by preparation and normal commands."""
    def __init__(self):
        self.buffer = b""
        self.eof = False

    def read(self, timeout=None):
        deadline = None if timeout is None else time.monotonic() + timeout
        while True:
            if b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                if len(line) > 2097152:
                    raise RuntimeError("fixture command line bound exceeded")
                return json.loads(line)
            if len(self.buffer) > 2097152:
                raise RuntimeError("fixture command line bound exceeded")
            if self.eof:
                if self.buffer:
                    line, self.buffer = self.buffer, b""
                    return json.loads(line)
                return {"op": "stop"}
            remaining = None if deadline is None else max(0, deadline - time.monotonic())
            if not select.select([sys.stdin], [], [], remaining)[0]:
                return None
            data = os.read(sys.stdin.fileno(), 65536)
            self.buffer += data
            self.eof = not data


class Peer:
    def __init__(self, protocol, manual, alpn, max_streams=None,
                 bind_address="127.0.0.1", listen_port=0, hold_upload_credit=False):
        self.protocol, self.manual, self.alpn = protocol, manual, alpn
        self.hold_upload_credit = hold_upload_credit
        self.max_streams = max_streams
        self.bind_address, self.listen_port = bind_address, listen_port
        self.lock = threading.RLock()
        self.stopping = threading.Event()
        self.clients, self.workers, self.events = {}, [], 0
        self.failed, self.accepts, self.requests = False, 0, 0
        self.temp = tempfile.TemporaryDirectory(prefix="gaoxy-fixed-h2-")
        self.context = None
        self.listener, self.acceptor = None, None
        self.joined = False
        self.deadline = time.monotonic() + 180

    def emit(self, event, **values):
        with self.lock:
            self.events += 1
            line = json.dumps(dict(event=event, **values), separators=(",", ":"))
            if self.events > 8192 or len(line) > 262144:
                raise RuntimeError("fixture event bound exceeded")
            print(line, flush=True)

    def fail(self, error):
        self.failed = True
        frames = traceback.extract_tb(error.__traceback__, limit=8)
        self.emit("failure", reason=repr(error)[:1024],
                  frames=[dict(file=frame.filename, line=frame.lineno, function=frame.name)
                          for frame in frames])

    def preparation_command(self, args, commands, deadline):
        # The certificate script and its descendants belong to this one group.
        # Its scratch directories also belong to the peer, including on failure.
        if time.monotonic() >= deadline:
            raise TimeoutError("fixture TLS preparation timed out")
        with tempfile.TemporaryFile(dir=self.temp.name) as output, tempfile.TemporaryFile(dir=self.temp.name) as errors:
            process = subprocess.Popen(args, stdout=output,
                                       stderr=errors, env=dict(os.environ, TMPDIR=self.temp.name),
                                       start_new_session=True)
            succeeded = False
            try:
                while process.poll() is None:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise TimeoutError("fixture TLS preparation timed out")
                    command = commands.read(min(0.05, remaining))
                    if command is not None:
                        if command["op"] != "stop":
                            raise RuntimeError("fixture only accepts stop during preparation")
                        self.stopping.set()
                        return None
                if time.monotonic() >= deadline:
                    raise TimeoutError("fixture TLS preparation timed out")
                if process.returncode:
                    errors.seek(0)
                    diagnostic = errors.read().decode(errors="replace")[-2048:]
                    raise RuntimeError(f"fixture preparation command exited {process.returncode}: {diagnostic}")
                output.seek(0)
                result = output.read().decode()
                succeeded = True
                return result
            finally:
                if not succeeded:
                    primary = sys.exc_info()[1]
                    try:
                        self.join_preparation(process)
                    except Exception as cleanup:
                        raise RuntimeError(f"{primary!r}; {cleanup}") from cleanup

    @staticmethod
    def join_preparation(process):
        # Wait for the group, not just its shell leader: a descendant may still
        # be unwinding after the leader reports its exit status.
        for termination in (signal.SIGTERM, signal.SIGKILL):
            try:
                os.killpg(process.pid, termination)
            except ProcessLookupError:
                process.wait(timeout=2)
                return
            deadline = time.monotonic() + 2
            while True:
                process.poll()
                try:
                    os.killpg(process.pid, 0)
                except ProcessLookupError:
                    process.wait(timeout=max(0, deadline - time.monotonic()))
                    return
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                select.select([], [], [], min(0.01, remaining))
        raise RuntimeError("fixture preparation process group did not join")

    def prepare(self, commands):
        deadline = time.monotonic() + 20
        versions = {p: importlib.metadata.version(p) for p in ("h2", "hpack", "hyperframe")}
        if versions != {"h2": "4.3.0", "hpack": "4.1.0", "hyperframe": "6.1.0"}:
            raise RuntimeError("BLOCKED_ENV: independent peer dependencies differ from pinned requirements")
        self.ca, self.cert, self.key = None, None, None
        self.identity = {"python": sys.executable, "python_version": sys.version,
                         "packages": versions, "python_openssl": ssl.OPENSSL_VERSION,
                         "openssl": None, "openssl_executable": None,
                         "source_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                         "certificate_sha256": None}
        if self.protocol == "tls":
            selected = os.environ.get("OPENSSL_BIN") or "openssl"
            openssl = shutil.which(selected)
            if openssl is None:
                raise RuntimeError(f"OPENSSL_BIN must select an available executable: {selected}")
            root = Path(__file__).resolve().parents[4]
            result = self.preparation_command(
                ["bash", str(root / "scripts/generate-fixtures.sh"), self.temp.name], commands, deadline)
            if result is None:
                return False
            metadata = self.preparation_command([openssl, "version", "-a"], commands, deadline)
            if metadata is None:
                return False
            self.ca, self.cert, self.key = [str(Path(self.temp.name) / n)
                                            for n in ("ca.pem", "cert.pem", "key.pem")]
            self.context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            self.context.load_cert_chain(self.cert, self.key)
            self.context.set_alpn_protocols([self.alpn])
            self.context.set_servername_callback(
                lambda sock, name, _context: setattr(sock, "_gaoxy_sni", name))
            self.identity.update(openssl=metadata, openssl_executable=openssl,
                                 certificate_sha256=hashlib.sha256(Path(self.cert).read_bytes()).hexdigest())
            if time.monotonic() >= deadline:
                raise TimeoutError("fixture TLS preparation timed out")
        return True

    def start(self):
        self.listener = socket.socket()
        self.listener.bind((self.bind_address, self.listen_port))
        self.listener.listen(8)
        self.listener.settimeout(0.1)
        self.port = self.listener.getsockname()[1]
        self.acceptor = threading.Thread(target=self.accept)
        self.acceptor.start()
        self.emit("ready", protocol=self.protocol, port=self.port,
                  bind_address=self.listener.getsockname()[0], ca=self.ca, cert=self.cert, key=self.key,
                  identity=self.identity)

    def accept(self):
        try:
            while not self.stopping.is_set() and time.monotonic() < self.deadline:
                try:
                    raw, _ = self.listener.accept()
                except socket.timeout:
                    continue
                with self.lock:
                    self.accepts += 1
                    number = self.accepts
                    if number > 8:
                        raw.close()
                        raise RuntimeError("fixture connection bound exceeded")
                    client = dict(socket=raw, h2=None, uploads={}, targets={}, pending={}, eof=False,
                                  responses=set(), write_closed=False, tls_close_request=None,
                                  credit_holds=set(), credit_released=set())
                    self.clients[number] = client
                    worker = threading.Thread(target=self.serve, args=(number, client))
                    self.workers.append(worker)
                    worker.start()
                    self.emit("accept", connection=number)
        except Exception as error:
            if not self.stopping.is_set():
                self.fail(error)

    def serve(self, number, client):
        sock = client["socket"]
        tls_unwrapped = False
        try:
            if self.context:
                sock.settimeout(3)
                sock = self.context.wrap_socket(sock, server_side=True)
                client["socket"] = sock
                selected = sock.selected_alpn_protocol()
                self.emit("tls", connection=number, alpn=selected,
                          sni=getattr(sock, "_gaoxy_sni", None))
                if selected != "h2":
                    # A no-fallback fixture expects EOF before any H1 request bytes.
                    data = sock.recv(4096)
                    if data:
                        raise RuntimeError("client fell back and sent non-H2 application bytes")
                    client["eof"] = True
                    self.emit("eof", connection=number)
                    return
            sock.settimeout(0.1)
            with self.lock:
                conn = h2.connection.H2Connection(config=h2.config.H2Configuration(
                    client_side=False, header_encoding="utf-8"))
                initial_values = dict(conn.local_settings.items()) if self.hold_upload_credit else {}
                if self.max_streams is not None:
                    initial_values[h2.settings.SettingCodes.MAX_CONCURRENT_STREAMS] = self.max_streams
                if self.hold_upload_credit:
                    initial_values[h2.settings.SettingCodes.INITIAL_WINDOW_SIZE] = 1
                if initial_values:
                    conn.local_settings = h2.settings.Settings(client=False, initial_values=initial_values)
                conn.initiate_connection()
                client["h2"] = conn
                sock.sendall(conn.data_to_send())
            while not self.stopping.is_set() and time.monotonic() < self.deadline:
                with self.lock:
                    close_request = client["tls_close_request"]
                if close_request is not None:
                    value, deadline = close_request
                    try:
                        sock = self.unwrap_health_tls(sock, deadline)
                    except ssl.SSLError as error:
                        # A local shutdown error is not a remote connection reset.
                        raise RuntimeError("fixture health TLS shutdown failed: " + repr(error)) from error
                    tls_unwrapped = True
                    sock.settimeout(0.1)
                    with self.lock:
                        client["socket"] = sock
                        socket.socket.shutdown(sock, socket.SHUT_WR)
                        client["write_closed"] = True
                        client["tls_close_request"] = None
                        self.emit("command", op=value["op"], connection=number,
                                  stream=value.get("stream", 1), command_id=value.get("command_id"),
                                  code=value.get("code"), last_stream=value.get("last_stream"),
                                  max_streams=value.get("max_streams"))
                try:
                    data = sock.recv(65536)
                except socket.timeout:
                    continue
                if not data:
                    client["eof"] = True
                    self.emit("eof", connection=number)
                    return
                if tls_unwrapped:
                    raise RuntimeError("fixture unexpected payload after health TLS shutdown")
                with self.lock:
                    for event in conn.receive_data(data):
                        if isinstance(event, h2.events.RequestReceived):
                            if client["write_closed"] or client["tls_close_request"] is not None:
                                raise RuntimeError("fixture request after write half-close")
                            self.requests += 1
                            if self.requests > 256:
                                raise RuntimeError("fixture request bound exceeded")
                            client["uploads"][event.stream_id] = bytearray()
                            fields = event.headers
                            target = dict(fields)[":path"]
                            client["targets"][event.stream_id] = target
                            self.emit("request", connection=number, stream=event.stream_id,
                                      headers=fields, target=target, ended=event.stream_ended is not None)
                            if not self.manual and target.split("?", 1)[0] not in ("/echo", "/hold"):
                                self.automatic(number, client, event.stream_id, target, dict(fields)[":method"])
                        elif isinstance(event, h2.events.DataReceived):
                            upload = client["uploads"][event.stream_id]
                            upload.extend(event.data)
                            if len(upload) > 1048576:
                                raise RuntimeError("fixture upload bound exceeded")
                            self.emit("upload", connection=number, stream=event.stream_id,
                                      chunk_bytes=len(event.data), total_bytes=len(upload),
                                      sha256=hashlib.sha256(upload).hexdigest())
                            held_target = (self.hold_upload_credit and
                                           client["targets"][event.stream_id] == "/hold/upload-credit")
                            if held_target and event.stream_id not in client["credit_released"]:
                                if (event.stream_id in client["credit_holds"] or len(upload) != 1 or
                                        event.flow_controlled_length != 1 or event.stream_ended is not None or
                                        conn.remote_flow_control_window(event.stream_id) != 0 or
                                        conn.inbound_flow_control_window <= 0):
                                    raise RuntimeError("fixture upload did not reach exact stream-credit hold")
                                client["credit_holds"].add(event.stream_id)
                                self.emit("upload_credit_held", connection=number, stream=event.stream_id,
                                          total_bytes=len(upload), held_bytes=event.flow_controlled_length,
                                          stream_window=conn.remote_flow_control_window(event.stream_id),
                                          connection_window=conn.inbound_flow_control_window,
                                          sha256=hashlib.sha256(upload).hexdigest())
                            else:
                                conn.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                        elif isinstance(event, h2.events.TrailersReceived):
                            if (self.hold_upload_credit and
                                    client["targets"][event.stream_id] == "/hold/upload-credit" and
                                    event.stream_id not in client["credit_released"]):
                                raise RuntimeError("fixture upload trailers preceded credit release")
                            self.emit("upload_trailers", connection=number, stream=event.stream_id,
                                      fields=event.headers)
                        elif isinstance(event, h2.events.StreamEnded):
                            upload_values = dict(total_bytes=len(client["uploads"].get(event.stream_id, b"")))
                            if (self.hold_upload_credit and
                                    client["targets"][event.stream_id] == "/hold/upload-credit"):
                                if event.stream_id not in client["credit_released"]:
                                    raise RuntimeError("fixture upload end preceded credit release")
                                upload_values["body64"] = base64.b64encode(
                                    client["uploads"].get(event.stream_id, b"")).decode("ascii")
                            self.emit("upload_end", connection=number, stream=event.stream_id, **upload_values)
                            if (not self.manual and event.stream_id not in client["responses"]
                                    and client["targets"][event.stream_id].split("?", 1)[0] != "/hold"):
                                body = bytes(client["uploads"].get(event.stream_id, b""))
                                self.respond(client, event.stream_id, 200, [], body, [])
                        elif isinstance(event, h2.events.StreamReset):
                            client["pending"].pop(event.stream_id, None)
                            reset_values = {}
                            if (self.hold_upload_credit and
                                    client["targets"].get(event.stream_id) == "/hold/upload-credit" and
                                    event.stream_id in client["credit_holds"]):
                                upload = bytes(client["uploads"][event.stream_id])
                                reset_values["upload_credit"] = {
                                    "total_bytes": len(upload),
                                    "body64": base64.b64encode(upload).decode("ascii"),
                                    "sha256": hashlib.sha256(upload).hexdigest(),
                                    "credit_released": event.stream_id in client["credit_released"],
                                    "response_started": event.stream_id in client["responses"],
                                }
                            self.emit("reset", connection=number, stream=event.stream_id,
                                      code=int(event.error_code), **reset_values)
                        elif isinstance(event, h2.events.ConnectionTerminated):
                            self.emit("goaway_received", connection=number, code=int(event.error_code),
                                      last_stream=event.last_stream_id)
                        elif isinstance(event, h2.events.SettingsAcknowledged):
                            settings_values = dict(max_streams=conn.local_settings.max_concurrent_streams)
                            if self.hold_upload_credit:
                                settings_values["initial_window"] = conn.local_settings.initial_window_size
                            self.emit("settings_ack", connection=number, **settings_values)
                            self.emit("control", connection=number, kind=type(event).__name__)
                        elif isinstance(event, (h2.events.RemoteSettingsChanged,
                                                h2.events.WindowUpdated, h2.events.PriorityUpdated)):
                            self.emit("control", connection=number, kind=type(event).__name__)
                        else:
                            raise RuntimeError("unexpected H2 event: " + repr(event))
                    self.flush(client)
        except (ssl.SSLError, ConnectionResetError) as error:
            client["eof"] = True
            self.emit("handshake_failed" if client["h2"] is None else "connection_reset",
                      connection=number, reason=repr(error)[:512])
        except Exception as error:
            if not self.stopping.is_set():
                self.fail(error)
        finally:
            sock.close()

    def unwrap_health_tls(self, sock, deadline):
        # Only the original reader may change this connection's TLS state.
        sock.setblocking(False)
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("fixture health TLS shutdown deadline expired")
            try:
                return sock.unwrap()
            except ssl.SSLWantReadError:
                readers, writers = [sock], []
            except ssl.SSLWantWriteError:
                readers, writers = [], [sock]
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not any(select.select(readers, writers, [], remaining)[:2]):
                raise TimeoutError("fixture health TLS shutdown deadline expired")

    def automatic(self, number, client, stream, target, method):
        path = target.split("?", 1)[0]
        fields, trailers, status = [("x-peer", "independent-h2"), ("x-target", target)], [], 200
        body = target.encode()
        if path == "/probe":
            fields += [("content-type", "text/html; charset=utf-8")]
            body = b"<!doctype html><title>Gaoxy managed H2</title><h1 id=probe>managed H2 probe</h1>"
        elif path == "/stream":
            body = b"managed-h2-stream:" + b"s" * 65536
        elif path == "/early":
            status, body = 413, b"early-final"
        elif path == "/gzip":
            body = gzip.compress(b"raw-compression", mtime=0)
            fields += [("content-encoding", "gzip")]
        elif path == "/redirect":
            status, body = 302, b"redirect"
            fields += [("location", "http://unfollowed.invalid/never")]
        elif path == "/trailers":
            body = b"trailers"
            fields += [("trailer", "x-check"), ("set-cookie", "one=1"), ("set-cookie", "two=2")]
            trailers = [("x-check", "first"), ("x-check", "second")]
        elif path in ("/204", "/205", "/304"):
            status, body = int(path[1:]), b""
            if status == 205:
                fields += [("content-length", "0")]
            elif status == 304:
                fields += [("content-length", "123")]
        if method == "HEAD":
            fields += [("content-length", str(len(body)))]
            body = b""
        elif status not in (204, 205, 304) and not trailers:
            fields += [("content-length", str(len(body)))]
        self.respond(client, stream, status, fields, body, trailers)

    def respond(self, client, stream, status, fields, body, trailers, ended=True):
        conn = client["h2"]
        conn.send_headers(stream, [(":status", str(status)), *fields], end_stream=ended and not body and not trailers)
        client["responses"].add(stream)
        if body or trailers or not ended:
            client["pending"][stream] = [body, trailers, ended]

    def flush(self, client):
        conn = client["h2"]
        if client["write_closed"]:
            # No application writes remain; discard control output after SHUT_WR.
            conn.data_to_send()
            return
        for stream, pending in list(client["pending"].items()):
            body, trailers, ended = pending
            while body and conn.local_flow_control_window(stream) > 0:
                count = min(len(body), conn.local_flow_control_window(stream), 16384)
                piece, body = body[:count], body[count:]
                conn.send_data(stream, piece, end_stream=ended and not body and not trailers)
            pending[0] = body
            if not body and ended:
                if trailers:
                    conn.send_headers(stream, trailers, end_stream=True)
                client["pending"].pop(stream)
        outbound = conn.data_to_send()
        if outbound:
            client["socket"].sendall(outbound)

    def command(self, value):
        op = value["op"]
        if op == "stop":
            self.stop()
            return False
        with self.lock:
            client = self.clients[value["connection"]]
            if client["write_closed"] or client["tls_close_request"] is not None:
                raise RuntimeError("fixture command after write half-close")
            conn, stream = client["h2"], value.get("stream", 1)
            if op == "respond":
                body = base64.b64decode(value.get("body64", ""), validate=True)
                if len(body) > 1048576:
                    raise RuntimeError("fixture command body bound exceeded")
                self.respond(client, stream, value.get("status", 200), value.get("fields", []),
                             body, value.get("trailers", []), value.get("ended", True))
            elif op == "data":
                body = base64.b64decode(value["body64"], validate=True)
                client["pending"][stream] = [body, value.get("trailers", []), value.get("ended", False)]
            elif op == "inform":
                conn.send_headers(stream, [(":status", str(value.get("status", 103))), *value.get("fields", [])])
            elif op == "reset":
                conn.reset_stream(stream, error_code=value.get("code", 8))
                client["pending"].pop(stream, None)
            elif op == "goaway":
                payload = value.get("last_stream", stream).to_bytes(4, "big") + value.get("code", 0).to_bytes(4, "big")
                client["socket"].sendall(len(payload).to_bytes(3, "big") + b"\x07\x00\x00\x00\x00\x00" + payload)
            elif op == "write_half_close":
                if (client["targets"] != {stream: "/health"} or client["pending"]
                        or stream not in client["responses"]):
                    raise RuntimeError("fixture write half-close requires completed sole health response")
            elif op == "release_upload_credit":
                if (not self.hold_upload_credit or value.get("credit_bytes") != 1 or
                        client["targets"].get(stream) != "/hold/upload-credit" or
                        stream not in client["credit_holds"] or
                        stream in client["credit_released"] or
                        conn.remote_flow_control_window(stream) != 0 or
                        conn.inbound_flow_control_window <= 0):
                    raise RuntimeError("fixture upload-credit release outside exact hold")
                conn.increment_flow_control_window(1, stream)
                conn.increment_flow_control_window(1)
                client["credit_released"].add(stream)
            elif op == "settings":
                conn.update_settings({h2.settings.SettingCodes.MAX_CONCURRENT_STREAMS: value["max_streams"]})
            else:
                raise RuntimeError("unknown fixture operation")
            self.flush(client)
            if op == "write_half_close":
                if isinstance(client["socket"], ssl.SSLSocket):
                    # No ACK until the original reader completes TLS then SHUT_WR.
                    client["tls_close_request"] = (
                        dict(value), min(self.deadline, time.monotonic() + 5.0))
                    return True
                socket.socket.shutdown(client["socket"], socket.SHUT_WR)
                client["write_closed"] = True
            credit_values = {"credit_bytes": 1} if op == "release_upload_credit" else {}
            self.emit("command", op=op, connection=value["connection"], stream=stream,
                      command_id=value.get("command_id"), code=value.get("code"),
                      last_stream=value.get("last_stream"), max_streams=value.get("max_streams"),
                      **credit_values)
        return True

    def stop(self):
        if self.joined:
            return
        self.stopping.set()
        try:
            if self.listener is not None:
                self.listener.close()
            if self.acceptor is not None:
                self.acceptor.join(2)
            forced = 0
            for client in self.clients.values():
                if not client["eof"]:
                    forced += 1
                    try:
                        client["socket"].shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass
            for worker in self.workers:
                worker.join(2)
            live = int(self.acceptor is not None and self.acceptor.is_alive()) + sum(w.is_alive() for w in self.workers)
        finally:
            self.temp.cleanup()
        self.joined = True
        self.emit("joined", accepts=self.accepts, requests=self.requests, forced=forced, live=live, failed=self.failed)
        if live:
            raise RuntimeError("fixture join failed")


class ClientBuffer:
    def __init__(self, sock):
        self.sock, self.buffer = sock, b""
        self.deadline = time.monotonic() + 20

    def read(self, count):
        if not 0 <= count <= 1048576:
            raise RuntimeError("client read bound exceeded")
        while len(self.buffer) < count:
            if time.monotonic() >= self.deadline:
                raise TimeoutError("independent client deadline")
            data = self.sock.recv(min(65536, count - len(self.buffer)))
            if not data:
                raise EOFError("downstream closed before complete response")
            self.buffer += data
        value, self.buffer = self.buffer[:count], self.buffer[count:]
        return value

    def line(self):
        value = bytearray()
        while not value.endswith(b"\r\n"):
            value.extend(self.read(1))
            if len(value) > 65536:
                raise RuntimeError("client line bound exceeded")
        return bytes(value[:-2])

    def fields(self, max_count=258):
        fields, total = [], 0
        while True:
            line = self.line()
            if not line:
                return fields
            total += len(line) + 2
            if len(fields) >= max_count or total > 81920:
                raise RuntimeError("client fields bound exceeded")
            name, value = line.split(b":", 1)
            fields.append([name.decode("ascii").lower(), value.lstrip(b" \t").decode("latin1")])


def client_prefix(args, data, complete):
    count = args.observe_prefix_bytes
    if count is None or args.prefix_observed or len(data) < count:
        return
    prefix = bytes(data[:count])
    args.prefix_observed = True
    print(json.dumps(dict(event="client_prefix", body64=base64.b64encode(prefix).decode(),
                          body_bytes=count, body_sha256=hashlib.sha256(prefix).hexdigest(),
                          complete=complete)), flush=True)


def client_h1_body(reader, args, data, count, complete=False):
    if not 0 <= count <= 1048576:
        raise RuntimeError("client read bound exceeded")
    threshold = args.observe_prefix_bytes
    if (threshold is not None and not args.prefix_observed and
            len(data) < threshold <= len(data) + count):
        prefix_count = threshold - len(data)
        data.extend(reader.read(prefix_count))
        client_prefix(args, data, complete and prefix_count == count)
        count -= prefix_count
    data.extend(reader.read(count))


def client_h1(sock, args, fields, body):
    if body and not any(name.lower() == "content-length" for name, _ in fields):
        fields = [*fields, ["content-length", str(len(body))]]
    request = (f"{args.method} {args.target} HTTP/1.1\r\n"
               f"Host: {args.hostname}:{args.port}\r\nConnection: close\r\n")
    request += "".join(f"{name}: {value}\r\n" for name, value in fields) + "\r\n"
    sock.sendall(request.encode("latin1") + body)
    args.chunked_upload = ["transfer-encoding", "chunked"] in fields
    sender = None
    if args.controlled:
        sender = threading.Thread(target=h1_upload_commands, args=(sock, args))
        sender.start()
        args.upload_thread = sender
    reader, informational = ClientBuffer(sock), []
    while True:
        line = reader.line().decode("ascii")
        version, raw_status, _ = line.split(" ", 2)
        if version != "HTTP/1.1":
            raise RuntimeError("unexpected downstream HTTP version")
        status, headers = int(raw_status), reader.fields()
        if status >= 200:
            break
        informational.append(dict(status=status, headers=headers))
        if len(informational) > 128:
            raise RuntimeError("client informational bound exceeded")
    client_head(args, status, headers, informational)
    data, trailers = bytearray(), []
    args.received_body = data
    lookup = dict(headers)
    if args.method == "HEAD" or status in (204, 205, 304):
        pass
    elif lookup.get("transfer-encoding") == "chunked":
        while True:
            count = int(reader.line().split(b";", 1)[0], 16)
            if count == 0:
                trailers = reader.fields(128)
                break
            if len(data) + count > 1048576:
                raise RuntimeError("client response body bound exceeded")
            client_h1_body(reader, args, data, count)
            if reader.read(2) != b"\r\n":
                raise RuntimeError("invalid downstream chunk delimiter")
    elif "content-length" in lookup:
        client_h1_body(reader, args, data, int(lookup["content-length"]), complete=True)
    else:
        while True:
            piece = sock.recv(65536)
            if not piece:
                break
            data.extend(piece)
            if len(data) > 1048576 or time.monotonic() >= reader.deadline:
                raise RuntimeError("client response body/deadline bound exceeded")
            client_prefix(args, data, False)
    return status, headers, trailers, informational, bytes(data)


def managed_fixed_socket_timeout(sock, deadline, timeout):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError("independent H2 client deadline")
    sock.settimeout(min(timeout, remaining) if timeout is not None else remaining)


def acknowledge_managed_fixed_header_list(conn, sock, deadline):
    # A same-value public update creates an actual pending SETTINGS change.
    # Its real ACK makes h2 synchronize the decoder with the existing finite
    # 131072 advertisement before any response can arrive.
    timeout, acknowledged = sock.gettimeout(), None
    conn.update_settings({h2.settings.SettingCodes.MAX_HEADER_LIST_SIZE: 131072})
    pending = conn.data_to_send()
    managed_fixed_socket_timeout(sock, deadline, timeout)
    sock.sendall(pending)
    try:
        while acknowledged is None:
            managed_fixed_socket_timeout(sock, deadline, timeout)
            try:
                received = sock.recv(65536)
            except socket.timeout:
                continue
            if not received:
                raise EOFError("downstream closed before header-list SETTINGS ACK")
            for event in conn.receive_data(received):
                if isinstance(event, h2.events.SettingsAcknowledged):
                    change = event.changed_settings.get(h2.settings.SettingCodes.MAX_HEADER_LIST_SIZE)
                    if change is not None and change.original_value == 131072 and change.new_value == 131072:
                        acknowledged = dict(original_value=change.original_value, new_value=change.new_value)
                elif not isinstance(event, (h2.events.RemoteSettingsChanged, h2.events.WindowUpdated,
                                            h2.events.PriorityUpdated)):
                    raise RuntimeError("unexpected downstream H2 event before settings ACK: " + repr(event))
            pending = conn.data_to_send()
            if pending:
                managed_fixed_socket_timeout(sock, deadline, timeout)
                sock.sendall(pending)
        return acknowledged
    finally:
        sock.settimeout(timeout)


def client_h2(sock, args, fields, body):
    conn = h2.connection.H2Connection(config=h2.config.H2Configuration(
        client_side=True, header_encoding="utf-8"))
    # Count the peer's actual bounded renderer projection, including RFC HPACK
    # per-field overhead, rather than the library's smaller default list cap.
    conn.local_settings = h2.settings.Settings(client=True, initial_values={
        h2.settings.SettingCodes.MAX_HEADER_LIST_SIZE: 131072})
    conn.initiate_connection()
    managed_deadline, managed_timeout = None, None
    if args.managed_fixed_client:
        managed_deadline, managed_timeout = time.monotonic() + 20, sock.gettimeout()
        args.managed_fixed_header_list_ack = acknowledge_managed_fixed_header_list(conn, sock, managed_deadline)
        managed_fixed_socket_timeout(sock, managed_deadline, managed_timeout)
    conn.send_headers(1, [(":method", args.method), (":scheme", "https" if args.tls else "http"),
                          (":authority", f"{args.hostname}:{args.port}"), (":path", args.target),
                          *fields], end_stream=not body and not args.controlled)
    pending = conn.data_to_send()
    if managed_deadline is not None:
        managed_fixed_socket_timeout(sock, managed_deadline, managed_timeout)
    sock.sendall(pending)
    remaining, data, headers, trailers, informational, status = body, bytearray(), [], [], [], None
    deadline, ended, upload_trailers = managed_deadline or time.monotonic() + 20, False, []
    args.received_body = data
    while not ended:
        if time.monotonic() >= deadline:
            raise TimeoutError("independent H2 client deadline")
        if args.controlled and not remaining and not args.upload_finished:
            command = upload_command()
            if command is not None:
                remaining = base64.b64decode(command.get("body64", ""), validate=True)
                args.upload_finished = command.get("ended", False)
                upload_trailers = command.get("trailers", [])
                if not remaining and args.upload_finished and not upload_trailers:
                    conn.end_stream(1)
                    args.upload_eof_sent = True
        while remaining and conn.local_flow_control_window(1) > 0:
            count = min(len(remaining), conn.local_flow_control_window(1), conn.max_outbound_frame_size)
            piece, remaining = remaining[:count], remaining[count:]
            end_stream = not remaining and not upload_trailers and (not args.controlled or args.upload_finished)
            conn.send_data(1, piece, end_stream=end_stream)
            if end_stream:
                args.upload_eof_sent = True
            args.upload_sent += len(piece)
            if args.upload_sent > 1048576:
                raise RuntimeError("controlled upload bound exceeded")
        if not remaining and upload_trailers:
            conn.send_headers(1, upload_trailers, end_stream=True)
            args.upload_eof_sent, upload_trailers = True, []
        pending = conn.data_to_send()
        if pending:
            sock.sendall(pending)
        try:
            if managed_deadline is not None:
                remaining_seconds = deadline - time.monotonic()
                if remaining_seconds <= 0:
                    raise TimeoutError("independent H2 client deadline")
                sock.settimeout(min(managed_timeout, remaining_seconds)
                                if managed_timeout is not None else remaining_seconds)
            received = sock.recv(65536)
        except socket.timeout:
            if args.controlled:
                continue
            raise
        if not received:
            raise EOFError("downstream closed before complete H2 response")
        for event in conn.receive_data(received):
            if isinstance(event, h2.events.ResponseReceived):
                status = int(dict(event.headers)[":status"])
                headers = [[name, value] for name, value in event.headers if not name.startswith(":")]
                client_head(args, status, headers, informational)
            elif isinstance(event, h2.events.InformationalResponseReceived):
                informational.append(dict(status=int(dict(event.headers)[":status"]),
                                          headers=[[name, value] for name, value in event.headers if not name.startswith(":")]))
                if len(informational) > 128:
                    raise RuntimeError("client informational bound exceeded")
            elif isinstance(event, h2.events.DataReceived):
                data.extend(event.data)
                if len(data) > 1048576:
                    raise RuntimeError("client response body bound exceeded")
                conn.acknowledge_received_data(event.flow_controlled_length, 1)
            elif isinstance(event, h2.events.TrailersReceived):
                trailers = [[name, value] for name, value in event.headers]
            elif isinstance(event, h2.events.StreamEnded):
                ended = True
            elif isinstance(event, (h2.events.StreamReset, h2.events.ConnectionTerminated)):
                if args.allow_incomplete and status is not None:
                    args.termination = "reset" if isinstance(event, h2.events.StreamReset) else "goaway"
                    client_prefix(args, data, ended)
                    return status, headers, trailers, informational, bytes(data)
                raise RuntimeError("downstream reset/GOAWAY before response: " + repr(event))
            elif not isinstance(event, (h2.events.RemoteSettingsChanged, h2.events.SettingsAcknowledged,
                                        h2.events.WindowUpdated, h2.events.PriorityUpdated)):
                raise RuntimeError("unexpected downstream H2 event: " + repr(event))
        pending = conn.data_to_send()
        if pending:
            sock.sendall(pending)
        client_prefix(args, data, ended)
    if status is None:
        raise RuntimeError("missing H2 response status")
    return status, headers, trailers, informational, bytes(data)


def client_head(args, status, headers, informational):
    args.head = (status, headers, informational)
    if args.events:
        print(json.dumps(dict(event="client_head", status=status, headers=headers,
                              informational=informational)), flush=True)


def upload_command():
    if not select.select([sys.stdin], [], [], 0)[0]:
        return None
    line = sys.stdin.readline()
    if not line:
        raise EOFError("controlled upload stdin closed")
    if len(line) > 2097152:
        raise RuntimeError("controlled client command bound exceeded")
    command = json.loads(line)
    if command.get("op") != "upload":
        raise ValueError("unknown controlled client command")
    trailers = command.get("trailers", [])
    if (not isinstance(trailers, list) or len(trailers) > 128 or
            any(not isinstance(pair, list) or len(pair) != 2 or
                any(not isinstance(part, str) or "\r" in part or "\n" in part for part in pair)
                for pair in trailers) or (trailers and not command.get("ended", False))):
        raise ValueError("invalid controlled request trailers")
    return command


def h1_upload_commands(sock, args):
    try:
        while not args.upload_stop.wait(0.01) and not args.upload_finished:
            command = upload_command()
            if command is None:
                continue
            chunk = base64.b64decode(command.get("body64", ""), validate=True)
            args.upload_sent += len(chunk)
            if args.upload_sent > 1048576:
                raise RuntimeError("controlled upload bound exceeded")
            if chunk:
                wire = (f"{len(chunk):x}\r\n".encode() + chunk + b"\r\n") if args.chunked_upload else chunk
                sock.sendall(wire)
            args.upload_finished = command.get("ended", False)
            trailers = command.get("trailers", [])
            if trailers and not args.chunked_upload:
                raise ValueError("H1 request trailers require chunk framing")
            if args.upload_finished:
                if args.chunked_upload:
                    terminal = "0\r\n" + "".join(f"{name}: {value}\r\n" for name, value in trailers) + "\r\n"
                    sock.sendall(terminal.encode("latin1"))
                args.upload_eof_sent = True
    except Exception as error:
        args.upload_error = repr(error)


def independent_client(args):
    if args.downstream is None or args.port is None or not 1 <= args.port <= 65535:
        raise ValueError("client requires downstream and finite port")
    if args.managed_fixed_client and args.downstream != "h2":
        raise ValueError("managed fixed client profile requires downstream H2")
    body = base64.b64decode(args.body64, validate=True)
    fields = json.loads(args.headers_json)
    if (len(body) > 1048576 or not args.target.startswith("/") or
            len(args.target.encode()) > 65536 or len(fields) > 256 or
            any(not isinstance(pair, list) or len(pair) != 2 or
                any(not isinstance(item, str) or "\r" in item or "\n" in item for item in pair)
                for pair in fields)):
        raise ValueError("client input bound exceeded")
    sock = socket.create_connection(("127.0.0.1", args.port), timeout=5)
    args.head, args.received_body, args.termination = None, bytearray(), "complete"
    args.prefix_observed = False
    args.upload_stop, args.upload_thread, args.upload_error = threading.Event(), None, None
    args.upload_sent, args.upload_finished, args.upload_eof_sent = 0, False, False
    protocol = "http/1.1" if args.downstream == "h1" else "h2c"
    try:
        if args.tls:
            context = ssl.create_default_context(cafile=args.ca)
            context.set_alpn_protocols(["http/1.1" if args.downstream == "h1" else "h2"])
            sock = context.wrap_socket(sock, server_hostname=args.hostname)
            protocol = sock.selected_alpn_protocol()
            if protocol != ("http/1.1" if args.downstream == "h1" else "h2"):
                raise RuntimeError("downstream ALPN mismatch")
        if args.controlled and args.downstream == "h2":
            sock.settimeout(0.1)
        elif args.events:
            sock.settimeout(20)
        try:
            response = (client_h1 if args.downstream == "h1" else client_h2)(sock, args, fields, body)
        except (EOFError, ConnectionResetError) as error:
            if not args.allow_incomplete or args.head is None:
                raise
            args.termination = "eof" if isinstance(error, EOFError) else "reset"
            status, headers, informational = args.head
            response = status, headers, [], informational, bytes(args.received_body)
    finally:
        args.upload_stop.set()
        if args.upload_thread is not None:
            args.upload_thread.join(1)
            if args.upload_thread.is_alive():
                raise RuntimeError("controlled upload helper failed to join")
        sock.close()
    if args.upload_error is not None:
        raise RuntimeError("controlled upload failed: " + args.upload_error)
    status, headers, trailers, informational, data = response
    result = dict(protocol=protocol, status=status, headers=headers, trailers=trailers,
                          informational=informational, body64=base64.b64encode(data).decode(),
                          body_bytes=len(data), body_sha256=hashlib.sha256(data).hexdigest(),
                          socket_closed=True, identity=dict(python=sys.executable,
                            packages={p: importlib.metadata.version(p) for p in ("h2", "hpack", "hyperframe")},
                            source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()))
    if args.managed_fixed_client:
        result["managed_fixed_header_list_ack"] = args.managed_fixed_header_list_ack
    if args.events:
        result.update(event="client_response", termination=args.termination,
                      complete=args.termination == "complete", upload_bytes=args.upload_sent,
                      upload_eof=args.upload_eof_sent, upload_helper_joined=True)
    print(json.dumps(result, separators=(",", ":")), flush=True)
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", choices=("tls", "h2c"))
    parser.add_argument("--manual", action="store_true")
    parser.add_argument("--hold-upload-credit", action="store_true")
    parser.add_argument("--staged-start", action="store_true")
    parser.add_argument("--bind-address", default="127.0.0.1",
                        choices=("127.0.0.1", "127.0.0.2", "127.0.0.3", "127.0.0.4"))
    parser.add_argument("--listen-port", type=int, default=0)
    parser.add_argument("--max-streams", type=int, choices=range(1, 129))
    parser.add_argument("--alpn", default="h2", choices=("h2", "http/1.1"))
    parser.add_argument("--client", action="store_true")
    parser.add_argument("--managed-fixed-client", action="store_true")
    parser.add_argument("--events", action="store_true")
    parser.add_argument("--observe-prefix-bytes", type=int)
    parser.add_argument("--controlled", action="store_true")
    parser.add_argument("--allow-incomplete", action="store_true")
    parser.add_argument("--downstream", choices=("h1", "h2"))
    parser.add_argument("--port", type=int)
    parser.add_argument("--target", default="/probe")
    parser.add_argument("--method", default="GET", choices=("GET", "HEAD", "POST", "PUT", "PATCH", "OPTIONS", "DELETE"))
    parser.add_argument("--body64", default="")
    parser.add_argument("--headers-json", default="[]")
    parser.add_argument("--tls", action="store_true")
    parser.add_argument("--ca")
    parser.add_argument("--hostname", default="localhost")
    args = parser.parse_args()
    if not 0 <= args.listen_port <= 65535:
        parser.error("--listen-port must be between 0 and 65535")
    if args.controlled:
        args.events = True
    if args.observe_prefix_bytes is not None:
        if not args.client or not args.events:
            parser.error("--observe-prefix-bytes requires --client and --events or --controlled")
        if not 1 <= args.observe_prefix_bytes <= 1048576:
            parser.error("--observe-prefix-bytes must be between 1 and 1048576")
    if args.client:
        try:
            return independent_client(args)
        except Exception as error:
            print(json.dumps(dict(event="client_failure", reason=repr(error)[:1024])), flush=True)
            return 1
    if args.protocol is None:
        parser.error("peer requires --protocol")
    peer = Peer(args.protocol, args.manual, args.alpn, args.max_streams,
                args.bind_address, args.listen_port, args.hold_upload_credit)
    commands = Commands()
    try:
        if peer.prepare(commands):
            if args.staged_start:
                peer.emit("prepared", protocol=peer.protocol)
                command = commands.read(5)
                if command is None:
                    raise TimeoutError("fixture staged listener start timed out")
                if command["op"] == "stop":
                    peer.stopping.set()
                elif command["op"] != "start":
                    raise RuntimeError("fixture requires explicit listener start")
            if not peer.stopping.is_set():
                peer.start()
                while peer.command(commands.read()):
                    pass
    except Exception as error:
        peer.fail(error)
    finally:
        peer.stop()
    return int(peer.failed)


if __name__ == "__main__":
    sys.exit(main())
