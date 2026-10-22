#!/usr/bin/env python3
"""Run the exact issue-15 regressions in a fresh Hex-only consumer."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
VERSION = "0.12.2"
TESTS = ("exchange_peer_close_test.exs", "exchange_peer_close_network_test.exs")
SOURCES = ("connection.ex", "exchange.ex")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sha", required=True)
    args = parser.parse_args()
    assert re.fullmatch(r"[0-9a-f]{40}", args.sha)
    folder = Path(tempfile.mkdtemp(prefix="public-peer-close-", dir=Path(__file__).resolve().parent))
    consumer = folder / "consumer"
    (consumer / "test").mkdir(parents=True)
    receipt = {"status": "FAIL", "source_commit": args.sha, "version": VERSION,
               "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "consumer": str(consumer), "commands": [], "test_sha256": {}, "source_sha256": {}}
    env = {**os.environ, "MIX_ENV": "test", "ELIXIR_ERL_OPTIONS": "+S 2:2"}
    for name in ("MIX_DEPS_PATH", "MIX_BUILD_PATH", "MIX_HOME", "HEX_HOME", "GAOXY_TEST_PACKAGES", "GAOXY_CONSUMER_DEPS"):
        env.pop(name, None)
    try:
        (consumer / "mix.exs").write_text('''defmodule PeerCloseConsumer.MixProject do
  use Mix.Project
  def project, do: [app: :peer_close_consumer, version: "0.1.0", elixir: "~> 1.18",
                    deps: [{:gaoxy_http, "== 0.12.2"}]]
  def application, do: [extra_applications: [:logger, :ssl]]
end
''')
        (consumer / "test/test_helper.exs").write_text("ExUnit.start()\n")
        for name in TESTS:
            data = subprocess.check_output(["git", "show", f"{args.sha}:apps/gaoxy_http/test/{name}"], cwd=ROOT)
            (consumer / "test" / name).write_bytes(data)
            receipt["test_sha256"][name] = sha256(data)
        commands = [("resolve", ["mix", "deps.get"]),
                    ("compile", ["mix", "compile", "--warnings-as-errors"]),
                    ("dependencies", ["mix", "deps"]),
                    ("regressions", ["mix", "test", "--warnings-as-errors", *[f"test/{name}" for name in TESTS],
                                     "--seed", "20261022", "--max-cases", "1"])]
        for name, command in commands:
            started = time.monotonic()
            log = folder / f"{name}.log"
            with log.open("wb") as output:
                result = subprocess.run(command, cwd=consumer, env=env, stdout=output,
                                        stderr=subprocess.STDOUT, timeout=600)
            receipt["commands"].append({"name": name, "command": command, "exit": result.returncode,
                                        "seconds": round(time.monotonic()-started, 3), "log": str(log),
                                        "sha256": sha256(log.read_bytes())})
            print(name, "exit", result.returncode, flush=True)
            assert result.returncode == 0, f"{name} failed: {log}"
            if name == "resolve":
                lock = (consumer / "mix.lock").read_bytes()
                receipt["lock_sha256"] = sha256(lock)
                assert b":git," not in lock and b":path," not in lock
                for app in ("gaoxy", "gaoxy_http", "websock_adapter"):
                    assert re.search(r'"' + app + r'": \{:hex, :\w+, "0\.12\.2"', lock.decode()), app
            if name == "compile":
                for source in SOURCES:
                    expected = subprocess.check_output(["git", "show", f"{args.sha}:apps/gaoxy_http/lib/gaoxy/http/{source}"], cwd=ROOT)
                    actual = (consumer / "deps/gaoxy_http/lib/gaoxy/http" / source).read_bytes()
                    assert actual == expected, f"public source mismatch: {source}"
                    receipt["source_sha256"][source] = sha256(actual)
            if name == "regressions":
                text = log.read_text()
                assert re.findall(r"(\d+) tests?, (\d+) failures?", text) == [("9", "0")], text[-3000:]
                assert not re.search(r"[1-9]\d* (?:excluded|skipped)", text)
                assert len(re.findall(r"PASS peer-close sent_body=", text)) == 2
                receipt["executed"] = 9
                receipt["failures"] = receipt["excluded"] = receipt["skipped"] = 0
                print(text, flush=True)
        receipt["status"] = "PASS"
    except Exception as error:
        receipt["error"] = f"{type(error).__name__}: {error}"
    receipt["finished_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    (folder / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"status":receipt["status"], "receipt":str(folder / "receipt.json"), "error":receipt.get("error")}), flush=True)
    return 0 if receipt["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
