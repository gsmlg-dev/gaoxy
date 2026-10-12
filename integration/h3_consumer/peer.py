#!/usr/bin/env python3
"""Independent verified-CA H3 wire consumer; no production client dependency."""
import argparse
import asyncio
import importlib.metadata

from aioquic.asyncio import connect
from aioquic.asyncio.protocol import QuicConnectionProtocol
from aioquic.h3.connection import H3_ALPN, H3Connection
from aioquic.h3.events import DataReceived, HeadersReceived
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.events import ConnectionTerminated, ProtocolNegotiated


class Peer(QuicConnectionProtocol):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.http = H3Connection(self._quic)
        self.headers, self.data, self.ended = {}, {}, set()
        self.changed = asyncio.Event()
        self.alpn = None
        self.terminated = None

    def quic_event_received(self, event):
        if isinstance(event, ProtocolNegotiated):
            self.alpn = event.alpn_protocol
        if isinstance(event, ConnectionTerminated):
            self.terminated = event
        for item in self.http.handle_event(event):
            if isinstance(item, HeadersReceived):
                self.headers.setdefault(item.stream_id, []).append(item.headers)
            if isinstance(item, DataReceived):
                self.data.setdefault(item.stream_id, bytearray()).extend(item.data)
            if isinstance(item, (HeadersReceived, DataReceived)) and item.stream_ended:
                self.ended.add(item.stream_id)
        self.changed.set()

    async def response(self, stream, body):
        async with asyncio.timeout(8):
            while stream not in self.ended:
                assert self.terminated is None, self.terminated
                self.changed.clear()
                await self.changed.wait()
        assert self.alpn == "h3", self.alpn
        assert self.headers[stream][0].count((b":status", b"200")) == 1, self.headers
        assert bytes(self.data.get(stream, b"")) == body, self.data


async def run(args):
    assert importlib.metadata.version("aioquic") == "1.2.0"
    configuration = QuicConfiguration(is_client=True, alpn_protocols=H3_ALPN)
    configuration.server_name = "localhost"
    configuration.load_verify_locations(args.ca)
    async with asyncio.timeout(20):
        async with connect("127.0.0.1", args.port, configuration=configuration,
                           create_protocol=Peer) as peer:
            ordinary = peer._quic.get_next_available_stream_id()
            peer.http.send_headers(ordinary, [
                (b":method", b"GET"), (b":scheme", b"https"),
                (b":authority", b"localhost"), (b":path", b"/")], end_stream=True)
            peer.transmit()
            await peer.response(ordinary, b"consumer")
            upload = peer._quic.get_next_available_stream_id()
            payload = b"clean-h3-consumer-" * 4096
            peer.http.send_headers(upload, [
                (b":method", b"POST"), (b":scheme", b"https"),
                (b":authority", b"localhost"), (b":path", b"/echo"),
                (b"content-length", str(len(payload)).encode())], end_stream=False)
            for offset in range(0, len(payload), 4096):
                peer.http.send_data(upload, payload[offset:offset + 4096], end_stream=False)
            peer.http.send_data(upload, b"", end_stream=True)
            peer.transmit()
            await peer.response(upload, payload)
    print("H3_CONSUMER_PASS cases=2 verified_ca=true protocol=h3", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--ca", required=True)
    asyncio.run(run(parser.parse_args()))
