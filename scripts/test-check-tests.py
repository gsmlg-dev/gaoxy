#!/usr/bin/env python3
"""Process-level regressions for nonempty ExUnit acceptance checks."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

WRAPPER = Path(__file__).with_name("check-tests.py")


class NonemptySuiteTest(unittest.TestCase):
    def run_wrapper(self, output, mix_status=0):
        with tempfile.TemporaryDirectory(prefix="gaoxy-test-counter-") as directory:
            executable = Path(directory, "mix")
            executable.write_text(
                "#!/usr/bin/env python3\nimport os, sys\n"
                "print(os.environ['FAKE_MIX_OUTPUT'])\n"
                "sys.exit(int(os.environ['FAKE_MIX_STATUS']))\n"
            )
            executable.chmod(0o700)
            environment = dict(
                os.environ,
                PATH=directory + os.pathsep + os.environ["PATH"],
                FAKE_MIX_OUTPUT=output,
                FAKE_MIX_STATUS=str(mix_status),
            )
            return subprocess.run(
                ["python3", str(WRAPPER)], env=environment, capture_output=True,
                text=True, timeout=5,
            )

    def test_all_excluded_elixir_118_fails(self):
        result = self.run_wrapper("5 tests, 0 failures, 5 excluded")
        self.assertEqual(result.returncode, 1)
        self.assertIn("zero executed tests", result.stderr)

    def test_zero_numerator_elixir_120_fails(self):
        result = self.run_wrapper("Result: 0/5 passed (5 excluded)")
        self.assertEqual(result.returncode, 1)
        self.assertIn("zero executed tests", result.stderr)

    def test_empty_umbrella_suites_fail(self):
        result = self.run_wrapper("2 tests, 0 failures, 2 excluded\n0 tests, 0 failures")
        self.assertEqual(result.returncode, 1)

    def test_all_skipped_elixir_118_fails(self):
        for output in ["5 tests, 0 failures, 5 skipped",
                       "5 tests, 0 failures, 1 skipped, 4 excluded"]:
            with self.subTest(output=output):
                self.assertEqual(self.run_wrapper(output).returncode, 1)

    def test_nonempty_elixir_118_succeeds(self):
        self.assertEqual(self.run_wrapper("5 tests, 0 failures, 4 excluded").returncode, 0)

    def test_nonempty_elixir_120_succeeds(self):
        for output in ["Result: 1/5 passed (4 excluded)", "Result: 1 passed"]:
            with self.subTest(output=output):
                self.assertEqual(self.run_wrapper(output).returncode, 0)

    def test_nonempty_umbrella_suites_succeed(self):
        result = self.run_wrapper("2 tests, 0 failures, 2 excluded\n1 test, 0 failures")
        self.assertEqual(result.returncode, 0)

    def test_mix_failure_status_is_preserved(self):
        result = self.run_wrapper("5 tests, 1 failure", mix_status=2)
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
