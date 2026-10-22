#!/usr/bin/env python3
"""Regression checks for the repair gate's execution accounting."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("repair_gate", Path(__file__).with_name("check-repairs.py"))
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class ExecutionAccounting(unittest.TestCase):
    def test_counts_nonempty_umbrella_summaries(self):
        self.assertEqual(gate.executed("2 tests, 0 failures\n1 test, 0 failures\n"), 3)

    def test_counts_elixir_120_summaries(self):
        self.assertEqual(gate.executed("Result: 2 passed\nResult: 1/1 passed\n"), 3)

    def test_rejects_elixir_120_incomplete_execution(self):
        for output in ("Result: 0 passed", "Result: 1/2 passed (1 excluded)",
                       "Result: 1/2 passed (1 skipped)", "Result: 1/2 passed (1 failure)"):
            with self.assertRaises(ValueError):
                gate.executed(output)

    def test_rejects_empty_or_missing_execution(self):
        for output in ("", "0 tests, 0 failures", "No tests to run"):
            with self.assertRaises(ValueError):
                gate.executed(output)

    def test_rejects_failed_skipped_or_excluded_contracts(self):
        for output in ("2 tests, 1 failure", "2 tests, 0 failures, 1 excluded",
                       "2 tests, 0 failures, 1 skipped"):
            with self.assertRaises(ValueError):
                gate.executed(output)

    def test_canonical_selectors_have_one_owner_per_path(self):
        self.assertEqual(set(gate.SUITES), {"unit", "component", "protocol"})
        paths = [path for entries in gate.SUITES.values() for path, _ in entries]
        self.assertEqual(len(paths), len(set(paths)))
        self.assertEqual(list(gate.selected_entries("all")),
                         [entry for entries in gate.SUITES.values() for entry in entries])

    def test_all_deduplicates_paths(self):
        from unittest.mock import patch
        with patch.object(gate, "SUITES", {"unit": [("same", 1)], "component": [("same", 1)], "protocol": []}):
            self.assertEqual(list(gate.selected_entries("all")), [("same", 1)])

    def test_legacy_selectors_are_removed(self):
        self.assertNotIn("test_helpers", gate.SUITES)
        self.assertNotIn("composition", gate.SUITES)
        self.assertFalse(hasattr(gate, "ALIASES"))

    def test_manifest_files_exist_and_have_positive_counts(self):
        for cases in gate.SUITES.values():
            for path, count in cases:
                self.assertTrue((gate.ROOT / path).is_file(), path)
                self.assertGreater(count, 0)


if __name__ == "__main__":
    unittest.main()
