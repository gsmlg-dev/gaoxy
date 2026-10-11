"""Bookkeeping-only regressions: AST extraction never runs collector launch code."""
import ast
import contextlib
import datetime
import hashlib
import inspect
import io
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile
import time
import unittest

SOURCE = Path(sys.argv.pop(1)).read_text()
PARSED = ast.parse(SOURCE)


def namespace(root):
    ns = dict(Path=Path, datetime=datetime, hashlib=hashlib, json=json, os=os,
              re=re, stat=stat, time=time, ROOT=root, OUT=root / 'out',
              __file__=str(root / 'collector.py'))
    # Only definitions of file bookkeeping and the hash lambda are executed.
    nodes = [n for n in PARSED.body if
             isinstance(n, ast.FunctionDef) and n.name in {'save', 'tree'} or
             isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'sha' for t in n.targets)]
    exec(compile(ast.Module(body=nodes, type_ignores=[]), '<bookkeeping>', 'exec'), ns)
    return ns


def inventory(ns, path):
    kwargs = {'owned': True} if 'owned' in inspect.signature(ns['tree']).parameters else {}
    return ns['tree'](path, **kwargs)


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ns = namespace(self.root)
        self.home = self.root / 'tools' / '.hex'
        self.home.mkdir(parents=True)

    def changed(self, action):
        before = inventory(self.ns, self.home)
        action()
        after = inventory(self.ns, self.home)
        self.assertNotEqual(before, after)

    def test_unchanged_empty_inventory(self):
        self.assertEqual(inventory(self.ns, self.home), inventory(self.ns, self.home))

    def test_hex_empty_directory_addition(self):
        self.changed(lambda: (self.home / 'unexpected').mkdir())
        self.assertTrue((self.home / 'unexpected').is_dir())

    def test_mix_empty_directory_addition(self):
        self.home = self.root / 'tools' / '.mix'
        self.home.mkdir()
        (self.home / 'hex.app').write_text('frozen')
        self.changed(lambda: (self.home / 'unexpected').mkdir())

    def test_empty_directory_symlink_addition(self):
        external = self.root / 'external'
        external.mkdir()
        self.changed(lambda: (self.home / 'leak').symlink_to(external, target_is_directory=True))

    def test_root_symlink_replacement(self):
        external = self.root / 'external'
        external.mkdir()
        def replace():
            self.home.rename(self.home.with_name('preserved'))
            self.home.symlink_to(external, target_is_directory=True)
        self.changed(replace)

    def test_root_real_directory_replacement(self):
        def replace():
            self.home.rename(self.home.with_name('preserved'))
            self.home.mkdir()
        self.changed(replace)

    def test_ancestor_symlink_replacement(self):
        def replace():
            self.home.parent.rename(self.root / 'preserved-tools')
            self.home.parent.symlink_to(self.root / 'preserved-tools', target_is_directory=True)
        self.changed(replace)

    def test_dangling_symlink_retained(self):
        self.changed(lambda: (self.home / 'dangling').symlink_to(self.root / 'absent'))

    def test_special_file_addition(self):
        self.changed(lambda: os.mkfifo(self.home / 'unexpected-fifo'))

    def test_file_hash_change(self):
        path = self.home / 'file'
        path.write_text('before')
        self.changed(lambda: path.write_text('after'))

    def test_file_type_change(self):
        path = self.home / 'file'
        path.write_text('before')
        def replace():
            path.rename(self.root / 'preserved-file')
            path.mkdir()
        self.changed(replace)


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        ns = self.ns = namespace(root)
        ns['OUT'].mkdir()
        Path(ns['__file__']).write_text('frozen collector')
        for rel in ['deps', '_build/test', '.mix', '.hex']:
            (root / rel).mkdir(parents=True)
        log = ns['OUT'] / 'case.log'
        log.write_text('TLS95_OK {"ok": true}\n')
        before = {ns['__file__']: ns['sha'](ns['__file__'])}
        def protected():
            current = {ns['__file__']: ns['sha'](ns['__file__'])}
            assert current == before, 'Reviewed input changed'
            return current
        ns.update(root=root, name='case', mode='candidate', before=before,
                  protected=protected, peers=lambda: [], peer_before=[],
                  mix_home=root / '.mix', hex_home=root / '.hex', tool_sources={},
                  tool_copy=inventory(ns, root / '.mix'), hex_before=inventory(ns, root / '.hex'),
                  disk_before=ns['tree'](root / '_build/test'), source_before=ns['tree'](root / 'deps'),
                  command=['synthetic-already-finished'], started='2026-10-11T00:00:00+00:00',
                  timer=time.monotonic(), timeout=450, code=27, timed_out=False,
                  log=log, reviewed={'review_verdict': 'PASS',
                      'files': {'.audit/m3-tls95-collector.py': before[ns['__file__']]}})
        outer = next(n for n in PARSED.body if isinstance(n, ast.FunctionDef) and n.name == 'outer')
        start = next(i for i, n in enumerate(outer.body) if isinstance(n, ast.Assign) and
                     any(isinstance(t, ast.Name) and t.id == 'post_errors' for t in n.targets))
        body = outer.body[start:]
        # Extraction begins after the command has terminated; no process calls exist.
        self.assertFalse(any(isinstance(n, ast.Name) and n.id == 'subprocess'
                             for statement in body for n in ast.walk(statement)))
        function = ast.FunctionDef(name='post_only', args=ast.arguments(posonlyargs=[], args=[],
            kwonlyargs=[], kw_defaults=[], defaults=[]), body=body, decorator_list=[])
        module = ast.fix_missing_locations(ast.Module(body=[function], type_ignores=[]))
        exec(compile(module, '<post-only>', 'exec'), ns)

    def run_post(self):
        with contextlib.redirect_stdout(io.StringIO()):
            try:
                return self.ns['post_only'](), None
            except BaseException as error:
                return None, error

    def receipt(self):
        return json.loads((self.ns['OUT'] / 'case.json').read_text())

    def check_failure(self, label):
        _, error = self.run_post()
        self.assertIsNotNone(error)
        receipt = self.receipt()
        self.assertEqual(receipt['exit'], 27)
        self.assertIn(label, receipt['post_collection_errors'])
        self.assertEqual(json.loads((self.ns['OUT'] / 'case-command-exit.json').read_text())['exit'], 27)
        return receipt

    def test_missing_collector_still_receipts_primary_exit(self):
        Path(self.ns['__file__']).unlink()
        receipt = self.check_failure('collector_sha256')
        self.assertIn('protected', receipt['post_collection_errors'])
        self.assertIsNone(receipt['collector_sha256'])

    def test_changed_protected_input_retains_log(self):
        raw = self.ns['log'].read_bytes()
        Path(self.ns['__file__']).write_text('drift')
        self.check_failure('protected')
        self.assertEqual(self.ns['log'].read_bytes(), raw)

    def test_changed_collector_fails_independently_of_protected(self):
        self.ns['protected'] = lambda: self.ns['before']
        Path(self.ns['__file__']).write_text('drift')
        _, error = self.run_post()
        self.assertIsNotNone(error)
        self.assertFalse(self.receipt()['collector_sha256_match'])

    def test_zero_exit_preserved(self):
        self.ns['code'] = 0
        result, error = self.run_post()
        self.assertIsNone(error)
        self.assertEqual(result, 0)
        self.assertEqual(self.receipt()['exit'], 0)

    def test_timeout_signal_exit_preserved(self):
        self.ns.update(code=-15, timed_out=True)
        result, error = self.run_post()
        self.assertIsNone(error)
        self.assertEqual(result, -15)
        self.assertEqual(self.receipt()['status'], 'FAIL_TIMEOUT')

    def test_missing_log_still_receipts_primary_exit(self):
        self.ns['log'].unlink()
        self.check_failure('log_text')

    def test_malformed_record_still_receipts_primary_exit(self):
        self.ns['log'].write_text('TLS95_BROKEN {invalid}\nTLS95_OK {"ok": true}\n')
        receipt = self.check_failure('record_parse')
        self.assertEqual(receipt['record_counts'].get('TLS95_OK'), 1)

    def fail_write(self, suffix):
        save = self.ns['save']
        def failing_save(path, value):
            if str(path).endswith(suffix):
                raise OSError('injected write failure: '+suffix)
            return save(path, value)
        self.ns['save'] = failing_save

    def test_source_sidecar_write_failure_still_final_receipt(self):
        self.fail_write('-source-after.json')
        self.check_failure('source_after_receipt')

    def test_primary_sidecar_write_failure_still_final_receipt(self):
        self.fail_write('-command-exit.json')
        _, error = self.run_post()
        self.assertIsNotNone(error)
        receipt = self.receipt()
        self.assertEqual(receipt['exit'], 27)
        self.assertIn('command_exit_receipt', receipt['post_collection_errors'])

    def test_final_write_failure_preserves_primary_sidecar(self):
        self.fail_write('/case.json')
        _, error = self.run_post()
        self.assertIsNotNone(error)
        primary = json.loads((self.ns['OUT'] / 'case-command-exit.json').read_text())
        self.assertEqual(primary['exit'], 27)

    def test_post_timing_failure_still_final_receipt(self):
        class Clock:
            @staticmethod
            def monotonic():
                raise ValueError('injected clock failure')
        self.ns['time'] = Clock
        self.check_failure('elapsed_seconds')

    def test_existing_sidecar_never_overwritten(self):
        path = self.ns['OUT'] / 'case-source-after.json'
        path.write_text('prior evidence')
        self.check_failure('source_after_receipt')
        self.assertEqual(path.read_text(), 'prior evidence')

    def test_success_and_nonzero_command_outcomes(self):
        result, error = self.run_post()
        self.assertIsNone(error)
        self.assertEqual(result, 27)
        self.assertEqual(self.receipt()['post_collection_errors'], {})

    def test_owned_drift_preserves_failure_inventory(self):
        (self.ns['hex_home'] / 'unknown-empty').mkdir()
        _, error = self.run_post()
        self.assertIsNotNone(error)
        receipt = self.receipt()
        self.assertFalse(receipt['hex_inventory_match'])
        self.assertIn(str(self.ns['hex_home'] / 'unknown-empty'), receipt['hex_inventory_after'])
        self.assertTrue((self.ns['hex_home'] / 'unknown-empty').is_dir())


if __name__ == '__main__':
    unittest.main(verbosity=2)
