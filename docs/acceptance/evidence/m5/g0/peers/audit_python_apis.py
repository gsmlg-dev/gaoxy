"""G0 public peer API checks; no Gaoxy connection or protocol acceptance."""
import hashlib
import importlib.metadata
import inspect
import json
from pathlib import Path

from aioquic.h3.connection import H3Connection, Setting
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.connection import QuicConnection
from h2.config import H2Configuration
from h2.connection import H2Connection
from h2.events import DataReceived, RequestReceived, ResponseReceived, StreamEnded
from h2.settings import SettingCodes
from wsproto.connection import Connection, ConnectionType
from wsproto.events import BytesMessage, CloseConnection, Ping, Pong, TextMessage

OUT = Path(__file__).parent
results = []


def check(name, function):
    detail = function()
    results.append({"case": name, "status": "PASS", "detail": detail})


def h2_extended_connect():
    client = H2Connection(config=H2Configuration(client_side=True))
    server = H2Connection(config=H2Configuration(client_side=False))
    client.initiate_connection()
    server.initiate_connection()
    server.update_settings({SettingCodes.ENABLE_CONNECT_PROTOCOL: 1})
    server.receive_data(client.data_to_send())
    client.receive_data(server.data_to_send())
    server.receive_data(client.data_to_send())
    assert client.remote_settings.enable_connect_protocol == 1
    headers = [
        (b":method", b"CONNECT"), (b":scheme", b"https"),
        (b":authority", b"localhost"), (b":path", b"/websocket"),
        (b":protocol", b"websocket"), (b"sec-websocket-version", b"13"),
    ]
    client.send_headers(1, headers, end_stream=False)
    assert any(isinstance(e, RequestReceived) and e.headers == headers
               for e in server.receive_data(client.data_to_send()))
    server.send_headers(1, [(b":status", b"200")], end_stream=False)
    assert any(isinstance(e, ResponseReceived) for e in client.receive_data(server.data_to_send()))
    client.send_data(1, b"frame-bytes", end_stream=False)
    events = server.receive_data(client.data_to_send())
    assert any(isinstance(e, DataReceived) and e.data == b"frame-bytes" for e in events)
    client.end_stream(1)
    assert any(isinstance(e, StreamEnded) for e in server.receive_data(client.data_to_send()))
    return "setting 8=1, CONNECT/:protocol, 200, DATA and END_STREAM through public APIs"


def h3_extended_connect():
    quic = QuicConnection(configuration=QuicConfiguration(is_client=True, alpn_protocols=["h3"]))
    h3 = H3Connection(quic)
    assert h3.sent_settings[Setting.ENABLE_CONNECT_PROTOCOL] == 1
    stream = quic.get_next_available_stream_id()
    h3.send_headers(stream, [
        (b":method", b"CONNECT"), (b":scheme", b"https"),
        (b":authority", b"localhost"), (b":path", b"/websocket"),
        (b":protocol", b"websocket"), (b"sec-websocket-version", b"13"),
    ], end_stream=False)
    h3.send_data(stream, b"frame-bytes", end_stream=False)
    h3.send_data(stream, b"", end_stream=True)
    assert h3.received_settings is None
    return "public H3Connection setting 8=1, send_headers(:protocol), send_data(end_stream); local queue only"


def websocket_frames():
    client = Connection(ConnectionType.CLIENT)
    server = Connection(ConnectionType.SERVER)
    frame = client.send(TextMessage(data="hello"))
    assert frame[1] & 0x80
    server.receive_data(frame[:3])
    server.receive_data(frame[3:])
    assert list(server.events()) == [TextMessage(data="hello", frame_finished=True, message_finished=True)]
    server.receive_data(client.send(BytesMessage(data=b"binary")))
    assert list(server.events()) == [BytesMessage(data=b"binary", frame_finished=True, message_finished=True)]
    server.receive_data(client.send(Ping(payload=b"ping")))
    ping, = server.events()
    client.receive_data(server.send(ping.response()))
    assert list(client.events()) == [Pong(payload=b"ping")]
    server.receive_data(client.send(CloseConnection(code=1000, reason="done")))
    close, = server.events()
    client.receive_data(server.send(close.response()))
    assert list(client.events()) == [CloseConnection(code=1000, reason="done")]
    return "wsproto.connection.Connection starts framed session directly; masked text/binary, split frame, ping/pong, normal Close"


check("h2-public-extended-connect", h2_extended_connect)
check("aioquic-public-extended-connect", h3_extended_connect)
check("wsproto-public-rfc6455-frames", websocket_frames)
sources = {}
for cls in [H2Connection, H3Connection, QuicConnection, Connection]:
    source = Path(inspect.getfile(cls))
    sources[cls.__module__] = {"path": str(source), "sha256": hashlib.sha256(source.read_bytes()).hexdigest()}
record = {
    "scope": "offline public API compatibility only; no Gaoxy network/browser acceptance",
    "versions": {name: importlib.metadata.version(name) for name in
                 ["h2", "hpack", "hyperframe", "aioquic", "wsproto", "playwright"]},
    "cases": results, "executed": len(results), "exit": 0, "sources": sources,
}
(OUT / "python-api-audit.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
