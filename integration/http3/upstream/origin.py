#!/usr/bin/env python3
"""Independent loopback aioquic origin with explicit wire/control barriers."""
import argparse
import asyncio
import hashlib
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
    def __init__(self, *args, identity, registry, **kwargs):
        super().__init__(*args, **kwargs)
        # aioquic's protocol subclass convention supplies the QUIC connection to H3.
        self.http = H3Connection(self._quic)
        self.identity = identity
        self.connection = len(registry)
        self.requests = {}
        registry.append(self)

    def snapshot(self, stream):
        request = self.requests[stream]
        body = bytes(request["body"])
        return {"origin": self.identity, "connection": self.connection,
                "stream": stream, "path": request["path"],
                "headers": request["headers"], "trailers": request["trailers"],
                "data_bytes": len(body), "data_sha256": hashlib.sha256(body).hexdigest(),
                "request_fin": request["fin"]}

    def respond(self, stream, body, finish=True):
        self.http.send_headers(stream, [(b":status", b"200"),
            (b"x-origin", self.identity.encode()), (b"x-repeat", b"one"),
            (b"x-repeat", b"two")])
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
                        "headers": fields, "trailers": [], "body": bytearray(),
                        "fin": http_event.stream_ended}
                    path = self.requests[stream]["path"]
                    emit("headers", **self.snapshot(stream))
                    if path == "/ordinary":
                        self.respond(stream, b"ordinary-", finish=False)
                    elif path == "/stalled-response":
                        self.respond(stream, b"unacknowledged", finish=False)
                else:
                    self.requests[stream]["trailers"] = fields
                    self.requests[stream]["fin"] = http_event.stream_ended
                    emit("trailers", **self.snapshot(stream))
            elif isinstance(http_event, DataReceived):
                self.requests[stream]["body"].extend(http_event.data)
                self.requests[stream]["fin"] = http_event.stream_ended
                emit("data", **self.snapshot(stream))

            request = self.requests[stream]
            if request["fin"] and not request.get("finished"):
                request["finished"] = True
                emit("request_fin", **self.snapshot(stream))
                if request["path"] == "/upload":
                    self.respond(stream, bytes(request["body"]))
                # /echo deliberately cannot return a final response before upload FIN.
                elif request["path"].startswith("/echo"):
                    self.respond(stream, b"echo-finished")


async def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cert-a", type=Path, required=True)
    parser.add_argument("--cert-b", type=Path, required=True)
    args = parser.parse_args()
    loop = asyncio.get_running_loop()
    registry, servers, transports, ports = [], [], [], []
    stop = asyncio.Event()
    for identity, directory in (("a", args.cert_a), ("b", args.cert_b)):
        configuration = QuicConfiguration(is_client=False, alpn_protocols=["h3"])
        configuration.load_cert_chain(directory / "cert.pem", directory / "key.pem")
        transport, server = await loop.create_datagram_endpoint(
            lambda c=configuration, i=identity: QuicServer(configuration=c,
                create_protocol=lambda *a, **kw: Origin(*a, identity=i, registry=registry, **kw)),
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
            elif command["command"] == "snapshot":
                emit("snapshot", requests=[p.snapshot(s) for p in registry for s in p.requests])
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
