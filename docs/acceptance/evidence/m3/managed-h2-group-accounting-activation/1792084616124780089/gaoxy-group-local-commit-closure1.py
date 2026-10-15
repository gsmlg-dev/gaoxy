from pathlib import Path
import hashlib, json, subprocess
R = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = R / 'docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089'
h = lambda data: hashlib.sha256(data).hexdigest()
def git(*args):
    return subprocess.check_output(['git', *args], cwd=R)
x = json.loads(Path('/tmp/gaoxy-group-local-commit-expected1.json').read_text())
head = git('rev-parse', 'HEAD').decode().strip()
tree = git('rev-parse', 'HEAD^{tree}').decode().strip()
assert git('show', '-s', '--format=%s', 'HEAD').decode().strip() == 'feat(proxy): enable bounded managed H2 upstream groups'
assert git('rev-parse', 'HEAD^').decode().strip() == '7cff6e87edb9b67e2667897bfbb7ee7e0075162e'
expected = {row['path'] for row in x['files']}
assert set(git('diff-tree', '--no-commit-id', '--name-only', '-r', '-z', head).decode().strip('\0').split('\0')) == expected
for row in x['files']:
    assert h(git('show', head + ':' + row['path'])) == row['sha256'] == h((R / row['path']).read_bytes()), row['path']
committed, external = {}, {}
for p, digest in x['source_manifest'].items():
    assert h((R / p).read_bytes()) == digest
    if p.startswith('deps/'):
        external[p] = digest
    else:
        assert h(git('show', head + ':' + p)) == digest, p
        committed[p] = digest
assert all(h(Path(p).read_bytes()) == digest for p,digest in x['protected'].items())
assert not git('diff', '--cached', '--name-only') and not git('diff', '--name-only')
assert git('status', '--porcelain', '--untracked-files=all') == b''
receipt = E / 'local-commit-closure1.json'
d = dict(kind='ACTUAL_LOCAL_MANAGED_H2_GROUP_ACTIVATION_FEATURE_COMMIT_CUSTODY', status='PASS_LOCAL_FEATURE_COMMIT', feature_commit=head, feature_tree=tree, parent='7cff6e87edb9b67e2667897bfbb7ee7e0075162e', path_count=len(x['files']), total_bytes=sum(row['bytes'] for row in x['files']), all_task_disk_index_commit_bytes_equal=True, all_changed_paths_exact=True, committed_source_count=len(committed), committed_source_manifest=committed, external_dependency_source_count=len(external), external_dependency_source_manifest=external, final_document_rebind=dict(path='final-document-source-rebind3.json',sha256=x['document_rebind_sha256']), actual_runtime_aggregate=dict(path='fresh-final-gates-aggregate7.json',sha256=h((E / 'fresh-final-gates-aggregate7.json').read_bytes())), counter_ledger=dict(path='counter-ledger15.json',sha256=h((E / 'counter-ledger15.json').read_bytes())), failed_green=24, ordered_root_repair_events=27, astra='2/2 exhausted unchanged no third round', historical_negative_cleanup='UNCONFIRMED_WITH_RETAINED_FAILURE', protected=x['protected'], task_worktree_clean_before_receipt=True, stage='DONE_LOCALLY_BOUNDED_GROUP_ACCOUNTING_ACTIVATION', remaining_M3='Router resource-sidecar consistency, H2 Generation accounting/activation, full matrix/rotation/reload, standalone and sustained load; no fullM3 acceptance', publication='NOT_RUN_NOT_AUTHORIZED', deployment='NOT_RUN', next='commit this factual closure receipt separately; retain worktree and automatically proceed to next bounded slice')
with receipt.open('x') as f:
    f.write(json.dumps(d, indent=2) + '\n')
print('ACTUAL feature commit', head, 'tree', tree, 'verified',len(x['files']),'task paths;',len(committed),'committed source files and',len(external),'external dependency identities; closure',h(receipt.read_bytes()))
