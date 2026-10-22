#!/usr/bin/env python3
"""Record the complete client gate, source restoration and actual process exit."""
import datetime
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = {
    "independent_h11_page", "independent_httpx_page", "independent_curl_page",
    "verified_https_and_hostname_rejection",
    "independent_websocket_channel_fragmentation_ping_close",
    "independent_static", "independent_sse", "development_code_reload_and_restore",
    "graceful_shutdown_and_listener_cleanup",
}


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def sources():
    files = set()
    for pattern in ["apps/*/lib/**/*.ex", "apps/*/mix.exs",
                    "examples/phoenix_native/lib/**/*", "examples/phoenix_native/config/*.exs",
                    "examples/phoenix_native/mix.*", "integration/phoenix_native/*.py",
                    "integration/phoenix_native/requirements.txt"]:
        files.update(path for path in ROOT.glob(pattern) if path.is_file())
    files.update(ROOT / name for name in ["mix.exs", "mix.lock", "scripts/generate-fixtures.sh"])
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(files)}


def main():
    evidence = Path(os.environ.get("GAOXY_PHOENIX_EVIDENCE", str(ROOT / ".audit/phoenix-clients"))).resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    os.environ["GAOXY_PHOENIX_EVIDENCE"] = str(evidence)
    expected = set(EXPECTED)
    if os.environ.get("PHOENIX_NATIVE_H2") == "1":
        expected.add("independent_verified_h2_phoenix")
    command = [sys.executable, str(Path(__file__).with_name("run.py"))]
    manifest = {
        "status": "NOT RUN", "started_utc": utc(), "command": command,
        "baseline": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "branch": subprocess.check_output(["git", "branch", "--show-current"], cwd=ROOT, text=True).strip(),
        "environment": {"python": sys.version, "h2_enabled": os.environ.get("PHOENIX_NATIVE_H2") == "1",
                        "dependencies": {name: importlib.metadata.version(name)
                                         for name in ["websockets", "h11", "httpx", "h2", "hpack", "hyperframe"]}},
        "source_before": sources(), "expected_checks": sorted(expected), "errors": [],
    }
    with (evidence / "gate.log").open("w") as log:
        result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    manifest["process_exit"] = result.returncode
    manifest["source_after"] = sources()
    manifest["source_restored"] = manifest["source_before"] == manifest["source_after"]
    try:
        checks = json.loads((evidence / "results.json").read_text())
        passed = {row["check"] for row in checks if row["status"] == "PASS"}
        if len(checks) != len(expected) or passed != expected:
            manifest["errors"].append("complete expected check set did not pass")
        manifest["executed_checks"] = len(checks)
        manifest["checks"] = checks
    except Exception as error:
        manifest["errors"].append(repr(error))
    if result.returncode != 0:
        manifest["errors"].append(f"client runner exited {result.returncode}")
    if not manifest["source_restored"]:
        manifest["errors"].append("source or controller restoration failed")
    manifest["status"] = "FAIL" if manifest["errors"] else "PASS"
    manifest["ended_utc"] = utc()
    manifest["exit_code"] = 0 if manifest["status"] == "PASS" else 1
    (evidence / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({key: manifest.get(key) for key in ["status", "executed_checks", "process_exit", "source_restored", "errors", "exit_code"]}), flush=True)
    return manifest["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
