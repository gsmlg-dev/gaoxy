"""Independent bounded H1 wire oracle; no historical fixture imports."""
import argparse
import hashlib
import json
import select
import socket
import sys
import threading
import time

SCENARIOS = frozenset(("ok", "held", "upload", "fanout", "cl", "eof", "line8192", "line8193", "bignum", "invalid", "trail128", "trail129", "forbidden", "trail65536", "trail65537"))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def field_digest(fields):
    return digest(b"".join(name.lower() + b": " + value + b"\r\n" for name, value in fields))


class PeerFailure(Exception):
    def __init__(self, category):
        self.category = category


class Worker:
    def __init__(self, peer, sock, number):
        self.peer, self.sock, self.number = peer, sock, number
        self.lock = threading.Lock()
        self.buffer = bytearray()
        self.thread = threading.Thread(target=self.run, name="h1-wire-%d" % number)
        self.head_bytes = 0
        self.requests = 0
        self.sock.settimeout(0.25)

    def read_more(self):
        while not self.peer.stopping.is_set():
            if time.monotonic() >= self.peer.deadline:
                raise PeerFailure("deadline")
            try:
                with self.lock:
                    data = self.sock.recv(min(8192, 131072 - len(self.buffer)))
                    if not data:
                        raise PeerFailure("eof")
                    self.buffer.extend(data)
                self.peer.add_wire(len(data))
                return
            except socket.timeout:
                continue
        raise PeerFailure("stopped")

    def take(self, n):
        if n < 0 or n > 131073:
            raise PeerFailure("body_limit")
        while len(self.buffer) < n:
            self.read_more()
        with self.lock:
            result = bytes(self.buffer[:n])
            del self.buffer[:n]
        return result

    def line(self, cap):
        while True:
            with self.lock:
                end = self.buffer.find(b"\r\n")
                if end >= 0:
                    if end + 2 > cap:
                        raise PeerFailure("line_limit")
                    value = bytes(self.buffer[:end])
                    del self.buffer[:end + 2]
                    return value
                if len(self.buffer) > cap:
                    raise PeerFailure("line_limit")
            self.read_more()

    def send(self, data, request, phase):
        if len(data) > 8192 and phase != "fanout":
            raise PeerFailure("response_piece_limit")
        self.sock.sendall(data)
        self.peer.emit("sent", connection=self.number, request=request,
                       phase=phase, length=len(data), sha256=digest(data))

    def send_pieces(self, data, request, phase):
        # Only an 8192-byte output workspace survives each write.
        for offset in range(0, len(data), 8192):
            self.sock.sendall(data[offset:offset + 8192])
        self.peer.emit("sent", connection=self.number, request=request,
                       phase=phase, length=len(data), sha256=digest(data))

    def body(self, fields, request):
        lowered = [(name.lower(), value) for name, value in fields]
        cls = [value for name, value in lowered if name == b"content-length"]
        chunked = any(name == b"transfer-encoding" and value.lower() == b"chunked" for name, value in lowered)
        hashed, length, chunks, trailers = hashlib.sha256(), 0, [], []
        if chunked:
            while True:
                line = self.line(8192)
                if not line or any(c not in b"0123456789abcdefABCDEF" for c in line):
                    raise PeerFailure("invalid_request_chunk")
                size = int(line, 16)
                if size == 0:
                    trailer_bytes = 2
                    while True:
                        line = self.line(65539)
                        trailer_bytes += len(line) + 2
                        if trailer_bytes > 65536:
                            raise PeerFailure("request_trailer_limit")
                        if not line:
                            break
                        if len(trailers) >= 128 or b":" not in line:
                            raise PeerFailure("request_trailer_limit")
                        name, value = line.split(b":", 1)
                        trailers.append((name, value.strip(b" \t")))
                    break
                if size > 65536 or len(chunks) >= 2 or length + size > 131073:
                    raise PeerFailure("body_limit")
                remaining = size
                while remaining:
                    piece = self.take(min(remaining, 8192))
                    hashed.update(piece)
                    length += len(piece)
                    remaining -= len(piece)
                if self.take(2) != b"\r\n":
                    raise PeerFailure("invalid_request_chunk")
                chunks.append(size)
        elif cls:
            if len(cls) != 1 or not cls[0].isdigit():
                raise PeerFailure("invalid_request_length")
            remaining = int(cls[0])
            if remaining > 131073:
                raise PeerFailure("body_limit")
            while remaining:
                piece = self.take(min(remaining, 8192))
                hashed.update(piece)
                length += len(piece)
                remaining -= len(piece)
        self.peer.emit("body", connection=self.number, request=request, length=length,
                       sha256=hashed.hexdigest(), chunks=chunks, trailer_count=len(trailers),
                       trailer_sha256=field_digest(trailers), terminal=True)

    def response(self, scenario, request):
        if scenario in ("ok", "upload"):
            self.send(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok", request, "response")
            return
        if scenario in ("cl", "eof"):
            header = (b"Content-Length: 131073" if scenario == "cl" else b"Connection: close")
            self.send(b"HTTP/1.1 200 OK\r\n" + header + b"\r\n\r\n", request, "response_head")
            hashed = hashlib.sha256()
            for offset in range(0, 131073, 8192):
                piece = bytes(i % 251 for i in range(offset, min(offset + 8192, 131073)))
                hashed.update(piece)
                self.sock.sendall(piece)
            self.peer.emit("sent", connection=self.number, request=request, phase="pattern",
                           length=131073, sha256=hashed.hexdigest())
            if scenario == "eof":
                self.sock.shutdown(socket.SHUT_WR)
                raise PeerFailure("eof")
            return
        close = b"Connection: close\r\n" if scenario in ("line8192", "line8193", "bignum", "invalid") else b""
        self.send(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n" + close + b"\r\n", request, "response_head")
        if scenario == "held":
            self.send(b"1\r\nh\r\n", request, "held")
            self.peer.wait_release(request)
            self.send(b"0\r\n\r\n", request, "terminal")
        elif scenario == "fanout":
            self.send(b"1\r\na\r\n" * 1365 + b"0\r\n\r\n", request, "fanout")
        elif scenario in ("line8192", "line8193"):
            n = 8192 if scenario == "line8192" else 8193
            self.send_pieces(b"0" * n, request, "line")
            self.peer.wait_release(request)
            if scenario == "line8192":
                self.send(b"\r\n\r\n", request, "terminal")
            else:
                raise PeerFailure("eof")
        elif scenario == "bignum":
            self.send(b"f" * 4096 + b"\r\nz\r\n", request, "bignum")
            self.sock.shutdown(socket.SHUT_WR)
            raise PeerFailure("eof")
        elif scenario == "invalid":
            self.send(b"g\r\n", request, "invalid")
            self.peer.wait_release(request)
            raise PeerFailure("eof")
        else:
            if scenario in ("trail128", "trail129"):
                n = 128 if scenario == "trail128" else 129
                trailer = b"".join(b"x-t: v%03d\r\n" % i for i in range(n)) + b"\r\n"
            elif scenario == "forbidden":
                trailer = b"Content-Length: 1\r\n\r\n"
            else:
                n = 65527 if scenario == "trail65536" else 65528
                trailer = b"x-t: " + b"p" * n + b"\r\n\r\n"
            self.send(b"1\r\nq\r\n0\r\n", request, "trailer_prefix")
            self.send_pieces(trailer, request, "trailers")
            if scenario in ("trail129", "forbidden", "trail65537"):
                self.peer.wait_release(request)
                raise PeerFailure("eof")

    def h1(self):
        while not self.peer.stopping.is_set():
            first = self.line(131072)
            parts = first.split(b" ")
            if len(parts) != 3 or parts[2] != b"HTTP/1.1":
                raise PeerFailure("invalid_request_head")
            method, target, _ = parts
            if len(target) > 128 or not target.startswith(b"/b"):
                raise PeerFailure("invalid_target")
            try:
                request = int(target.rstrip(b"?").rsplit(b"/", 1)[1])
            except ValueError:
                # B04 intentionally uses the exact opaque target /b04 or /b04?.
                request = self.peer.next_b04()
            scenario = self.peer.scenario(request)
            fields, raw, head_len = [], bytearray(first + b"\r\n"), len(first) + 2
            while True:
                line = self.line(131072)
                head_len += len(line) + 2
                if head_len > 131072:
                    raise PeerFailure("head_limit")
                raw.extend(line + b"\r\n")
                if not line:
                    break
                if len(fields) >= 256 or b":" not in line:
                    raise PeerFailure("invalid_request_head")
                name, value = line.split(b":", 1)
                fields.append((name, value.strip(b" \t")))
            with self.lock:
                self.requests += 1
                self.head_bytes += head_len
            self.peer.record_request(request, self.number)
            self.peer.emit("head", connection=self.number, request=request, target=target.decode("ascii"),
                           method=method.decode("ascii"), length=head_len, sha256=digest(raw),
                           field_count=len(fields), field_sha256=field_digest(fields))
            del raw
            self.body(fields, request)
            del fields
            self.response(scenario, request)

    def tls(self):
        scratch = bytearray()
        wire = 0
        while True:
            header = self.take(5)
            size = int.from_bytes(header[3:5], "big")
            wire += 5 + size
            if header[0] != 22 or size > 18432 or wire > 65536:
                raise PeerFailure("invalid_clienthello")
            scratch.extend(self.take(size))
            if len(scratch) >= 4:
                n = int.from_bytes(scratch[1:4], "big")
                if scratch[0] != 1 or n > 65532:
                    raise PeerFailure("invalid_clienthello")
                if len(scratch) >= n + 4:
                    self.peer.emit("head", connection=self.number, request=self.number,
                                   phase="clienthello", length=n + 4, sha256=digest(scratch[:n + 4]))
                    del scratch
                    self.peer.wait_release(self.number)
                    return

    def run(self):
        category = "eof"
        try:
            if self.peer.mode == "h1":
                self.h1()
            else:
                self.tls()
        except PeerFailure as error:
            category = error.category
            if category not in ("eof", "stopped"):
                self.peer.emit("failure", category=category, connection=self.number)
        except (OSError, ValueError, OverflowError):
            category = "socket_closed"
        finally:
            self.sock.close()
            self.peer.emit("eof", connection=self.number, phase=category)


class Peer:
    def __init__(self, mode, case):
        self.mode, self.case = mode, case
        self.deadline = time.monotonic() + 35
        self.stopping = threading.Event()
        self.lock, self.output_lock = threading.Lock(), threading.Lock()
        self.workers = [None] * 8
        self.scenarios = [None] * 128
        self.releases = [threading.Event() for _ in range(128)]
        self.requests = [0] * 128
        self.connections = self.events = self.controls = self.wire = self.b04_cursor = 0
        self.listener = socket.socket()
        self.listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(8)
        self.listener.setblocking(False)
        self.accept_thread = threading.Thread(target=self.accept, name="h1-accept")

    def emit(self, event, **data):
        with self.output_lock:
            self.events += 1
            if self.events > 128:
                self.stopping.set()
                raise PeerFailure("event_limit")
            line = json.dumps(dict(event=event, case=self.case, sequence=self.events, **data), separators=(",", ":"))
            if len(line) > 4096:
                self.stopping.set()
                raise PeerFailure("line_limit")
            print(line, flush=True)

    def add_wire(self, n):
        with self.lock:
            self.wire += n
            if self.wire > 4 * 1024 * 1024:
                raise PeerFailure("wire_limit")

    def accept(self):
        while not self.stopping.is_set() and time.monotonic() < self.deadline:
            try:
                readable, _, _ = select.select([self.listener], [], [], 0.1)
                if not readable:
                    continue
                with self.lock:
                    sock, _ = self.listener.accept()
                    if self.connections >= 8:
                        sock.close()
                        raise PeerFailure("connection_limit")
                    number = self.connections + 1
                    self.connections = number
                    worker = Worker(self, sock, number)
                    self.workers[number - 1] = worker
                    self.emit("accepted", connection=number)
                    worker.thread.start()
            except BlockingIOError:
                continue
            except OSError:
                return
            except PeerFailure as error:
                self.emit("failure", category=error.category)
                return

    def next_b04(self):
        with self.lock:
            while self.b04_cursor < 128 and self.scenarios[self.b04_cursor] is None:
                self.b04_cursor += 1
            result = self.b04_cursor
            self.b04_cursor += 1
            return result

    def scenario(self, request):
        if not 0 <= request < 128 or self.scenarios[request] not in SCENARIOS:
            raise PeerFailure("unarmed_request")
        return self.scenarios[request]

    def record_request(self, request, connection):
        with self.lock:
            if self.requests[request]:
                raise PeerFailure("duplicate_request")
            self.requests[request] = connection

    def wait_release(self, request):
        if not 0 <= request < 128:
            raise PeerFailure("invalid_request")
        while not self.stopping.is_set():
            if self.releases[request].wait(min(0.1, max(self.deadline - time.monotonic(), 0))):
                return
            if time.monotonic() >= self.deadline:
                raise PeerFailure("deadline")
        raise PeerFailure("stopped")

    def cut(self, operation):
        # Drained bytes stay in the worker's bounded parser buffer. This is a cut,
        # not a prediction of future silence or a private parser ingestion claim.
        with self.lock:
            while self.connections < 8:
                readable, _, _ = select.select([self.listener], [], [], 0)
                if not readable:
                    break
                try:
                    sock, _ = self.listener.accept()
                except BlockingIOError:
                    break
                number = self.connections + 1
                self.connections = number
                worker = Worker(self, sock, number)
                self.workers[number - 1] = worker
                self.emit("accepted", connection=number)
                worker.thread.start()
            for worker in self.workers:
                if worker is None or not worker.thread.is_alive():
                    continue
                with worker.lock:
                    try:
                        while len(worker.buffer) < 131072:
                            readable, _, _ = select.select([worker.sock], [], [], 0)
                            if not readable:
                                break
                            data = worker.sock.recv(min(8192, 131072 - len(worker.buffer)), socket.MSG_DONTWAIT)
                            if not data:
                                break
                            self.wire += len(data)
                            if self.wire > 4 * 1024 * 1024:
                                raise PeerFailure("wire_limit")
                            worker.buffer.extend(data)
                    except (OSError, ValueError):
                        pass
            connections = self.connections
            requests = sum(bool(n) for n in self.requests)
            head_bytes = sum(w.head_bytes for w in self.workers if w is not None)
        self.emit("wire_cut", operation=operation, connections=connections, requests=requests,
                  head_bytes=head_bytes, wire_bytes=self.wire)

    def stop(self, operation, deadline=None):
        deadline = self.deadline if deadline is None else min(deadline, self.deadline)
        self.stopping.set()
        self.listener.close()
        for gate in self.releases:
            gate.set()
        for worker in self.workers:
            if worker is not None:
                try:
                    worker.sock.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
        self.accept_thread.join(max(deadline - time.monotonic(), 0))
        for worker in self.workers:
            if worker is not None:
                worker.thread.join(max(deadline - time.monotonic(), 0))
        alive = int(self.accept_thread.is_alive()) + sum(w.thread.is_alive() for w in self.workers if w is not None)
        self.emit("stopped", operation=operation, connections=self.connections,
                  requests=sum(bool(n) for n in self.requests), alive_workers=alive,
                  joined_workers=sum(w is not None for w in self.workers), accept_join=not self.accept_thread.is_alive())
        return alive == 0

    def run(self):
        self.accept_thread.start()
        self.emit("ready", port=self.listener.getsockname()[1], protocol=self.mode)
        last_operation = 0
        try:
            while time.monotonic() < self.deadline:
                readable, _, _ = select.select([sys.stdin], [], [], min(0.25, max(self.deadline - time.monotonic(), 0)))
                if not readable:
                    continue
                raw = sys.stdin.buffer.readline(4097)
                if not raw:
                    raise PeerFailure("control_eof")
                if len(raw) > 4096 or not raw.endswith(b"\n"):
                    raise PeerFailure("control_limit")
                data = json.loads(raw)
                budget_ms = data.get("budget_ms")
                if not isinstance(budget_ms, int) or isinstance(budget_ms, bool) or not 0 <= budget_ms <= 35000:
                    raise PeerFailure("control_deadline")
                command_deadline = min(self.deadline, time.monotonic() + budget_ms / 1000)
                self.controls += 1
                operation = data.get("operation")
                if self.controls > 64 or not isinstance(operation, int) or operation <= last_operation:
                    raise PeerFailure("control_limit")
                last_operation = operation
                command, request = data.get("command"), data.get("request")
                if command == "arm" and isinstance(request, int) and 0 <= request < 128 and data.get("scenario") in SCENARIOS and self.scenarios[request] is None:
                    self.scenarios[request] = data["scenario"]
                    self.emit("armed", operation=operation, request=request)
                elif command == "release" and isinstance(request, int) and 0 <= request < 128:
                    self.releases[request].set()
                    self.emit("sent", operation=operation, request=request, phase="released")
                elif command == "wire_cut":
                    self.cut(operation)
                elif command == "close" and isinstance(request, int) and 1 <= request <= 8:
                    worker = self.workers[request - 1]
                    if worker is None:
                        raise PeerFailure("invalid_control")
                    try:
                        worker.sock.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass
                    self.emit("closed", operation=operation, connection=request)
                elif command == "stop":
                    return 0 if self.stop(operation, command_deadline) else 1
                else:
                    raise PeerFailure("invalid_control")
            raise PeerFailure("deadline")
        except (PeerFailure, ValueError, TypeError) as error:
            category = error.category if isinstance(error, PeerFailure) else "invalid_control"
            self.emit("failure", category=category)
            self.stop(last_operation + 1)
            return 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("h1", "tls-clienthello"), required=True)
    parser.add_argument("--case", required=True)
    args = parser.parse_args()
    if args.case not in {"B%02d" % n for n in range(1, 22)}:
        parser.error("unknown case")
    sys.exit(Peer(args.mode, args.case).run())
