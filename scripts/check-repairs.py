#!/usr/bin/env python3
"""Run correctness repairs and curated ordinary compatibility with exact counts."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
# Each file is checked separately: losing a case or excluding it fails the gate.
SUITES = {
    "unit": [
        ("apps/gaoxy_http/test/plug_body_test.exs", 28),
        ("apps/gaoxy_http/test/http2_authority_test.exs", 8),
        ("apps/gaoxy_proxy/test/cookie_headers_test.exs", 5),
        # Preserve ordinary policy, framing, response and accounting coverage.
        ("apps/gaoxy/test/config_test.exs", 4),
        ("apps/gaoxy_http/test/http1_parser_test.exs", 9),
        ("apps/gaoxy_http/test/http1_body_test.exs", 6),
        ("apps/gaoxy_proxy/test/http_headers_test.exs", 19),
        ("apps/gaoxy_http/test/managed_proxy_renderer_test.exs", 10),
        ("apps/gaoxy_http/test/http2_worker_accounting_test.exs", 7),
        ("apps/gaoxy_http/test/http2_facade_test.exs", 2),
        ("apps/gaoxy_http/test/connection_poll_test.exs", 9),
        ("apps/gaoxy_http/test/native_proxy_seams_test.exs", 21),
        ("apps/gaoxy_http3/test/transport_test.exs", 13),
    ],
    "protocol": [
        ("apps/gaoxy_server/test/standalone_recovery_test.exs", 2),
        ("apps/gaoxy_http/test/plug_body_network_test.exs", 4),
        ("apps/gaoxy_http3/test/plug_body_network_test.exs", 1),
        ("apps/gaoxy_http/test/http2_authority_network_test.exs", 1),
        ("apps/gaoxy_proxy/test/cookie_forwarding_network_test.exs", 3),
        ("apps/gaoxy_proxy/test/websocket_protocol_rejection_test.exs", 1),
        ("apps/gaoxy_http3/test/websocket_proxy_rejection_test.exs", 1),
        # Successful H1 proxying and native local multiplexed WebSockets.
        ("apps/gaoxy_proxy/test/websocket_tls_test.exs", 3),
        ("apps/gaoxy_http/test/http2_websocket_network_test.exs", 2),
        ("apps/gaoxy_http3/test/websocket_network_test.exs", 1),
    ],
}


def executed(output):
    summaries = re.findall(r"(\d+) tests?, (\d+) failures?([^\n]*)", output)
    modern = re.findall(r"Result:\s+(\d+)(?:/(\d+))? passed([^\n]*)", output)
    if not summaries and not modern:
        raise ValueError("missing ExUnit summary")
    count = 0
    for total, failures, suffix in summaries:
        if int(failures) or re.search(r"[1-9]\d* (?:excluded|skipped)", suffix):
            raise ValueError("failing, excluded or skipped required cases")
        count += int(total)
    for passed, total, suffix in modern:
        if (total and int(passed) != int(total)) or re.search(
                r"[1-9]\d* (?:failures?|failed|excluded|skipped)", suffix):
            raise ValueError("failing, excluded or skipped required cases")
        count += int(passed)
    if count <= 0:
        raise ValueError("zero executed tests")
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", choices=[*SUITES, "all"], nargs="?", default="all")
    args = parser.parse_args()
    selected = list(SUITES) if args.suite == "all" else [args.suite]
    env = dict(os.environ, MIX_ENV="test")  # The release parent uses MIX_ENV=prod.
    env.setdefault("GAOXY_QUIC_PYTHON", str(ROOT / ".audit/h2peer/bin/python"))
    total = 0
    print("REPAIR_SOURCE", subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), flush=True)
    for suite in selected:
        for path, expected in SUITES[suite]:
            if not (ROOT / path).is_file():
                raise ValueError(f"missing required test file: {path}")
            command = [sys.executable, "scripts/check-tests.py", path, "--seed", "0", "--max-cases", "1"]
            print("REPAIR_COMMAND", " ".join(command), flush=True)
            result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            print(result.stdout, end="", flush=True)
            if result.returncode:
                raise ValueError(f"required file failed: {path}, exit {result.returncode}")
            actual = executed(result.stdout)
            if actual != expected:
                raise ValueError(f"required case count changed: {path}, expected {expected}, executed {actual}")
            total += actual
    print(f"REPAIR_PASS {total} executed, 0 failures, 0 excluded, 0 skipped", flush=True)


if __name__ == "__main__":
    try:
        main()
    except ValueError as error:
        sys.exit(f"REPAIR_FAIL: {error}")
