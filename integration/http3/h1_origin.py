#!/usr/bin/env python3
"""Independent bounded loopback H1 origin and wire receipts for the H3 matrix."""
import asyncio
import base64
import json
import sys
from urllib.parse import parse_qs, urlsplit


class Origin:
    def __init__(self):
        self.requests = []
        self.active = set()
        self.releases = {}
        self.stopping = asyncio.Event()

    def snapshot(self):
        return {"event": "snapshot", "requests": self.requests, "active": len(self.active)}

    @staticmethod
    def emit(value):
        print(json.dumps(value), flush=True)

    async def control(self):
        reader = asyncio.StreamReader()
        await asyncio.get_running_loop().connect_read_pipe(
            lambda: asyncio.StreamReaderProtocol(reader), sys.stdin.buffer)
        while line := await reader.readline():
            command = json.loads(line)
            if command["command"] == "snapshot":
                self.emit(self.snapshot())
            elif command["command"] == "release":
                self.releases.setdefault(command["id"], asyncio.Event()).set()
                self.emit({"event": "released", "id": command["id"]})
            elif command["command"] == "stop":
                self.emit(self.snapshot())
                self.stopping.set()
                return
            else:
                raise AssertionError(f"unknown origin command: {command}")
        self.stopping.set()

    async def fields(self, reader):
        fields, size = [], 0
        while True:
            line = await reader.readline()
            assert line.endswith(b"\r\n"), "truncated H1 field"
            size += len(line)
            assert size <= 65536 and len(fields) <= 128, "H1 field bound"
            if line == b"\r\n":
                return fields
            name, value = line[:-2].split(b":", 1)
            fields.append([name.decode("ascii").lower(), value.strip().decode("latin1")])

    async def body(self, reader, receipt):
        headers = dict(receipt["headers"])
        body = bytearray()
        if headers.get("transfer-encoding") == "chunked":
            while True:
                line = await reader.readline()
                assert line.endswith(b"\r\n"), "truncated H1 chunk size"
                size = int(line.strip().split(b";", 1)[0], 16)
                assert 0 <= size <= 1048576 and len(body) + size <= 1048576
                if size == 0:
                    receipt["trailers"] = await self.fields(reader)
                    break
                piece = await reader.readexactly(size)
                assert await reader.readexactly(2) == b"\r\n", "H1 chunk terminator"
                body.extend(piece)
                receipt["chunks"].append(size)
                receipt["body"] = base64.b64encode(body).decode("ascii")
                receipt["bytes"] = len(body)
        else:
            remaining = int(headers.get("content-length", "0"))
            assert 0 <= remaining <= 1048576
            while remaining:
                piece = await reader.read(min(4096, remaining))
                assert piece, "truncated fixed H1 body"
                remaining -= len(piece)
                body.extend(piece)
                receipt["chunks"].append(len(piece))
                receipt["body"] = base64.b64encode(body).decode("ascii")
                receipt["bytes"] = len(body)
        receipt["complete"] = True

    async def json_response(self, writer, value):
        body = json.dumps(value, sort_keys=True).encode()
        writer.write(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " +
                     str(len(body)).encode() + b"\r\nConnection: close\r\n\r\n" + body)
        await writer.drain()

    async def handle(self, reader, writer):
        task = asyncio.current_task()
        self.active.add(task)
        receipt = None
        phase = "request"
        try:
            async with asyncio.timeout(12):
                line = await reader.readline()
                method, target, version = line.rstrip(b"\r\n").split(b" ")
                assert version == b"HTTP/1.1", version
                headers = await self.fields(reader)
                path = urlsplit(target.decode("ascii"))
                if path.path == "/__control/snapshot":
                    await self.json_response(writer, self.snapshot())
                    return
                if path.path == "/__control/release":
                    identity = parse_qs(path.query)["id"][0]
                    self.releases.setdefault(identity, asyncio.Event()).set()
                    await self.json_response(writer, {"released": identity})
                    return
                identity = dict(headers).get("x-matrix-id", str(len(self.requests)))
                receipt = {"id": identity, "method": method.decode("ascii"),
                           "target": target.decode("ascii"), "headers": headers,
                           "body": "", "bytes": 0, "chunks": [], "trailers": [],
                           "complete": False, "cancelled": False, "closed": False}
                self.requests.append(receipt)
                if path.path == "/proxy/early":
                    writer.write(b"HTTP/1.1 413 Content Too Large\r\nContent-Length: 0\r\n\r\n")
                    await writer.drain()
                    assert await reader.read() == b"", "upload continued after early final"
                    receipt["cancelled"] = True
                elif path.path == "/proxy/cancel":
                    await self.body(reader, receipt)
                    writer.write(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n")
                    await writer.drain()
                    assert await reader.read() == b"", "unexpected extra upload"
                    receipt["cancelled"] = True
                else:
                    await self.body(reader, receipt)
                    body = json.dumps(receipt, sort_keys=True).encode()
                    if path.path == "/proxy/download":
                        body = b"download-first-" + b"download-rest-" * 4096
                        writer.write(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n"
                                     b"Trailer: X-Origin\r\nConnection: X-Origin-Hop, close\r\n"
                                     b"X-Origin-Hop: secret\r\nSet-Cookie: first=1\r\n"
                                     b"Set-Cookie: second=2\r\n\r\n")
                        first = body[:15]
                        writer.write(f"{len(first):x}\r\n".encode() + first + b"\r\n")
                        await writer.drain()
                        await self.releases.setdefault(identity, asyncio.Event()).wait()
                        body = body[15:]
                    else:
                        writer.write(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n"
                                     b"Trailer: X-Origin\r\nConnection: close\r\n\r\n")
                    writer.write(f"{len(body):x}\r\n".encode() + body + b"\r\n"
                                 b"0\r\nX-Origin: first\r\nX-Origin: second\r\n\r\n")
                    phase = "response_drain"
                    await writer.drain()
                    phase = "response_close"
                    writer.close()
                    await writer.wait_closed()
                    phase = "request_eof"
                    assert await reader.read() == b"", "request replay/extra H1 bytes"
                receipt["closed"] = True
        except (asyncio.IncompleteReadError, ConnectionResetError, BrokenPipeError) as error:
            if receipt is not None:
                receipt["cancelled"] = True
                receipt["closed"] = True
                receipt["error"] = type(error).__name__
                receipt["error_phase"] = phase
        except Exception as error:
            if receipt is not None:
                receipt["error"] = repr(error)
            self.emit({"event": "error", "error": repr(error), "request": receipt})
        finally:
            writer.close()
            try:
                await writer.wait_closed()
            except (ConnectionResetError, BrokenPipeError):
                pass
            self.active.discard(task)

    async def run(self):
        server = await asyncio.start_server(self.handle, "127.0.0.1", 0, limit=65536)
        self.emit({"event": "ready", "port": server.sockets[0].getsockname()[1]})
        control = asyncio.create_task(self.control())
        await self.stopping.wait()
        server.close()
        await server.wait_closed()
        if self.active:
            await asyncio.wait_for(asyncio.gather(*self.active), 15)
        await control
        self.emit({**self.snapshot(), "event": "stopped"})


if __name__ == "__main__":
    asyncio.run(Origin().run())
