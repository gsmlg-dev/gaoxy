"""Build and run the pinned, public-API quic-go WebSocket test client."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def prepare(evidence_dir):
    evidence = Path(evidence_dir)
    evidence.mkdir(parents=True, exist_ok=True)
    source = ROOT / "integration/http3/channel_peer"
    binary = ROOT / ".audit/release-h3-channel-peer"
    command = ["go", "build", "-mod=readonly", "-o", str(binary), "."]
    env = dict(os.environ, GOTOOLCHAIN="local")
    with (evidence / "channel-peer-build.log").open("w") as output:
        output.write(json.dumps(command) + "\n")
        output.flush()
        child = subprocess.Popen(command, cwd=source, env=env, stdout=output,
                                 stderr=subprocess.STDOUT, start_new_session=True)
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
    build = subprocess.check_output(["go", "version", "-m", str(binary)],
                                    env=env, text=True, timeout=10)
    (evidence / "channel-peer-build-info.log").write_text(build)
    version = build.splitlines()[0].split()[-1]
    assert version == "go1.26.6", build
    receipt = {
        "command": command, "go_version": version,
        "source_hashes": {name: hashlib.sha256((source / name).read_bytes()).hexdigest()
                          for name in ["go.mod", "go.sum", "main.go"]},
        "dependencies": {row.split()[1]: row.split()[2] for row in build.splitlines()
                         if row.startswith("\tdep\t")},
    }
    return binary, receipt


def channel(binary, port, ca, messages, timeout=15, evidence_dir=None):
    command = [str(binary), str(port), str(ca)]
    result = subprocess.run(command, input=json.dumps(messages), stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, timeout=timeout)
    if evidence_dir is not None:
        evidence = Path(evidence_dir)
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "channel-peer.stdout.log").write_text(result.stdout)
        (evidence / "channel-peer.stderr.log").write_text(result.stderr)
    assert result.returncode == 0, f"independent H3 channel peer failed: {result.stderr}"
    return json.loads(result.stdout)
