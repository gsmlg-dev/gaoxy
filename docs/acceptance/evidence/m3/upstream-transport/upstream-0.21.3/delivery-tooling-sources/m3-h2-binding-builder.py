import hashlib
import json
from pathlib import Path
import re
import sys

root = Path.cwd().resolve()
out = root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.3'
name = sys.argv[1]
driver, peer = [Path(path).resolve(strict=True) for path in sys.argv[2:4]]
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
native = json.loads((out / 'h2-native-profile-before1-extracted.json').read_text())
inputs = dict(native['file_sha256'])
for path, expected in inputs.items():
    assert sha(path) == expected
packages = ['http_core', 'http_runtime', 'http_fetch', 'http_web_socket',
            'ex_ssl', 'elixir_quic', 'elixir_quic_http3']
sources = [path for package in packages for path in (root / 'deps' / package / 'lib').rglob('*')
           if path.is_file()]
assert len(sources) == 175
plan = root / 'docs/plans/m3-h2-0.21.3-functional-supplement.md'
assert sha(plan) == '25fdfb876f7e83f65b97414816a6a82c258ec8f789f0d0eb7f4e07f627ad7270'
plan_inputs = [root / path for path, expected in re.findall(
    r'\| `([^`]+)` \| `([0-9a-f]{64})` \|', plan.read_text())
    if sha(root / path) == expected]
assert len(plan_inputs) == 16
files = sources + plan_inputs + [plan, driver, peer, Path(__file__).resolve(),
    root / 'mix.lock', root / 'integration/h2_gateway/requirements.txt',
    root / '.audit/m3-qualified-collector.py',
    root / '.audit/m3-transport/tls95-runtime-identity.exs',
    root / 'integration/http_fetch_contract/pooled_completion_probe.exs',
    root / 'integration/http_fetch_contract/upstream_peer.py',
    out / 'h2-functional-supplement-repair1-review.json',
    out / 'installed-cohort-verification.json', out / 'installed-final-verification.json',
    out / 'h2-native-profile-before1-extracted.json']
for base in ['_build/test/lib', 'deps/ex_ssl/priv', 'deps/elixir_quic/priv',
             '.audit/m3-transport/tls95-candidate-tools/.mix/archives']:
    files += [path for path in (root / base).rglob('*')
              if path.is_file() and path.suffix in ['.beam', '.app', '.so']]
for path in sys.argv[4:]:
    files.append(Path(path).resolve(strict=True))
for path in files:
    key = str(path.absolute())
    actual = sha(path)
    if key in inputs:
        assert inputs[key] == actual
    inputs[key] = actual
manifest_path = root / '.audit/m3-transport' / (name + '-inputs.json')
with manifest_path.open('x') as stream:
    stream.write(json.dumps(inputs, indent=2, sort_keys=True) + '\n')
binding = {'status': 'AWAITING_INDEPENDENT_MANIFEST_REVIEW',
           'name': name, 'driver': str(driver), 'driver_sha256': sha(driver),
           'peer': str(peer), 'peer_sha256': sha(peer),
           'plan_sha256': sha(plan), 'runtime_sources': len(sources),
           'manifest': str(manifest_path), 'manifest_sha256': sha(manifest_path),
           'inputs': len(inputs), 'builder_sha256': sha(Path(__file__)),
           'native_profile': str(out / 'h2-native-profile-before1-extracted.json'),
           'claim': 'Frozen loaded/imported/tool file identity; no native lifetime/accounting proof'}
with (out / (name + '-binding.json')).open('x') as stream:
    stream.write(json.dumps(binding, indent=2) + '\n')
print(json.dumps(binding, indent=2))
