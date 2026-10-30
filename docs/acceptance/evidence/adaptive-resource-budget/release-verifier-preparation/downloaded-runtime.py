#!/usr/bin/env python3
"""Qualify an explicitly selected verified published standalone on this Nix host; never publish."""
import argparse
import hashlib
import importlib.metadata
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import ssl
import subprocess
import sys
import tarfile
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
VERSION = None
VERIFIER_SHA256 = None
HOST_RECEIPT = ROOT / '.audit/release-0.9.0-public-runtime/receipt.json'
CA = Path('/etc/ssl/certs/ca-certificates.crt')
SCRIPTS = [
    'scripts/release-smoke.py', 'scripts/gateway-release-smoke.py',
    'scripts/h3-release-smoke.py', 'scripts/generate-fixtures.sh',
    'apps/gaoxy_http/test/support/mixed_http_peer.py',
    'integration/http3/quinn_peer.py', 'integration/http3/release_peer/Cargo.toml',
    'integration/http3/release_peer/Cargo.lock', 'integration/http3/release_peer/src/main.rs',
    'integration/http3/upstream/origin.py', 'integration/http3/upstream/run.py',
]
PACKAGES = {'gaoxy', 'gaoxy_http', 'gaoxy_http3', 'gaoxy_proxy', 'gaoxy_test', 'gaoxy_websock_adapter'}
STANDALONE = None
PAYLOADS = set()
EXPECTED = set()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def artifact_verifier():
    path = HERE / 'verify-public-artifacts.py'
    require(digest(path.read_bytes()) == VERIFIER_SHA256,
            'artifact verifier differs from explicitly reviewed SHA256')
    spec = importlib.util.spec_from_file_location('public_artifact_verifier', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def configure(version, verifier_sha256):
    global VERSION, STANDALONE, PAYLOADS, EXPECTED, VERIFIER_SHA256
    require(re.fullmatch(r'[0-9a-f]{64}', verifier_sha256),
            '--artifact-verifier-sha256 must be a full lowercase SHA256')
    VERIFIER_SHA256 = verifier_sha256
    module = artifact_verifier()
    module.configure(version)
    require(module.ROOT == ROOT, 'artifact verifier root differs')
    VERSION, STANDALONE = module.VERSION, module.STANDALONE
    PAYLOADS, EXPECTED = module.PAYLOADS, module.EXPECTED


def validate_receipt(verified, sha):
    require(verified.get('verifier_sha256') == VERIFIER_SHA256,
            'artifact receipt verifier digest differs from reviewed helper')
    require(verified['status'] == 'PASS' and verified['version'] == VERSION
            and verified['tag'] == f'v{VERSION}', 'artifact receipt is not this passing stable version')
    require(verified['source_commit'] == sha and verified['remote_tag_sha'] == sha,
            'artifact source/tag differs from requested publication commit')
    require(set(verified['packages']) == PACKAGES and set(verified['assets']) == EXPECTED
            and verified['sha256sums_entries'] == 7, 'artifact cohort differs')
    for package in verified['packages'].values():
        require(package['source_file_count'] == len(package['source_files'])
                and all(item['source_commit'] == sha for item in package['source_files'].values()),
                'artifact package source receipt differs')
    require(verified['package_source_file_count'] == sum(
        package['source_file_count'] for package in verified['packages'].values()),
        'aggregate source count differs from derived package counts')
    build = verified['release_build']
    require(build['head_sha'] == sha and build['head_branch'] == 'main'
            and build['event'] == 'workflow_dispatch' and build['conclusion'] == 'success'
            and build['workflow_path'] == '.github/workflows/release.yml'
            and build['artifact_name'] == f'gaoxy-{VERSION}-linux-x86_64',
            'release Actions provenance differs')
    require(build['compared_file_count'] == 8 and set(build['compared_files']) == EXPECTED
            and build['cryptographic_build_attestation_verified'] is False,
            'release Actions comparison or explicit attestation disposition differs')
    for name in EXPECTED:
        require(all(build['compared_files'][name][key] == verified['assets'][name][key]
                    for key in ('sha256', 'bytes')), 'Actions/public artifact payload differs: ' + name)


def checked_archive(verified, assets):
    sums = {}
    for line in (assets / 'SHA256SUMS').read_text().splitlines():
        match = re.fullmatch(r'([0-9a-f]{64})  ([A-Za-z0-9_.-]+)', line)
        require(match is not None, 'malformed payload checksum')
        checksum, name = match.groups()
        require(name not in sums, 'duplicate payload checksum')
        sums[name] = checksum
    require(set(sums) == PAYLOADS, 'payload checksum file set differs')
    require(all(verified['assets'][name]['sha256'] == checksum
                for name, checksum in sums.items()), 'checksum manifest differs from verified assets')
    archive = assets / STANDALONE
    require(digest(archive.read_bytes()) == sums[STANDALONE], 'standalone archive digest differs')
    return archive


def extract_archive(archive, runtime):
    require(not runtime.exists(), 'runtime extraction target already exists')
    runtime.mkdir()
    with tarfile.open(archive, 'r:gz') as package:
        members = package.getmembers()
        require(len(members) < 100000 and sum(item.size for item in members) < 1024 * 1024 * 1024,
                'standalone extraction allowance exceeded')
        package.extractall(runtime, filter='data')
    release = runtime / 'bin/gaoxy'
    require(release.is_file() and os.access(release, os.X_OK), 'extracted release is not executable')
    boot = runtime / f'releases/{VERSION}/start.boot'
    require(boot.is_file() and boot.stat().st_size > 0, 'extracted release start.boot is missing or empty')
    return release, len(members)


def host_environment():
    host = json.loads(HOST_RECEIPT.read_text())
    require(host['status'] == 'PASS', 'prior Nix host qualification did not pass')
    environment = dict(os.environ)
    for name in ('LD_LIBRARY_PATH', 'NIX_LD_LIBRARY_PATH', 'ERL_FLAGS'):
        environment[name] = host['environment'][name]
    for directory in environment['LD_LIBRARY_PATH'].split(':'):
        require(Path(directory).is_dir(), 'required Nix host library directory unavailable')
    require(Path(environment['NIX_LD_LIBRARY_PATH']).is_dir(), 'Nix loader library directory unavailable')
    context = ssl.create_default_context(cafile=str(CA))
    require(context.verify_mode == ssl.CERT_REQUIRED and context.check_hostname,
            'system CA verification is not enabled')
    environment.update(ELIXIR_ERL_OPTIONS='+S 4:4', SSL_CERT_FILE=str(CA), PYTHONDONTWRITEBYTECODE='1')
    return environment


def source_script_hashes(sha):
    hashes = {}
    for name in SCRIPTS:
        current = (ROOT / name).read_bytes()
        committed = subprocess.check_output(['git', 'show', f'{sha}:{name}'], cwd=ROOT, timeout=30)
        require(current == committed, 'runtime qualification script differs from publication source: ' + name)
        hashes[name] = digest(current)
    return hashes


def remote_tag_sha():
    module = artifact_verifier()
    module.configure(VERSION)
    require(module.VERSION == VERSION and module.ROOT == ROOT, 'artifact verifier version/root differs')
    return module.tag_sha()


def commands(release, evidence):
    core = ('import importlib.util,sys;from pathlib import Path;'
            's=importlib.util.spec_from_file_location("release_smoke","scripts/release-smoke.py");'
            'm=importlib.util.module_from_spec(s);s.loader.exec_module(m);'
            'm.release=Path(sys.argv[1]);m.main()')
    return [
        ('core', [sys.executable, '-B', '-c', core, str(release)], 3, 150),
        ('gateway', [sys.executable, '-B', 'scripts/gateway-release-smoke.py', '--release', str(release)], 7, 150),
        ('h3', [sys.executable, '-B', 'scripts/h3-release-smoke.py', '--release', str(release),
                '--evidence', str(evidence / 'h3')], 3, 750),
    ]


def validate_smoke(name, output, evidence):
    if name == 'core':
        require('PASS portable release TCP/TLS/UDP' in output and '; 3 transports' in output,
                'core transport smoke did not execute all three transports')
        return {}
    if name == 'gateway':
        require('PASS standalone gateway release readiness' in output and '; 7 exchanges' in output,
                'gateway smoke did not execute all seven exchanges')
        return {}
    detail = json.loads((evidence / 'h3/result.json').read_text())
    require(detail['status'] == 'PASS' and len(detail['checks']) == 3
            and all(item['status'] == 'PASS' for item in detail['checks']), 'H3 checks did not all pass')
    require(set(detail['child_exits']) == {'release', 'origin'}
            and all(code == 0 for code in detail['child_exits'].values()), 'H3 child exit differs')
    require(detail['ports_rebound'] is True, 'H3 port reuse was not proven')
    return {'h3_child_exits': detail['child_exits'], 'ports_rebound': True}


def group_gone(pid):
    try:
        os.killpg(pid, 0)
    except ProcessLookupError:
        return True
    return False


def stop_owned_group(process):
    if not group_gone(process.pid):
        os.killpg(process.pid, signal.SIGTERM)
        end = time.monotonic() + 5
        while not group_gone(process.pid) and time.monotonic() < end:
            process.poll()
            time.sleep(0.05)
        if not group_gone(process.pid):
            os.killpg(process.pid, signal.SIGKILL)
    if process.poll() is None:
        process.wait(timeout=5)
    return group_gone(process.pid)


def run(sha, artifact_receipt):
    evidence = Path(tempfile.mkdtemp(prefix='downloaded-runtime-', dir=HERE))
    receipt = {'status': 'FAIL', 'source_commit': sha, 'version': VERSION,
               'artifact_receipt': str(artifact_receipt), 'evidence': str(evidence),
               'checks': [], 'processes_stopped': True,
               'runner_sha256': digest(Path(__file__).read_bytes()),
               'artifact_verifier_sha256': VERIFIER_SHA256}
    def save():
        (evidence / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    save()
    try:
        verified = json.loads(artifact_receipt.read_text())
        validate_receipt(verified, sha)
        archive = checked_archive(verified, artifact_receipt.parent)
        hashes = source_script_hashes(sha)
        environment = host_environment()
        require(remote_tag_sha() == sha, 'remote release tag differs before runtime qualification')
        release, count = extract_archive(archive, evidence / 'runtime')
        receipt.update(archive_sha256=digest(archive.read_bytes()), release=str(release),
                       safe_extraction_filter='data', archive_members=count,
                       host_environment_source=str(HOST_RECEIPT),
                       host_environment_scope='process-local Nix compatibility for downloaded Ubuntu runtime only',
                       environment={name: environment[name] for name in
                                    ('LD_LIBRARY_PATH', 'NIX_LD_LIBRARY_PATH', 'ERL_FLAGS',
                                     'ELIXIR_ERL_OPTIONS', 'SSL_CERT_FILE')},
                       system_CA_sha256=digest(CA.read_bytes()), script_hashes=hashes,
                       python=sys.version, python_dependencies={name: importlib.metadata.version(name)
                                                               for name in ('aioquic', 'h2', 'hpack', 'hyperframe')})
        save()
        for name, command, expected, timeout in commands(release, evidence):
            logfile = evidence / (name + '.log')
            entry = {'name': name, 'command': command, 'expected_checks': expected,
                     'timeout_seconds': timeout, 'status': 'RUNNING', 'log': str(logfile)}
            receipt['checks'].append(entry)
            receipt['processes_stopped'] = False
            save()
            started = time.monotonic()
            with logfile.open('w') as output:
                child = subprocess.Popen(command, cwd=ROOT, env=environment,
                                         stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
                entry['pid'] = entry['process_group'] = child.pid
                try:
                    entry['exit'] = child.wait(timeout=timeout)
                finally:
                    clean = group_gone(child.pid)
                    if not clean:
                        receipt['processes_stopped'] = stop_owned_group(child)
                    else:
                        receipt['processes_stopped'] = True
                    entry.update(exit=child.returncode, process_group_gone=clean,
                                 seconds=round(time.monotonic() - started, 2))
                    save()
            require(entry['exit'] == 0 and entry['process_group_gone'], 'runtime command or natural cleanup failed')
            entry.update(validate_smoke(name, logfile.read_text(), evidence))
            entry.update(status='PASS', verified_checks=expected, log_sha256=digest(logfile.read_bytes()))
            save()
            print(json.dumps(entry), flush=True)
        require(remote_tag_sha() == sha, 'remote release tag changed during runtime qualification')
        require(source_script_hashes(sha) == hashes, 'qualification scripts changed during runtime checks')
        receipt['verified_checks'] = sum(item['verified_checks'] for item in receipt['checks'])
        require(receipt['verified_checks'] == 13, 'runtime qualification count differs')
        receipt['status'] = 'PASS'
    except BaseException as error:
        receipt['error'] = f'{type(error).__name__}: {error}'
    finally:
        save()
    print(json.dumps({'status': receipt['status'], 'receipt': str(evidence / 'receipt.json'),
                      'error': receipt.get('error')}), flush=True)
    return 0 if receipt['status'] == 'PASS' else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True, help='explicit published version without v prefix')
    parser.add_argument('--artifact-verifier-sha256', required=True, help='reviewed verifier SHA256 checked before import')
    parser.add_argument('--sha', required=True, help='full exact successfully published source commit')
    parser.add_argument('--artifact-receipt', required=True, type=Path,
                        help='PASS receipt from the reviewed public artifact verifier')
    args = parser.parse_args()
    configure(args.version, args.artifact_verifier_sha256)
    require(re.fullmatch(r'[0-9a-f]{40}', args.sha), '--sha must be full lowercase commit SHA')
    return run(args.sha, args.artifact_receipt.resolve())


if __name__ == '__main__':
    sys.exit(main())
