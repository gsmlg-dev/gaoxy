#!/usr/bin/env python3
"""Execute exact-source issue 18 tests using fresh, public Hex-only dependencies."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = ROOT / "docs/acceptance/evidence/release-0.13.0/helpers/public-issue-regressions.py"


def require(value, message):
    if not value:
        raise ValueError(message)


def load_base():
    data = BASE.read_bytes()
    expected = json.loads((ROOT / "docs/acceptance/evidence/release-0.13.0/evidence-manifest.json").read_text())
    entry, = [item for item in expected["copies"] if item["path"] == "helpers/public-issue-regressions.py"]
    require(hashlib.sha256(data).hexdigest() == entry["original_sha256"] == entry["archived_sha256"],
            "reviewed base helper checksum differs")
    spec = importlib.util.spec_from_file_location("gaoxy_public_audit_0130", BASE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT, module.HERE, module.VERSION = ROOT, HERE, "0.13.1"
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--adapter-test", default="plug_response_headers_test.exs")
    parser.add_argument("--adapter-count", type=int, required=True)
    parser.add_argument("--protocol-test", default="plug_response_headers_network_test.exs")
    parser.add_argument("--protocol-count", type=int, required=True)
    parser.add_argument("--support", action="append", default=[])
    parser.add_argument("--run-published", action="store_true")
    args = parser.parse_args()
    require(re.fullmatch(r"[0-9a-f]{40}", args.sha), "full publication SHA required")
    require(args.adapter_count > 0 and args.protocol_count > 0, "positive reviewed execution counts required")
    require(args.run_published, "explicit --run-published required after publication")
    for name in (args.adapter_test, args.protocol_test):
        require(re.fullmatch(r"[a-z0-9_]+_test\.exs", name), "test basename required")
    for support in args.support:
        require(re.fullmatch(r"apps/gaoxy_http/test/support/[a-zA-Z0-9_./-]+", support)
                and ".." not in Path(support).parts, "unsafe support source path")

    base = load_base()
    audit = base.Audit(args.sha, args.protocol_count)
    audit.receipt.update(task="issue-18-published-regressions", adapter_expected_executions=args.adapter_count,
                         runner_sha256=base.sha256(Path(__file__).read_bytes()),
                         reused_helper_sha256=base.sha256(BASE.read_bytes()))
    try:
        ca = Path("/etc/ssl/certs/ca-certificates.crt")
        require(ca.is_file(), "verified system CA bundle unavailable")
        audit.env.update(SSL_CERT_FILE=str(ca), PIP_CERT=str(ca), PYTHONDONTWRITEBYTECODE="1")
        audit.receipt["certificate_environment"] = {"SSL_CERT_FILE": str(ca), "PIP_CERT": str(ca),
                                                     "bundle_sha256": base.sha256(ca.read_bytes())}
        audit.command("source-identity", ["git", "rev-parse", args.sha + "^{commit}"])
        audit.tag_guard("remote_tag_before")
        audit.copy("scripts/check-tests.py")
        audit.copy("scripts/generate-fixtures.sh")
        native = audit.workspace / "apps/gaoxy_http"
        audit.manifest(native)
        audit.copy("apps/gaoxy_http/test/test_helper.exs")
        for filename in (args.adapter_test, args.protocol_test):
            audit.copy("apps/gaoxy_http/test/" + filename)
        requirements = "apps/gaoxy_http/test/support/h2-requirements.txt"
        audit.copy(requirements)
        for relative in args.support:
            if relative != requirements:
                audit.copy(relative)
        venv = audit.workspace / ".audit/h2peer"
        audit.command("python-peer-venv", [sys.executable, "-m", "venv", str(venv)])
        audit.command("python-peer-dependencies", [str(venv / "bin/python"), "-m", "pip", "install",
                      "--requirement", str(audit.workspace / requirements)], timeout=180)
        audit.command("python-peer-versions", [str(venv / "bin/python"), "-m", "pip", "freeze"])
        audit.resolve("native", native)
        audit.test("adapter-compatibility", args.adapter_test, args.adapter_count, native)
        audit.test("real-h1-h2-sse", args.protocol_test, args.protocol_count, native)
        audit.tag_guard("remote_tag_after")
        audit.receipt.update(status="PASS", executed=args.adapter_count + args.protocol_count,
                             failures=0, excluded=0, skipped=0)
    except BaseException as error:
        audit.receipt["error"] = f"{type(error).__name__}: {error}"
    finally:
        audit.receipt["finished_at"] = base.now()
        audit.checkpoint()
        print(json.dumps({"status": audit.receipt["status"], "receipt": str(audit.folder / "receipt.json"),
                          "error": audit.receipt.get("error")}), flush=True)
    return 0 if audit.receipt["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
