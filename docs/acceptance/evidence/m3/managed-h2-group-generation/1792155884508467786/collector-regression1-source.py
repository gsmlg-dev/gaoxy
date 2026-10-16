import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = ROOT/'docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786'
SOURCE = E/'command-collector1.py'

class FakeProcess:
    pid = 424242
    def __init__(self, timeouts):
        self.timeouts = timeouts
        self.calls = 0
        self.returncode = None
    def wait(self, timeout):
        self.calls += 1
        if self.calls <= self.timeouts:
            raise subprocess.TimeoutExpired(['never-launched'], timeout)
        self.returncode = 0
        return self.returncode
    def poll(self):
        return self.returncode

class CollectorRegression(unittest.TestCase):
    def exercise(self, timeouts, races, expected, wait_error):
        spec = importlib.util.spec_from_file_location('collector_regression', SOURCE)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        process = FakeProcess(timeouts)
        reaped = [{'pid': process.pid, 'wait_status': 2 << 8}] if timeouts == 3 else []
        cleanup = {'forced': False, 'initial': [], 'reaped': reaped, 'remaining': []}
        with tempfile.TemporaryDirectory(prefix='gaoxy-group-collector-regression-') as tmp:
            module.EVIDENCE = Path(tmp)
            with patch.object(module, 'source_manifest', return_value={}), \
                 patch.object(module.subprocess, 'Popen', return_value=process) as spawn, \
                 patch.object(module.subprocess, 'check_output', return_value=''), \
                 patch.object(module.os, 'killpg', side_effect=races) as signal, \
                 patch.object(module, 'cleanup_descendants', return_value=cleanup) as reap, \
                 patch.object(sys, 'argv', ['collector', '--name', 'case', '--kind', 'static', '--timeout', '1', '--', 'never-launched']), \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(module.main(), 1)
                spawn.assert_called_once()
                reap.assert_called_once_with()
                self.assertEqual(signal.call_count, len(races))
            receipt = json.loads((Path(tmp)/'case.json').read_text())
            self.assertEqual(receipt['verdict'], 'FAIL')
            self.assertEqual(receipt['actual_exit'], expected)
            self.assertEqual(receipt['process_joined'], True)
            self.assertEqual(receipt['forced'], True)
            self.assertEqual(receipt['source_stable'], True)
            self.assertEqual(receipt['descendant_cleanup'], cleanup)
            self.assertEqual(receipt['process_group_remaining'], [])
            self.assertEqual(receipt['wait_error'] is not None, wait_error)
    def test_term_process_lookup_race_still_joins_and_records_failure(self):
        self.exercise(1, [ProcessLookupError()], 0, False)
    def test_kill_process_lookup_race_still_joins_and_records_failure(self):
        self.exercise(2, [None, ProcessLookupError()], 0, False)
    def test_final_wait_failure_runs_cleanup_and_reconciles_reaped_exit(self):
        self.exercise(3, [None, None], 2, True)

if __name__ == '__main__':
    log = E/'collector-regression1.log'; receipt = E/'collector-regression1.json'
    assert not log.exists() and not receipt.exists()
    before = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    with log.open('x') as output:
        result = unittest.TextTestRunner(stream=output, verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(CollectorRegression))
    data = {'kind':'DETERMINISTIC_COLLECTOR_REGRESSION','status':'PASS' if result.wasSuccessful() else 'FAIL','tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'skipped':len(result.skipped),'source_before':before,'source_after':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'harness_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'boundary':'Mocked command wait/signal/cleanup services only; no external child launched or signalled; not protocol/browser acceptance'}
    receipt.write_text(json.dumps(data,indent=2)+'\n'); print(json.dumps(data)); sys.exit(0 if result.wasSuccessful() else 1)
