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
SOURCE = E/'command-collector2.py'

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

class CleanupRegression(unittest.TestCase):
    pass


def cleanup_case(filename, scenario):
    def run(self):
        spec = importlib.util.spec_from_file_location('cleanup_regression', E/filename)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        pid, other = 424243, 424244
        if scenario == 'ready':
            censuses = [{pid, other}, set()]
            waits = [(pid, 0), (other, 10), ChildProcessError()]
        elif scenario == 'deadline':
            censuses = [{pid}, {pid}, {pid}]
            waits = [(0, 0), (0, 0)]
        else:
            censuses = [set() if scenario == 'late' else {pid}, {pid}, set()]
            waits = [(0, 0), (pid, 15 if scenario != 'lookup' else 0), ChildProcessError()]
        with contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(module, 'children', side_effect=censuses))
            stack.enter_context(patch.object(module.os, 'waitpid', side_effect=waits))
            stack.enter_context(patch.object(module.os, 'getpgrp', return_value=7))
            group = stack.enter_context(patch.object(module.os, 'getpgid',
                side_effect=ProcessLookupError() if scenario == 'lookup' else None,
                return_value=424245))
            signal = stack.enter_context(patch.object(module.os, 'killpg'))
            if scenario == 'deadline':
                stack.enter_context(patch.object(module.time, 'monotonic', side_effect=[0, 14, 15]))
            result = module.cleanup_descendants()
        self.assertEqual(result['initial'], [] if scenario == 'late' else
                         [pid, other] if scenario == 'ready' else [pid])
        self.assertEqual(result['forced'], scenario != 'ready')
        self.assertEqual(result['remaining'], [pid] if scenario == 'deadline' else [])
        if scenario == 'ready':
            self.assertEqual(result['initial_after_reap'], [])
            self.assertEqual(result['reaped_before_force'], [
                {'pid': pid, 'wait_status': 0, 'phase': 'before_force'},
                {'pid': other, 'wait_status': 10, 'phase': 'before_force'}])
            self.assertEqual(result['signal_attempts'], [])
            group.assert_not_called(); signal.assert_not_called()
        elif scenario == 'lookup':
            self.assertEqual(result['initial_after_reap'], [pid])
            self.assertEqual(result['reaped_before_force'], [])
            self.assertEqual(result['signal_attempts'], [])
            signal.assert_not_called()
            self.assertEqual(result['reaped'], [{'pid': pid, 'wait_status': 0, 'phase': 'after_force'}])
        else:
            self.assertEqual(result['initial_after_reap'], [pid])
            self.assertEqual(result['reaped_before_force'], [])
            expected_signal = 9 if scenario == 'deadline' else 15
            signal.assert_called_once_with(424245, expected_signal)
            self.assertEqual(result['signal_attempts'], [{'pid': pid, 'pgid': 424245,
                'signal': expected_signal, 'outcome': 'syscall_returned_success'}])
    return run


for filename in ('command-collector2.py', 'browser-command-collector2.py'):
    for scenario in ('ready', 'live', 'lookup', 'late', 'deadline'):
        setattr(CleanupRegression, 'test_' + filename.replace('-', '_').replace('.', '_') + '_' + scenario,
                cleanup_case(filename, scenario))


if __name__ == '__main__':
    log = E/'collector-regression2.log'; receipt = E/'collector-regression2.json'
    assert not log.exists() and not receipt.exists()
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    sources = [SOURCE, E/'browser-command-collector2.py']
    before = {path.name: digest(path) for path in sources}
    suite = unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(cls)
                               for cls in (CollectorRegression, CleanupRegression)])
    with log.open('x') as output:
        result = unittest.TextTestRunner(stream=output, verbosity=2).run(suite)
    after = {path.name: digest(path) for path in sources}
    passed = result.wasSuccessful() and result.testsRun > 0 and not result.skipped and before == after
    data = {'kind': 'DETERMINISTIC_READY_REAP_COLLECTOR_REGRESSION',
            'status': 'PASS' if passed else 'FAIL', 'tests': result.testsRun,
            'failures': len(result.failures), 'errors': len(result.errors),
            'skipped': len(result.skipped), 'source_before': before, 'source_after': after,
            'harness_sha256': digest(Path(__file__)),
            'boundary': 'Mocked wait/signal/census controls only; no external child launched/signalled; not protocol/browser acceptance'}
    with receipt.open('x') as output:
        json.dump(data, output, indent=2); output.write('\n')
    print(json.dumps(data)); sys.exit(0 if passed else 1)
