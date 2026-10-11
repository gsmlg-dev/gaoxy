"""Build parent B21 admission from the preserved, actually executed TLS95 runs."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path.cwd().resolve()
OUT = ROOT / 'docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.3'


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        while chunk := stream.read(4096):
            digest.update(chunk)
    return digest.hexdigest()


def load(name):
    return json.loads((OUT / name).read_text())


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()


def write_new(name, value):
    path = OUT / name
    with path.open('xb') as stream:
        stream.write(encoded(value))
    return path


def records(name):
    result = {}
    for line in (OUT / name).read_text().splitlines():
        line = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', line)
        if line.startswith('TLS95_') and ' {' in line:
            marker, payload = line.split(' ', 1)
            result.setdefault(marker, []).append(json.loads(payload))
    return result


def check_raw(name, expected_ids, expected_exit):
    receipt = load(name + '.json')
    assert receipt['exit'] == expected_exit and not receipt['timed_out']
    for key in ['source_tree_match', 'build_tree_match', 'tool_sources_match',
                'tool_copy_match', 'hex_inventory_match', 'protected_inputs_match']:
        assert receipt[key] is True, key
    assert not receipt['peer_processes_after'] and not receipt['post_collection_errors']
    assert sha(OUT / receipt['log']) == receipt['log_sha256']
    raw = records(receipt['log'])
    cases = raw['TLS95_CASE']
    cleanup = raw['TLS95_CLEANUP']
    assert [row['case'] for row in cases] == expected_ids
    assert [row['case'] for row in cleanup] == expected_ids
    assert all(row['result'] == 'pass' and row['original_cleanup_deadline_met']
               for row in cleanup)
    for row in cleanup:
        assert all(row[key]['status'] == 'ok' for key in
                   ['open_registration', 'producer_registration', 'receipt_registration'])
        assert all(actor['joined'] and actor['join_ok'] and not actor['forced']
                   for actor in row['helpers'] + row['custodians'])
        assert row['peer']['port_joined'] and row['peer']['exit_status'] == 0
    summary, = raw['TLS95_SUMMARY']
    assert summary['executed_cases'] == len(expected_ids)
    assert summary['successful_cleanups'] == len(expected_ids)
    outcome, = raw['TLS95_WRAPPER_OUTCOME']
    assert outcome['post_identity']['status'] == 'OK'
    assert outcome['primary']['status'] == ('OK' if expected_exit == 0 else 'ERROR')
    return raw


candidate_ids = ['tls_h1_inventory_idle_close', 'tls_h2_inventory_idle_close',
                 'tls_h1_retire_isolation', 'tls_h2_retire_isolation',
                 'tls_failed_handshake_unconfirmed']
candidate = check_raw('tls95-candidate-green1', candidate_ids, 0)
baseline = check_raw('tls95-baseline-red2', candidate_ids[:2], 1)
assert all(row['result'] == 'pass' for row in candidate['TLS95_CASE'])
assert all(row['result'] == 'fail' for row in baseline['TLS95_CASE'])
for index, expected in enumerate([3, 4]):
    assert all(row['expected_resources'] == expected and
               row['observed_resources'] == expected
               for row in candidate['TLS95_CASE'][index]['inventory_observations'])
    mismatches = baseline['TLS95_CASE'][index]['inventory_mismatches']
    assert len(mismatches) == 2
    assert all(row['expected_resources'] == expected and row['observed_resources'] == expected - 2
               for row in mismatches)
failed_handshake = candidate['TLS95_CASE'][4]['primary']['value']
assert failed_handshake['public_failure'] == 'unknown_ca'
assert failed_handshake['original_completion'] == '{:error, :cleanup_unconfirmed}'
assert failed_handshake['retirement'] == '{:error, :cleanup_unconfirmed}'
assert failed_handshake['tls_reclamation_claimed'] is False
analysis = load('tls95-supplemental-analysis.json')
negative = load('tls95-baseline-negative-analysis.json')
assert analysis['status'] == 'PASS_TLS95_SUPPLEMENTAL'
assert analysis['loaded_identity_before_after'] == 'PASS_ORIGINAL_COMPARISONS_AND_MONOTONIC_LOADED_CLOSURE'
assert negative['status'] == 'PASS_EXPECTED_NEGATIVE_TLS95_REGISTRATION'
for path, expected in analysis['artifacts_sha256'].items():
    assert sha(ROOT / path) == expected
for path, expected in negative['inputs'].items():
    assert sha(OUT / path) == expected
review = load('tls95-0.21.3-independent-review.json')
assert not review['open_findings']
assert review['verdicts']['SPEC'] == review['verdicts']['CODE_QUALITY'] == 'PASS_STATIC_REVIEW'
for path, expected in review['reviewed_tooling_input_sha256'].items():
    assert sha(ROOT / path) == expected
fixture_review_path = OUT.parent / 'upstream-0.21.2/tls95-fixture-repair1-review.json'
fixture_review = json.loads(fixture_review_path.read_text())
assert fixture_review['specification_conformance'] == 'PASS_STATIC'
assert fixture_review['code_quality_review'] == 'PASS_STATIC'
for path, expected in fixture_review['input_sha256'].items():
    if path.startswith('integration/http_fetch_contract/managed_tls_tracking_'):
        assert sha(ROOT / path) == expected

before, = candidate['TLS95_IDENTITY_BEFORE']
after, = candidate['TLS95_IDENTITY_AFTER']
assert after['static_inputs_unchanged'] is True
assert before['applications'] == after['applications'] and before['inputs'] == after['inputs']
common_runtime = {key: value for key, value in before['runtime'].items()
                  if key not in ['actual_loaded_modules', 'mapped_files', 'jit_memory_exclusions']}
assert common_runtime == {key: value for key, value in after['runtime'].items()
                          if key not in ['actual_loaded_modules', 'mapped_files', 'jit_memory_exclusions']}
closure_counts = {}
for key, id_key in [('actual_loaded_modules', 'module'), ('mapped_files', 'path')]:
    old = {row[id_key]: row for row in before['runtime'][key]}
    new = {row[id_key]: row for row in after['runtime'][key]}
    assert len(old) == len(before['runtime'][key]) and len(new) == len(after['runtime'][key])
    assert all(new.get(identity) == row for identity, row in old.items())
    for row in new.values():
        if key == 'mapped_files':
            assert sha(row['path']) == row['sha256']
        elif row.get('origin') != 'ERTS_PRELOADED':
            assert row['disk_code_md5'] == row['loaded_code_md5']
            assert sha(row['beam_path']) == row['beam_sha256']
    closure_counts[key] = {'before': len(old), 'after': len(new), 'validated_new': len(new.keys() - old.keys())}
native_before = load('tls95-candidate-green1-environment-before.json')
native_after = load('tls95-candidate-green1-environment-after.json')
assert native_before == native_after
profiles = {
    'source': {'cohort': before['cohort'], 'applications': before['applications'], 'inputs': before['inputs']},
    'loaded': {'runtime': common_runtime, 'original_rows': before['runtime']['actual_loaded_modules'],
               'comparison': 'PASS_ORIGINAL_COMPARISONS_AND_MONOTONIC_LOADED_CLOSURE'},
    'native': {'environment': native_before, 'original_mapped_files': before['runtime']['mapped_files'],
               'comparison': 'PASS_ORIGINAL_COMPARISONS_AND_MONOTONIC_LOADED_CLOSURE'},
}
profile_paths = {key: write_new('h1-b21-normalized-' + key + '.json', value) for key, value in profiles.items()}
root_pem = ROOT / '.audit/m3-transport/upstream-0.21.3/tag-source/apps/ex_ssl/test/fixtures/pkix_identity/root.pem'
root_der = ROOT / '.audit/m3-transport/h1-b21-disposable-root.der'
assert not root_der.exists()
conversion = subprocess.run(['openssl', 'x509', '-in', str(root_pem), '-outform', 'DER', '-out', str(root_der)],
                            capture_output=True, timeout=10)
assert conversion.returncode == 0 and 1 <= root_der.stat().st_size <= 65536
inventory_path = OUT / 'h1-fixture-spec-inventory.json'
inventory = load(inventory_path.name)
h1_identity = load('h1-baseline1-artifacts/run-identity.json')
bindings = []


def row(kind, path, expected=None):
    path = Path(path).absolute()
    actual = sha(path)
    assert expected is None or actual == expected
    return {'kind': kind, 'path': str(path), 'sha256': actual}


assert len(inventory['runtime_source_paths']) == 175
bindings += [row('runtime_source', ROOT / path, inventory['source_sha256'][path])
             for path in inventory['runtime_source_paths']]
bindings += [row('loaded_beam', item['origin'], item['sha256']) for item in h1_identity['beams']]
bindings += [row('native_binary', item['path'], item['sha256']) for item in before['runtime']['mapped_files']]
native_binding = ROOT / '.audit/m3-transport/h1-b21-native-profile-binding.json'
with native_binding.open('xb') as stream:
    stream.write(encoded(profiles['native']))
bindings += [row('native_profile', native_binding),
             row('fixture_inventory', inventory_path),
             row('reviewed_input_manifest', ROOT / '.audit/m3-transport/tls95-0.21.3-tooling-verified-inputs.json')]
artifacts = []
for run, label in [('tls95-candidate-green1', 'candidate'), ('tls95-baseline-red2', 'baseline')]:
    artifacts += [row(label + '_log', OUT / (run + '.log')), row(label + '_receipt', OUT / (run + '.json'))]
artifacts += [row('source_' + phase, OUT / ('tls95-candidate-green1-source-' + phase + '.json'))
              for phase in ['before', 'after']]
source_after = write_new('h1-b21-normalized-source-after.json', profiles['source'])
artifacts += [row('source_before', profile_paths['source']), row('source_after', source_after)]
artifacts += [row('loaded_profile_' + phase, profile_paths['loaded']) for phase in ['before']]
# Each artifact path is unique; the same normalized identity digest is attested for both phases.
loaded_after = write_new('h1-b21-normalized-loaded-after.json', profiles['loaded'])
artifacts += [row('loaded_profile_after', loaded_after)]
artifacts += [row('native_profile_' + phase, OUT / ('tls95-candidate-green1-environment-' + phase + '.json'))
              for phase in ['before', 'after']]
native_after = write_new('h1-b21-normalized-native-after.json', profiles['native'])
artifacts += [row('native_profile_before', profile_paths['native']), row('native_profile_after', native_after)]
artifacts += [row('spec_review', OUT / 'h1-b21-spec-review.json'),
              row('code_review', fixture_review_path),
              row('tooling_review', OUT / 'tls95-0.21.3-independent-review.json'),
              row('qualification_analysis', OUT / 'tls95-supplemental-analysis.json'),
              row('qualification_analysis', OUT / 'tls95-baseline-negative-analysis.json')]
mapping = write_new('h1-b21-parent-semantic-extraction.json', {
    'status': 'PASS_PARENT_SEMANTIC_EXTRACTION', 'candidate_ids': candidate_ids,
    'baseline_ids': candidate_ids[:2], 'directed_identity_validation': closure_counts,
    'normalization': 'All original rows preserved; all current/new rows hash and original loaded/disk checks validated. No intersection.',
    'early_failure': 'tls95-baseline-red1: FAIL_PREFLIGHT_ZERO_CASES, excluded from negative oracle',
    'public_root_pem_sha256': sha(root_pem), 'root_der_sha256': sha(root_der),
    'conversion_exit': conversion.returncode, 'operational_certificate_issuance': False,
    'inputs': artifacts, 'builder_sha256': sha(Path(__file__)), 'binding_count': len(bindings),
    'accounting': 'BLOCKED_FEATURE_97', 'activation': 'DISABLED'})
artifacts += [row('qualification_analysis', mapping)]
identity = {}
for field, profile in [('source', 'source'), ('loaded_profile', 'loaded'), ('native_profile', 'native')]:
    identity[field + '_before_sha256'] = identity[field + '_after_sha256'] = sha(profile_paths[profile])
gate = {
    'schema_version': 1, 'status': 'PASS_TLS95_SUPPLEMENTAL', 'cohort': '0.21.3',
    'tag_commit': analysis['tag'], 'tree': analysis['tree'],
    'candidate': {'executed': 5, 'passed': 5, 'failed': 0, 'cleanup_passed': 5, 'exit': 0},
    'baseline': {'cohort': '0.21.1', 'executed': 2, 'passed': 0, 'failed': 2, 'cleanup_passed': 2,
                 'exit': 1, 'negative_oracle': 'EXACT_TLS_REGISTRATION_MISMATCH'},
    'registration': {protocol: {'expected': expected, 'baseline_observed': expected - 2,
                               'candidate_observed': expected, 'handoff': 'PASS'}
                     for protocol, expected in [('tls_h1', 3), ('tls_h2', 4)]},
    'identity': identity, 'reviews': {'spec': 'PASS', 'code': 'PASS', 'tooling': 'PASS'},
    'binding_files': bindings, 'artifacts': artifacts,
    'root_der': {'path': str(root_der), 'sha256': sha(root_der), 'bytes': root_der.stat().st_size,
                 'purpose': 'DISPOSABLE_TEST_ROOT'}}
assert all(0 < len(rows) <= 256 and len({r['path'] for r in rows}) == len(rows)
           for rows in [bindings, artifacts])
payload = encoded(gate)
assert len(payload) <= 65536
gate_path = ROOT / '.audit/m3-transport/h1-accounting-tls95-gate.json'
with gate_path.open('xb') as stream:
    stream.write(payload)
write_new('h1-b21-parent-gate-generation.json', {'status': 'PASS_PARENT_GATE_GENERATION',
          'path': str(gate_path), 'sha256': sha(gate_path), 'bytes': len(payload),
          'binding_rows': len(bindings), 'artifact_rows': len(artifacts),
          'B21_runtime': 'NOT_RUN', 'independent_CODE': 'NOT_RUN'})
print('PASS_PARENT_GATE_GENERATION', len(payload), 'bytes;', len(bindings), 'bindings')
