#!/usr/bin/env python3
"""Read-only remote release verification. Run only after actual publication."""
import argparse
import datetime
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import time
import urllib.request

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy')
BASE = Path(__file__).resolve().parent
VERSION = '0.6.0'
REPO = 'gsmlg-dev/gaoxy'
PACKAGES = ['gaoxy_websock_adapter', 'gaoxy', 'gaoxy_http', 'gaoxy_http3', 'gaoxy_proxy']
EXPECTED = {
    'gaoxy_websock_adapter': {'websock': ('websock', '~> 0.5', False), 'plug': ('plug', '~> 1.14', False),
                              'bandit': ('bandit', '>= 0.6.0', True), 'plug_cowboy': ('plug_cowboy', '~> 2.6', True)},
    'gaoxy': {'hell': ('hell', '== 0.1.2', False), 'abyss': ('abyss', '== 0.9.0', False),
              'telemetry': ('telemetry', '~> 1.3', False)},
    'gaoxy_http': {'gaoxy': ('gaoxy', '== 0.6.0', False), 'plug': ('plug', '== 1.20.3', False),
                   'hpax': ('hpax', '== 1.1.0', False), 'websock': ('websock', '== 0.5.3', False),
                   'gaoxy_websock_adapter': ('websock_adapter', '== 0.6.0', False)},
    'gaoxy_http3': {'gaoxy_http': ('gaoxy_http', '== 0.6.0', False),
                    'elixir_quic_http3': ('elixir_quic_http3', '== 0.21.14', False)},
    'gaoxy_proxy': {'gaoxy': ('gaoxy', '== 0.6.0', False), 'gaoxy_http': ('gaoxy_http', '== 0.6.0', False),
                    'http_fetch': ('http_fetch', '== 0.21.14', False),
                    'http_web_socket': ('http_web_socket', '== 0.21.14', False)},
}
REQUIRED_STEPS = {
    'Validate exact pre-versioned release source', 'Hex packaging regressions',
    'Pinned ordinary repair peers', 'Correctness repair and ordinary compatibility on publication source',
    'Standalone core and native H1/H2 gateway release smoke', 'Package Linux x86_64 application',
    'Build all Hex packages before publication', 'Recheck publication source before irreversible upload',
    'Publish and verify Hex packages', 'Tag the validated source without generating source changes',
    'Create GitHub Release with application artifacts',
}
ENV = {**os.environ, 'ELIXIR_ERL_OPTIONS': '+S 2:2', 'GODEBUG': 'http2client=0'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def files(directory):
    return {str(p.relative_to(directory)): sha(p.read_bytes())
            for p in sorted(directory.rglob('*')) if p.is_file()}


def tar_files(data):
    result = {}
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:*') as archive:
        for entry in archive:
            name = entry.name.removeprefix('./')
            assert not name.startswith('/') and '..' not in Path(name).parts, name
            if entry.isdir():
                continue
            assert entry.isfile() and name not in result, name
            result[name] = archive.extractfile(entry).read()
    return result


def main(args):
    out = BASE / ('run-' + str(time.time_ns()))
    out.mkdir()
    receipt = {'status': 'RUNNING', 'version': VERSION, 'source': args.source, 'run_id': args.run,
               'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'tool_sha256': sha(Path(__file__).read_bytes()), 'commands': []}

    def save():
        (out / 'verification.json').write_text(json.dumps(receipt, indent=2) + '\n')

    def command(argv, label, cwd=ROOT, timeout=120):
        before = datetime.datetime.now(datetime.timezone.utc).isoformat()
        record = {'command': list(map(str, argv)), 'cwd': str(cwd), 'started_utc': before}
        try:
            proc = subprocess.run(argv, cwd=cwd, env=ENV, capture_output=True, timeout=timeout)
            stdout, stderr, code = proc.stdout, proc.stderr, proc.returncode
        except subprocess.TimeoutExpired as error:
            stdout, stderr, code = error.stdout or b'', error.stderr or b'', 'TIMEOUT'
        for stream, data in [('stdout', stdout), ('stderr', stderr)]:
            filename = label + '.' + stream
            (out / filename).write_bytes(data)
            record[stream] = filename
            record[stream + '_sha256'] = sha(data)
        record['exit'] = code
        receipt['commands'].append(record)
        save()
        assert code == 0, (label, code, stderr.decode(errors='replace'))
        return stdout

    def api(path, label):
        return json.loads(command(['gh', 'api', path], label))

    def public(url, name):
        started = datetime.datetime.now(datetime.timezone.utc).isoformat()
        with urllib.request.urlopen(url, timeout=60) as response:
            body, status = response.read(), response.status
        (out / name).write_bytes(body)
        receipt['commands'].append({'url': url, 'started_utc': started, 'status': status,
                                    'output': name, 'output_sha256': sha(body)})
        save()
        assert status == 200
        return body

    def metadata(body, name):
        path = out / (name + '.config')
        path.write_bytes(body)
        code = '''
{:ok, terms} = :file.consult(String.to_charlist(hd(System.argv())))
convert = fn
  values, recur when is_list(values) ->
    if values != [] and Enum.all?(values, &match?({_, _}, &1)),
      do: Map.new(values, fn {key, value} -> {key, recur.(value, recur)} end),
      else: Enum.map(values, &recur.(&1, recur))
  value, _ -> value
end
IO.puts(JSON.encode!(convert.(terms, convert)))
'''
        return json.loads(command(['elixir', '-e', code, str(path)], name + '-parsed'))

    try:
        assert re.fullmatch(r'[0-9a-f]{40}', args.source)
        assert command(['git', 'rev-parse', args.source + '^{commit}'], 'source-commit').decode().strip() == args.source
        # Produce expectations from immutable Git objects, never the dirty live checkout.
        archive = command(['git', 'archive', args.source, 'mix.exs', 'LICENSE', 'scripts/stage-hex-packages.exs',
                           'apps', 'vendor/websock_adapter', '.github/workflows/release.yml'], 'source-archive')
        source = out / 'source'
        source.mkdir()
        source_files = tar_files(archive)
        for name, body in source_files.items():
            dest = source / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(body)
        receipt['source_files_sha256'] = {name: sha(body) for name, body in source_files.items()}
        stage = out / 'stage'
        command(['elixir', str(source / 'scripts/stage-hex-packages.exs'), str(source), str(stage)], 'source-stage')
        expected_payloads = {name: files(stage / name) for name in PACKAGES}
        receipt['expected_package_files_sha256'] = expected_payloads
        run = api(f'repos/{REPO}/actions/runs/{args.run}', 'hosted-run')
        assert run['id'] == args.run and run['head_sha'] == args.source
        assert run['status'] == 'completed' and run['conclusion'] == 'success'
        assert run['path'] == '.github/workflows/release.yml' and run['event'] == 'workflow_dispatch'
        jobs = api(f'repos/{REPO}/actions/runs/{args.run}/jobs?per_page=100', 'hosted-jobs')
        assert jobs['total_count'] == 1 and len(jobs['jobs']) == 1
        job = jobs['jobs'][0]
        assert job['name'] == 'release' and job['conclusion'] == 'success'
        assert all(s.get('conclusion') in ('success', 'skipped') for s in job['steps'])
        assert REQUIRED_STEPS <= {s['name'] for s in job['steps'] if s.get('conclusion') == 'success'}
        release = api(f'repos/{REPO}/releases/tags/v{VERSION}', 'release')
        assert release['tag_name'] == 'v' + VERSION and not release['draft'] and not release['prerelease']
        parse_time = lambda x: datetime.datetime.fromisoformat(x.replace('Z', '+00:00'))
        assert parse_time(run['created_at']) <= parse_time(release['published_at']) <= parse_time(run['updated_at'])
        obj = api(f'repos/{REPO}/git/ref/tags/v{VERSION}', 'tag')['object']
        for depth in range(4):
            if obj['type'] != 'tag':
                break
            obj = api(f'repos/{REPO}/git/tags/{obj["sha"]}', f'annotated-tag-{depth}')['object']
        assert obj['type'] == 'commit' and obj['sha'] == args.source
        expected_assets = {f'{name}-{VERSION}.tar' for name in PACKAGES} | {f'gaoxy-{VERSION}-linux-x86_64.tar.gz', 'SHA256SUMS'}
        assert len(release['assets']) == 7 and {a['name'] for a in release['assets']} == expected_assets
        downloads = out / 'downloads'
        downloads.mkdir()
        command(['gh', 'release', 'download', 'v' + VERSION, '--repo', REPO, '--dir', str(downloads)], 'download', timeout=300)
        receipt['assets'] = []
        for asset in release['assets']:
            body = (downloads / asset['name']).read_bytes()
            assert len(body) == asset['size'] and asset['digest'] == 'sha256:' + sha(body), asset['name']
            receipt['assets'].append({'name': asset['name'], 'id': asset['id'], 'size': len(body), 'sha256': sha(body)})
        sums = {}
        lines = (downloads / 'SHA256SUMS').read_text().splitlines()
        for line in lines:
            digest, name = line.split()
            name = name.removeprefix('*')
            assert name in expected_assets - {'SHA256SUMS'} and name not in sums
            assert re.fullmatch('[0-9a-f]{64}', digest) and sha((downloads / name).read_bytes()) == digest
            sums[name] = digest
        assert len(lines) == len(sums) == 6 and set(sums) == expected_assets - {'SHA256SUMS'}
        receipt['checksum_entries_verified'] = 6
        receipt['packages'] = []
        for name in PACKAGES:
            record = json.loads(public(f'https://hex.pm/api/packages/{name}/releases/{VERSION}', name + '-hex-record.json'))
            assert record['version'] == VERSION and not record.get('retirement')
            expected_reqs = {key: {'app': app, 'requirement': requirement, 'optional': optional}
                             for key, (app, requirement, optional) in EXPECTED[name].items()}
            assert record['requirements'] == expected_reqs, (name, record['requirements'])
            body = public(f'https://repo.hex.pm/tarballs/{name}-{VERSION}.tar', name + '-hex.tar')
            assert record['checksum'] == sha(body) == sums[f'{name}-{VERSION}.tar']
            assert body == (downloads / f'{name}-{VERSION}.tar').read_bytes()
            outer = tar_files(body)
            contents = tar_files(outer['contents.tar.gz'])
            payload_hashes = {path: sha(value) for path, value in contents.items()}
            assert payload_hashes == expected_payloads[name], (name, 'payload differs from committed staging')
            meta = metadata(outer['metadata.config'], name + '-metadata')
            assert meta['name'] == name and meta['version'] == VERSION
            assert meta['app'] == ('websock_adapter' if name == 'gaoxy_websock_adapter' else name)
            assert meta['elixir'] == ('~> 1.9' if name == 'gaoxy_websock_adapter' else '~> 1.18')
            assert meta['build_tools'] == ['mix']
            assert meta['licenses'] == ['MIT']
            assert len(meta['files']) == len(set(meta['files']))
            assert set(meta['files']) == {str(path.relative_to(stage / name)) for path in (stage / name).rglob('*')}
            expected_full = {key: {'name': key, **value, 'repository': 'hexpm'} for key, value in expected_reqs.items()}
            actual_full = {item['name']: item for item in meta['requirements']}
            assert len(meta['requirements']) == len(actual_full) and actual_full == expected_full
            if args.artifacts_dir:
                local = (args.artifacts_dir / f'{name}-{VERSION}.tar').read_bytes()
                local_outer = tar_files(local)
                assert tar_files(local_outer['contents.tar.gz']) == contents
                local_meta = metadata(local_outer['metadata.config'], name + '-local-metadata')
                for value in (meta, local_meta):
                    value['files'] = sorted(value['files'])
                    value['requirements'] = sorted(value['requirements'], key=lambda item: item['name'])
                assert local_meta == meta, (name, 'qualified metadata differs')
            receipt['packages'].append({'name': name, 'sha256': sha(body), 'metadata': meta,
                                        'github_public_hex_bytes_equal': True, 'payload_matches_commit': True,
                                        'qualified_local_comparison': True, 'local_tar_sha256': sha(local), 'local_tar_bytes_equal': local == body})
        with tarfile.open(downloads / f'gaoxy-{VERSION}-linux-x86_64.tar.gz') as archive:
            standalone = {}
            for entry in archive:
                name = entry.name.removeprefix('./')
                assert not name.startswith('/') and '..' not in Path(name).parts, name
                if entry.isfile():
                    standalone[name] = archive.extractfile(entry).read() if name.endswith('.app') else b''
                elif not entry.isdir():
                    assert entry.issym() or entry.islnk(), name
                    standalone[name] = b''
        assert 'lib/abyss-0.9.0/ebin/abyss.app' in standalone
        assert not any('abyss_raw' in n or '/rustler-' in n or 'dhcp_socket' in n for n in standalone)
        versions = {}
        for name in ['gaoxy', 'gaoxy_http', 'gaoxy_http3', 'gaoxy_proxy', 'gaoxy_server']:
            path = f'lib/{name}-{VERSION}/ebin/{name}.app'
            assert f'"{VERSION}"' in standalone[path].decode()
            versions[name] = VERSION
        receipt.update(status='PASS', release_url=release['html_url'], run_url=run['html_url'],
                       release_id=release['id'], verified_successful_steps=sorted(REQUIRED_STEPS),
                       standalone={'file_count': len(standalone), 'versions': versions,
                                   'native_libraries': sorted(n for n in standalone if n.endswith(('.so', '.dylib'))),
                                   'qualification': 'Static archive inspection and exact-source successful workflow provenance only; downloaded standalone not executed or reproduced byte for byte.'})
    except Exception as error:
        receipt.update(status='FAIL', error=repr(error))
        raise
    finally:
        receipt['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        receipt['evidence_files_sha256'] = {name: value for name, value in files(out).items() if name != 'verification.json'}
        save()
        print(json.dumps({'status': receipt['status'], 'receipt': str(out / 'verification.json')}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, help='Full actual published commit SHA')
    parser.add_argument('--run', required=True, type=int, help='Actual successful release workflow run ID')
    parser.add_argument('--artifacts-dir', required=True, type=Path, help='Directory containing the five qualified local Hex artifacts; compare metadata/payload in addition to immutable Git source')
    main(parser.parse_args())
