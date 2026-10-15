import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time

R = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
E = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-group-opening-boundary/1792066597490227419')
OWNED = ['apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_boundary.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex', 'apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs', 'docs/designs/m3-managed-h2-group-opening-boundary.md', 'docs/plans/m3-managed-h2-group-opening-boundary.md', 'docs/acceptance/m3-managed-h2-group-opening-boundary.md', 'AGENTS.md', 'mix.exs', 'mix.lock', 'flake.nix', 'flake.lock', 'apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/options.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex', 'apps/gaoxy_proxy/test/managed_h2_group_source_test.exs', 'apps/gaoxy_proxy/test/managed_h2_envelope_test.exs', 'apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs', 'apps/gaoxy_proxy/test/managed_h2_reservation_test.exs', 'apps/gaoxy_proxy/test/managed_h2_preparation_test.exs', 'apps/gaoxy_proxy/test/http3_guardian_test.exs', 'apps/gaoxy_proxy/test/http3_proxy_test.exs', 'apps/gaoxy_proxy/test/http3_session_client_test.exs', 'apps/gaoxy_proxy/test/http_fetch_completion_test.exs', 'apps/gaoxy_proxy/test/http_fetch_contract_test.exs', 'apps/gaoxy_proxy/test/http_headers_test.exs', 'apps/gaoxy_proxy/test/http_proxy_runtime_test.exs', 'apps/gaoxy_proxy/test/http_proxy_tls_test.exs', 'apps/gaoxy_proxy/test/http_proxy_wire_test.exs', 'apps/gaoxy_proxy/test/managed_h1_accounting_test.exs', 'apps/gaoxy_proxy/test/managed_h1_preparation_test.exs', 'apps/gaoxy_proxy/test/managed_h2_client_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_control_bounds_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_write_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs', 'apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs', 'apps/gaoxy_proxy/test/upstream_group_tls_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_generation_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_identity_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_transports_options_test.exs', 'apps/gaoxy_proxy/test/upstream_transports_test.exs', 'apps/gaoxy_proxy/test/upstream_groups_test.exs', 'apps/gaoxy_proxy/test/upstream_group_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_group_probe_test.exs', 'apps/gaoxy_http/test/managed_proxy_renderer_test.exs', 'apps/gaoxy_http/test/native_proxy_seams_test.exs']
FORMAT_PATHS = ['apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_boundary.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex', 'apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs']
PREFIX = ['nix', 'develop', '--command', 'env', 'ERL_FLAGS=+S 2:2', 'MIX_ENV=test', 'unbuffer']
TESTS = ['apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_source_test.exs', 'apps/gaoxy_proxy/test/managed_h2_envelope_test.exs', 'apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs', 'apps/gaoxy_proxy/test/managed_h2_reservation_test.exs', 'apps/gaoxy_proxy/test/managed_h2_preparation_test.exs']
COMPATIBILITY = ['apps/gaoxy_proxy/test/http3_guardian_test.exs', 'apps/gaoxy_proxy/test/http3_proxy_test.exs', 'apps/gaoxy_proxy/test/http3_session_client_test.exs', 'apps/gaoxy_proxy/test/http_fetch_completion_test.exs', 'apps/gaoxy_proxy/test/http_fetch_contract_test.exs', 'apps/gaoxy_proxy/test/http_headers_test.exs', 'apps/gaoxy_proxy/test/http_proxy_runtime_test.exs', 'apps/gaoxy_proxy/test/http_proxy_tls_test.exs', 'apps/gaoxy_proxy/test/http_proxy_wire_test.exs', 'apps/gaoxy_proxy/test/managed_h1_accounting_test.exs', 'apps/gaoxy_proxy/test/managed_h1_preparation_test.exs', 'apps/gaoxy_proxy/test/managed_h2_client_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_control_bounds_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_write_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs', 'apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs', 'apps/gaoxy_proxy/test/upstream_group_tls_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_generation_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_identity_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_transports_options_test.exs', 'apps/gaoxy_proxy/test/upstream_transports_test.exs', 'apps/gaoxy_proxy/test/upstream_groups_test.exs', 'apps/gaoxy_proxy/test/upstream_group_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_group_probe_test.exs', 'apps/gaoxy_http/test/managed_proxy_renderer_test.exs', 'apps/gaoxy_http/test/native_proxy_seams_test.exs']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot():
    return {p: sha(R / p) if (R / p).is_file() else None for p in OWNED}


def run(gate):
    if gate == 'toolchain':
        command = PREFIX + ['elixir', '--version']
    elif gate.startswith('red'):
        test_file = TESTS[1] if 'session' in gate else TESTS[0]
        command = PREFIX + ['mix', 'test', test_file, '--warnings-as-errors', '--max-cases', '1', '--seed', '33012']
    elif gate in ['green', 'fresh-tests'] or gate.startswith('green-repair'):
        command = PREFIX + ['mix', 'test'] + TESTS + ['--warnings-as-errors', '--max-cases', '1', '--seed', '33012']
    elif gate in ['compatibility', 'fresh-compatibility']:
        command = PREFIX + ['mix', 'test'] + COMPATIBILITY + ['--warnings-as-errors', '--max-cases', '1', '--seed', '33012']
    elif gate in ['format', 'fresh-format']:
        command = PREFIX + ['mix', 'format', '--check-formatted'] + FORMAT_PATHS
    elif gate == 'format-write':
        command = PREFIX + ['mix', 'format'] + FORMAT_PATHS
    elif gate in ['compile', 'fresh-compile']:
        command = PREFIX + ['mix', 'compile', '--warnings-as-errors', '--force']
    else:
        raise ValueError(gate)
    before = snapshot()
    stamp = str(time.time_ns())
    log = E / (gate + '-' + stamp + '.log')
    receipt = log.with_suffix('.json')
    started = time.monotonic()
    timed_out = False
    with log.open('xb') as output:
        process = subprocess.Popen(command, cwd=R, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            actual_exit = process.wait(timeout=600)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGTERM)
            try:
                actual_exit = process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                actual_exit = process.wait(timeout=10)
    after = snapshot()
    clean = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', log.read_text(errors='replace'))
    counts = []
    for match in re.finditer(r'(\d+) tests?, (\d+) failures?([^\n]*)', clean):
        trailer = match[3]
        skipped = sum(int(m) for m in re.findall(r'(\d+) skipped', trailer))
        excluded = sum(int(m) for m in re.findall(r'(\d+) excluded', trailer))
        counts.append({'tests': int(match[1]), 'failures': int(match[2]), 'skipped': skipped,
                       'excluded': excluded, 'executed': int(match[1]) - skipped - excluded})
    report = {'kind': 'GROUP_OPENING_BOUNDARY_ACTUAL_COMMAND', 'gate': gate,
              'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
              'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R, text=True).strip(),
              'argv': command, 'cwd': str(R), 'pid': process.pid,
              'actual_exit': actual_exit, 'timed_out': timed_out, 'process_joined': process.poll() is not None,
              'elapsed_ms': round((time.monotonic() - started) * 1000),
              'log': str(log.relative_to(R)), 'log_bytes': log.stat().st_size, 'log_sha256': sha(log),
              'collector_sha256': sha(Path(__file__)), 'source_before': before, 'source_after': after,
              'source_stable': before == after, 'counts': counts,
              'tests_executed': sum(c['executed'] for c in counts),
              'failures': sum(c['failures'] for c in counts),
              'skips': sum(c['skipped'] for c in counts), 'exclusions': sum(c['excluded'] for c in counts),
              'zero_skip_exclusion_configuration': '--only' not in command and '--exclude' not in command,
              'live_group_activation': 'NOT_RUN ACCOUNTING_NOT_READY', 'astra_recovery': '2/2 exhausted'}
    receipt.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ['gate', 'actual_exit', 'timed_out', 'process_joined',
          'source_stable', 'tests_executed', 'failures', 'skips', 'exclusions']}, indent=2))
    print('receipt', str(receipt.relative_to(R)), 'sha256', sha(receipt))
    if gate == 'toolchain' or actual_exit != 0:
        print(clean[-16000:])
    test_gate = gate in ['compatibility', 'fresh-compatibility'] or gate.startswith('red') or gate in ['green', 'fresh-tests'] or gate.startswith('green-repair')
    if timed_out or not report['process_joined']:
        raise SystemExit(1)
    if gate != 'format-write' and not report['source_stable']:
        raise SystemExit(1)
    if test_gate and not report['tests_executed']:
        raise SystemExit(1)
    if test_gate and (report['skips'] or report['exclusions']):
        raise SystemExit(1)
    raise SystemExit(actual_exit)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('gate')
    run(parser.parse_args().gate)
