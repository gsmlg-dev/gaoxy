#!/usr/bin/env python3
"""Single-command, non-overwriting scoped receipt collector; root runs gates."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
EVIDENCE = ROOT / 'docs/acceptance/evidence/m3/native-generation-checked-capture/1792107581748432565'
KICKOFF = EVIDENCE / 'kickoff1.json'
NEW_TEST = 'apps/gaoxy_proxy/test/managed_generation_checked_capture_test.exs'
NEW_MODULE = 'apps/gaoxy_http/lib/gaoxy/http/generation/accounting.ex'
FUTURE = {NEW_TEST, NEW_MODULE, 'apps/gaoxy_http/test/generation_checked_capture_test.exs', 'apps/gaoxy/test/admission_timeout_test.exs'}
SCOPED_PROXY = ['apps/gaoxy_proxy/lib/gaoxy/proxy/managed_generation_accounting.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex']
FORMAT = SCOPED_PROXY + [NEW_MODULE, 'apps/gaoxy_http/lib/gaoxy/http/generation.ex', 'apps/gaoxy_http/lib/gaoxy/http/resources.ex', 'apps/gaoxy/lib/gaoxy/admission.ex', NEW_TEST, 'apps/gaoxy_proxy/test/managed_generation_accounting_test.exs', 'apps/gaoxy_http/test/generation_checked_capture_test.exs', 'apps/gaoxy_proxy/test/upstream_groups_test.exs', 'apps/gaoxy_proxy/test/upstream_transports_test.exs', 'apps/gaoxy/test/admission_timeout_test.exs']
ACCOUNTING = ['apps/gaoxy_proxy/test/managed_generation_accounting_test.exs', NEW_TEST]
OWNERS = ['apps/gaoxy_proxy/test/upstream_groups_test.exs','apps/gaoxy_proxy/test/upstream_transports_test.exs','apps/gaoxy/test/admission_timeout_test.exs']
HTTP = ['apps/gaoxy_http/test/generation_checked_capture_test.exs','apps/gaoxy_http/test/generation_resources_test.exs','apps/gaoxy_http/test/generation_test.exs','apps/gaoxy_http/test/generation_loader_test.exs','apps/gaoxy_http/test/generation_release_deadline_test.exs','apps/gaoxy_http/test/generation_endpoint_validation_test.exs','apps/gaoxy_http/test/generation_resource_consistency_test.exs']
TEST_FILES = {'historical': [ACCOUNTING[0]], 'store': [HTTP[0], NEW_TEST], 'accounting': ACCOUNTING, 'owners': OWNERS, 'http': HTTP, 'constructor': ACCOUNTING + HTTP[:2] + OWNERS, 'integration': HTTP[:3]+ACCOUNTING, 'native': [NEW_TEST, 'apps/gaoxy_proxy/test/upstream_transport_generation_test.exs','apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs','apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs','apps/gaoxy_http/test/http2_network_test.exs','apps/gaoxy_http/test/native_proxy_seams_test.exs'], 'compat': OWNERS + ['apps/gaoxy/test/native_stream_test.exs','apps/gaoxy/test/cleanup_attachment_test.exs']}
TEST_FILES['acceptance'] = sorted(set(TEST_FILES['integration'] + TEST_FILES['http'] + TEST_FILES['native'] + TEST_FILES['compat']))
ANSI = re.compile(r'\x1b\][^\x07]*(?:\x07|\x1b\\)|\x1b\[[0-?]*[ -/]*[@-~]')
SUMMARY = re.compile(r'^\s*(?P<body>\d+\s+(?:doctests?|tests?|properties)(?:,\s*\d+\s+(?:doctests?|tests?|properties|failures?|skipped|excluded))*)\s*\.?\s*$', re.I)
FIELD = re.compile(r'(\d+)\s+(doctests?|tests?|properties|failures?|skipped|excluded)', re.I)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def git_identity():
    # No extra subprocess: support the worktree gitdir/common-dir reference layout.
    marker = ROOT / '.git'
    gitdir = marker if marker.is_dir() else (ROOT / marker.read_text().strip().split(':', 1)[1].strip()).resolve()
    common_marker = gitdir / 'commondir'
    common = (gitdir / common_marker.read_text().strip()).resolve() if common_marker.exists() else gitdir
    head = (gitdir / 'HEAD').read_text().strip()
    if not head.startswith('ref: '):
        return {'head': head, 'branch': None, 'ref': None, 'git_dir': str(gitdir), 'common_dir': str(common)}
    ref = head[5:]
    value = None
    for directory in (gitdir, common):
        candidate = directory / ref
        if candidate.is_file():
            value = candidate.read_text().strip()
            break
    if value is None:
        packed = common / 'packed-refs'
        for line in packed.read_text().splitlines() if packed.exists() else []:
            if not line.startswith(('#', '^')) and line.split()[1:] == [ref]:
                value = line.split()[0]
                break
    if value is None or not re.fullmatch(r'[a-f0-9]{40,64}', value):
        raise ValueError('Cannot resolve worktree HEAD')
    return {'head': value, 'branch': ref.removeprefix('refs/heads/'), 'ref': ref,
            'git_dir': str(gitdir), 'common_dir': str(common)}


def guard_snapshot():
    kickoff = json.loads(KICKOFF.read_text())
    paths = set(kickoff['source_manifest']) | set(SCOPED_PROXY) | FUTURE
    paths |= {'apps/gaoxy/test/test_helper.exs', 'apps/gaoxy_proxy/test/test_helper.exs'}
    paths |= {str(p.relative_to(ROOT)) for app in ('gaoxy', 'gaoxy_http')
              for p in (ROOT / 'apps' / app / 'lib').rglob('*.ex')}
    result = {}
    for relative in sorted(paths):
        path = ROOT / relative
        if not path.is_file():
            if relative not in FUTURE:
                raise FileNotFoundError(f'Required source guard absent: {path}')
            result[relative] = {'full_path': str(path), 'sha256': None, 'bytes': None, 'absent': True}
        else:
            data = path.read_bytes()
            result[relative] = {'full_path': str(path), 'sha256': hashlib.sha256(data).hexdigest(),
                                'bytes': len(data), 'absent': False}
    return result


def command(gate, seed):
    prefix = ['nix', 'develop', '--command', 'env', 'ERL_FLAGS=+S 2:2', 'MIX_ENV=test', 'unbuffer']
    if gate in TEST_FILES:
        return prefix + ['mix', 'test', '--warnings-as-errors', '--max-cases', '1', '--seed', str(seed)] + (['--only', 'checked_capture_constructor'] if gate == 'constructor' else []) + TEST_FILES[gate]
    if gate == 'format':
        return prefix + ['mix', 'format', '--check-formatted'] + [p for p in FORMAT if (ROOT / p).is_file()]
    if gate == 'compile':
        return prefix + ['mix', 'compile', '--warnings-as-errors']
    if gate == 'probe':
        return prefix + ['elixir', str(EVIDENCE / 'loaded-toolchain-probe1.exs')]
    if gate == 'formatter':
        return prefix + ['mix', 'format'] + [p for p in FORMAT if (ROOT / p).is_file()]
    if gate in ('core_consumer', 'http_consumer'):
        return prefix + ['env', 'GIT_CONFIG_COUNT=1', 'GIT_CONFIG_KEY_0=url.file:///tmp/gaoxy-consumer-local-git-diagnosis1-f2s_326d/locked-source.git.insteadOf', 'GIT_CONFIG_VALUE_0=https://github.com/mtrudel/thousand_island.git', 'bash', 'scripts/external-consumer.sh' if gate == 'core_consumer' else 'scripts/http-consumer.sh']
    return prefix + ['elixir', '--version']


def parse_log(raw):
    clean = ANSI.sub('', raw.decode('utf-8', errors='replace')).replace('\r', '\n')
    totals = dict(tests=0, doctests=0, properties=0, failures=0, skipped=0, excluded=0)
    summaries = []
    warnings = []
    expected_environment_warnings = []
    all_warnings = []
    exclusions = []
    for line in clean.splitlines():
        match = SUMMARY.fullmatch(line)
        if match and re.search(r'\b\d+\s+failures?\b', match['body'], re.I):
            counts = dict.fromkeys(totals, 0)
            for number, label in FIELD.findall(match['body']):
                label = label.lower()
                key = {'test': 'tests', 'doctest': 'doctests', 'failure': 'failures'}.get(label, label)
                counts[key] += int(number)
            summaries.append({'line': line, **counts})
            for key in totals:
                totals[key] += counts[key]
        if re.search(r'\bwarnings?\b', line, re.I) and not re.search(r'\b0\s+warnings?\b', line, re.I):
            all_warnings.append(line)
            if line == "warning: Git tree '/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation' is dirty":
                expected_environment_warnings.append(line)
            else:
                warnings.append(line)
        if re.match(r'^\s*Excluding tags:\s*(?!\[\s*\]\s*$)\S', line, re.I):
            exclusions.append(line)
    invoked = totals['tests'] + totals['doctests'] + totals['properties']
    return {'exunit_summaries': summaries, 'counts': totals,
            'test_invocations_including_doctests_properties': invoked,
            'executed_test_invocations': invoked - totals['skipped'] - totals['excluded'],
            'total_warning_count': len(all_warnings), 'all_warning_lines': all_warnings,
            'expected_environment_warning_lines': expected_environment_warnings,
            'warning_count': len(warnings), 'warning_lines': warnings,
            'unexpected_warning_lines': warnings,
            'exclusion_declarations': exclusions}


def group_alive(pgid):
    try:
        os.killpg(pgid, 0)
        return True
    except ProcessLookupError:
        return False


def signal_group(pgid, signum, actions):
    try:
        os.killpg(pgid, signum)
        actions.append({'signal': signal.Signals(signum).name, 'at_utc': utc(), 'sent': True})
    except ProcessLookupError:
        actions.append({'signal': signal.Signals(signum).name, 'at_utc': utc(), 'sent': False, 'reason': 'group_absent'})


def stop_and_join(process, actions):
    signal_group(process.pid, signal.SIGTERM, actions)
    end = time.monotonic() + 5
    while time.monotonic() < end and group_alive(process.pid):
        process.poll()  # Reap the direct child if it exits; never invent its exit.
        time.sleep(0.05)
    if group_alive(process.pid):
        signal_group(process.pid, signal.SIGKILL, actions)
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        return False
    end = time.monotonic() + 2
    while time.monotonic() < end and group_alive(process.pid):
        time.sleep(0.05)
    return not group_alive(process.pid)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('receipt_name', help='Unique stem; existing log/JSON is never overwritten')
    parser.add_argument('gate', choices=tuple(TEST_FILES) + ('format', 'compile', 'toolchain', 'probe', 'formatter', 'core_consumer', 'http_consumer'))
    parser.add_argument('seed', nargs='?', type=int, default=1)
    args = parser.parse_args()
    def interrupt_handler(signum, frame):
        raise KeyboardInterrupt(f'collector received {signal.Signals(signum).name}')
    for signum in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(signum, interrupt_handler)
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', args.receipt_name):
        parser.error('receipt_name must be a safe filename stem')
    if args.seed < 0:
        parser.error('seed must be nonnegative')
    log_path = EVIDENCE / (args.receipt_name + '.log')
    json_path = EVIDENCE / (args.receipt_name + '.json')
    # Claim both output names exclusively before starting any command.
    log_fd = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    try:
        json_fd = os.open(json_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    except BaseException:
        os.close(log_fd)
        # Preserve the claimed empty log too; use a fresh receipt name next time.
        raise
    record = {'kind': 'SCOPED_COMMAND_RECEIPT', 'gate': args.gate, 'seed': args.seed,
              'recorded_at_utc': utc(), 'cwd': str(ROOT), 'timeout_seconds': 600,
              'argv': command(args.gate, args.seed), 'script': str(Path(__file__).resolve()),
              'script_sha256': sha(Path(__file__)), 'kickoff_path': str(KICKOFF),
              'kickoff_sha256': sha(KICKOFF), 'log_path': str(log_path),
              'environment_overrides': {'ERL_FLAGS': '+S 2:2', 'MIX_ENV': 'test'},
              'parent_environment': {k: os.environ.get(k) for k in ('PATH', 'NIX_PATH', 'IN_NIX_SHELL', 'ERL_FLAGS', 'MIX_ENV')},
              'started': False, 'timed_out': False, 'interrupted': False,
              'actual_exit_code': None, 'command_wall_seconds': None, 'direct_process_joined': False,
              'process_group_absent': None, 'joined': False, 'shutdown_actions': []}
    process = None
    start = time.monotonic()
    try:
        record['git_before'] = git_identity()
        record['source_before'] = guard_snapshot()
        with os.fdopen(log_fd, 'wb', buffering=0) as output:
            log_fd = None
            record['started_at_utc'] = utc()
            command_start = time.monotonic()
            process = subprocess.Popen(record['argv'], cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            record.update(started=True, pid=process.pid, process_group=process.pid)
            try:
                process.wait(timeout=600)
            except subprocess.TimeoutExpired:
                record['timed_out'] = True
                stop_and_join(process, record['shutdown_actions'])
            except KeyboardInterrupt:
                record['interrupted'] = True
                stop_and_join(process, record['shutdown_actions'])
            # Allow normal descendants to finish before treating a group as orphaned.
            settle = time.monotonic() + 1
            while process.returncode is not None and group_alive(process.pid) and time.monotonic() < settle:
                time.sleep(0.05)
            # A returned direct process does not itself prove its group is gone.
            if process.returncode is not None and group_alive(process.pid):
                record['residual_group_after_direct_exit'] = True
                stop_and_join(process, record['shutdown_actions'])
            record['actual_exit_code'] = process.returncode
            record['direct_process_joined'] = process.returncode is not None
            record['process_group_absent'] = not group_alive(process.pid)
            record['joined'] = record['direct_process_joined'] and record['process_group_absent']
            record['command_wall_seconds'] = round(time.monotonic() - command_start, 6)
    except BaseException as error:
        record['collector_error'] = f'{type(error).__name__}: {error}'
        if process is not None:
            stop_and_join(process, record['shutdown_actions'])
            record['actual_exit_code'] = process.returncode
            record['direct_process_joined'] = process.returncode is not None
            record['process_group_absent'] = not group_alive(process.pid)
            record['joined'] = record['direct_process_joined'] and record['process_group_absent']
            record['command_wall_seconds'] = round(time.monotonic() - command_start, 6)
    finally:
        if log_fd is not None:
            os.close(log_fd)
        record['wall_seconds'] = round(time.monotonic() - start, 6)
        record['finished_at_utc'] = utc()
        try:
            record['git_after'] = git_identity()
            record['source_after'] = guard_snapshot()
            record['source_stable'] = (record.get('source_before') == record['source_after']
                                       and record.get('git_before') == record['git_after']
                                       and record['kickoff_sha256'] == sha(KICKOFF)
                                       and record['script_sha256'] == sha(Path(__file__)))
        except BaseException as error:
            record['post_guard_error'] = f'{type(error).__name__}: {error}'
            record['source_stable'] = False
        raw = log_path.read_bytes()
        record['log_sha256'] = hashlib.sha256(raw).hexdigest()
        record['log_bytes'] = len(raw)
        record.update(parse_log(raw))
        tests_required = args.gate in TEST_FILES or args.gate in ('core_consumer','http_consumer')
        record['tests_applicable'] = tests_required
        test_ok = (not tests_required or (
            record['executed_test_invocations'] > 0 and bool(record['exunit_summaries'])
            and all(record['counts'][k] == 0 for k in ('failures', 'skipped'))
            and (args.gate == 'constructor' or (record['counts']['excluded'] == 0 and not record['exclusion_declarations']))))
        formatter_ok = args.gate == 'formatter' and all(record['source_before'][p] == record['source_after'][p] for p in record['source_before'] if p not in FORMAT)
        passed = (record['actual_exit_code'] == 0 and record['joined'] and (record['source_stable'] or formatter_ok)
                  and not record['timed_out'] and not record['interrupted'] and record['warning_count'] == 0
                  and 'collector_error' not in record
                  and not record.get('residual_group_after_direct_exit', False) and test_ok)
        record['status'] = 'PASS' if passed else 'FAIL'
        with os.fdopen(json_fd, 'w') as receipt:
            json.dump(record, receipt, indent=2, sort_keys=True)
            receipt.write('\n')
        print(json.dumps({k: record[k] for k in ('status', 'gate', 'actual_exit_code', 'joined',
                                               'source_stable', 'counts', 'warning_count', 'wall_seconds')}))
        print(str(json_path))
    return 0 if record['status'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
