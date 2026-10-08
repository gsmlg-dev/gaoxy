#!/usr/bin/env python3
"""Deterministic regressions for standalone release readiness and admission barriers."""
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

SPEC = importlib.util.spec_from_file_location(
    "release_smoke", Path(__file__).with_name("release-smoke.py")
)
SMOKE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SMOKE)


class ReleaseSmokeTest(unittest.TestCase):
    def test_readiness_waits_for_missing_empty_partial_then_valid_json(self):
        with tempfile.TemporaryDirectory(prefix="gaoxy-ready-test-") as directory:
            ready = Path(directory, "ready.json")
            expected = {"services": [{"id": "udp", "address": "127.0.0.1", "port": 1234}]}
            writes = iter(["", '{"services":', json.dumps(expected)])
            process = Mock()
            process.poll.return_value = None
            with patch.object(SMOKE.time, "monotonic", return_value=0), \
                    patch.object(SMOKE.time, "sleep", side_effect=lambda _: ready.write_text(next(writes))) as poll:
                self.assertEqual(SMOKE.wait_for_readiness(process, ready, io.StringIO()), expected)
            self.assertEqual(poll.call_count, 3)

    def test_readiness_exit_retains_release_diagnostics(self):
        with tempfile.TemporaryDirectory(prefix="gaoxy-ready-test-") as directory:
            ready = Path(directory, "ready.json")
            ready.write_text("")
            process = Mock()
            process.poll.return_value = 1
            with self.assertRaisesRegex(AssertionError, "release readiness failed: release crashed"):
                SMOKE.wait_for_readiness(process, ready, io.StringIO("release crashed"))

    def test_incomplete_readiness_expires_at_original_deadline(self):
        with tempfile.TemporaryDirectory(prefix="gaoxy-ready-test-") as directory:
            ready = Path(directory, "ready.json")
            ready.write_text('{"services":')
            process = Mock()
            process.poll.return_value = None
            with patch.object(SMOKE.time, "monotonic", side_effect=[0, 0, 7, 14, 15]), \
                    patch.object(SMOKE.time, "sleep") as poll:
                with self.assertRaisesRegex(AssertionError, "release readiness failed: still starting"):
                    SMOKE.wait_for_readiness(process, ready, io.StringIO("still starting"))
            self.assertEqual(poll.call_count, 3)

    def test_admission_barrier_requires_refusal_after_reset(self):
        process = Mock()
        process.poll.return_value = None
        address = ("127.0.0.1", 1234)
        with patch.object(SMOKE.time, "monotonic", return_value=0), \
                patch.object(SMOKE.time, "sleep") as poll, \
                patch.object(SMOKE.socket, "create_connection", side_effect=[
                    ConnectionResetError(), ConnectionRefusedError()
                ]) as connect:
            SMOKE.wait_for_admission_barrier(process, [address])
        self.assertEqual(connect.call_count, 2)
        self.assertEqual(poll.call_count, 1)

    def test_resets_do_not_extend_admission_deadline(self):
        process = Mock()
        process.poll.return_value = None
        with patch.object(SMOKE.time, "monotonic", side_effect=[0, 0, 2]), \
                patch.object(SMOKE.time, "sleep"), \
                patch.object(SMOKE.socket, "create_connection", side_effect=ConnectionResetError()):
            with self.assertRaisesRegex(AssertionError, "listeners still accepting during shutdown"):
                SMOKE.wait_for_admission_barrier(process, [("127.0.0.1", 1234)])


if __name__ == "__main__":
    unittest.main()
