#!/usr/bin/env python3
"""Independent loopback aioquic origin with explicit wire/control barriers."""
import argparse
import asyncio
import hashlib
import gzip
import json
import signal
import sys
from pathlib import Path

from aioquic.asyncio import QuicConnectionProtocol
from aioquic.asyncio.server import QuicServer
from aioquic.h3.connection import H3Connection
from aioquic.h3.events import DataReceived, HeadersReceived
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.events import ConnectionTerminated, StopSendingReceived, StreamReset


def emit(event, **fields):
    print("GAOXY_UPSTREAM_ORIGIN " + json.dumps({"event": event, **fields}), flush=True)


class Origin(QuicConnectionProtocol):
    def __init__(self, *args, identity, certificate_sha256, registry, **kwargs):
        super().__init__(*args, **kwargs)
        # aioquic's protocol subclass convention supplies the QUIC connection to H3.
        self.http = H3Connection(self._quic)
        self.identity = identity
        self.certificate_sha256 = certificate_sha256
        self.connection = len(registry)
        self.requests = {}
        registry.append(self)

    def snapshot(self, stream):
        request = self.requests[stream]
        return {"origin": self.identity, "connection": self.connection,
                "stream": stream, "path": request["path"],
                "method": dict(request["headers"])[":method"],
                "authority": dict(request["headers"])[":authority"],
                "id": dict(request["headers"]).get("x-matrix-id"),
                "certificate_sha256": self.certificate_sha256,
                "trailer_blocks": request["trailer_blocks"],
                "headers": request["headers"], "trailers": request["trailers"],
                "data_bytes": len(request["body"]), "data_sha256": request["data_hash"].hexdigest(),
                "request_fin": request["fin"], "fin_count": request["fin_count"],
                "data_events": request["data_events"],
                "response_fin": request.get("response_fin", False)}

    def matrix_response(self, stream, body=b"matrix-ok", status=b"200", finish=True,
                        trailers=True, extra=()):
        request = self.requests[stream]
        if not request.get("response_started"):
            fields = [(b":status", status), (b"x-origin", self.identity.encode()),
                      (b"x-repeat", b"one"), (b"x-repeat", b"two"),
                      (b"set-cookie", b"first=1"), (b"set-cookie", b"second=2")]
            if trailers:
                fields.append((b"trailer", b"x-check"))
            self.http.send_headers(stream, fields + list(extra),
                                   end_stream=finish and not body and not trailers)
            request["response_started"] = True
        if body:
            self.http.send_data(stream, body, end_stream=finish and not trailers)
        if finish and trailers:
            self.http.send_headers(stream, [(b"x-check", b"one"), (b"x-check", b"two")],
                                   end_stream=True)
        elif finish and not body and not trailers and request.get("response_fin"):
            raise AssertionError("duplicate matrix response FIN")
        self.transmit()
        if finish:
            request["response_fin"] = True
            emit("response_fin", **self.snapshot(stream))

    def matrix_headers(self, stream):
        request = self.requests[stream]
        case = dict(request["headers"])["x-matrix-case"]
        if case in ("progressive_download", "downstream_cancel", "total_timeout"):
            self.matrix_response(stream, b"progress-", finish=False)
        elif case == "early_final":
            self.matrix_response(stream, b"", b"413", trailers=False)

    def matrix_finished(self, stream):
        request = self.requests[stream]
        fields = dict(request["headers"])
        case = fields["x-matrix-case"]
        if case in ("progressive_download", "downstream_cancel", "total_timeout", "opening_timeout", "early_final"):
            return
        if case == "upstream_reset":
            self._quic.reset_stream(stream, 0x10C)
            self.transmit()
            emit("origin_reset", error_code=0x10C, **self.snapshot(stream))
        elif fields[":method"] == "HEAD" or case in ("bodyless_204", "bodyless_304"):
            status = {"bodyless_204": b"204", "bodyless_304": b"304"}.get(case, b"200")
            self.matrix_response(stream, b"", status, trailers=False,
                                 extra=[] if status == b"204" else [(b"content-length", b"7")])
        elif case in ("progressive_upload", "tiny_window_1mib"):
            self.matrix_response(stream, bytes(request["body"]))
        elif case == "raw_compression":
            self.matrix_response(stream, gzip.compress(b"raw-compressed-response" * 32, mtime=0),
                                 extra=[(b"content-encoding", b"gzip")])
        elif case == "redirect_no_replay":
            self.matrix_response(stream, b"redirect", b"302",
                                 extra=[(b"location", b"/matrix/a/must-not-follow")])
        else:
            self.matrix_response(stream)

    def respond(self, stream, body, finish=True, trailers=False):
        fields = [(b":status", b"200"),
            (b"x-origin", self.identity.encode()), (b"x-repeat", b"one"),
            (b"x-repeat", b"two")]
        if trailers:
            fields.append((b"trailer", b"x-check"))
        self.http.send_headers(stream, fields)
        self.http.send_data(stream, body, end_stream=finish)
        self.transmit()

    def finish_ordinary(self, stream):
        self.http.send_data(stream, b"response", end_stream=False)
        self.http.send_headers(stream, [(b"x-check", b"one"), (b"x-check", b"two")],
                               end_stream=True)
        self.transmit()
        emit("response_fin", **self.snapshot(stream))

    def quic_event_received(self, event):
        if isinstance(event, (StreamReset, StopSendingReceived)):
            request = self.requests.get(event.stream_id)
            emit("reset" if isinstance(event, StreamReset) else "stop_sending",
                 origin=self.identity, connection=self.connection, stream=event.stream_id,
                 path=request["path"] if request else None, error_code=event.error_code)
        elif isinstance(event, ConnectionTerminated):
            emit("connection_closed", origin=self.identity, connection=self.connection,
                 error_code=event.error_code, reason=event.reason_phrase)

        for http_event in self.http.handle_event(event):
            stream = http_event.stream_id
            if isinstance(http_event, HeadersReceived):
                fields = [(k.decode("ascii"), v.decode("latin1"))
                          for k, v in http_event.headers]
                if stream not in self.requests:
                    self.requests[stream] = {"path": dict(fields)[":path"],
                        "headers": fields, "trailers": [], "trailer_blocks": 0, "body": bytearray(),
                        "data_hash": hashlib.sha256(),
                        "fin": http_event.stream_ended, "fin_count": 0, "data_events": 0}
                    path = self.requests[stream]["path"]
                    emit("headers", **self.snapshot(stream))
                    if path.startswith("/matrix/"):
                        self.matrix_headers(stream)
                    elif path == "/ordinary":
                        self.respond(stream, b"ordinary-", finish=False, trailers=True)
                    elif path.startswith("/sibling-"):
                        self.respond(stream, b"sibling-", finish=False)
                    elif path in ("/stalled-response", "/owner-loss", "/guardian-loss"):
                        self.respond(stream, b"unacknowledged", finish=False)
                else:
                    self.requests[stream]["trailer_blocks"] += 1
                    self.requests[stream]["trailers"] = fields
                    self.requests[stream]["fin"] = http_event.stream_ended
                    emit("trailers", **self.snapshot(stream))
            elif isinstance(http_event, DataReceived):
                self.requests[stream]["data_events"] += 1
                self.requests[stream]["body"].extend(http_event.data)
                self.requests[stream]["data_hash"].update(http_event.data)
                self.requests[stream]["fin"] = http_event.stream_ended
                emit("data", **self.snapshot(stream))

            request = self.requests[stream]
            if request["fin"] and not request.get("finished"):
                request["finished"] = True
                request["fin_count"] += 1
                emit("request_fin", **self.snapshot(stream))
                if request["path"].startswith("/matrix/"):
                    self.matrix_finished(stream)
                elif request["path"] in ("/upload", "/tiny-upload"):
                    self.respond(stream, bytes(request["body"]))
                # /echo deliberately cannot return a final response before upload FIN.
                elif request["path"].startswith("/echo"):
                    self.respond(stream, b"echo-finished", finish=False, trailers=True)
                    self.http.send_headers(stream, [(b"x-check", b"one"), (b"x-check", b"two")], end_stream=True)
                    self.transmit()


async def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cert-a", type=Path, required=True)
    parser.add_argument("--cert-b", type=Path, required=True)
    args = parser.parse_args()
    loop = asyncio.get_running_loop()
    registry, servers, transports, ports = [], [], [], []
    stop = asyncio.Event()
    for identity, directory in (("a", args.cert_a), ("b", args.cert_b)):
        configuration = QuicConfiguration(is_client=False, alpn_protocols=["h3"], max_stream_data=16_384)
        configuration.load_cert_chain(directory / "cert.pem", directory / "key.pem")
        transport, server = await loop.create_datagram_endpoint(
            lambda c=configuration, i=identity: QuicServer(configuration=c,
                create_protocol=lambda *a, certificate=hashlib.sha256((directory / "cert.pem").read_bytes()).hexdigest(), **kw: Origin(
                    *a, identity=i, certificate_sha256=certificate, registry=registry, **kw)),
            local_addr=("127.0.0.1", 0))
        transports.append(transport)
        servers.append(server)
        ports.append(transport.get_extra_info("sockname")[1])
    emit("ready", ports=ports)
    for signum in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(signum, stop.set)

    async def commands():
        while not stop.is_set():
            line = await asyncio.to_thread(sys.stdin.readline)
            if not line:
                stop.set()
                return
            command = json.loads(line)
            if command["command"] == "finish_ordinary":
                found = [(p, s) for p in registry for s, r in p.requests.items()
                         if r["path"] == "/ordinary" and p.identity == command["origin"]]
                assert len(found) == 1, found
                found[0][0].finish_ordinary(found[0][1])
            elif command["command"] == "finish_sibling":
                found = [(p, s) for p in registry for s, r in p.requests.items()
                         if r["path"] == command["path"] and p.identity == command["origin"]]
                assert len(found) == 1, found
                p, stream = found[0]
                p.http.send_data(stream, b"response", end_stream=True)
                p.transmit()
                emit("response_fin", **p.snapshot(stream))
            elif command["command"] in ("pause_upload", "resume_upload"):
                transport = transports[0]
                if command["command"] == "pause_upload":
                    transport.pause_reading()
                else:
                    transport.resume_reading()
                emit(command["command"], origin="a")
            elif command["command"] == "snapshot":
                emit("snapshot", requests=[p.snapshot(s) for p in registry for s in p.requests])
            elif command["command"] == "matrix_finish_download":
                found = [(p, s) for p in registry for s, r in p.requests.items()
                         if dict(r["headers"]).get("x-matrix-id") == command["id"]]
                assert len(found) == 1, found
                p, stream = found[0]
                p.matrix_response(stream, b"response" * 8192)
                emit("matrix_released", id=command["id"])
            elif command["command"] == "stop":
                stop.set()
                return
            else:
                raise ValueError(command)

    control = asyncio.create_task(commands())
    waiter = asyncio.create_task(stop.wait())
    try:
        done, _ = await asyncio.wait([control, waiter], return_when=asyncio.FIRST_COMPLETED)
        for task in done:
            task.result()
    finally:
        for server in servers:
            server.close()
        for transport in transports:
            transport.close()
        control.cancel()
        waiter.cancel()
        emit("stopped", ports=ports)


if __name__ == "__main__":
    asyncio.run(main())
