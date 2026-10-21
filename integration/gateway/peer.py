"""Finite independent peers for shared Gateway generations and proxy discovery."""
import asyncio
import json
from pathlib import Path
import sys
from types import SimpleNamespace

sys.path.insert(0, str(Path.cwd() / "apps/gaoxy_http/test/support"))
from listener_set_peer import h1, h2
sys.path.insert(0, str(Path.cwd() / "integration/http3"))
from peer import opened


async def h3(port, ca, expected):
    async with opened(SimpleNamespace(port=port, ca=ca, mode="startup")) as client:
        sid = client.request(path=b"/")
        await client.response(sid, body=expected.encode())
        assert client.negotiated == "h3"


def main():
    mode, tls, quic, ca, expected = sys.argv[1:]
    versions = []
    for request, version in [(h1, "HTTP/1.1"), (h2, "HTTP/2")]:
        if mode == "held" and version != "HTTP/1.1":
            continue
        headers, body = request(int(tls), ca, "/held" if mode == "held" else "/")
        assert body.decode() == expected, (version, body, expected)
        alternatives = [v for k, v in headers if k == b"alt-svc"]
        assert alternatives == [f'h3=":{quic}"; ma=60'.encode()], (version, headers)
        versions.append(version)
    if mode != "held":
        asyncio.run(asyncio.wait_for(h3(int(quic), ca, expected), timeout=10))
        versions.append("HTTP/3")
    print(json.dumps({"result": "PASS", "versions": versions, "body": expected}))


if __name__ == "__main__":
    main()
