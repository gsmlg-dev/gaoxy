"""Independent bounded UDP peer for relay acceptance tests."""
import select
import socket
import sys

mode = sys.argv[1]
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1], flush=True)
pending = []
while True:
    readable, _, _ = select.select([sock, sys.stdin], [], [], 3)
    if not readable:
        break
    if sys.stdin in readable:
        command = sys.stdin.readline()
        if not command or command.strip() == "stop":
            break
        if command.strip() == "reply":
            for data, peer in pending:
                sock.sendto(data, peer)
            pending.clear()
    if sock in readable:
        data, peer = sock.recvfrom(65536)
        print(f"seen {peer[1]} {len(data)}", flush=True)
        if mode == "gate":
            if len(pending) < 8:
                pending.append((data, peer))
        else:
            sock.sendto(data, peer)
            if mode == "double":
                sock.sendto(data, peer)
sock.close()
