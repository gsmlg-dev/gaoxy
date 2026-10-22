#!/usr/bin/env python3
"""Test an existing GitHub Linux release with HTTP clients; never build its server."""
import argparse
import asyncio
import base64
import hashlib
import importlib.metadata
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import ssl
import subprocess
import sys
import tarfile
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
REPO = "gsmlg-dev/gaoxy"


def verified_digest(archive, sums):
    matches = [line.split()[0] for line in sums.read_text().splitlines()
               if len(line.split()) == 2 and line.split()[1].lstrip("*") == archive.name]
    if len(matches) != 1 or not re.fullmatch(r"[0-9a-f]{64}", matches[0]):
        raise ValueError("release archive must have exactly one valid SHA256SUMS entry")
    actual = hashlib.sha256(archive.read_bytes()).hexdigest()
    if actual != matches[0]:
        raise ValueError("release archive checksum mismatch")
    return actual


def load_peer(source):
    spec = importlib.util.spec_from_file_location("released_h3_peer", source / "scripts/h3-release-smoke.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?", args.version):
        parser.error("version must be a release version without v")
    args.evidence = args.evidence.resolve()
    args.evidence.mkdir(parents=True, exist_ok=True)
    report = {"status": "FAIL", "version": args.version, "checks": [], "commands": [],
              "harness_source": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "harness_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "fixture_sha256": hashlib.sha256(Path(__file__).with_name("fixture.exs").read_bytes()).hexdigest()}
    child, stop, temporary = None, None, None

    def command(argv, *, env=None, timeout=30):
        report["commands"].append(argv)
        with (args.evidence / "clients.log").open("ab") as log:
            log.write(("COMMAND " + " ".join(argv) + "\n").encode())
            log.flush()
            process = subprocess.Popen(argv, env=env, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                output, _ = process.communicate(timeout=timeout)
            except BaseException as error:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                output, _ = process.communicate(timeout=5)
                marker = "COMMAND_TIMEOUT" if isinstance(error, subprocess.TimeoutExpired) else "COMMAND_INTERRUPTED"
                log.write(output + ("\n" + marker + "\n").encode())
                raise
            log.write(output + b"\n")
        if process.returncode:
            raise RuntimeError(f"command exit {process.returncode}: {argv}; see clients.log")
        return output

    def passed(name, client, protocol):
        report["checks"].append(dict(name=name, client=client, protocol=protocol, status="PASS"))

    try:
        import httpx
        from websockets.sync.client import connect as websocket_connect
        from aioquic.asyncio import connect as quic_connect
        from aioquic.quic.configuration import QuicConfiguration

        report["client_versions"] = {name: importlib.metadata.version(name)
                                     for name in ("httpx", "websockets", "aioquic")}
        report["client_versions"]["curl"] = command(["curl", "--version"]).decode().splitlines()[0]
        temporary = tempfile.TemporaryDirectory(prefix="gaoxy-released-clients-")
        stage = Path(temporary.name)
        asset = f"gaoxy-{args.version}-linux-x86_64.tar.gz"
        tag = "v" + args.version
        source_sha = command(["gh", "api", f"repos/{REPO}/commits/{tag}", "--jq", ".sha"]).decode().strip()
        assert re.fullmatch(r"[0-9a-f]{40}", source_sha), source_sha
        report["release_source"] = source_sha
        command(["gh", "release", "download", tag, "--repo", REPO, "--dir", str(stage),
                 "--pattern", asset, "--pattern", "SHA256SUMS"], timeout=120)
        report["artifact"] = asset
        report["artifact_sha256"] = verified_digest(stage / asset, stage / "SHA256SUMS")
        runtime = stage / "runtime"
        with tarfile.open(stage / asset) as archive:
            archive.extractall(runtime, filter="data")
        assert (runtime / "releases" / args.version / "start.boot").is_file()
        release = runtime / "bin/gaoxy"
        # Fetch only existing peer/credential helpers from the artifact's tag.
        source = stage / "source"
        for relative in ("scripts/h3-release-smoke.py", "integration/http3/upstream/run.py"):
            path = source / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            data = command(["gh", "api", f"repos/{REPO}/contents/{relative}?ref={source_sha}", "--jq", ".content"])
            path.write_bytes(base64.b64decode(data))
        peer = load_peer(source)
        certificates = stage / "certificates"
        with (args.evidence / "certificates.log").open("w") as log:
            peer.credentials(certificates, log, lambda maximum: maximum)
        ready, stop = stage / "ready.json", stage / "stop"
        environment = dict(os.environ, GAOXY_E2E_VERSION=args.version,
                           GAOXY_E2E_CERTS=str(certificates), GAOXY_E2E_READY=str(ready),
                           GAOXY_E2E_STOP=str(stop),
                           GAOXY_E2E_FIXTURE=str(Path(__file__).with_name("fixture.exs").resolve()),
                           ERL_CRASH_DUMP=str(args.evidence / "erl_crash.dump"))
        environment.pop("GAOXY_CONFIG", None)
        argv = [str(release), "eval", 'Code.require_file(System.fetch_env!("GAOXY_E2E_FIXTURE"))']
        report["commands"].append(argv)
        with (args.evidence / "server.log").open("w") as log:
            child = subprocess.Popen(argv, env=environment, cwd=stage, stdout=log,
                                     stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 30
        while True:
            assert child.poll() is None, "released fixture exited during startup; see server.log"
            assert time.monotonic() < deadline, "released fixture startup deadline; see server.log"
            try:
                actual = json.loads(ready.read_text())
                break
            except (FileNotFoundError, json.JSONDecodeError):
                time.sleep(0.02)
        assert actual["version"] == args.version
        ports = actual["ports"]
        assert set(ports) == {"h1", "https", "h3"} and all(0 < port < 65536 for port in ports.values())
        report["server"] = actual
        ca = certificates / "ca.pem"
        plain = f"http://127.0.0.1:{ports['h1']}"
        secure = f"https://localhost:{ports['https']}"
        for name, url, extra in (("curl_h1", plain, []), ("curl_tls", secure, ["--cacert", str(ca)])):
            result = command(["curl", "--fail", "--silent", "--show-error", "--noproxy", "*",
                              "--http1.1", "--max-time", "5", *extra,
                              "--write-out", "\n%{http_code} %{http_version}", url + "/health"])
            assert result == b"ok\n200 1.1", result
            passed(name, "curl", "HTTP/1.1")
        payload = b"E2E-upload\x00" * 2048
        for name, url, options in (("h1", plain, {}), ("h2", secure, {"http2": True, "verify": ssl.create_default_context(cafile=str(ca))})):
            protocol = "HTTP/1.1" if name == "h1" else "HTTP/2"
            with httpx.Client(timeout=5, trust_env=False, **options) as client:
                response = client.get(url + "/health")
                assert response.status_code == 200 and response.content == b"ok"
                assert response.headers["x-e2e"] == "gaoxy" and response.http_version == protocol
                passed("httpx_" + name, "httpx", response.http_version)
                response = client.post(url + "/upload", content=payload)
                assert response.status_code == 200 and response.content == payload and response.http_version == protocol
                passed("upload_" + name, "httpx", response.http_version)
                with client.stream("GET", url + "/stream") as response:
                    assert response.status_code == 200 and response.http_version == protocol
                    assert b"".join(response.iter_bytes()) == b"first\nsecond\n"
                    if name == "h1":
                        assert response.headers["transfer-encoding"] == "chunked"
                passed("stream_" + name, "httpx", protocol)
        expression = '''
        {:ok, _} = Application.ensure_all_started(:http_fetch)
        response = HTTP.fetch(System.fetch_env!("GAOXY_E2E_URL"), http_version: :http1, timeout: 3000) |> HTTP.Promise.await(5000)
        %HTTP.Response{status: 200, http_version: :http1} = response
        "ok" = HTTP.Response.text(response)
        IO.puts("GAOXY_E2E_HTTPFETCH " <> to_string(Application.spec(:http_fetch, :vsn)))
        '''
        result = command([str(release), "eval", expression], env=dict(environment, GAOXY_E2E_URL=plain + "/health"), timeout=15)
        receipt = re.search(rb"GAOXY_E2E_HTTPFETCH ([^\s]+)", result)
        assert receipt, result
        report["http_fetch_version"] = receipt[1].decode()
        passed("http_fetch_h1", "HTTPFetch", "HTTP/1.1")

        async def h3():
            configuration = QuicConfiguration(is_client=True, alpn_protocols=["h3"], server_name="localhost")
            configuration.load_verify_locations(cafile=str(ca))
            async with asyncio.timeout(10):
                async with quic_connect("127.0.0.1", ports["h3"], configuration=configuration, create_protocol=peer.Peer) as client:
                    response = await client.request(ports["h3"], "/health")
                    assert bytes(response["body"]) == b"ok" and client.alpn == "h3"
        asyncio.run(h3())
        passed("h3_health", "aioquic", "h3")
        with websocket_connect(f"ws://127.0.0.1:{ports['h1']}/websocket", open_timeout=5, close_timeout=3, proxy=None) as client:
            client.send("e2e")
            assert client.recv(timeout=5) == "e2e"
            client.close(code=1000)
            assert client.close_code == 1000
        passed("websocket_message_close", "websockets", "HTTP/1.1 WebSocket")
        stop.touch()
        report["server_exit"] = child.wait(timeout=15)
        assert report["server_exit"] == 0
        assert "GAOXY_E2E_STOPPED" in (args.evidence / "server.log").read_text()
        assert len(report["checks"]) == 11
        report["status"] = "PASS"
    except (ModuleNotFoundError, FileNotFoundError) as error:
        report.update(status="BLOCKED_ENV", error=repr(error))
        raise
    except BaseException as error:
        report["error"] = repr(error)
        report["checks"].append(dict(name="suite_completion", status="FAIL", error=repr(error)))
        raise
    finally:
        if child is not None and child.poll() is None:
            if stop is not None:
                stop.touch()
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait(timeout=5)
        if child is not None:
            report["server_exit"] = child.returncode
        if temporary is not None:
            temporary.cleanup()
        (args.evidence / "result.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "checks": len(report["checks"])}))


if __name__ == "__main__":
    main()
