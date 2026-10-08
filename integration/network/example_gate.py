#!/usr/bin/env python3
"""Exercise the shipped custom-handler example in isolated Linux namespaces."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from fixture import Child, Fixture, ROOT


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-privileged", action="store_true")
    options = parser.parse_args()
    if sys.platform != "linux" or not options.allow_privileged:
        print("BLOCKED_ENV: Linux and explicit --allow-privileged required", file=sys.stderr)
        return 77
    fixture = Fixture()
    try:
        for executable in ("ip", "setpriv", "openssl", "bash", "mix"):
            assert shutil.which(executable), "missing prerequisite: " + executable
        fixture.setup()
        with tempfile.TemporaryDirectory(prefix="gaoxy-mixed-example-") as directory:
            credentials = Path(directory)
            subprocess.run(["bash", str(ROOT / "scripts/generate-fixtures.sh"), directory], check=True)
            server = Child(fixture, fixture.server, [
                "env", "GAOXY_FIXTURE_CONFIRM=isolated", "GAOXY_FIXTURE_INTERFACE=eth0",
                "GAOXY_FIXTURE_ADDRESS=192.0.2.10",
                "GAOXY_FIXTURE_CERT=" + str(credentials / "cert.pem"),
                "GAOXY_FIXTURE_KEY=" + str(credentials / "key.pem"),
                "mix", "run", str(ROOT / "examples/mixed_transports/run.exs"),
            ])
            line = server.wait(lambda item: item.startswith("MIXED_READY "), timeout=15)
            ready = json.loads(line.removeprefix("MIXED_READY "))
            bound = {("udp" if e["id"] == "unicast" else e["id"]): e for e in ready["services"]}
            assert set(bound) == {"tcp", "tls", "udp", "broadcast", "multicast"}, bound
            assert all(e["port"] > 0 for e in bound.values()), bound
            endpoints = credentials / "bound.json"
            endpoints.write_text(json.dumps(bound))
            peer_command = [sys.executable, str(Path(__file__).with_name("release_gate.py"))]
            count = 0
            for namespace in fixture.peers:
                peer = Child(fixture, namespace, peer_command + ["--peer", str(endpoints), directory])
                for _ in range(5):
                    print(peer.wait(lambda item: item.startswith("PASS "), timeout=15), flush=True)
                    count += 1
                assert peer.process.wait(timeout=5) == 0
            server.process.terminate()
            assert server.process.wait(timeout=8) == 0, server.events
            probe = Child(fixture, fixture.server, peer_command + ["--probe", str(endpoints)])
            print(probe.wait(lambda item: item.startswith("PASS "), timeout=5), flush=True)
            assert probe.process.wait(timeout=5) == 0
            print(json.dumps({"result": "PASS", "suite": "mixed_transport_custom_example",
                              "count": count + 1, "transports": 5, "independent_peers": 2}), flush=True)
        return 0
    except Exception as error:
        print("FAIL " + repr(error), file=sys.stderr)
        for child in fixture.children:
            print("Child output:\n" + "\n".join(child.events[-20:]), file=sys.stderr)
        return 1
    finally:
        fixture.cleanup()


if __name__ == "__main__":
    sys.exit(main())
