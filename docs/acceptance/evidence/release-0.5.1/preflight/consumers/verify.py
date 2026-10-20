#!/usr/bin/env python3
"""Disposable prepublication Hex-registry acceptance; owns only its run directory."""
import argparse
import concurrent.futures
import datetime
import hashlib
import http.server
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import threading
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
BASE = Path(__file__).resolve().parent
OWN = ['gaoxy_websock_adapter', 'gaoxy', 'gaoxy_http', 'gaoxy_http3', 'gaoxy_proxy']
VERSION = '0.5.1'
parser = argparse.ArgumentParser()
parser.add_argument('--artifacts', type=Path, default=ROOT / '.audit/hex-artifacts')
parser.add_argument('--prepare-only', action='store_true')
args = parser.parse_args()
RUN = BASE / f'run-{time.time_ns()}'
RUN.mkdir()
REG = RUN / 'registry'
(REG / 'tarballs').mkdir(parents=True)
ENV = dict(os.environ, HEX_HOME=str(RUN / 'hex-home'), MIX_ENV='test',
           ELIXIR_ERL_OPTIONS='+S 2:2', ERL_FLAGS='+S 2:2', HEX_HTTP_TIMEOUT='30')
# Preserve installed Hex/Rebar compiler tools, never global Hex repository configuration.
checks = []
result = {'run': str(RUN), 'source_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
          'source_diff_sha256': hashlib.sha256(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT)).hexdigest(),
          'version': VERSION, 'status': 'PREPARING', 'checks': checks}
def save():
    (RUN / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def run(name, command, cwd=RUN, timeout=300):
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    print('START', name, flush=True)
    proc = subprocess.run(command, cwd=cwd, env=ENV, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True, timeout=timeout)
    log = RUN / f'{name}.log'
    log.write_text(proc.stdout)
    checks.append({'name': name, 'command': list(map(str,command)), 'cwd': str(cwd),
                   'started_utc': started, 'exit': proc.returncode,
                   'log': str(log), 'log_sha256': sha(log)})
    save()
    print(proc.stdout, end='', flush=True)
    assert proc.returncode == 0, f'{name} failed: {proc.returncode}'
    return proc.stdout

def manifest(module, app, deps, extra='', application='[extra_applications: [:logger]]'):
    return f'''defmodule {module}.MixProject do
  use Mix.Project
  def project, do: [app: :{app}, version: "0.1.0", elixir: "~> 1.18", deps: [{deps}]{extra}]
  def application, do: {application}
end
'''

try:
    # Use accepted exact third-party cohorts as the only versions offered by the registry.
    third = {}
    pattern = r'"[^"]+": \{{:hex, :([^,]+), "([^"]+)", .*?, "hexpm", "([a-f0-9]{{64}})"\}}'
    for lock in [ROOT / 'mix.lock', ROOT / 'examples/phoenix_native/mix.lock']:
        for package, version, checksum in re.findall(pattern.replace('{{','{').replace('}}','}'), lock.read_text()):
            key = (package, version)
            assert key not in third or third[key] == checksum
            third[key] = checksum
    assert ('phoenix', '1.8.15') in third and ('plug', '1.20.3') in third
    # These accepted Git pins are distributed at the verified equivalent public versions.
    third[('hell', '0.1.2')] = None
    third[('abyss', '0.7.0')] = None
    cache = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'hex/packages/hexpm'
    def acquire(item):
        (package, version), expected = item
        filename = f'{package}-{version}.tar'
        target = REG / 'tarballs' / filename
        cached = cache / filename
        if cached.is_file():
            shutil.copyfile(cached, target)
            origin = str(cached)
        else:
            origin = 'https://repo.hex.pm/tarballs/' + filename
            with urllib.request.urlopen(origin, timeout=60) as response:
                target.write_bytes(response.read())
        actual = sha(target)
        if expected is not None:
            assert actual == expected, (filename, actual, expected)
        return {'file': filename, 'sha256': actual, 'origin': origin}
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        result['third_party_tarballs'] = list(pool.map(acquire, sorted(third.items())))
    result['fixture_source_sha256'] = {}
    def copy_tree(relative, destination):
        source = ROOT / relative
        shutil.copytree(source, destination)
        for file in source.rglob('*'):
            if file.is_file():
                result['fixture_source_sha256'][str(file.relative_to(ROOT))] = sha(file)
    core, http_project, phoenix = [RUN / name for name in ('core', 'http', 'phoenix')]
    for path in [core, http_project, phoenix]:
        path.mkdir()
    copy_tree('integration/core_consumer/test', core / 'test')
    copy_tree('integration/http_consumer/test', http_project / 'test')
    for folder in ['lib', 'config', 'test']:
        copy_tree('examples/phoenix_native/' + folder, phoenix / folder)
    (core / 'mix.exs').write_text(manifest('CoreConsumer', 'core_consumer', '{:gaoxy, "== 0.5.1"}'))
    (http_project / 'mix.exs').write_text(manifest('HTTPConsumer', 'http_consumer', '{:gaoxy_http, "== 0.5.1"}'))
    (phoenix / 'mix.exs').write_text(manifest('PhoenixNative', 'phoenix_native', '''
      {:gaoxy_http, "== 0.5.1"},
      {:websock_adapter, "== 0.5.1", hex: :gaoxy_websock_adapter, override: true},
      {:phoenix, "== 1.8.15"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.4"}
    ''', extra=', elixirc_paths: ["lib"], listeners: [Phoenix.CodeReloader]',
    application='[mod: {PhoenixNative.Application, []}, extra_applications: [:logger, :ssl]]'))
    assert not any(path.name in {'deps', '_build'} for path in RUN.rglob('*'))
    if args.prepare_only:
        result['status'] = 'PREPARED'
        save()
        print('PREPARED', RUN, flush=True)
        raise SystemExit(0)
    result['own_tarballs'] = []
    for package in OWN:
        source = args.artifacts / f'{package}-{VERSION}.tar'
        assert source.is_file(), f'missing built package: {source}'
        target = REG / 'tarballs' / source.name
        shutil.copyfile(source, target)
        result['own_tarballs'].append({'file': source.name, 'sha256': sha(target)})
    run('signing-key', ['openssl', 'genrsa', '-out', str(RUN / 'registry-private.pem'), '2048'])
    run('registry-build', ['mix', 'hex.registry', 'build', str(REG), '--name=hexpm', '--private-key=' + str(RUN / 'registry-private.pem')])
    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(REG), **kw)
        def log_message(self, format, *a):
            with (RUN / 'registry-http.log').open('a') as output:
                output.write(format % a + '\n')
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever)
    thread.start()
    result['registry_url'] = f'http://127.0.0.1:{server.server_port}'
    try:
        run('registry-config', ['mix', 'hex.repo', 'set', 'hexpm', '--url', result['registry_url'], '--public-key', str(REG / 'public_key')])
        for name, project, expected in [('core', core, 1), ('http', http_project, 2), ('phoenix', phoenix, 4)]:
            run(name + '-deps', ['mix', 'deps.get'], cwd=project)
            lock = (project / 'mix.lock').read_text()
            assert ':git' not in lock and ':path' not in lock
            run(name + '-compile', ['mix', 'compile', '--warnings-as-errors'], cwd=project)
            assertion = '''
            deps = Mix.Dep.load_and_cache()
            true = Enum.all?(deps, &(&1.scm == Hex.SCM))
            Enum.each(deps, fn dep -> IO.puts("HEX_DEP #{dep.app} #{inspect(dep.opts[:hex])}") end)
            '''
            run(name + '-resolved', ['mix', 'run', '--no-start', '--no-compile', '-e', assertion], cwd=project)
            output = run(name + '-tests', ['mix', 'test', '--warnings-as-errors', '--seed', '0', '--max-cases', '1'], cwd=project)
            summary = re.findall(r'(\d+) tests?, (\d+) failures?([^\n]*)', output)
            assert len(summary) == 1 and tuple(map(int, summary[0][:2])) == (expected, 0), summary
            assert 'excluded' not in summary[0][2] and 'skipped' not in summary[0][2]
            result.setdefault('consumers', {})[name] = {'executed': expected, 'failures': 0, 'lock_sha256': sha(project / 'mix.lock')}
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=10)
        assert not thread.is_alive()
        result['registry_server_joined'] = True
    for relative, digest in result['fixture_source_sha256'].items():
        assert sha(ROOT / relative) == digest, f'original fixture changed: {relative}'
    for row in result['own_tarballs']:
        assert sha(args.artifacts / row['file']) == row['sha256']
    result['status'] = 'PASS'
    save()
    print('PASS core1 / HTTP2 / Phoenix4 real signed Hex registry consumers:', RUN, flush=True)
except Exception as exc:
    result['status'] = 'FAIL'
    result['error'] = repr(exc)
    save()
    raise
