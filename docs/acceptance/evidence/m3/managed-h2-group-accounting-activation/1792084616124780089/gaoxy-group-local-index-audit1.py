from pathlib import Path
import datetime, hashlib, json, stat, subprocess
R = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = R / 'docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089'
h = lambda data: hashlib.sha256(data).hexdigest()
def git(*args):
    return subprocess.check_output(['git', *args], cwd=R)
def save(p, data):
    with p.open('x') as f:
        f.write(json.dumps(data, indent=2) + '\n')
def record(p):
    full = R / p
    assert stat.S_ISREG(full.lstat().st_mode), ('not regular', p)
    data = full.read_bytes()
    return dict(path=p, bytes=len(data), sha256=h(data))
def verify_index(rows):
    for row in rows:
        assert h(git('show', ':' + row['path'])) == row['sha256'], ('index mismatch', row['path'])
        assert h((R / row['path']).read_bytes()) == row['sha256'], ('disk changed', row['path'])

assert git('branch', '--show-current').decode().strip() == 'codex/m3-h1-resource-foundation'
assert git('rev-parse', 'HEAD').decode().strip() == '7cff6e87edb9b67e2667897bfbb7ee7e0075162e'
assert git('diff', '--cached', '--name-only', '-z') == b''
dpath = E / 'final-document-source-rebind3.json'
d = json.loads(dpath.read_text())
assert {p:h((R / p).read_bytes()) for p in d['source_manifest']} == d['source_manifest']
p = d['additional_parent_plan']
assert h((R / p['path']).read_bytes()) == p['after_sha256']
for ext in ['md', 'json']:
    for role in ['spec', 'code']:
        assert (E / ('gaoxy-group-final-document-closure3-' + role + '1.' + ext)).is_file()
assert json.loads((E / 'final-document-closure3-adoption1.json').read_text())['verdict'] == 'PASS_NO_OPEN_FINDINGS_LOCAL_COMMIT_AUTHORIZED'
protect = {'/home/gao/Workspace/gsmlg-opt/gaoxy/gaoxy-m1.1-fix-prompt.md':'7982874aacafe8bc4f4814740f25d1bd1e5bb35cbdc3938338ab132f2cdf9f1f', str(R / 'codex-prompt.md'):'87112f8eb621966e0062c8611054bda49af0508693c46fa621de87a2b774038c'}
assert all(h(Path(p).read_bytes()) == digest for p, digest in protect.items())
tracked = git('diff', '--name-only', '-z', 'HEAD').split(b'\0')
untracked = git('ls-files', '--others', '--exclude-standard', '-z').split(b'\0')
paths = sorted({p.decode() for p in tracked + untracked if p})
allowed = set(d['source_manifest']) | {d['additional_parent_plan']['path']}
prefix = str(E.relative_to(R)) + '/'
assert paths and all(p in allowed or p.startswith(prefix) for p in paths), ('unexpected ownership', [p for p in paths if p not in allowed and not p.startswith(prefix)])
assert not any('codex-prompt.md' in p or 'gaoxy-m1.1-fix-prompt.md' in p or p.startswith('deps/') for p in paths)
non_evidence = [p for p in paths if not p.startswith(prefix)]
subprocess.run(['git', 'diff', '--check', '--', *non_evidence], cwd=R, check=True)
rows = [record(p) for p in paths]
inventory = E / 'precommit-byte-inventory1.json'
save(inventory, dict(kind='TASK_OWNED_PRECOMMIT_DISK_BYTE_INVENTORY', source_head=git('rev-parse', 'HEAD').decode().strip(), document_rebind=dict(path=dpath.name, sha256=h(dpath.read_bytes())), path_count=len(rows), total_bytes=sum(row['bytes'] for row in rows), files=rows, protected=protect, excludes_self=True, runtime_source_manifest_count=198, external_dependency_source='Exact original qualified0.21.10 cohort, disk identity retained in source map; deps not staged'))
rows.append(record(str(inventory.relative_to(R))))
staging = Path('/tmp/gaoxy-group-local-index-paths1.nul')
staging.write_bytes(b''.join(row['path'].encode() + b'\0' for row in rows))
subprocess.run(['git', 'add', '--pathspec-from-file=' + str(staging), '--pathspec-file-nul'], cwd=R, check=True)
assert set(git('diff', '--cached', '--name-only', '-z').decode().strip('\0').split('\0')) == {row['path'] for row in rows}
verify_index(rows)
subprocess.run(['git', 'diff', '--cached', '--check', '--', *non_evidence], cwd=R, check=True)
audit = E / 'git-index-byte-audit1.json'
save(audit, dict(kind='ACTUAL_TASK_OWNED_DISK_INDEX_BYTE_AUDIT', status='PASS', source_head=git('rev-parse', 'HEAD').decode().strip(), path_count=len(rows), total_bytes=sum(row['bytes'] for row in rows), mismatches=[], staged_path_set_exact=True, raw_log_artifact_bytes_preserved=True, inventory=dict(path=inventory.name, sha256=h(inventory.read_bytes())), source_doc_map_stable=True, protected=protect, independently_reviewed_source_and_document_closure='final-document-closure3-adoption1.json', index_tree_before_this_receipt=git('write-tree').decode().strip(), excludes_self=True, next='stage and separately byte-check this audit, then local conventional commit; verify actual commit blobs'))
subprocess.run(['git', 'add', '--', str(audit.relative_to(R))], cwd=R, check=True)
rows.append(record(str(audit.relative_to(R))))
verify_index(rows)
assert set(git('diff', '--cached', '--name-only', '-z').decode().strip('\0').split('\0')) == {row['path'] for row in rows}
assert all(h(Path(p).read_bytes()) == digest for p, digest in protect.items())
expected = Path('/tmp/gaoxy-group-local-commit-expected1.json')
expected.write_text(json.dumps(dict(files=rows, protected=protect, source_manifest=d['source_manifest'], document_rebind_sha256=h(dpath.read_bytes())), indent=2) + '\n')
print('PASS disk/index', len(rows), 'files', sum(row['bytes'] for row in rows), 'bytes; index tree', git('write-tree').decode().strip(), 'audit', h(audit.read_bytes()))
