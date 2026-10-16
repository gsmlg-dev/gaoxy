#!/usr/bin/env python3
"""Test-only single-connection raw TCP relay. TLS terminates at native Gaoxy."""
import hashlib
import json
import os
import select
import socket
import sys
import time


def emit(value):
    print(json.dumps(value), flush=True)


def run(port):
    listener = socket.socket()
    pair = []
    selected = attempts = rejected = 0
    authorized = completed = False
    pending_control = b''
    queues = [bytearray(), bytearray()]
    eof = [False, False]
    half_closed = [False, False]
    received = [0, 0]
    sent = [0, 0]
    read_hash = [hashlib.sha256(), hashlib.sha256()]
    write_hash = [hashlib.sha256(), hashlib.sha256()]
    high_water = [0, 0]
    deadline = time.monotonic() + 90
    listener.bind(('127.0.0.1', 0))
    listener.listen(8)
    listener.setblocking(False)
    emit(dict(event='ready', port=listener.getsockname()[1], backend_port=port,
              profile='single-selected-raw-tcp-connection'))
    try:
        while True:
            assert time.monotonic() < deadline, 'front door absolute deadline'
            readers = [sys.stdin.fileno(), listener]
            writers = []
            if pair:
                readers += [endpoint for i, endpoint in enumerate(pair)
                            if not eof[i] and len(queues[1-i]) <= 65536-16384]
                writers += [endpoint for i, endpoint in enumerate(pair) if queues[i]]
            ready_read, ready_write, _ = select.select(readers, writers, [], .1)
            # Acknowledgment is emitted before the controller can close Chrome.
            if sys.stdin.fileno() in ready_read:
                control = os.read(sys.stdin.fileno(), 4096)
                assert control, 'front door control EOF before normal stop'
                pending_control += control
                assert len(pending_control) <= 4096, 'front door control bound'
                while b'\n' in pending_control:
                    line, pending_control = pending_control.split(b'\n', 1)
                    command = json.loads(line)
                    if command == {'op': 'authorize_close'}:
                        assert selected == attempts == 1 and pair and not completed
                        assert not authorized and not any(eof)
                        authorized = True
                        emit(dict(event='close_authorized', selected=selected,
                                  backend_attempts=attempts, live_pair=True))
                    else:
                        assert command == {'op': 'stop'}
                        assert authorized and completed and not pair
                        assert pending_control == b''
                        listener.close()
                        emit(dict(event='joined', selected=selected, backend_attempts=attempts,
                                  rejected=rejected, live_sockets=0, forced=False,
                                  received=received, sent=sent, queue_high_water=high_water,
                                  read_sha256=[h.hexdigest() for h in read_hash],
                                  write_sha256=[h.hexdigest() for h in write_hash]))
                        return
            if listener in ready_read:
                client, _ = listener.accept()
                if selected:
                    rejected += 1
                    client.close()
                else:
                    # Irreversible latch: no replacement even if Chrome abandons it.
                    selected = 1
                    attempts += 1
                    pair.append(client)
                    backend = socket.create_connection(('127.0.0.1', port), timeout=5)
                    pair.append(backend)
                    for endpoint in pair:
                        endpoint.setblocking(False)
                    emit(dict(event='selected', selected=selected, backend_attempts=attempts))
            for i, endpoint in enumerate(pair):
                if endpoint in ready_read:
                    data = endpoint.recv(16384)
                    if data:
                        received[i] += len(data)
                        read_hash[i].update(data)
                        queues[1-i].extend(data)
                        high_water[1-i] = max(high_water[1-i], len(queues[1-i]))
                        assert len(queues[1-i]) <= 65536
                    else:
                        assert authorized, 'selected socket EOF before authorized Chrome close'
                        eof[i] = True
                if endpoint in ready_write:
                    count = endpoint.send(queues[i])
                    assert count > 0, 'zero byte write'
                    write_hash[i].update(queues[i][:count])
                    sent[i] += count
                    del queues[i][:count]
            for i, endpoint in enumerate(pair):
                if eof[1-i] and not queues[i] and not half_closed[i]:
                    endpoint.shutdown(socket.SHUT_WR)
                    half_closed[i] = True
            if pair and all(eof) and not any(queues):
                assert authorized and all(half_closed)
                assert all(count > 0 for count in received)
                assert received == list(reversed(sent))
                assert all(read_hash[i].digest() == write_hash[1-i].digest() for i in (0, 1))
                for endpoint in pair:
                    endpoint.close()
                pair = []
                completed = True
                emit(dict(event='connection_complete', both_eof=True, queues_empty=True,
                          byte_identity=True, selected=selected, backend_attempts=attempts))
    finally:
        listener.close()
        for endpoint in pair:
            endpoint.close()


if __name__ == '__main__':
    run(int(sys.argv[1]))
