#!/usr/bin/env python3
"""Independent verified-CA H3 wire consumer; no production client dependency."""
import argparse
import json
import os
import subprocess


def run(args):
    result = subprocess.run(
        [os.environ["GAOXY_H3_CONSUMER_PEER"], str(args.port), args.ca, "--consumer"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=20,
    )
    assert result.returncode == 0, result.stderr
    receipt = json.loads(result.stdout)
    assert receipt["alpn"] == "h3", receipt
    responses = receipt["responses"]
    assert len(responses) == 2, receipt
    assert [row["path"] for row in responses] == ["/", "/echo"], receipt
    assert len({row["stream_id"] for row in responses}) == 2, receipt
    for response, expected in zip(responses, [b"consumer", b"clean-h3-consumer-" * 4096], strict=True):
        assert response["connection_id"] == receipt["connection_id"], response
        assert response["ended"], response
        assert response["headers"][0].count([":status", "200"]) == 1, response
        assert bytes(response["body"]) == expected, response
    print("H3_CONSUMER_PASS cases=2 verified_ca=true protocol=h3", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--ca", required=True)
    run(parser.parse_args())
