#!/usr/bin/env python3
"""Run established smoke checks against the verified downloaded standalone."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import time

ROOT = Path(__file__).resolve().parents[3]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publication", type=Path, required=True)
    args = parser.parse_args()
    publication_path = args.publication.resolve()
    publication = json.loads(publication_path.read_text())
    assert publication["status"] == "PASS"
    source = publication["source"]
    archive_name = "gaoxy-0.7.0-linux-x86_64.tar.gz"
    archive = publication_path.parent / "downloads" / archive_name
    asset = next(x for x in publication["assets"] if x["name"] == archive_name)
    assert digest(archive) == asset["sha256"]
    output = Path(__file__).parent / ("runtime-" + str(time.time_ns()))
    output.mkdir()
    receipt = {"status": "RUNNING", "source": source, "version": "0.7.0",
               "publication": str(publication_path), "publication_sha256": digest(publication_path),
               "archive_sha256": digest(archive), "tool_sha256": digest(Path(__file__)),
               "environment": {name: os.environ.get(name) for name in
                               ("NIX_LD", "NIX_LD_LIBRARY_PATH", "LD_LIBRARY_PATH")},
               "commands": []}

    def command(name, argv):
        started = time.time()
        path = output / (name + ".log")
        with path.open("wb") as stream:
            result = subprocess.run(argv, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                                    timeout=180, env=dict(os.environ, ELIXIR_ERL_OPTIONS="+S 4:4"))
        receipt["commands"].append({"name": name, "argv": argv, "exit": result.returncode,
                                    "seconds": time.time() - started, "log": path.name,
                                    "sha256": digest(path)})
        assert result.returncode == 0, (name, result.returncode, str(path))

    try:
        inputs = ["scripts/release-smoke.py", "scripts/gateway-release-smoke.py",
                  "scripts/h3-release-smoke.py", "scripts/generate-fixtures.sh",
                  "apps/gaoxy_http/test/support/mixed_http_peer.py",
                  "integration/http3/upstream/run.py", "integration/http3/upstream/origin.py"]
        receipt["source_files_sha256"] = {}
        for name in inputs:
            committed = subprocess.check_output(["git", "show", source + ":" + name], cwd=ROOT)
            assert committed == (ROOT / name).read_bytes(), name
            receipt["source_files_sha256"][name] = hashlib.sha256(committed).hexdigest()
        standalone = output / "standalone"
        standalone.mkdir()
        with tarfile.open(archive) as packed:
            packed.extractall(standalone, filter="data")
        release = str(standalone.resolve() / "bin/gaoxy")
        command("version", [release, "version"])
        assert "0.7.0" in (output / "version.log").read_text()
        core = ("import pathlib,runpy,sys; "
                "x=runpy.run_path('scripts/release-smoke.py',run_name='downloaded_release'); "
                "f=x['main']; f.__globals__['release']=pathlib.Path(sys.argv[1]); f()")
        command("core", [sys.executable, "-c", core, release])
        peer = str(ROOT / ".audit/h2peer/bin/python")
        command("gateway", [peer, "scripts/gateway-release-smoke.py", "--release", release])
        command("h3", [peer, "scripts/h3-release-smoke.py", "--release", release,
                       "--evidence", str((output / "h3-evidence").resolve())])
        receipt.update(status="PASS", counts={"core_transports": 3, "gateway_exchanges": 7,
                                               "mixed_port_exchanges": 5, "h3_checks": 3})
    except BaseException as error:
        receipt.update(status="FAIL", error=repr(error))
        raise
    finally:
        path = output / "verification.json"
        path.write_text(json.dumps(receipt, indent=2) + "\n")
        print(json.dumps({"status": receipt["status"], "receipt": str(path)}), flush=True)


if __name__ == "__main__":
    main()
