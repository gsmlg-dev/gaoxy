"""Offline runner guard controls; never invoke its network/build/runtime entrypoint."""
import ast
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RUNNER = HERE / 'downloaded-runtime.py'
ORIGINAL = ROOT / '.audit/release-0.13.1/public-verification/downloaded-runtime.py'
BASELINE = '84c7ff76461ada8aebaa34c567c61206bc963d83'
VERSION = '0.14.0'
OLD_ARTIFACTS = ROOT / '.audit/release-0.13.1/public-verification/public-artifacts-mpybge0q/receipt.json'
spec = importlib.util.spec_from_file_location('runtime_audit', RUNNER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
VERIFIER_HASH = module.digest((HERE / 'verify-public-artifacts.py').read_bytes())
module.configure(VERSION, VERIFIER_HASH)
checks = []
def passed(name): checks.append({'check': name, 'status': 'PASS'})
def rejected(name, callback, text):
    try:
        callback()
    except ValueError as error:
        assert text in str(error), str(error)
    else:
        raise AssertionError(name + ' incorrectly accepted')
    passed(name)

ast.parse(RUNNER.read_text())
assert module.ROOT == ROOT and module.HERE == HERE and module.VERSION == VERSION
passed('syntax_and_subtree_root_version')
original = json.loads(OLD_ARTIFACTS.read_text())
verified = copy.deepcopy(original)
verified.update(version=VERSION, tag='v' + VERSION, source_commit=BASELINE, remote_tag_sha=BASELINE, verifier_sha256=VERIFIER_HASH)
rename = lambda name: name.replace('0.13.1', VERSION)
verified['assets'] = {rename(name): data for name, data in verified['assets'].items()}
for package in verified['packages'].values():
    for item in package['source_files'].values(): item['source_commit'] = BASELINE
verified['package_source_file_count'] = sum(p['source_file_count'] for p in verified['packages'].values())
verified['release_build']['head_sha'] = BASELINE
verified['release_build']['artifact_name'] = 'gaoxy-0.14.0-linux-x86_64'
verified['release_build']['compared_files'] = {rename(name): data for name, data in verified['release_build']['compared_files'].items()}
module.validate_receipt(verified, BASELINE)
passed('synthetic_correct_receipt_guard_accepted')
for name, mutate, message in [
    ('wrong_sha', lambda r: r.update(remote_tag_sha='0' * 40), 'source/tag differs'),
    ('wrong_version', lambda r: r.update(version='0.13.1'), 'stable version'),
    ('missing_asset', lambda r: r['assets'].pop('SHA256SUMS'), 'cohort differs'),
    ('wrong_derived_count', lambda r: r.update(package_source_file_count=0), 'aggregate source count differs'),
    ('different_Actions_payload', lambda r: r['release_build']['compared_files']['SHA256SUMS'].update(sha256='0' * 64), 'Actions/public artifact payload differs'),
    ('false_attestation_claim', lambda r: r['release_build'].update(cryptographic_build_attestation_verified=True), 'attestation disposition differs'),
    ('failed_release', lambda r: r['release_build'].update(conclusion='failure'), 'Actions provenance differs'),
]:
    changed = copy.deepcopy(verified); mutate(changed)
    rejected(name + '_rejected', lambda r=changed: module.validate_receipt(r, BASELINE), message)

with tempfile.TemporaryDirectory(prefix='runtime-offline-', dir=HERE) as folder:
    folder = Path(folder)
    def archive(name, unsafe=None):
        path = folder / (name + '.tar.gz')
        with tarfile.open(path, 'w:gz') as output:
            member = tarfile.TarInfo(unsafe or 'bin/gaoxy')
            data = b'fixture only; never executed\n';member.size = len(data);member.mode = 0o755
            output.addfile(member, io.BytesIO(data))
            boot = tarfile.TarInfo(f'releases/{VERSION}/start.boot')
            boot.size = 4
            output.addfile(boot, io.BytesIO(b'boot'))
        return path
    safe = archive('safe')
    release, count = module.extract_archive(safe, folder / 'safe-runtime')
    assert release.read_bytes() == b'fixture only; never executed\n' and count == 2
    passed('data_filter_safe_extraction_only_no_execution')
    rejected('existing_extraction_target_rejected', lambda: module.extract_archive(safe, folder / 'safe-runtime'), 'already exists')
    bad = archive('traversal', '../outside')
    try:
        module.extract_archive(bad, folder / 'bad-runtime')
    except tarfile.FilterError:
        assert not (folder / 'outside').exists()
    else:
        raise AssertionError('unsafe traversal accepted')
    passed('data_filter_rejects_traversal')
    assets = folder / 'assets';assets.mkdir()
    fixture = copy.deepcopy(verified)
    archive_bytes = safe.read_bytes(); (assets / module.STANDALONE).write_bytes(archive_bytes)
    fixture['assets'][module.STANDALONE]['sha256'] = module.digest(archive_bytes)
    sums = ''.join(f'{fixture["assets"][name]["sha256"]}  {name}\n' for name in sorted(module.PAYLOADS))
    (assets / 'SHA256SUMS').write_text(sums)
    assert module.checked_archive(fixture, assets) == assets / module.STANDALONE
    passed('standalone_digest_and_seven_manifest_entries_accepted')
    (assets / module.STANDALONE).write_bytes(archive_bytes + b'corrupt')
    rejected('corrupt_standalone_rejected', lambda: module.checked_archive(fixture, assets), 'archive digest differs')
    (assets / 'SHA256SUMS').write_text(sums + sums.splitlines(True)[0])
    rejected('duplicate_payload_checksum_rejected', lambda: module.checked_archive(fixture, assets), 'duplicate payload checksum')
    evidence = folder / 'smokes';(evidence / 'h3').mkdir(parents=True)
    detail = {'status': 'PASS', 'checks': [{'status': 'PASS'} for _ in range(3)],
              'child_exits': {'release': 0, 'origin': 0}, 'ports_rebound': True}
    report = evidence / 'h3/result.json';report.write_text(json.dumps(detail))
    assert module.validate_smoke('core', 'PASS portable release TCP/TLS/UDP; 3 transports', evidence) == {}
    assert module.validate_smoke('gateway', 'PASS standalone gateway release readiness; 7 exchanges', evidence) == {}
    assert module.validate_smoke('h3', '', evidence)['ports_rebound'] is True
    passed('synthetic_three_seven_three_result_contracts')
    for name, mutate, message in [
        ('missing_H3_check', lambda d: d['checks'].pop(), 'checks did not all pass'),
        ('failed_H3_child', lambda d: d['child_exits'].update(origin=1), 'child exit differs'),
        ('missing_H3_rebind', lambda d: d.update(ports_rebound=False), 'port reuse was not proven'),
    ]:
        changed = copy.deepcopy(detail);mutate(changed);report.write_text(json.dumps(changed))
        rejected(name + '_rejected', lambda: module.validate_smoke('h3', '', evidence), message)
    planned = module.commands(Path('/never-executed/bin/gaoxy'), evidence)
    assert [(name, count, timeout) for name, command, count, timeout in planned] == [('core', 3, 150), ('gateway', 7, 150), ('h3', 3, 750)]
    passed('qualified_counts_commands_and_outer_deadlines_preserved')
    for name, command, _, _ in planned:
        assert str(Path('/never-executed/bin/gaoxy')) in command
    passed('every_smoke_uses_actual_downloaded_executable')
    missing_boot = folder / 'no-boot.tar.gz'
    with tarfile.open(missing_boot, 'w:gz') as output:
        member = tarfile.TarInfo('bin/gaoxy'); data = b'never execute'
        member.size = len(data); member.mode = 0o755
        output.addfile(member, io.BytesIO(data))
    rejected('missing_start_boot_rejected', lambda: module.extract_archive(missing_boot, folder / 'no-boot-runtime'), 'start.boot is missing')
    link_archive = folder / 'link.tar.gz'
    with tarfile.open(link_archive, 'w:gz') as output:
        member = tarfile.TarInfo('bin/gaoxy'); member.type = tarfile.SYMTYPE; member.linkname = '/outside'
        output.addfile(member)
    try:
        module.extract_archive(link_archive, folder / 'link-runtime')
    except tarfile.FilterError:
        pass
    else:
        raise AssertionError('unsafe absolute symlink accepted')
    passed('data_filter_rejects_absolute_symlink')


rejected('unreviewed_verifier_digest_rejected_before_import',
         lambda: module.configure(VERSION, '0' * 64), 'explicitly reviewed SHA256')
module.configure(VERSION, VERIFIER_HASH)
changed = copy.deepcopy(verified); changed['verifier_sha256'] = '0' * 64
rejected('artifact_receipt_from_other_verifier_rejected', lambda: module.validate_receipt(changed, BASELINE), 'receipt verifier digest differs')
with patch.object(module.importlib.util, 'spec_from_file_location', side_effect=AssertionError('must not import')):
    module.VERIFIER_SHA256 = '0' * 64
    rejected('wrong_verifier_never_imported', module.artifact_verifier, 'explicitly reviewed SHA256')
module.configure(VERSION, VERIFIER_HASH)

with patch.object(module.subprocess, 'check_output', side_effect=lambda args, **kw: (ROOT / args[2].split(':', 1)[1]).read_bytes()):
    hashes = module.source_script_hashes(BASELINE)
    assert len(hashes) == 11
passed('source_script_hash_guards_without_builds')
with patch.object(module.subprocess, 'check_output', return_value=b'wrong publication bytes'):
    rejected('source_script_mismatch_rejected', lambda: module.source_script_hashes(BASELINE), 'differs from publication source')
environment = module.host_environment()
host = json.loads(module.HOST_RECEIPT.read_text())
assert all(environment[name] == host['environment'][name] for name in ('LD_LIBRARY_PATH', 'NIX_LD_LIBRARY_PATH', 'ERL_FLAGS'))
assert environment['SSL_CERT_FILE'] == '/etc/ssl/certs/ca-certificates.crt'
passed('exact_prior_Nix_environment_and_verified_system_CA')

import difflib
(HERE / 'qualified-0.13.1-runtime-to-parameterized.patch').write_text(''.join(difflib.unified_diff(ORIGINAL.read_text().splitlines(True), RUNNER.read_text().splitlines(True), fromfile=str(ORIGINAL.relative_to(ROOT)), tofile=str(RUNNER.relative_to(ROOT)))))
receipt = {'status': 'PASS', 'task': 'downloaded-runtime-preparation-parameterized',
           'baseline': BASELINE, 'scope': 'offline fixture guard controls only; no runtime acceptance',
           'controls': len(checks), 'checks': checks,
           'qualified_parent_sha256': module.digest(ORIGINAL.read_bytes()),
           'runner_sha256': module.digest(RUNNER.read_bytes()),
           'controls_sha256': module.digest(Path(__file__).read_bytes()),
           'artifact_verifier_sha256': module.digest((HERE / 'verify-public-artifacts.py').read_bytes()),
           'system_CA_sha256': module.digest(module.CA.read_bytes()),
           'network_requests': 0, 'builds': 0, 'runtime_commands': 0,
           'actual_downloaded_runtime': 'NOT RUN: waiting for stable publication and parent signal',
           'sol_repair_rounds': 0, 'commands_finished': True}
(HERE / 'runtime-preparation.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
