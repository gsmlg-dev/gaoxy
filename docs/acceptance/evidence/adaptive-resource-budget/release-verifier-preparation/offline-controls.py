"""Offline fixture controls only: no public queries, builds, or artifact execution."""
import ast
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import ssl
import subprocess
import tarfile
import tempfile
import zipfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
BASELINE = '84c7ff76461ada8aebaa34c567c61206bc963d83'
VERSION = '0.14.0'
OLD = ROOT / '.audit/release-0.13.1/public-verification/verify-public-artifacts.py'
NEW = HERE / 'verify-public-artifacts.py'
VERIFIED = ROOT / '.audit/release-0.13.1/public-verification/public-artifacts-mpybge0q'

def digest(data): return hashlib.sha256(data).hexdigest()
def load(path):
    spec = importlib.util.spec_from_file_location('audit_verifier', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def members(data, mode):
    with tarfile.open(fileobj=io.BytesIO(data), mode=mode) as archive:
        return [(copy.copy(member), archive.extractfile(member).read() if member.isfile() else None)
                for member in archive.getmembers()]

def packed(items, mode):
    result = io.BytesIO()
    with tarfile.open(fileobj=result, mode=mode) as archive:
        for original, data in items:
            member = copy.copy(original)
            if data is not None:
                member.size = len(data)
            archive.addfile(member, io.BytesIO(data) if data is not None else None)
    return result.getvalue()

def fixture(package, name, mutate=None):
    original = (VERIFIED / f'hex-{package}-0.13.1.tar').read_bytes()
    outer = members(original, 'r:')
    rewritten = []
    for member, data in outer:
        if member.name == 'metadata.config':
            data, count = re.subn(rb'(\{<<"version">>,\s*<<")0\.13\.1(">>\})',
                                  rb'\g<1>0.14.0\2', data)
            assert count == 1
        elif member.name == 'contents.tar.gz':
            inner = members(data, 'r:gz')
            inner = [(item, body.replace(b'"0.13.1"', b'"0.14.0"')
                      if item.name == 'mix.exs' else body) for item, body in inner]
            if mutate is not None:
                inner = mutate(inner)
            data = packed(inner, 'w:gz')
        rewritten.append((member, data))
    path = HERE / 'fixtures' / (name + '.tar')
    path.parent.mkdir(exist_ok=True)
    path.write_bytes(packed(rewritten, 'w:'))
    return path

def changed_manifest(replacement):
    return lambda items: [(member, replacement(body) if member.name == 'mix.exs' else body)
                          for member, body in items]

module = load(NEW)
module.configure(VERSION)
checks = []
def passed(name): checks.append({'check': name, 'status': 'PASS'})
def rejected(name, callback, message):
    try:
        callback()
    except ValueError as error:
        assert message in str(error), str(error)
    else:
        raise AssertionError(name + ' unexpectedly passed')
    passed(name)

assert module.ROOT == ROOT and module.VERSION == VERSION and module.TAG == 'v' + VERSION
assert len(module.PACKAGES) == 6 and len(module.EXPECTED) == 8 and len(module.PAYLOADS) == 7
assert module.ARTIFACT_NAME == 'gaoxy-0.14.0-linux-x86_64'
passed('version_root_and_six_eight_seven_cohort')
old_ast, new_ast = ast.parse(OLD.read_text()), ast.parse(NEW.read_text())
functions = lambda tree: {node.name: ast.dump(node, include_attributes=False)
                          for node in tree.body if isinstance(node, ast.FunctionDef)}
old_functions, new_functions = functions(old_ast), functions(new_ast)
for name in old_functions:
    if name not in {'source_files', 'check_hex_requirements', 'check_package', 'check_standalone', 'verify', 'main'}:
        assert old_functions[name] == new_functions[name], name
passed('reviewed_parser_pins_source_and_workflow_functions_unchanged')
assert '"cryptographic_build_attestation_verified": False' in NEW.read_text()
passed('attestation_remains_explicitly_false')
versions = module.expected_runtime_versions(BASELINE)
assert versions['hell'] == '0.1.3' and versions['abyss'] == '0.10.0'
assert all(versions[name] == '0.21.17' for name in module.RUNTIME_DEPENDENCIES)
passed('exact_baseline_dependency_lock_pins')
counts = {}
for package in module.PACKAGES:
    result = module.check_package(fixture(package, package + '-canonical'), package, BASELINE)
    expected = module.source_files(BASELINE, module.PACKAGES[package])
    assert result['source_file_count'] == len(expected)
    counts[package] = len(expected)
    passed('synthetic_version_fixture_exact_source_' + package)
for app, version in [('hell', '0.1.3'), ('abyss', '0.10.0')]:
    for mode in ['wrong', 'missing']:
        target = f'{app}: "== {version}"'.encode()
        replacement = f'{app}: "== 0.0.1"'.encode() if mode == 'wrong' else f'other_{app}: "== {version}"'.encode()
        path = fixture('gaoxy', app + '-' + mode,
                       changed_manifest(lambda body, a=target, b=replacement: body.replace(a, b)))
        rejected(app + '_' + mode + '_pin_rejected',
                 lambda p=path: module.check_package(p, 'gaoxy', BASELINE),
                 'manifest lacks exact ' + app + ' pin')
legacy = fixture('gaoxy', 'legacy-tuples', changed_manifest(lambda body:
    body.replace(b'hell: "== 0.1.3"', b'{:hell, "== 0.1.3"}')
        .replace(b'abyss: "== 0.10.0"', b'{:abyss, "== 0.10.0"}')))
module.check_package(legacy, 'gaoxy', BASELINE)
passed('reviewed_legacy_tuple_pins_accepted')
for app, version in [('hell', '0.1.3'), ('abyss', '0.10.0')]:
    requirements = {'meta': {'app': 'gaoxy'}, 'requirements': {a: {'app': a, 'requirement': '== ' + v, 'optional': False}
                                    for a, v in [('hell', '0.1.3'), ('abyss', '0.10.0')]}}
    module.check_hex_requirements(requirements, 'gaoxy')
    requirements['requirements'][app]['optional'] = True
    rejected(app + '_optional_requirement_rejected',
             lambda r=requirements: module.check_hex_requirements(r, 'gaoxy'), 'wrong required ' + app + ' pin')

def corrupt_source(items):
    target = next(member.name for member, data in items if member.name.startswith('lib/') and member.name.endswith('.ex'))
    return [(member, data + b'\n# offline source mismatch\n' if member.name == target else data)
            for member, data in items]
path = fixture('gaoxy', 'source-mismatch', corrupt_source)
rejected('changed_source_byte_rejected', lambda: module.check_package(path, 'gaoxy', BASELINE), 'package source differs')
path = fixture('gaoxy', 'source-missing', lambda items: [pair for pair in items if pair[0].name != next(m.name for m, d in items if m.name.startswith('lib/') and m.name.endswith('.ex'))])
rejected('missing_source_file_rejected', lambda: module.check_package(path, 'gaoxy', BASELINE), 'lib/priv file set differs')
module.configure('0.13.1')
module.check_source_versions(BASELINE)
passed('qualified_exact_source_version_and_vendor_app_accepted')
module.configure(VERSION)
rejected('publication_SHA_with_other_source_version_rejected', lambda: module.check_source_versions(BASELINE), 'publication source version differs')

for bad_version in ['v0.14.0', '0.014.0', '../0.14.0', '0.14']:
    rejected('invalid_version_' + bad_version + '_rejected',
             lambda v=bad_version: module.configure(v), 'SemVer')
module.configure(VERSION)
for package in module.PACKAGES:
    metadata = json.loads((VERIFIED / f'hex-{package}.json').read_text())
    for name, dependency in metadata['requirements'].items():
        if name in module.PACKAGES:
            dependency['requirement'] = '== ' + VERSION
    module.check_hex_requirements(metadata, package)
    passed('exact_Hex_identity_dependency_metadata_' + package)
    if package == 'gaoxy_test':
        metadata['requirements']['gaoxy_http3']['optional'] = False
        rejected('test_H3_optionality_change_rejected',
                 lambda: module.check_hex_requirements(metadata, package), 'sibling dependency')
    if package == 'gaoxy_http':
        metadata['requirements']['gaoxy']['requirement'] = '== 0.13.1'
        rejected('old_sibling_version_rejected',
                 lambda: module.check_hex_requirements(metadata, package), 'sibling dependency')
    if package == 'gaoxy_websock_adapter':
        metadata['meta']['app'] = 'gaoxy_websock_adapter'
        rejected('renamed_adapter_application_rejected',
                 lambda: module.check_hex_requirements(metadata, package), 'application identity')

def corrupt_priv(items):
    target = next(member.name for member, body in items if member.name.startswith('priv/') and member.isfile())
    return [(member, body + b'changed' if member.name == target else body) for member, body in items]
path = fixture('gaoxy_test', 'priv-mismatch', corrupt_priv)
rejected('changed_priv_byte_rejected', lambda: module.check_package(path, 'gaoxy_test', BASELINE), 'package source differs')
path = fixture('gaoxy_test', 'priv-missing', lambda items: [pair for pair in items if pair[0].name != next(m.name for m, d in items if m.name.startswith('priv/') and m.isfile())])
rejected('missing_priv_file_rejected', lambda: module.check_package(path, 'gaoxy_test', BASELINE), 'lib/priv file set differs')
def extra_source(items):
    member = tarfile.TarInfo('lib/uncommitted.txt')
    return items + [(member, b'not in requested commit')]
path = fixture('gaoxy', 'extra-file', extra_source)
rejected('extra_non_Elixir_library_file_rejected', lambda: module.check_package(path, 'gaoxy', BASELINE), 'lib/priv file set differs')
path = fixture('gaoxy', 'wrong-package-version', changed_manifest(lambda body: body.replace(b'version: "0.14.0"', b'version: "0.13.1"')))
rejected('wrong_packaged_manifest_version_rejected', lambda: module.check_package(path, 'gaoxy', BASELINE), 'manifest version differs')
path = fixture('gaoxy_websock_adapter', 'wrong-adapter-app', changed_manifest(lambda body: body.replace(b'app: :websock_adapter', b'app: :gaoxy_websock_adapter')))
rejected('wrong_packaged_adapter_app_rejected', lambda: module.check_package(path, 'gaoxy_websock_adapter', BASELINE), 'manifest app differs')
for unsafe in ['../outside', '/absolute']:
    blob = packed([(tarfile.TarInfo(unsafe), b'x')], 'w:')
    with tarfile.open(fileobj=io.BytesIO(blob), mode='r:') as archive:
        rejected('unsafe_package_path_' + unsafe + '_rejected', lambda: module.archive_members(archive), 'unsafe archive path')

# Exercise the retained Actions byte comparison using local ZIP payloads only.
with tempfile.TemporaryDirectory(prefix='actions-offline-', dir=HERE) as folder:
    folder = Path(folder)
    assets = {name: ('offline payload ' + name).encode() for name in module.EXPECTED}
    for name, data in assets.items():
        (folder / name).write_bytes(data)
    def action_zip(payloads):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            for name, body in payloads.items():
                archive.writestr(name, body)
        return data.getvalue()
    run = {'id': 1, 'head_sha': BASELINE, 'head_branch': 'main',
           'event': 'workflow_dispatch', 'status': 'completed', 'conclusion': 'success',
           'path': module.WORKFLOW_PATH, 'html_url': 'https://example.invalid/offline'}
    artifact = {'id': 2, 'name': module.ARTIFACT_NAME, 'expired': False,
                'workflow_run': {'id': 1, 'head_sha': BASELINE, 'head_branch': 'main'}}
    def compare(payloads, bad_digest=False):
        output = folder / ('comparison-' + str(len(list(folder.glob('comparison-*')))))
        output.mkdir()
        for name, data in assets.items():
            (output / name).write_bytes(data)
        data = action_zip(payloads)
        item = {**artifact, 'digest': 'sha256:' + ('0' * 64 if bad_digest else module.digest(data))}
        with patch.object(module, 'paginated_api', side_effect=lambda path, key: [run] if key == 'workflow_runs' else [item]), patch.object(module, 'command', return_value=data):
            receipt = {}
            module.check_workflow_artifact(BASELINE, output, receipt)
        return receipt
    receipt = compare(assets)
    assert receipt['release_build']['compared_file_count'] == 8
    assert receipt['release_build']['cryptographic_build_attestation_verified'] is False
    passed('eight_Actions_payload_bytes_match_without_attestation_claim')
    changed = dict(assets)
    changed['SHA256SUMS'] = b'x' * len(assets['SHA256SUMS'])
    rejected('same_size_wrong_Actions_payload_rejected', lambda: compare(changed), 'differs from public asset')
    rejected('wrong_Actions_ZIP_digest_rejected', lambda: compare(assets, True), 'ZIP digest differs')

# Read preserved standalone metadata; no runtime or source-built executable is used.
module.configure('0.13.1')
standalone = VERIFIED / module.STANDALONE
result = module.check_standalone(standalone, versions)
assert result['version'] == '0.13.1' and result['start_boot_sha256']
passed('qualified_standalone_boot_and_all_app_dependency_metadata')
module.configure(VERSION)
rejected('wrong_version_standalone_metadata_rejected', lambda: module.check_standalone(standalone, versions), 'missing regular archive member')

ca = Path('/etc/ssl/certs/ca-certificates.crt')
context = ssl.create_default_context(cafile=str(ca))
assert context.verify_mode == ssl.CERT_REQUIRED and context.check_hostname
passed('system_CA_loaded_with_hostname_and_certificate_verification')
receipt = {'status': 'PASS', 'mode': 'offline_preparation_only', 'baseline': BASELINE,
           'fixture_scope': 'synthetic provisional 0.14.0 metadata over qualified 0.13.1 lib/priv payloads at baseline; no next-release publication or runtime acceptance',
           'source_file_counts_derived_from_baseline': counts, 'total_source_files': sum(counts.values()),
           'future_source_counts': 'all lib/priv files derived from requested SHA matching remote publication tag; no fixed source count',
           'expected_packages': 6, 'expected_assets': 8, 'expected_payload_checksums': 7,
           'checked': len(checks), 'checks': checks,
           'source_sha256': digest(OLD.read_bytes()), 'prepared_sha256': digest(NEW.read_bytes()),
           'runner_sha256': digest(Path(__file__).read_bytes()),
           'system_CA': str(ca), 'system_CA_sha256': digest(ca.read_bytes()),
           'actual_public_verification': 'NOT RUN: waiting for publication source and successful release',
           'network_requests': 0, 'product_changes': False, 'sol_repair_rounds': 0}
(HERE / 'offline-controls.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
