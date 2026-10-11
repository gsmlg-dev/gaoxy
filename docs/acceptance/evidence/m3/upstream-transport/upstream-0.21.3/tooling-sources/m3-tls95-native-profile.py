"""No peer starts: identify the fixed Python/import/native and shell tool closure."""
from pathlib import Path
import hashlib
from concurrent.futures import ThreadPoolExecutor
import importlib.metadata
import json
import os
import re
import shutil
import ssl
import subprocess
import sys

root = Path(os.environ['TLS95_PARENT_ROOT'])
sys.path.insert(0, str(root / 'integration/http_fetch_contract'))
import managed_tls_tracking_peer
import h2.connection
import hpack
import hyperframe.frame

sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
files = {}
def add(path):
    path = Path(path).resolve(strict=True)
    assert path.is_file()
    files[str(path)] = sha(path)
    return str(path)

modules = {}
for name, module in sorted(sys.modules.copy().items()):
    path = getattr(module, '__file__', None)
    if path and Path(path).is_file():
        modules[name] = add(path)
executable = add(sys.executable)
for path in [Path(sys.prefix) / 'pyvenv.cfg', root / 'flake.nix', root / 'flake.lock']:
    add(path)
for line in Path(f'/proc/{os.getpid()}/maps').read_text().splitlines():
    parts = line.split(maxsplit=5)
    if len(parts) == 6 and parts[5].startswith('/'):
        add(parts[5])

tools = {}
for name, args in [('python3', ['--version']), ('openssl', ['version', '-a']),
                   ('nix', ['--version']), ('mix', []), ('elixir', []), ('erl', []),
                   ('unbuffer', []), ('bash', ['--version']), ('gcc', ['--version']),
                   ('ld', ['--version']), ('ldd', ['--version']), ('nix-store', ['--version'])]:
    path = shutil.which(name)
    assert path, 'Missing pinned tool: ' + name
    resolved = add(path)
    record = {'path': path, 'real': resolved, 'sha256': files[resolved]}
    if args:
        result = subprocess.run([path, *args], capture_output=True, text=True, timeout=10, check=True)
        record['version_output'] = result.stdout + result.stderr
    tools[name] = record

# NAR verification covers hidden executable wrappers, script interpreters,
# Tcl/Expect packages, compiler support files and every declared store reference.
# Hash the real trees as well as recording registered hashes; lexical launchers
# and ELF linkage alone cannot establish this closure.
store_roots = set()
for tool in tools.values():
    parts = Path(tool['real']).parts
    assert parts[:3] == ('/', 'nix', 'store'), 'Pinned tool escaped Nix store'
    store_roots.add(str(Path(*parts[:4])))
    companion = Path(tool['path']).parent / ('.'+Path(tool['path']).name+'-wrapped')
    if companion.is_file():
        tool['hidden_wrapper'] = add(companion)
        tool['hidden_wrapper_sha256'] = files[tool['hidden_wrapper']]

closure = set()
for store_root in sorted(store_roots):
    result = subprocess.run([tools['nix-store']['path'], '--query', '--requisites', store_root],
                            capture_output=True, text=True, timeout=15, check=True)
    closure.update(result.stdout.splitlines())

def verify_store(path):
    registered = subprocess.run([tools['nix-store']['path'], '--query', '--hash', path],
                                capture_output=True, text=True, timeout=15, check=True).stdout.strip()
    actual = subprocess.run([tools['nix']['path'], 'hash', 'path', '--type', 'sha256', '--base32', path],
                            capture_output=True, text=True, timeout=45, check=True).stdout.strip()
    assert registered == 'sha256:'+actual, 'Native/tool store tree drift: '+path
    return {'path': path, 'registered_nar_hash': registered, 'actual_nar_hash': 'sha256:'+actual}

with ThreadPoolExecutor(max_workers=4) as workers:
    store_identities = list(workers.map(verify_store, sorted(closure)))

ldd_path = tools['ldd']['path']
queue = [p for p in files if Path(p).read_bytes()[:4] == b'\x7fELF']
done = set()
while queue:
    path = queue.pop()
    if path in done:
        continue
    done.add(path)
    result = subprocess.run([ldd_path, path], capture_output=True, text=True, timeout=10)
    text = result.stdout + result.stderr
    assert 'not found' not in text, text
    assert result.returncode == 0 or 'not a dynamic executable' in text or 'statically linked' in text, text
    for library in re.findall(r'(/[^\s()]+)', text):
        if Path(library).is_file():
            real = add(library)
            if real not in done:
                queue.append(real)

print(json.dumps({'python_executable': executable, 'python_version': sys.version,
                  'python_prefix': sys.prefix, 'python_path': sys.path,
                  'openssl_version': ssl.OPENSSL_VERSION,
                  'packages': {name: importlib.metadata.version(name) for name in ['h2', 'hpack', 'hyperframe']},
                  'modules': modules, 'tools': tools, 'file_sha256': files,
                  'tool_store_roots': sorted(store_roots), 'verified_transitive_tool_store_closure': store_identities,
                  'ELF_dynamic_dependency_closure': sorted(done),
                  'claim': 'Immutable loaded/imported/tool and native file identity only; no ABI or byte/lifetime proof.'},
                 indent=2, sort_keys=True))
