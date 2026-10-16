#!/usr/bin/env python3
"""Freeze the completed initial gates for independent full SPEC then CODE."""
import datetime as dt
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
EVIDENCE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(paths, base):
    return {name: {'sha256': sha(base / name), 'bytes': (base / name).stat().st_size}
            for name in sorted(paths)}


def main():
    previous = json.loads((EVIDENCE / 'constructor-candidate-freeze2.json').read_text())
    names = set(previous['source_manifest'])
    names.add('apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs')
    for name in ('native-worker-browser-host6.exs', 'native-worker-browser-runner7.py',
                 'native-worker-browser-cohort3.exs', 'browser-command-collector3.py',
                 'scoped-command-collector4.py', 'full-stage-freeze2.py'):
        names.add(str((EVIDENCE / name).relative_to(ROOT)))
    names.update(('docs/designs/m3-native-worker-startup-accounting.md',
                  'docs/plans/m3-native-worker-startup-accounting.md',
                  'docs/acceptance/m3-native-worker-startup-accounting.md',
                  'implement-plan.md', 'AGENTS.md'))
    source = snapshot(names, ROOT)
    changed = [name for name, old in previous['source_manifest'].items()
               if source[name]['sha256'] != old['sha256']]
    production_changes = [name for name in changed if name.startswith('apps/') and '/lib/' in name]
    assert sorted(production_changes) == ['apps/gaoxy_http/lib/gaoxy/http/connection.ex',
                                          'apps/gaoxy_http/lib/gaoxy/http/http2/transport.ex']
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    assert head == '58307a7084298db309a93697b9102b2cc4c87eda'
    branch = subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT, text=True).strip()
    assert branch == 'codex/m3-h1-resource-foundation'
    gates = {}
    for name in ('core-green2', 'native-green5', 'preserve-http-green1',
                 'preserve-compat-green1', 'compile-green1', 'formatting9',
                 'core-consumer-green1', 'http-consumer-green1'):
        record = json.loads((EVIDENCE / (name + '.json')).read_text())
        assert record['status'] == 'PASS' and record['actual_exit_code'] == 0
        assert record['joined'] and record['source_stable'] and record['warning_count'] == 0
        assert sha(Path(record['log_path'])) == record['log_sha256']
        if record['tests_applicable']:
            assert record['executed_test_invocations'] > 0
            assert record['counts']['failures'] == record['counts']['skipped'] == record['counts']['excluded'] == 0
        gates[name] = {'sha256': sha(EVIDENCE / (name + '.json')), 'counts': record['counts']}
    browser_path = EVIDENCE / 'browser-green4/qualification.json'
    browser = json.loads(browser_path.read_text())
    browser_command = json.loads((EVIDENCE / 'browser-command4.json').read_text())
    assert browser_command['status'] == 'PASS' and browser_command['actual_exit_code'] == 0
    assert browser_command['joined'] and browser_command['owned_group_gone']
    assert not browser_command['descendant_cleanup']['forced']
    assert browser_command['descendant_cleanup']['remaining'] == []
    assert browser['status'] == 'PASS' and browser['executed'] == 2 and browser['source_stable']
    assert {case['mode'] for case in browser['cases']} == {'h2', 'h1'}
    assert all(case['status'] == 'PASS' for case in browser['cases'])
    assert all(row['exit'] == 0 and not row['forced'] and row['reader_joined'] and row['owned_group_gone'] for row in browser['joins'])
    for name, expected in browser['artifact_sha256'].items():
        assert sha(browser_path.parent / name) == expected
    protected = {
        '/home/gao/Workspace/gsmlg-opt/gaoxy/gaoxy-m1.1-fix-prompt.md':
            '7982874aacafe8bc4f4814740f25d1bd1e5bb35cbdc3938338ab132f2cdf9f1f',
        str(ROOT / 'codex-prompt.md'):
            '87112f8eb621966e0062c8611054bda49af0508693c46fa621de87a2b774038c',
    }
    assert all(sha(Path(name)) == value for name, value in protected.items())
    evidence_names = [str(path.relative_to(EVIDENCE)) for path in EVIDENCE.rglob('*') if path.is_file()]
    evidence = snapshot(evidence_names, EVIDENCE)
    result = {
        'kind': 'FULL_STAGE_CANDIDATE', 'status': 'FROZEN_FOR_FULL_SPEC_THEN_CODE',
        'at_utc': dt.datetime.now(dt.timezone.utc).isoformat(), 'head': head, 'branch': branch,
        'source_manifest': source,
        'source_manifest_sha256': hashlib.sha256(json.dumps(source, sort_keys=True).encode()).hexdigest(),
        'evidence_manifest': evidence,
        'evidence_manifest_sha256': hashlib.sha256(json.dumps(evidence, sort_keys=True).encode()).hexdigest(),
        'constructor_candidate': 'constructor-candidate-freeze2.json',
        'constructor_candidate_sha256': sha(EVIDENCE / 'constructor-candidate-freeze2.json'),
        'source_changes_since_constructor_checkpoint': changed,
        'production_changes_since_constructor_checkpoint': production_changes,
        'constructor_semantics_changed': False,
        'initial_gates': gates, 'browser_green4_sha256': sha(browser_path),
        'protected': protected,
        'counters': {'group_failed_GREEN': 39, 'root_failure_events': 51,
                     'stage_failed_GREEN': 9, 'stage_production_repairs': 3,
                     'stage_completed_fixture_repairs': 5, 'nonaccepted_diagnostic_failures': 4, 'astra_used': 2, 'astra_limit': 2},
        'remaining': ['full independent SPEC then CODE', 'fresh affected scoped union',
                      'fresh strict compile/format', 'fresh H2 and H1 browser',
                      'final documentation and byte custody', 'local commit'],
        'whole_M3': 'INCOMPLETE', 'publication': 'NOT_AUTHORIZED_FOR_THIS_STAGE',
    }
    destination = EVIDENCE / 'full-stage-candidate1.json'
    with destination.open('x') as output:
        json.dump(result, output, indent=2, sort_keys=True)
        output.write('\n')
    print(json.dumps({'status': result['status'], 'candidate': str(destination),
                      'sha256': sha(destination), 'source_files': len(source),
                      'evidence_files': len(evidence), 'source_manifest_sha256': result['source_manifest_sha256']}))


if __name__ == '__main__':
    main()
