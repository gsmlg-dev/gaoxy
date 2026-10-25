"""Prepare and run the locked, independently implemented HTTP/3 test peer."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import tomllib

ROOT = Path(__file__).resolve().parents[2]


def prepare(evidence_dir):
    evidence = Path(evidence_dir)
    evidence.mkdir(parents=True, exist_ok=True)
    manifest = ROOT / "integration/http3/release_peer/Cargo.toml"
    target = ROOT / ".audit/release-h3-peer-target"
    command = ["cargo", "build", "--locked", "--manifest-path", str(manifest),
               "--target-dir", str(target)]
    with (evidence / "peer-build.log").open("w") as output:
        output.write(json.dumps(command) + "\n")
        output.flush()
        child = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT,
                                 start_new_session=True)
        try:
            code = child.wait(timeout=600)
        except BaseException:
            os.killpg(child.pid, signal.SIGTERM)
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=5)
            raise
    if code != 0:
        raise subprocess.CalledProcessError(code, command)
    lock = manifest.with_name("Cargo.lock").read_bytes()
    receipt = {
        "command": command,
        "lock_sha256": hashlib.sha256(lock).hexdigest(),
        "dependencies": {row["name"]: row["version"] for row in tomllib.loads(lock.decode())["package"]
                         if row["name"] in {"h3", "h3-quinn", "quinn", "quinn-proto", "rustls"}},
    }
    return target / "debug/gaoxy-h3-release-peer", receipt


def request(binary, port, ca, *, path=None, timeout=15, evidence_dir=None):
    command = [str(binary), str(port), str(ca)]
    if path is not None:
        command += ["--path", path]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, timeout=timeout)
    if evidence_dir is not None:
        evidence = Path(evidence_dir)
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "peer.stdout.log").write_text(result.stdout)
        (evidence / "peer.stderr.log").write_text(result.stderr)
    assert result.returncode == 0, f"independent H3 peer failed: {result.stderr}"
    return json.loads(result.stdout)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare", type=Path, required=True)
    args = parser.parse_args()
    binary, _ = prepare(args.prepare)
    print(binary)
