#!/usr/bin/env python3
"""Independent, certificate-validating aioquic 1.2.0 application peer."""
import argparse
import asyncio
import json

from aioquic.asyncio import connect
from aioquic.asyncio.protocol import QuicConnectionProtocol
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.events import (
    ConnectionTerminated, ProtocolNegotiated, StopSendingReceived, StreamDataReceived, StreamReset,
)


class Peer(QuicConnectionProtocol):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.data, self.fins, self.resets, self.stops = {}, set(), {}, {}
        self.terminated = None
        self.negotiated = None
        self.changed = asyncio.Event()

    def quic_event_received(self, event):
        if isinstance(event, ProtocolNegotiated):
            self.negotiated = event.alpn_protocol
        elif isinstance(event, StreamDataReceived):
            sid = event.stream_id
            self.data[sid] = self.data.get(sid, b"") + event.data
            if event.end_stream:
                self.fins.add(sid)
                # A server bidi FIN only closes its sending direction.
                if sid == 1:
                    self._quic.send_stream_data(sid, b"after-server-fin", end_stream=True)
                    self.transmit()
        elif isinstance(event, StreamReset):
            self.resets[event.stream_id] = event.error_code
        elif isinstance(event, StopSendingReceived):
            self.stops[event.stream_id] = event.error_code
        elif isinstance(event, ConnectionTerminated):
            self.terminated = event.error_code
        self.changed.set()

    async def until(self, predicate):
        async with asyncio.timeout(15):
            while not predicate():
                assert self.terminated is None, (self.terminated, self.data, self.fins)
                self.changed.clear()
                await self.changed.wait()

    def send(self, sid, data, fin=True):
        self._quic.send_stream_data(sid, data, end_stream=fin)
        self.transmit()


async def exchange(peer, value):
    assert peer.negotiated == "h3", peer.negotiated
    peer.send(2, b"peer-uni-", False)
    peer.send(0, value[:17], False)
    await peer.until(lambda: len(peer.data.get(0, b"")) >= 17)
    peer.send(2, b"fragment", True)
    peer.send(0, value[17:], True)
    await peer.until(lambda: 0 in peer.fins and 1 in peer.fins and 3 in peer.fins)
    assert peer.data[0] == value
    assert peer.data[1] == b"x" * 4096 + b"server-fin"
    assert peer.data[3] == b"server-uni-fin"


async def run(args):
    config = QuicConfiguration(
        is_client=True, alpn_protocols=[args.alpn], max_data=4096,
        max_stream_data=2048, idle_timeout=20,
    )
    config.server_name = args.server_name
    config.load_verify_locations(args.ca)
    async with connect("127.0.0.1", args.port, configuration=config, create_protocol=Peer) as peer:
        if args.mode == "echo":
            await exchange(peer, b"bounded-gaoxy-stream-" * 16384)
            peer.send(4, b"second-stream")
            await peer.until(lambda: 4 in peer.fins)
            assert peer.data[4] == b"second-stream"
            print(json.dumps({"result": "PASS", "gate": "stream_flow_control_fin",
                              "bytes": len(peer.data[0]), "streams": 5, "alpn": peer.negotiated,
                              "verified_name": config.server_name, "local_uni_id": 3, "peer_uni_id": 2}), flush=True)
        elif args.mode == "isolation":
            async with connect("127.0.0.1", args.port, configuration=config, create_protocol=Peer) as sibling:
                peer.close(error_code=0x9876, reason_phrase="one connection")
                await asyncio.wait_for(peer.wait_closed(), 5)
                await exchange(sibling, b"surviving-connection-" * 4096)
                print(json.dumps({"result": "PASS", "gate": "connection_close_isolation",
                                  "bytes": len(sibling.data[0])}), flush=True)
        elif args.mode == "controls":
            peer.send(0, b"reset", False)
            peer.send(4, b"stop", False)
            await peer.until(lambda: 0 in peer.resets and 4 in peer.stops)
            assert peer.resets[0] == 0x12345
            assert peer.stops[4] == 0x54321
            print(json.dumps({"result": "PASS", "gate": "directional_reset_stop",
                              "reset": peer.resets[0], "stop": peer.stops[4]}), flush=True)
        elif args.mode == "peer-controls":
            await peer.until(lambda: len(peer.data.get(1, b"")) >= 1024)
            assert 1 not in peer.fins, "STOP must precede server FIN"
            peer.send(0, b"cancel", False)
            peer._quic.reset_stream(0, error_code=0x111)
            peer._quic.stop_stream(1, error_code=0x222)
            peer.transmit()
            peer.send(4, b"surviving-stream")
            await peer.until(lambda: 1 in peer.resets and 4 in peer.fins)
            assert peer.resets[1] == 0x222
            assert peer.data[4] == b"surviving-stream"
            print(json.dumps({"result": "PASS", "gate": "peer_reset_stop_sibling_isolation",
                              "reset_code": 0x111, "stop_code": 0x222,
                              "sibling_bytes": len(peer.data[4])}), flush=True)
        elif args.mode == "listener":
            assert args.sibling_port is not None
            async with connect("127.0.0.1", args.sibling_port, configuration=config,
                               create_protocol=Peer) as sibling:
                peer.send(0, b"listener-remove")
                await asyncio.wait_for(peer.wait_closed(), 10)
                assert peer.terminated == 0, peer.terminated
                await exchange(sibling, b"surviving-listener-" * 4096)
                print(json.dumps({"result": "PASS", "gate": "live_listener_stop_isolation",
                                  "close_code": peer.terminated,
                                  "bytes": len(sibling.data[0])}), flush=True)
        elif args.mode == "negative":
            raise AssertionError("unsupported ALPN / untrusted CA unexpectedly connected")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--ca", required=True)
    parser.add_argument("--alpn", default="h3")
    parser.add_argument("--server-name", default="localhost")
    parser.add_argument("--sibling-port", type=int)
    parser.add_argument("--mode", required=True, choices=["echo", "isolation", "controls", "peer-controls", "listener", "negative"])
    args = parser.parse_args()
    try:
        asyncio.run(run(args))
    except ConnectionError:
        if args.mode != "negative":
            raise
        print(json.dumps({"result": "PASS", "gate": "handshake_rejected", "alpn": args.alpn,
                          "server_name": args.server_name}), flush=True)


if __name__ == "__main__":
    main()
