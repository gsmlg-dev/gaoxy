"""Materialize verified, unmodified release sources; never reuse parent BEAMs."""
from pathlib import Path
import hashlib
import io
import json
import tarfile

root = Path.cwd()
baseline = root / '.audit/m3-transport/tls95-baseline-0.21.1'
prior = root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.1/release-provenance.json'
provenance = json.loads(prior.read_text())
assert provenance['version'] == '0.21.1'
old_installed = json.loads((root / '.audit/m3-transport/upstream-0.21.2/installed-0.21.1-freeze.json').read_text())['sha256']
packages = ['http_core', 'http_runtime', 'http_fetch', 'http_web_socket',
            'ex_ssl', 'elixir_quic', 'elixir_quic_http3']
digest = lambda data: hashlib.sha256(data).hexdigest()

def preserve(path, data):
    for ancestor in [path, *path.parents]:
        assert not ancestor.is_symlink(), str(ancestor)
        if ancestor == root:
            break
    assert path.resolve().is_relative_to(baseline.resolve()), str(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        assert path.is_file() and path.read_bytes() == data, str(path)
    else:
        path.write_bytes(data)

inputs = {}
contents = {}
for package in packages:
    for relative, expected in provenance['packages'][package]['contents_sha256'].items():
        source = root / '.audit/m3-transport/upstream-0.21.1/packages' / package / relative
        data = source.read_bytes()
        assert digest(data) == expected == old_installed[package + '/' + relative], str(source)
        destination = baseline / 'packages' / package / relative
        contents[str(destination.relative_to(baseline))] = data
        inputs[str(destination.relative_to(baseline))] = expected
assert len(inputs) == 196

telemetry_archive = root / '.audit/m3-transport/tls95-telemetry-1.4.2.tar'
assert telemetry_archive.is_file() and not telemetry_archive.is_symlink(), 'Complete separately receipted archive acquisition first'
archive = telemetry_archive.read_bytes()
assert digest(archive) == '928f6495066506077862c0d1646609eed891a4326bee3126ba54b60af61febb1'
with tarfile.open(fileobj=io.BytesIO(archive)) as outer:
    parts = {member.name: outer.extractfile(member).read() for member in outer.getmembers() if member.isfile()}
assert set(parts) == {'VERSION', 'CHECKSUM', 'metadata.config', 'contents.tar.gz'}
assert digest(parts['VERSION'] + parts['metadata.config'] + parts['contents.tar.gz']) == 'a0cb522801dffb1c49fe6e30561badffc7b6d0e180db1300df759faa22062855'
assert parts['CHECKSUM'].decode().lower() == 'a0cb522801dffb1c49fe6e30561badffc7b6d0e180db1300df759faa22062855'
telemetry_files = {}
with tarfile.open(fileobj=io.BytesIO(parts['contents.tar.gz']), mode='r:gz') as inner:
    for member in inner.getmembers():
        if member.isdir():
            continue
        assert member.isfile() and not Path(member.name).is_absolute() and '..' not in Path(member.name).parts
        data = inner.extractfile(member).read()
        source = root / 'deps/telemetry' / member.name
        assert source.is_file() and source.read_bytes() == data, str(source)
        destination = baseline / 'packages/telemetry' / member.name
        assert member.name not in telemetry_files, 'Duplicate archive member'
        contents[str(destination.relative_to(baseline))] = data
        telemetry_files[member.name] = digest(data)
        inputs[str(destination.relative_to(baseline))] = digest(data)
assert 'src/telemetry.hrl' in telemetry_files and 'src/telemetry.app.src' in telemetry_files
telemetry_hex = (root / 'deps/telemetry/.hex').read_bytes()
acquisition = json.loads((root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.2/tls95-telemetry-acquisition.json').read_text())
reviewed_inventory = json.loads((root / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.2/tls-registration-inventory.json').read_text())
assert acquisition['status'] == 'PASS_ARCHIVE_AND_SHIPPED_IDENTITY'
assert digest(archive) == acquisition['archive_sha256']
assert digest(telemetry_hex) == acquisition['installed_hex_sha256'] == reviewed_inventory['input_sha256']['deps/telemetry/.hex']
contents['packages/telemetry/.hex'] = telemetry_hex
inputs['packages/telemetry/.hex'] = digest(telemetry_hex)

manifest = '''defmodule TLS95Baseline.MixProject do
  use Mix.Project
  def project do
    [app: :tls95_baseline, version: "0.0.0", elixir: "~> 1.18",
     build_path: "_build", deps_path: "deps", config_path: "config/config.exs",
     deps: deps()]
  end
  def application, do: [extra_applications: []]
  defp deps do
    for app <- [:http_core, :http_runtime, :http_fetch, :http_web_socket,
                :elixir_quic, :elixir_quic_http3, :ex_ssl, :telemetry] do
      {app, path: Path.expand("packages/#{app}", __DIR__), override: true, env: :prod}
    end
  end
end
'''
contents['mix.exs'] = manifest.encode()
inputs['mix.exs'] = digest(manifest.encode())
for relative, data in [('mix.lock', b'%{}\n'), ('config/config.exs', b'import Config\n')]:
    contents[relative] = data
    inputs[relative] = digest(data)
for ancestor in [baseline, *baseline.parents]:
    assert not ancestor.is_symlink(), str(ancestor)
allowed_dirs = {'packages', 'config', 'deps', '_build', '.mix', '.hex'}
for relative in contents:
    allowed_dirs.update(str(p) for p in Path(relative).parents if str(p) != '.')
if baseline.exists():
    assert baseline.is_dir()
    for path in baseline.rglob('*'):
        assert not path.is_symlink(), str(path)
        relative = str(path.relative_to(baseline))
        if path.is_dir():
            assert relative in allowed_dirs, 'Unlisted destination directory: ' + relative
        else:
            assert path.is_file() and relative in contents, 'Unlisted destination file: ' + relative
            assert path.read_bytes() == contents[relative], 'Stale destination input: ' + relative
assert set(contents) == set(inputs)
for relative, data in contents.items():
    preserve(baseline / relative, data)
for relative in ['deps', '_build', '.mix', '.hex']:
    directory = baseline / relative
    assert not directory.is_symlink()
    directory.mkdir(exist_ok=True)
actual = {}
for path in baseline.rglob('*'):
    assert not path.is_symlink(), str(path)
    if path.is_file():
        actual[str(path.relative_to(baseline))] = digest(path.read_bytes())
assert actual == inputs, 'Unexpected or changed baseline files/builds; preserve and diagnose'
print(json.dumps({'status': 'PASS_MATERIALIZED_SOURCE_ONLY', 'baseline_root': str(baseline),
                  'source_provenance': str(prior.relative_to(root)), 'source_provenance_sha256': digest(prior.read_bytes()),
                  'old_shipped_files': 196, 'telemetry_version': '1.4.2', 'telemetry_files': telemetry_files,
                  'telemetry_archive_sha256': digest(archive), 'inputs': inputs,
                  'no_preserved_beam_reuse': True, 'compile_and_runtime': 'NOT_RUN'}, indent=2, sort_keys=True))
