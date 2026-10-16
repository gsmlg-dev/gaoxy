#!/usr/bin/env python3
"""Real adopted-zombie regression; no Gaoxy/browser runtime or injected waits."""
import ctypes
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys

EVIDENCE = Path(__file__).resolve().parent

def load(name):
    path = EVIDENCE / name
    spec = importlib.util.spec_from_file_location(name.replace('.', '_'), path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def group_alive(pid):
    try:
        os.killpg(pid, 0)
        return True
    except ProcessLookupError:
        return False

def run(module, label):
    # The child inherits the Actor's process group and log. Its real stdin EOF
    # on parent exit makes it terminate naturally and become our adopted zombie.
    program = ('import subprocess,sys,json; '
               'child=subprocess.Popen([sys.executable,"-B","-c",'
               '"import sys; sys.stdin.read()"],stdin=subprocess.PIPE); '
               'print(json.dumps(dict(event="child",pid=child.pid)),flush=True)')
    actor = module.Actor([sys.executable, '-B', '-c', program],
                         EVIDENCE / ('browser-reaping-' + label + '.log'))
    child = actor.event('child')['pid']
    actor.join()
    assert actor.process.returncode == 0 and group_alive(actor.process.pid)
    try:
        result = actor.dispose()
    except AssertionError as error:
        assert label == 'red' and str(error) == 'owned process group did not join'
        joined, status = os.waitpid(child, 0)
        assert joined == child and os.waitstatus_to_exitcode(status) == 0
        actor.log.close()
        assert not group_alive(actor.process.pid)
        return dict(status='EXPECTED_RED', parent_exit=0, child_exit=0,
                    child_joined=True, original_group_assertion_failed=True,
                    group_gone_after_test_cleanup=True)
    assert label == 'green' and result['exit'] == 0 and not result['forced']
    assert result['owned_group_gone'] and result['reader_joined']
    assert any(row['pid'] == child and row['exit'] == 0 for row in module.ADOPTED_JOINS)
    assert module.adopted_children() == set()
    return dict(status='PASS', actor=result, adopted_joins=module.ADOPTED_JOINS,
                group_gone=True, no_adopted_children=True)

assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
before = {name: hashlib.sha256((EVIDENCE / name).read_bytes()).hexdigest()
          for name in ('native-worker-browser-runner7.py', 'native-worker-browser-runner8.py')}
red = run(load('native-worker-browser-runner7.py'), 'red')
green = run(load('native-worker-browser-runner8.py'), 'green')
assert all(hashlib.sha256((EVIDENCE / name).read_bytes()).hexdigest() == sha
           for name, sha in before.items())
record = dict(kind='REAL_ADOPTED_ZOMBIE_ACTOR_REGRESSION', status='PASS',
              red=red, green=green, source=before, source_stable=True,
              script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              full_browser='NOT_RUN')
with (EVIDENCE / 'browser-reaping-regression1.json').open('x') as output:
    json.dump(record, output, indent=2)
    output.write('\n')
print(json.dumps(record, indent=2))
