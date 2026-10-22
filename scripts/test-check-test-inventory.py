#!/usr/bin/env python3
"""Inventory regressions use only temporary source trees and Python manifests."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

CHECKER = Path(__file__).with_name('check-test-inventory.py').resolve()


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'scripts').mkdir()
        self.path = 'apps/example/test/options_test.exs'
        self.source(self.path, unit=True)
        self.suites = {'unit': [(self.path, 1)], 'component': [], 'protocol': []}
        self.retained = []

    def source(self, path, unit=False):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('defmodule OptionsTest do\n  use ExUnit.Case\n' +
                          ('  @moduletag :unit\n' if unit else '') +
                          '  test "options", do: assert true\nend\n')

    def check(self, ok, message=''):
        manifest = self.root / 'manifest.py'
        manifest.write_text('SUITES = ' + repr(self.suites) + '\n')
        (self.root / 'scripts/test-inventory.json').write_text(json.dumps({'retained': self.retained}))
        result = subprocess.run([sys.executable, str(CHECKER), '--root', str(self.root),
                                 '--manifest', str(manifest)], capture_output=True, text=True)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode == 0, ok, output)
        self.assertIn(message, output)

    def test_valid_explicit_retention(self):
        self.source('apps/example/test/specialist_test.exs')
        self.retained = [{'path': 'apps/example/test/specialist_test.exs', 'reason': 'Dedicated pressure environment',
                          'disposition': 'specialist_deferred'}]
        self.check(True, 'INVENTORY_PASS')

    def test_retention_requires_known_disposition(self):
        self.source('apps/example/test/retained_test.exs')
        for disposition in (None, 'skip', ''):
            self.retained = [{'path': 'apps/example/test/retained_test.exs', 'reason': 'Outside current selection',
                              'disposition': disposition}]
            self.check(False, 'disposition')

    def test_valid_existing_unscheduled_retention(self):
        self.source('apps/example/test/retained_test.exs')
        self.retained = [{'path': 'apps/example/test/retained_test.exs', 'reason': 'Outside current selection',
                          'disposition': 'existing_not_scheduled'}]
        self.check(True, 'INVENTORY_PASS')

    def test_unknown_file(self):
        self.source('apps/example/test/new_test.exs')
        self.check(False, 'unknown')

    def test_missing_active_file(self):
        (self.root / self.path).unlink()
        self.check(False, 'missing')

    def test_duplicate_active_ownership(self):
        self.suites['component'].append((self.path, 1))
        self.check(False, 'duplicate')

    def test_duplicate_within_suite(self):
        self.suites['unit'].append((self.path, 1))
        self.check(False, 'duplicate')

    def test_active_retained_overlap(self):
        self.retained = [{'path': self.path, 'reason': 'retained'}]
        self.check(False, 'overlap')

    def test_wildcard_retention(self):
        self.retained = [{'path': 'apps/**/test/*_test.exs', 'reason': 'retained'}]
        self.check(False, 'wildcard')

    def test_nonpositive_count(self):
        for count in (0, -1, True):
            self.suites['unit'] = [(self.path, count)]
            self.check(False, 'positive')

    def test_unit_requires_declaration(self):
        self.source(self.path)
        self.check(False, 'unit declaration')

    def test_nonunit_cannot_declare_unit(self):
        self.suites['component'] = self.suites.pop('unit')
        self.suites['unit'] = []
        self.check(False, 'unit declaration')

    def test_missing_retained_file(self):
        self.retained = [{'path': 'apps/example/test/absent_test.exs', 'reason': 'retained'}]
        self.check(False, 'missing')

    def test_retention_requires_reason(self):
        self.source('apps/example/test/retained_test.exs')
        self.retained = [{'path': 'apps/example/test/retained_test.exs', 'reason': ''}]
        self.check(False, 'reason')


if __name__ == '__main__':
    unittest.main()
