"""Offline pinned-decoder defect reproduction and existing raw peer regression."""
import asyncio
import json
import sys

sys.path.insert(0, "integration/http3")
from peer import Peer, encode_frame, head
from aioquic.h3.connection import H3Connection
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.connection import QuicConnection
from aioquic.quic.events import StreamDataReceived


def connection():
    return QuicConnection(configuration=QuicConfiguration(is_client=True, alpn_protocols=["h3"]))


async def run():
    for initial, body in [(b"103", b"informed"), (b"100", b"continued-input")]:
        headers = [(b":status", initial)]
        if initial == b"103":
            headers.append((b"link", b"</fixture>; rel=preload"))
        final = [(b":status", b"200"), (b"content-length", str(len(body)).encode())]
        wire = head(0, headers) + head(0, final) + encode_frame(0, body)
        quic = connection()
        closed = []
        quic.close = lambda **kwargs: closed.append(kwargs)
        standard = H3Connection(quic)
        events = standard.handle_event(StreamDataReceived(data=wire, end_stream=True, stream_id=0))
        assert events == []
        assert closed == [{"error_code": 0x10E, "reason_phrase": "Pseudo-header b':status' is not valid"}]
        raw = Peer(connection(), standard=False)
        for offset in range(0, len(wire), 3):
            raw.quic_event_received(StreamDataReceived(
                data=wire[offset:offset + 3], end_stream=offset + 3 >= len(wire), stream_id=0))
        assert raw.headers[0] == [headers, final]
        assert raw.data[0] == body and raw.ended == {0} and raw.buffers[0] == b""
        assert raw.terminated is None
        print(json.dumps({"initial": initial.decode(), "result": "PASS",
              "pinned_decoder_failure": closed[0], "wire_hex": wire.hex(),
              "raw_headers": [[[k.decode(), v.decode()] for k, v in h] for h in raw.headers[0]],
              "body": raw.data[0].decode(), "fragment_bytes": 3, "fin": True}))


asyncio.run(run())
