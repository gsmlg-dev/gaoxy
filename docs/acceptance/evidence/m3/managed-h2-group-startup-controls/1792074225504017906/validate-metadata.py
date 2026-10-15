import hashlib
import json
from pathlib import Path
import re
import sys

R = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


receipt = Path(sys.argv[1]).resolve()
run = json.loads(receipt.read_text())
assert run['gate'] in ['metadata', 'fresh-metadata']
assert run['actual_exit'] == 0 and run['process_joined'] and run['source_stable']
assert not run['timed_out'] and run['tests_executed'] == 0
assert run['skips'] == run['exclusions'] == 0
log = R / run['log']
assert sha(log) == run['log_sha256']
clean = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', log.read_text())
records = []
for line in clean.splitlines():
    if line.startswith('{'):
        value = json.loads(line)
        if value.get('kind') == 'CANONICAL_PROBE_STARTUP_SOURCE_CATALOG_METADATA_ONLY':
            records.append(value)
assert len(records) == 1
record = records[0]
assert record['tests_executed'] == 0 and record['owner_or_probe_started'] is False
assert record['private_startup_trace'] is False
assert record['startup_maximum'] == 'UNPROVED' and record['reservation_bytes'] is None
assert record['source_to_beam_reproducibility'] == 'NOT_CLAIMED'
assert record['exact_marker_identity_preserved'] is True
assert record['generated_child_spec'] == record['public_supervisor_child_spec']
assert record['elixir_version'] == '1.18.5' and record['otp_version'] == '28.5.0.7'
assert record['otp_release'] == '28'
candidate = json.loads((E / 'design-readiness-candidate2.json').read_text())
for field, expected in [
    ('canonical_startup_sources', candidate['canonical_source_hashes']),
    ('supplemental_metadata_sources', candidate['supplemental_metadata_source_hashes'])
]:
    supplied = {row['path']: row['sha256'] for row in record[field]}
    assert supplied == expected
    assert all(sha(Path(path)) == digest for path, digest in supplied.items())
modules = record['modules']
assert len(modules) == 4
assert {row['module'] for row in modules} == {
    'DynamicSupervisor', 'GenServer', 'Supervisor', 'Gaoxy.Proxy.UpstreamGroups.Probe'
}
for row in modules:
    assert row['module_md5_match'] and row['object_disk_sha256_match']
    assert row['loaded_module_md5'] == row['loaded_module_md5_after']
    assert row['loaded_module_md5'] == row['code_path_object_module_md5'] == row['disk_beam_module_md5']
    assert re.fullmatch('[0-9a-f]{32}', row['loaded_module_md5'])
    assert 'loaded_binary_sha256' not in row
    origin, obj, disk = [Path(row[key]) for key in [
        'loaded_module_origin', 'code_path_object_path', 'disk_beam_path'
    ]]
    assert origin.resolve() == obj.resolve() == disk.resolve()
    assert sha(obj) == row['code_path_object_sha256'] == row['disk_beam_sha256'] == sha(disk)
    if row['compile_source_sha256'] is not None:
        assert sha(Path(row['compile_source'])) == row['compile_source_sha256']
probe_source = record['probe_source']
assert probe_source['path'] == str(R / 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex')
assert probe_source['sha256'] == sha(Path(probe_source['path']))
assert probe_source['sha256'] == candidate['source_hashes']['apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex']
for name, root in [('elixir', record['canonical_elixir_root']),
                   ('mix', record['canonical_elixir_root']), ('erl', record['canonical_otp_root'])]:
    executable = record['executables'][name]
    assert str(Path(executable['path']).resolve()) == executable['resolved_path']
    assert executable['resolved_path'].startswith(root + '/')
out = receipt.with_name(receipt.stem + '-validated.json')
result = {
    'kind': 'AUTHENTICATED_METADATA_ONLY_RECORD', 'status': 'PASS_METADATA_ONLY',
    'command_receipt': str(receipt.relative_to(R)), 'command_receipt_sha256': sha(receipt),
    'log_sha256': sha(log), 'validator_sha256': sha(Path(__file__)),
    'modules': 4, 'canonical_sources': 6, 'supplemental_sources': 3,
    'tests_executed': 0, 'owner_or_probe_started': False,
    'supported_loaded_module_md5_and_object_disk_identity': True,
    'captured_loaded_binary_or_reproducible_source_to_beam_claim': False,
    'record': record
}
with out.open('x') as output:
    output.write(json.dumps(result, indent=2) + '\n')
print(json.dumps({'artifact': str(out.relative_to(R)), 'sha256': sha(out), 'status': result['status']}))
