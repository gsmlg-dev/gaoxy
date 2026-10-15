#!/usr/bin/env python3
"""Real peer startup/ownership regressions; no protocol success is synthesized."""
import json
import os
from pathlib import Path
import queue
import selectors
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import unittest

import h2.config
import h2.connection
import h2.events

ROOT = Path(__file__).resolve().parents[4]
PEER = ROOT / "apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py"
OPENSSL = os.environ.get("OPENSSL_BIN") or shutil.which("openssl")
PROBE = b"<!doctype html><title>Gaoxy managed H2</title><h1 id=probe>managed H2 probe</h1>"


class CertificateBarrier:
    """Hold a real key operation using FIFOs, with a real owned descendant."""
    def __init__(self, directory, operation="key"):
        self.operation = operation
        self.root = directory / "barrier"
        self.root.mkdir()
        self.marker = self.root / "marker"
        self.release = self.root / "release"
        os.mkfifo(self.marker)
        os.mkfifo(self.release)
        self.marker_fd = os.open(self.marker, os.O_RDWR | os.O_NONBLOCK)
        self.release_fd = os.open(self.release, os.O_RDWR | os.O_NONBLOCK)
        self.wrapper = self.root / "openssl"
        self.wrapper.write_text("#!" + sys.executable + "\n" + r'''
import json, os, signal, subprocess, sys
from pathlib import Path
root = Path(os.environ["GAOXY_KEY_BARRIER"])
args = sys.argv[1:]
child = None

def terminate(signum, _frame):
    raise SystemExit(128 + signum)

wanted = args == ["version", "-a"] if os.environ["GAOXY_BARRIER_OPERATION"] == "metadata" else bool(args and args[0] == "req")
if wanted and not (root / "claimed").exists():
    (root / "claimed").write_text("owned first key operation")
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    try:
        child = subprocess.Popen([sys.executable, "-c", "import signal; signal.pause()"])
        identity = dict(pid=os.getpid(), child=child.pid, pgid=os.getpgrp())
        (root / "identities.json").write_text(json.dumps(identity))
        with (root / "marker").open("w") as output:
            output.write(json.dumps(identity) + "\n")
            output.flush()
        with (root / "release").open("r") as control:
            if control.read(1) != "1":
                raise RuntimeError("certificate barrier not released")
    finally:
        if child is not None:
            if child.poll() is None:
                child.terminate()
            child.wait(timeout=2)
os.execv(os.environ["GAOXY_REAL_OPENSSL"], [os.environ["GAOXY_REAL_OPENSSL"], *args])
''')
        self.wrapper.chmod(0o700)

    def environment(self):
        return dict(OPENSSL_BIN=str(self.wrapper), GAOXY_KEY_BARRIER=str(self.root),
                    GAOXY_REAL_OPENSSL=str(OPENSSL), GAOXY_BARRIER_OPERATION=self.operation,
                    PATH=str(self.root) + os.pathsep + os.environ.get("PATH", ""))

    def entered(self):
        with selectors.DefaultSelector() as selector:
            selector.register(self.marker_fd, selectors.EVENT_READ)
            if not selector.select(timeout=5):
                raise AssertionError("real certificate key operation did not reach barrier")
        return json.loads(os.read(self.marker_fd, 4096))

    def unblock(self):
        os.write(self.release_fd, b"1")

    def close(self):
        os.close(self.marker_fd)
        os.close(self.release_fd)


class RunningPeer:
    def __init__(self, directory, protocol, staged=False, environment=None, barrier=None):
        self.owned = directory / "owned"
        self.owned.mkdir()
        self.barrier = barrier
        env = dict(os.environ, TMPDIR=str(self.owned))
        env.update(environment or {})
        args = [sys.executable, "-B", str(PEER), "--protocol", protocol]
        if staged:
            args.append("--staged-start")
        self.process = subprocess.Popen(args, cwd=ROOT, env=env, stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                        text=True, bufsize=1, start_new_session=True)
        self.events = queue.Queue()
        self.backlog, self.lines = [], []
        self.reader = threading.Thread(target=self.read)
        self.reader.start()

    def read(self):
        try:
            for line in self.process.stdout:
                self.lines.append(line)
                try:
                    self.events.put(json.loads(line))
                except json.JSONDecodeError:
                    pass
        finally:
            self.events.put({"event": "process_eof"})

    def send(self, op):
        self.process.stdin.write(json.dumps({"op": op}) + "\n")
        self.process.stdin.flush()

    def event(self, name, timeout=5):
        for index, value in enumerate(self.backlog):
            if value.get("event") == name:
                return self.backlog.pop(index)
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError(f"missing real peer event {name}: {''.join(self.lines)}")
            try:
                value = self.events.get(timeout=remaining)
            except queue.Empty:
                raise AssertionError(f"missing real peer event {name}: {''.join(self.lines)}") from None
            if value.get("event") == name:
                return value
            if value.get("event") == "process_eof":
                raise AssertionError(f"peer exited before {name}: {''.join(self.lines)}")
            if value.get("event") == "failure" and name != "failure":
                raise AssertionError(f"peer failed before {name}: {value}")
            self.backlog.append(value)

    def join(self, expected=0, timeout=5):
        try:
            code = self.process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            raise AssertionError("owned peer did not exit/join within its finite deadline") from None
        self.reader.join(timeout=2)
        if self.reader.is_alive():
            raise AssertionError("owned peer stdout reader failed to join")
        if code != expected:
            raise AssertionError(f"peer exit {code} != {expected}: {''.join(self.lines)}")
        if "AttributeError" in "".join(self.lines):
            raise AssertionError("partial-start cleanup masked its original failure")

    def assert_empty(self, case):
        case.assertEqual(list(self.owned.iterdir()), [], "owned certificate/TMPDIR artifacts leaked")

    def dispose(self):
        # Test-failure disposal only. Passing ownership assertions run BEFORE it.
        identities = {}
        if self.barrier is not None:
            record = self.barrier.root / "identities.json"
            if record.exists():
                identities = json.loads(record.read_text())
        groups = set()
        if self.process.poll() is None:
            groups.add(self.process.pid)
        if identities and any(alive(identities[key]) for key in ("pid", "child")):
            groups.add(identities["pgid"])
        for group in groups:
            if group == os.getpgrp():
                raise AssertionError("refusing to dispose the test runner's process group")
            try:
                os.killpg(group, signal.SIGTERM)
            except ProcessLookupError:
                pass
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            for group in groups:
                try:
                    os.killpg(group, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            self.process.wait(timeout=5)
        if not self.process.stdin.closed:
            self.process.stdin.close()
        self.reader.join(timeout=2)
        self.process.stdout.close()
        if self.reader.is_alive():
            raise AssertionError("test-failure disposal left stdout reader alive")


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


class PeerStartupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gaoxy-peer-startup-regression-")
        self.directory = Path(self.temp.name)
        self.peers, self.barriers = [], []

    def tearDown(self):
        try:
            for peer in reversed(self.peers):
                peer.dispose()
        finally:
            for barrier in self.barriers:
                barrier.close()
            self.temp.cleanup()

    def peer(self, protocol, **options):
        directory = self.directory / f"peer-{len(self.peers)}"
        directory.mkdir()
        peer = RunningPeer(directory, protocol, **options)
        self.peers.append(peer)
        return peer

    def barrier(self, operation="key"):
        barrier = CertificateBarrier(self.directory, operation)
        self.barriers.append(barrier)
        return barrier

    def assert_joined(self, peer, *, failed=False, requests=0):
        joined = peer.event("joined")
        self.assertEqual(joined["live"], 0)
        self.assertEqual(joined["forced"], 0)
        self.assertIs(joined["failed"], failed)
        self.assertEqual(joined["requests"], requests)
        return joined

    def exchange(self, peer, ready, tls):
        self.assertGreater(ready["port"], 0)
        raw = socket.create_connection(("127.0.0.1", ready["port"]), timeout=3)
        if tls:
            context = ssl.create_default_context(cafile=ready["ca"])
            context.set_alpn_protocols(["h2"])
            sock = context.wrap_socket(raw, server_hostname="localhost")
            self.assertEqual(sock.selected_alpn_protocol(), "h2")
        else:
            sock = raw
        with sock:
            sock.settimeout(3)
            conn = h2.connection.H2Connection(config=h2.config.H2Configuration(
                client_side=True, header_encoding="utf-8"))
            conn.initiate_connection()
            conn.send_headers(1, [(":method", "GET"), (":scheme", "https" if tls else "http"),
                                  (":authority", "localhost"), (":path", "/probe")], end_stream=True)
            sock.sendall(conn.data_to_send())
            headers, body, ended = None, bytearray(), False
            deadline = time.monotonic() + 5
            while not ended:
                self.assertLess(time.monotonic(), deadline, "real H2 response deadline")
                data = sock.recv(65536)
                self.assertTrue(data, "peer closed before real H2 response ended")
                for event in conn.receive_data(data):
                    if isinstance(event, h2.events.ResponseReceived):
                        headers = dict(event.headers)
                    elif isinstance(event, h2.events.DataReceived):
                        body.extend(event.data)
                        conn.acknowledge_received_data(event.flow_controlled_length, event.stream_id)
                    elif isinstance(event, h2.events.StreamEnded):
                        ended = True
                outbound = conn.data_to_send()
                if outbound:
                    sock.sendall(outbound)
            self.assertEqual(headers[":status"], "200")
            self.assertEqual(headers["x-peer"], "independent-h2")
            self.assertEqual(bytes(body), PROBE)
        self.assertEqual(peer.event("request")["target"], "/probe")
        self.assertEqual(peer.event("eof")["connection"], 1)

    def test_h2c_without_openssl_serves_real_h2_and_joins(self):
        peer = self.peer("h2c", environment={"OPENSSL_BIN": str(self.directory / "absent-openssl")})
        ready = peer.event("ready")
        for key in ("ca", "cert", "key"):
            self.assertIn(key, ready)
            self.assertIsNone(ready[key])
        for key in ("certificate_sha256", "openssl", "openssl_executable"):
            self.assertIn(key, ready["identity"])
            self.assertIsNone(ready["identity"][key])
        self.assertEqual(ready["identity"]["python_openssl"], ssl.OPENSSL_VERSION)
        self.exchange(peer, ready, False)
        peer.send("stop")
        self.assert_joined(peer, requests=1)
        peer.join()
        peer.assert_empty(self)

    def test_default_tls_auto_start_keeps_real_tls_response_and_join(self):
        peer = self.peer("tls")
        ready = peer.event("ready", timeout=25)
        self.assertTrue(Path(ready["ca"]).is_file())
        self.exchange(peer, ready, True)
        peer.send("stop")
        self.assert_joined(peer, requests=1)
        peer.join()
        peer.assert_empty(self)

    def test_staged_tls_preparation_barrier_then_explicit_start_and_real_tls(self):
        barrier = self.barrier()
        peer = self.peer("tls", staged=True, environment=barrier.environment(), barrier=barrier)
        identities = barrier.entered()
        self.assertTrue(alive(identities["child"]))
        self.assertFalse(any(json.loads(line).get("event") in ("prepared", "ready")
                             for line in peer.lines if line.startswith("{")))
        barrier.unblock()
        prepared = peer.event("prepared", timeout=25)
        self.assertEqual(prepared["protocol"], "tls")
        self.assertFalse(any('"event":"ready"' in line for line in peer.lines))
        self.assertIsNone(peer.process.poll())
        peer.send("start")
        ready = peer.event("ready")
        self.exchange(peer, ready, True)
        peer.send("stop")
        self.assert_joined(peer, requests=1)
        peer.join()
        peer.assert_empty(self)
        self.assertFalse(alive(identities["pid"]))
        self.assertFalse(alive(identities["child"]))

    def test_staged_h2c_prepares_without_openssl_then_real_h2(self):
        peer = self.peer("h2c", staged=True,
                         environment={"OPENSSL_BIN": str(self.directory / "absent-openssl")})
        prepared = peer.event("prepared")
        self.assertEqual(prepared["protocol"], "h2c")
        self.assertFalse(any('"event":"ready"' in line for line in peer.lines))
        peer.send("start")
        ready = peer.event("ready")
        self.exchange(peer, ready, False)
        peer.send("stop")
        self.assert_joined(peer, requests=1)
        peer.join()
        peer.assert_empty(self)

    def test_staged_stop_after_prepared_joins_without_listener(self):
        peer = self.peer("tls", staged=True)
        peer.event("prepared", timeout=25)
        peer.send("stop")
        joined = self.assert_joined(peer)
        self.assertEqual(joined["accepts"], 0)
        peer.join()
        peer.assert_empty(self)
        self.assertFalse(any('"event":"ready"' in line for line in peer.lines))

    def assert_cancel_preparation(self, eof):
        barrier = self.barrier()
        peer = self.peer("tls", environment=barrier.environment(), barrier=barrier)
        identities = barrier.entered()
        if eof:
            peer.process.stdin.close()
        else:
            peer.send("stop")
        self.assert_joined(peer)
        peer.join()
        peer.assert_empty(self)
        self.assertFalse(alive(identities["pid"]), "certificate wrapper survived cancellation")
        self.assertFalse(alive(identities["child"]), "certificate descendant survived cancellation")
        self.assertFalse(any('"event":"ready"' in line for line in peer.lines))

    def test_stop_during_real_certificate_preparation_joins_owned_process_group(self):
        self.assert_cancel_preparation(False)

    def test_eof_during_real_certificate_preparation_joins_owned_process_group(self):
        self.assert_cancel_preparation(True)

    def test_preparation_timeout_reports_failure_and_joins_owned_process_group(self):
        barrier = self.barrier()
        peer = self.peer("tls", environment=barrier.environment(), barrier=barrier)
        identities = barrier.entered()
        failure = peer.event("failure", timeout=25)
        self.assertRegex(failure["reason"].lower(), r"timeout|timed out")
        self.assert_joined(peer, failed=True)
        peer.join(expected=1)
        peer.assert_empty(self)
        self.assertFalse(alive(identities["pid"]))
        self.assertFalse(alive(identities["child"]))

    def test_metadata_timeout_is_within_preparation_and_joins_owned_process_group(self):
        barrier = self.barrier("metadata")
        peer = self.peer("tls", staged=True, environment=barrier.environment(), barrier=barrier)
        identities = barrier.entered()
        self.assertFalse(any('"event":"prepared"' in line or '"event":"ready"' in line
                             for line in peer.lines))
        failure = peer.event("failure", timeout=25)
        self.assertRegex(failure["reason"].lower(), r"timeout|timed out")
        self.assert_joined(peer, failed=True)
        peer.join(expected=1)
        peer.assert_empty(self)
        self.assertFalse(alive(identities["pid"]))
        self.assertFalse(alive(identities["child"]))

    def test_metadata_failure_preserves_primary_diagnostic_without_listener(self):
        wrapper = self.directory / "openssl"
        wrapper.write_text("#!" + sys.executable + "\n" +
                           "import os, sys\n" +
                           "if sys.argv[1:] == ['version', '-a']:\n" +
                           "    print('fixture metadata identity failure', file=sys.stderr)\n" +
                           "    sys.exit(73)\n" +
                           "os.execv(os.environ['GAOXY_REAL_OPENSSL'], " +
                           "[os.environ['GAOXY_REAL_OPENSSL'], *sys.argv[1:]])\n")
        wrapper.chmod(0o700)
        peer = self.peer("tls", environment={"OPENSSL_BIN": str(wrapper),
                         "GAOXY_REAL_OPENSSL": str(OPENSSL),
                         "PATH": str(self.directory) + os.pathsep + os.environ.get("PATH", "")})
        failure = peer.event("failure", timeout=25)
        self.assertIn("fixture metadata identity failure", failure["reason"])
        self.assert_joined(peer, failed=True)
        peer.join(expected=1)
        peer.assert_empty(self)
        self.assertFalse(any('"event":"ready"' in line for line in peer.lines))

    def test_preparation_executable_failure_preserves_diagnostic_and_partial_stop(self):
        peer = self.peer("tls", environment={"OPENSSL_BIN": str(self.directory / "absent-openssl")})
        failure = peer.event("failure")
        self.assert_joined(peer, failed=True)
        peer.join(expected=1)
        self.assertIn("OPENSSL_BIN", failure["reason"])
        peer.assert_empty(self)


if __name__ == "__main__":
    unittest.main(verbosity=2)
