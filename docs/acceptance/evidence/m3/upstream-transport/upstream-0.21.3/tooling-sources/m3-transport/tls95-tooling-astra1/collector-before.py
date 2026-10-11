"""Serialized, receipted sanitized build/runtime launcher; immutable failure logs."""
from pathlib import Path
import datetime
import hashlib
import json
import os
import re
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.2'
BASELINE = ROOT / '.audit/m3-transport/tls95-baseline-0.21.1'
PYTHON = '/tmp/gaoxy-m3-h2-soak-venv/bin/python'
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(path, value):
    with Path(path).open('x') as output:
        output.write(json.dumps(value, indent=2, sort_keys=True)+'\n')

def tree(path):
    result = {}
    if path.exists():
        for p in sorted(path.rglob('*')):
            if p.is_file():
                result[str(p)] = {'real': str(p.resolve(strict=True)), 'sha256': sha(p)}
            elif p.is_symlink():
                p.resolve(strict=True)
    return result

def protected():
    old = json.loads((ROOT / '.audit/m3-transport/upstream-0.21.2/installed-0.21.1-freeze.json').read_text())
    assert len(old['sha256']) == 196
    expected = json.loads((OUT / 'tls-registration-inventory.json').read_text())['input_sha256']
    expected.update(json.loads((ROOT / '.audit/m3-transport/tls95-fixture-inputs.json').read_text()))
    for p, value in expected.items():
        assert sha(ROOT / p) == value, 'Reviewed input changed: '+p
    paths = set(expected)
    paths.update(json.loads((OUT / 'compatibility-source-after.json').read_text()))
    for base in [ROOT / '.audit/m3-transport/upstream-0.21.1/packages',
                 ROOT / '.audit/m3-transport/upstream-0.21.2/packages',
                 ROOT / '.audit/m3-transport/installed-0.21.1-preserved',
                 ROOT / 'config']:
        paths.update(str(p) for p in base.rglob('*') if p.is_file())
    paths.update(['mix.exs', 'mix.lock', 'flake.nix', 'flake.lock'])
    return {str(ROOT / p): sha(ROOT / p) for p in sorted(paths)}

def peers():
    return [line.strip() for line in subprocess.check_output(['ps', '-eo', 'pid=,ppid=,args='], text=True).splitlines()
            if re.search(r'(?:^|/| )managed_tls_tracking_peer\.py(?: |$)', line)]

def install_tools(root, mode):
    target = root / '.mix' if mode != 'candidate' else ROOT / '.audit/m3-transport/tls95-candidate-tools/.mix'
    hex_home = target.parent / '.hex' if mode == 'candidate' else root / '.hex'
    source = Path('/home/gao/.local/share/mix/archives/hex-2.4.2-otp-27')
    assert source.is_dir() and not source.is_symlink()
    expected = {}
    for p in source.rglob('*'):
        assert not p.is_symlink()
        if p.is_file():
            expected['archives/hex-2.4.2-otp-27/'+str(p.relative_to(source))] = p
    assert expected and any(p.name == 'hex.app' for p in expected.values())
    frozen_tools = json.loads((ROOT / '.audit/m3-transport/tls95-build-tool-inputs.json').read_text())['files']
    assert {str(p): sha(p) for p in expected.values()} == frozen_tools, 'Cached compiler archive drifted'
    for directory in [target, hex_home]:
        for ancestor in [directory, *directory.parents]:
            assert not ancestor.is_symlink(), str(ancestor)
            if ancestor == ROOT:
                break
        assert directory.resolve().is_relative_to(root if mode != 'candidate' else ROOT / '.audit/m3-transport/tls95-candidate-tools')
    allowed_dirs = {str(parent) for rel in expected for parent in Path(rel).parents if str(parent) != '.'}
    if target.exists():
        for p in target.rglob('*'):
            assert not p.is_symlink()
            rel = str(p.relative_to(target))
            if p.is_file():
                assert rel in expected and p.read_bytes() == expected[rel].read_bytes()
            else:
                assert p.is_dir() and rel in allowed_dirs, 'Unlisted Mix tool directory: '+rel
    if hex_home.exists():
        assert hex_home.is_dir() and list(hex_home.iterdir()) == [], 'Stale Hex home; preserve and diagnose'
    if mode == 'candidate' and target.parent.exists():
        assert set(p.name for p in target.parent.iterdir()).issubset({'.mix', '.hex'})
    for rel, p in expected.items():
        destination = target / rel
        for ancestor in [destination, *destination.parents]:
            assert not ancestor.is_symlink()
            if ancestor == ROOT:
                break
        destination.parent.mkdir(parents=True, exist_ok=True)
        if not destination.exists():
            destination.write_bytes(p.read_bytes())
    hex_home.mkdir(exist_ok=True)
    return target, hex_home, frozen_tools, tree(target)

def profile(name, phase):
    result = subprocess.run([PYTHON, str(ROOT / '.audit/m3-tls95-native-profile.py')],
                            capture_output=True, text=True, timeout=90, check=True)
    value = json.loads(result.stdout)
    value['sanitized_environment'] = dict(sorted(os.environ.items()))
    value['cwd'] = os.getcwd()
    save(OUT / f'{name}-environment-{phase}.json', value)
    return value

def inner(name, mode):
    before = profile(name, 'before')
    if mode == 'build':
        commands = [['unbuffer', 'mix', 'deps.compile'], ['unbuffer', 'mix', 'compile', '--warnings-as-errors']]
    else:
        commands = [['unbuffer', 'mix', 'run', '--no-compile', '--no-start',
                     str(ROOT / '.audit/m3-transport/tls95-runtime-identity.exs')]]
        if mode == 'baseline':
            commands[0].extend(['--cases', 'inventory'])
    outcomes = []
    post_error = None
    try:
        for command in commands:
            code = subprocess.run(command).returncode
            outcomes.append({'argv': command, 'exit': code})
            if code:
                break
    finally:
        try:
            after = profile(name, 'after')
            assert before == after, 'Pinned Python/tool/native/environment identity changed'
        except BaseException as error:
            post_error = repr(error)
        save(OUT / f'{name}-inner.json', {'commands': outcomes,
             'immutable_environment_matches': post_error is None, 'post_environment_error': post_error})
    primary_exit = outcomes[-1]['exit'] if outcomes else 1
    return primary_exit if primary_exit else int(post_error is not None)

def outer(name, mode):
    assert mode in ['build', 'baseline', 'candidate']
    assert re.fullmatch(r'[a-z0-9-]+', name)
    assert not any(OUT.glob(name+'.*')) and not any(OUT.glob(name+'-*')), 'Never reuse any partial evidence name'
    reviewed = json.loads((ROOT / '.audit/m3-transport/tls95-tooling-verified-inputs.json').read_text())
    for p, expected in reviewed['files'].items():
        assert sha(ROOT / p) == expected, 'Independent tooling input drift: '+p
    assert reviewed['review_verdict'] == 'PASS'
    root = ROOT if mode == 'candidate' else BASELINE
    before = protected()
    mix_home, hex_home, tool_sources, tool_copy = install_tools(root, mode)
    hex_before = tree(hex_home)
    save(OUT / f'{name}-mix-tool-copy.json', {'source': tool_sources, 'copy': tool_copy,
         'hex_home': str(hex_home), 'hex_inventory': hex_before})
    disk_before = tree(root / '_build/test')
    source_before = tree(root / 'packages') if mode != 'candidate' else tree(ROOT / 'deps')
    save(OUT / f'{name}-source-before.json', {'protected': before, 'source_tree': source_before, 'build_tree': disk_before})
    peer_before = peers()
    assert peer_before == [], 'Existing peer must be resolved before launching another VM'
    shell = '''set -eu
tls95_root="$1"
tls95_parent="$2"
tls95_mix="$3"
tls95_hex="$4"
tls95_version="$5"
tls95_name="$6"
tls95_mode="$7"
exec env -i PATH="$PATH" HOME="$HOME" LANG=C.UTF-8 LC_ALL=C.UTF-8 \
 LD_LIBRARY_PATH="${LD_LIBRARY_PATH-}" ERL_FLAGS="+S 2:2" MIX_ENV=test \
 MIX_BUILD_PATH="$tls95_root/_build/test" MIX_DEPS_PATH="$tls95_root/deps" \
 MIX_HOME="$tls95_mix" HEX_HOME="$tls95_hex" HEX_OFFLINE=1 \
 PYTHONNOUSERSITE=1 PYTHONPATH= PYTHONDONTWRITEBYTECODE=1 \
 HTTP_FETCH_PEER_PYTHON=/tmp/gaoxy-m3-h2-soak-venv/bin/python \
 HTTP_FETCH_TLS95_DRIVER="$tls95_parent/integration/http_fetch_contract/managed_tls_tracking_probe.exs" \
 HTTP_FETCH_TLS95_INPUTS="$tls95_parent/.audit/m3-transport/tls95-fixture-inputs.json" \
 TLS95_COHORT_VERSION="$tls95_version" TLS95_COHORT_ROOT="$tls95_root" TLS95_PARENT_ROOT="$tls95_parent" \
 python3 "$tls95_parent/.audit/m3-tls95-collector.py" --inner "$tls95_name" "$tls95_mode"
'''
    command = ['nix', 'develop', '--offline', str(ROOT), '--command', 'bash', '-c', shell,
               'tls95', str(root), str(ROOT), str(mix_home), str(hex_home),
               '0.21.2' if mode == 'candidate' else '0.21.1', name, mode]
    timeout = 180 if mode == 'build' else 450
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    timer = time.monotonic(); timed_out = False
    log = OUT / f'{name}.log'
    with log.open('xb') as output:
        process = subprocess.Popen(command, cwd=root, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True; os.killpg(process.pid, signal.SIGTERM)
            try:
                code = process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL); code = process.wait(timeout=5)
    post_errors = {}
    def collect(label, operation):
        try:
            return operation()
        except BaseException as error:
            post_errors[label] = repr(error)
            return None
    after = collect('protected', protected)
    disk_after = collect('build_tree', lambda: tree(root / '_build/test'))
    source_after = collect('source_tree', lambda: tree(root / 'packages') if mode != 'candidate' else tree(ROOT / 'deps'))
    save(OUT / f'{name}-source-after.json', {'protected': after, 'source_tree': source_after, 'build_tree': disk_after})
    text = re.sub(r'\x1b\[[0-9;]*m', '', log.read_text(errors='replace'))
    records = {}
    for line in text.splitlines():
        if line.startswith('TLS95_') and ' ' in line:
            key, value = line.split(' ', 1)
            if value.startswith('{'):
                try:
                    records.setdefault(key, []).append(json.loads(value))
                except BaseException as error:
                    post_errors.setdefault('record_parse', []).append(repr(error))
    peer_after = collect('peer_inventory', peers)
    tool_after = collect('tool_copy', lambda: tree(mix_home))
    hex_after = collect('hex_inventory', lambda: tree(hex_home))
    tool_source_after = collect('tool_sources', lambda: {p: sha(p) for p in tool_sources})
    receipt = {'status': 'COMMAND_FINISHED' if not timed_out else 'FAIL_TIMEOUT', 'mode': mode,
               'argv': command, 'cwd': str(root), 'started_utc': started,
               'completed_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'elapsed_seconds': round(time.monotonic()-timer, 3), 'timeout_seconds': timeout,
               'exit': code, 'timed_out': timed_out, 'log': log.name, 'log_sha256': sha(log),
               'protected_inputs_match': before == after, 'source_tree_match': source_before == source_after,
               'build_tree_match': disk_before == disk_after, 'build_mutation_authorized': mode == 'build',
               'tool_copy_match': tool_copy == tool_after,
               'hex_inventory_match': hex_before == hex_after, 'hex_inventory_before': hex_before,
               'hex_inventory_after': hex_after, 'tool_sources_match': tool_sources == tool_source_after,
               'post_collection_errors': post_errors,
               'peer_processes_before': peer_before, 'peer_processes_after': peer_after,
               'record_counts': {k: len(v) for k, v in records.items()},
               'tooling_reviewed_inputs': reviewed, 'collector_sha256': sha(Path(__file__))}
    save(OUT / f'{name}.json', receipt)
    print(json.dumps(receipt, indent=2))
    assert before == after and source_before == source_after
    assert mode == 'build' or disk_before == disk_after
    assert not post_errors and receipt['tool_copy_match'] and receipt['tool_sources_match']
    assert receipt['hex_inventory_match'] and peer_after == []
    return code

if __name__ == '__main__':
    if sys.argv[1] == '--inner':
        sys.exit(inner(*sys.argv[2:]))
    else:
        sys.exit(outer(*sys.argv[1:]))
