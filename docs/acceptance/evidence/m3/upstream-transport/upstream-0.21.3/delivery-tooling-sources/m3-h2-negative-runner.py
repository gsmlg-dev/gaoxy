import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time

root = Path.cwd().resolve()
out = root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.3'
manifest = json.loads((root / '.audit/m3-transport/h2-failure-regressions/manifest.json').read_text())
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path, value):
    with path.open('x') as stream:
        stream.write(json.dumps(value, indent=2, sort_keys=True) + '\n')
def members(group):
    rows = []
    for path in Path('/proc').iterdir():
        if path.name.isdigit():
            try:
                stat = (path / 'stat').read_text().rsplit(') ', 1)[1].split()
                if int(stat[2]) == group:
                    rows.append({'pid': int(path.name), 'state': stat[0], 'start_ticks': stat[19]})
            except (FileNotFoundError, ProcessLookupError):
                pass
    return sorted(rows, key=lambda row: row['pid'])
eval_code = ('IO.puts("H2_NEGATIVE_VM_IDENTITY " <> JSON.encode!(%{vm_os_pid: System.pid()})); '
             'Code.require_file(".audit/m3-transport/tls95-runtime-identity.exs")')
order = ['prerepair-acquired-manual', 'prerepair-acquired-follow',
         'repair1-acquired-manual', 'repair1-acquired-follow', 'repair1-lost-alias-follow']
for key in order:
    probe, = [probe for probe in manifest['probes'] if probe['name'] == key]
    name = 'h2-negative-' + key + '1'
    inputs_path = root / '.audit/m3-transport' / (name + '-inputs.json')
    inputs = json.loads(inputs_path.read_text())
    before = {path: sha(path) for path in inputs}
    assert before == inputs
    save(out / (name + '-parent-inputs-before.json'), before)
    evidence = out / (name + '-artifacts')
    environment = {
        'MIX_HOME': str(root / '.audit/m3-transport/tls95-candidate-tools/.mix'),
        'HEX_HOME': str(root / '.audit/m3-transport/tls95-candidate-tools/.hex'),
        'HEX_OFFLINE': '1', 'MIX_BUILD_PATH': str(root / '_build/test'),
        'MIX_DEPS_PATH': str(root / 'deps'), 'PYTHONNOUSERSITE': '1', 'PYTHONPATH': '',
        'TLS95_COHORT_VERSION': '0.21.3', 'TLS95_COHORT_ROOT': str(root),
        'TLS95_PARENT_ROOT': str(root), 'HTTP_FETCH_TLS95_DRIVER': probe['source']['path'],
        'HTTP_FETCH_TLS95_INPUTS': str(inputs_path)}
    command = ['nix', 'develop', '--offline', '--command', 'env']
    command += [key + '=' + value for key, value in environment.items()]
    command += ['unbuffer', 'mix', 'run', '--no-compile', '--no-start', '--eval', eval_code,
                '--', '--evidence', str(evidence)]
    argv = ['python3', '.audit/m3-qualified-collector.py', '--lane', 'h2', '--timeout', '600',
            '--sol-repairs', '1', '--sol-unsuccessful', '0', '--astra-rounds', '0', name, '--', *command]
    group = vm = None
    owned_before = []
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    deadline = time.monotonic() + 650
    with (out / (name + '-parent-collector.log')).open('xb') as output:
        process = subprocess.Popen(argv, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            while process.poll() is None:
                if vm is None and (out / (name + '.log')).exists():
                    with (out / (name + '.log')).open('rb') as stream:
                        prefix = stream.read(16384).decode(errors='replace')
                    match = re.search(r'H2_NEGATIVE_VM_IDENTITY (\{[^\n]+\})', prefix)
                    if match:
                        vm = int(json.loads(match.group(1))['vm_os_pid'])
                        group = os.getpgid(vm)
                        owned_before = members(group)
                assert time.monotonic() < deadline, 'Parent collector outer deadline exceeded'
                time.sleep(0.05)  # Bounded OS-ownership polling, never a peer/test synchronization oracle.
            collector_exit = process.wait()
        finally:
            if process.poll() is None:
                for owned_group in [group, process.pid]:
                    if owned_group:
                        try:
                            os.killpg(owned_group, signal.SIGTERM)
                        except ProcessLookupError:
                            pass
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    for owned_group in [group, process.pid]:
                        if owned_group:
                            try:
                                os.killpg(owned_group, signal.SIGKILL)
                            except ProcessLookupError:
                                pass
                    process.wait(timeout=5)
    # Preserve actual parent termination before interpreting any case results.
    after = {path: sha(path) for path in inputs}
    save(out / (name + '-parent-inputs-after.json'), after)
    ownership = {'started_utc': started, 'completed_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                 'argv': argv, 'collector_exit': collector_exit, 'vm_os_pid': vm, 'vm_process_group': group,
                 'group_members_observed': owned_before, 'group_members_after': members(group) if group else None,
                 'vm_proc_after_exists': (Path('/proc') / str(vm)).exists() if vm else None,
                 'parent_inputs_match': before == after, 'parent_frozen_inputs': len(inputs),
                 'manifest_sha256': sha(inputs_path), 'runner_sha256': sha(Path(__file__)),
                 'wrapper_post_identity': 'NOT_RUN_EXPECTED_SYSTEM_HALT',
                 'fixture_result': 'NOT_YET_INTERPRETED'}
    save(out / (name + '-parent-ownership.json'), ownership)
    assert collector_exit == 0 and vm and group and owned_before
    assert not ownership['group_members_after'] and not ownership['vm_proc_after_exists']
    assert before == after
    receipt = json.loads((out / (name + '.json')).read_text())
    assert receipt['exit'] == 1 and not receipt['timed_out'] and receipt['inputs_match']
    assert not receipt['owned_peer_processes_before'] and not receipt['owned_peer_processes_after']
    print(name, 'actual VM exit1; group joined; all', len(inputs), 'parent inputs unchanged', flush=True)
