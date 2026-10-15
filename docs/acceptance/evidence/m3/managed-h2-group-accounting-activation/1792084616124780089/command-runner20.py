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
E = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation/docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089')
OWNED = ['AGENTS.md', 'apps/gaoxy/lib/gaoxy/admission.ex', 'apps/gaoxy/lib/gaoxy/lifecycle.ex', 'apps/gaoxy/lib/gaoxy/service.ex', 'apps/gaoxy_http/lib/gaoxy/http/exchange.ex', 'apps/gaoxy_http/lib/gaoxy/http/generation.ex', 'apps/gaoxy_http/lib/gaoxy/http/resources.ex', 'apps/gaoxy_http/lib/gaoxy/http/router.ex', 'apps/gaoxy_http/test/managed_proxy_renderer_test.exs', 'apps/gaoxy_http/test/native_proxy_seams_test.exs', 'apps/gaoxy_proxy/lib/gaoxy/proxy/application.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/group_endpoint.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/http_fetch_client.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_client.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_boundary.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_preparation.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/options.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports/options.ex', 'apps/gaoxy_proxy/test/http3_guardian_test.exs', 'apps/gaoxy_proxy/test/http3_proxy_test.exs', 'apps/gaoxy_proxy/test/http3_session_client_test.exs', 'apps/gaoxy_proxy/test/http_fetch_completion_test.exs', 'apps/gaoxy_proxy/test/http_fetch_contract_test.exs', 'apps/gaoxy_proxy/test/http_headers_test.exs', 'apps/gaoxy_proxy/test/http_proxy_runtime_test.exs', 'apps/gaoxy_proxy/test/http_proxy_tls_test.exs', 'apps/gaoxy_proxy/test/http_proxy_wire_test.exs', 'apps/gaoxy_proxy/test/managed_h1_accounting_test.exs', 'apps/gaoxy_proxy/test/managed_h1_preparation_test.exs', 'apps/gaoxy_proxy/test/managed_h2_activation_reservation_test.exs', 'apps/gaoxy_proxy/test/managed_h2_client_test.exs', 'apps/gaoxy_proxy/test/managed_h2_envelope_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_control_bounds_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_peer_startup_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_write_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_preopen_control_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_probe_arguments_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_probe_boundary_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_source_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_startup_catalog_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_startup_projection_test.exs', 'apps/gaoxy_proxy/test/managed_h2_preparation_test.exs', 'apps/gaoxy_proxy/test/managed_h2_reservation_test.exs', 'apps/gaoxy_proxy/test/support/managed_h2_control_projection.exs', 'apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py', 'apps/gaoxy_proxy/test/support/managed_h2_fixed_peer_startup_test.py', 'apps/gaoxy_proxy/test/support/managed_h2_group_startup_projection.exs', 'apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs', 'apps/gaoxy_proxy/test/upstream_group_probe_test.exs', 'apps/gaoxy_proxy/test/upstream_group_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_group_tls_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_test.exs', 'apps/gaoxy_proxy/test/upstream_groups_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_generation_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_identity_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_transports_options_test.exs', 'apps/gaoxy_proxy/test/upstream_transports_test.exs', 'deps/elixir_quic/mix.exs', 'deps/elixir_quic_http3/mix.exs', 'deps/ex_ssl/mix.exs', 'deps/http_core/mix.exs', 'deps/http_fetch/lib/http/promise.ex', 'deps/http_fetch/lib/http/request_completion.ex', 'deps/http_fetch/mix.exs', 'deps/http_runtime/mix.exs', 'deps/http_web_socket/mix.exs', 'docs/acceptance/m3-managed-h2-group-accounting-activation.md', 'docs/acceptance/m3-managed-h2-group-opening-boundary.md', 'docs/acceptance/m3-managed-h2-group-preopen-control.md', 'docs/acceptance/m3-managed-h2-group-probe-boundary.md', 'docs/acceptance/m3-managed-h2-group-startup-controls.md', 'docs/designs/m3-managed-h2-group-accounting-activation.md', 'docs/designs/m3-managed-h2-group-opening-boundary.md', 'docs/designs/m3-managed-h2-group-preopen-control.md', 'docs/designs/m3-managed-h2-group-probe-boundary.md', 'docs/designs/m3-managed-h2-group-startup-controls.md', 'docs/plans/m3-managed-h2-group-accounting-activation.md', 'docs/plans/m3-managed-h2-group-opening-boundary.md', 'docs/plans/m3-managed-h2-group-preopen-control.md', 'docs/plans/m3-managed-h2-group-probe-boundary.md', 'docs/plans/m3-managed-h2-group-startup-controls.md', 'flake.lock', 'flake.nix', 'implement-plan.md', 'integration/http_fetch_contract/managed_h2_fixed_qualification.py', 'mix.exs', 'mix.lock', 'scripts/generate-fixtures.sh', 'scripts/managed_h2_group_startup_sources.exs']
OWNED += ['apps/gaoxy_proxy/test/managed_h2_group_accounting_session_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_control_preflight_test.exs']
FORMAT_PATHS = ['apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex', 'apps/gaoxy_proxy/test/managed_h2_group_preopen_control_test.exs']
PREFIX = ['nix', 'develop', '--command', 'env', 'ERL_FLAGS=+S 2:2', 'MIX_ENV=test', 'unbuffer']
TESTS = ['apps/gaoxy_proxy/test/managed_h2_group_preopen_control_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_startup_projection_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_startup_catalog_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_probe_arguments_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_probe_boundary_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_boundary_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_session_boundary_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_source_test.exs', 'apps/gaoxy_proxy/test/managed_h2_envelope_test.exs']
COMPATIBILITY = ['apps/gaoxy_proxy/test/http3_guardian_test.exs', 'apps/gaoxy_proxy/test/http3_proxy_test.exs', 'apps/gaoxy_proxy/test/http3_session_client_test.exs', 'apps/gaoxy_proxy/test/http_fetch_completion_test.exs', 'apps/gaoxy_proxy/test/http_fetch_contract_test.exs', 'apps/gaoxy_proxy/test/http_headers_test.exs', 'apps/gaoxy_proxy/test/http_proxy_runtime_test.exs', 'apps/gaoxy_proxy/test/http_proxy_tls_test.exs', 'apps/gaoxy_proxy/test/http_proxy_wire_test.exs', 'apps/gaoxy_proxy/test/managed_h1_accounting_test.exs', 'apps/gaoxy_proxy/test/managed_h1_preparation_test.exs', 'apps/gaoxy_proxy/test/managed_h2_client_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_control_bounds_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_write_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_generation_exclusion_test.exs', 'apps/gaoxy_proxy/test/upstream_group_member_limits_test.exs', 'apps/gaoxy_proxy/test/upstream_group_tls_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_group_transport_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_generation_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_h2_identity_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_identity_test.exs', 'apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_transports_options_test.exs', 'apps/gaoxy_proxy/test/upstream_transports_test.exs', 'apps/gaoxy_proxy/test/upstream_groups_test.exs', 'apps/gaoxy_proxy/test/upstream_group_proxy_test.exs', 'apps/gaoxy_proxy/test/upstream_group_probe_test.exs', 'apps/gaoxy_http/test/managed_proxy_renderer_test.exs', 'apps/gaoxy_http/test/native_proxy_seams_test.exs']
OWNED += ['apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py', 'apps/gaoxy_proxy/test/support/managed_h2_fixed_peer_startup_test.py', 'apps/gaoxy_proxy/test/managed_h2_fixed_peer_startup_test.exs', 'scripts/generate-fixtures.sh', 'integration/http_fetch_contract/managed_h2_fixed_qualification.py']
FORMAT_PATHS += ['apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_peer_startup_test.exs']
FIXTURE_TESTS = ['apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_release_order_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_write_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_control_bounds_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_peer_startup_test.exs']

FORMAT_PATHS += ['apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/group_endpoint.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/probe.ex', 'apps/gaoxy_proxy/test/managed_h2_group_control_preflight_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_session_test.exs', 'apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_test.exs', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups.ex', 'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_groups/options.ex']


OWNED += ['apps/gaoxy_proxy/test/managed_h2_group_accounting_transitions_test.exs']
FORMAT_PATHS += ['apps/gaoxy_proxy/test/managed_h2_group_accounting_transitions_test.exs']

OWNED += ['apps/gaoxy_proxy/test/managed_h2_group_accounting_probe_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_pin_response_test.exs']
FORMAT_PATHS += ['apps/gaoxy_proxy/test/managed_h2_group_accounting_probe_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_pin_response_test.exs']

OWNED += ['apps/gaoxy_proxy/test/support/managed_h2_group_fixture.exs', 'apps/gaoxy_proxy/test/managed_h2_group_startup_reservation_test.exs']
FORMAT_PATHS += ['apps/gaoxy_proxy/test/support/managed_h2_group_fixture.exs', 'apps/gaoxy_proxy/test/managed_h2_group_startup_reservation_test.exs']

OWNED += ['apps/gaoxy_proxy/test/managed_h2_group_control_forms_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_failure_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_activation_test.exs']
FORMAT_PATHS += ['apps/gaoxy_proxy/test/managed_h2_group_control_forms_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_failure_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_activation_test.exs']

OWNED += ['apps/gaoxy_proxy/test/managed_h2_group_public_endpoint_host_test.exs']
FORMAT_PATHS += ['apps/gaoxy_proxy/test/managed_h2_group_public_endpoint_host_test.exs']

OWNED += ['apps/gaoxy_proxy/test/managed_h2_group_session_control_test.exs']
FORMAT_PATHS += ['apps/gaoxy_proxy/test/managed_h2_group_session_control_test.exs']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot():
    return {p: sha(R / p) if (R / p).is_file() else None for p in OWNED}


def run(gate):
    if gate in ['session-control-red1', 'session-control-green1', 'fresh-session-control']:
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_session_control_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate == 'startup-reservation-green2':
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_startup_reservation_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate == 'public-endpoint-host1':
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_public_endpoint_host_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate in ['control-forms-red1', 'control-forms-red2', 'control-forms-green1', 'fresh-control-forms']:
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_control_forms_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate in ['group-live-red1', 'group-live-red2', 'group-live-green1', 'fresh-group-live']:
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_endpoint_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_lifecycle_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_failure_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_activation_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate in ['startup-reservation-red1', 'startup-reservation-red2', 'startup-reservation-green1', 'fresh-startup-reservation']:
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_startup_reservation_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate == 'identity-diagnostic5':
        command = PREFIX + ['mix', 'run', '--no-start', str(E / 'gaoxy-h2-accounting-identity-diagnostic5.exs')]
    elif gate in ['probe-red1', 'probe-red2', 'probe-green1', 'probe-green2', 'fresh-probe']:
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_probe_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate in ['pin-response-red1', 'pin-response-green1', 'fresh-pin-response']:
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_pin_response_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate == 'identity-diagnostic4':
        command = PREFIX + ['mix', 'run', '--no-start', 'docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089/gaoxy-h2-accounting-identity-diagnostic4.exs']
    elif gate == 'identity-diagnostic2':
        command = PREFIX + ['mix', 'run', '--no-start', 'docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089/gaoxy-h2-accounting-identity-diagnostic2.exs']
    elif gate == 'identity-diagnostic1':
        command = PREFIX + ['mix', 'run', '--no-start', 'docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089/gaoxy-h2-accounting-identity-diagnostic1.exs']
    elif gate in ['transitions-red1', 'transitions-red2', 'transitions-green1', 'transitions-green2', 'fresh-transitions']:
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_transitions_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate == 'preflight-red1':
        command = PREFIX + ['elixir', '-e', 'ExUnit.start(seed: 33015, max_cases: 1); Code.require_file("apps/gaoxy_proxy/test/managed_h2_group_control_preflight_test.exs")']
    elif gate in ['preflight-green1', 'fresh-preflight']:
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_control_preflight_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate == 'format-preflight-test-write':
        command = PREFIX + ['mix', 'format', 'apps/gaoxy_proxy/test/managed_h2_group_control_preflight_test.exs']
    elif gate in ['session-red1', 'session-red2', 'session-green1', 'fresh-session']:
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_session_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate == 'format-session-test-write':
        command = PREFIX + ['mix', 'format', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_session_test.exs']
    elif gate in ['accounting-red1', 'accounting-red2', 'accounting-red3', 'accounting-green1', 'accounting-green2', 'accounting-green3', 'fresh-accounting']:
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate in ['owner-red1', 'owner-red2', 'owner-green1', 'owner-green2', 'fresh-owner']:
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate in ['peer-startup-red', 'peer-startup', 'fresh-peer-startup']:
        command = ['/tmp/gaoxy-m3-h2-soak-venv/bin/python', '-B', 'apps/gaoxy_proxy/test/support/managed_h2_fixed_peer_startup_test.py', '-v']
    elif gate in ['fixture-tests', 'fresh-fixture-tests']:
        command = PREFIX + ['mix', 'test'] + FIXTURE_TESTS + ['--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate == 'startup-exunit-red':
        command = PREFIX + ['mix', 'test', 'apps/gaoxy_proxy/test/managed_h2_fixed_endpoint_test.exs', 'apps/gaoxy_proxy/test/managed_h2_fixed_peer_startup_test.exs', '--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate == 'toolchain':
        command = PREFIX + ['elixir', '--version']
    elif gate.startswith('red'):
        command = PREFIX + ['mix', 'test'] + TESTS[:1] + ['--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate in ['green', 'fresh-tests'] or gate.startswith('green-repair'):
        command = PREFIX + ['mix', 'test'] + TESTS + ['--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate in ['compatibility', 'fresh-compatibility']:
        command = PREFIX + ['mix', 'test'] + COMPATIBILITY + ['--warnings-as-errors', '--max-cases', '1', '--seed', '33015']
    elif gate in ['format', 'fresh-format']:
        command = PREFIX + ['mix', 'format', '--check-formatted'] + [p for p in FORMAT_PATHS if (R / p).is_file()]
    elif gate == 'format-new-tests-write':
        command = PREFIX + ['mix', 'format', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs', 'apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_test.exs']
    elif gate == 'format-test-write':
        command = PREFIX + ['mix', 'format'] + TESTS[:1]
    elif gate == 'format-write':
        command = PREFIX + ['mix', 'format'] + [p for p in FORMAT_PATHS if (R / p).is_file()]
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
    python_summary = re.search(r'Ran (\d+) tests? in [^\n]+', clean)
    if python_summary:
        failed = re.search(r'FAILED \(([^\n]+)\)', clean)
        details = failed[1] if failed else ''
        pf = sum(int(v) for v in re.findall(r'(?:failures|errors)=(\d+)', details))
        ps = sum(int(v) for v in re.findall(r'skipped=(\d+)', details))
        counts.append({'tests': int(python_summary[1]), 'failures': pf, 'skipped': ps, 'excluded': 0, 'executed': int(python_summary[1])-ps})
    warnings = [line for line in clean.splitlines() if re.match(r'^\s*warning:', line) and not re.match(r'^\s*warning: Git tree .* is dirty$', line)]
    report = {'kind': 'GROUP_ACCOUNTING_ACTIVATION_ACTUAL_COMMAND', 'gate': gate,
              'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
              'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=R, text=True).strip(),
              'argv': command, 'cwd': str(R), 'pid': process.pid,
              'actual_exit': actual_exit, 'timed_out': timed_out, 'process_joined': process.poll() is not None,
              'elapsed_ms': round((time.monotonic() - started) * 1000),
              'log': str(log.relative_to(R)), 'log_bytes': log.stat().st_size, 'log_sha256': sha(log),
              'collector_sha256': sha(Path(__file__)), 'source_before': before, 'source_after': after,
              'source_stable': before == after, 'counts': counts, 'unexpected_warnings': warnings,
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
        print(clean[-2400:])
    test_gate = gate in ['boundary-green', 'compatibility', 'fresh-compatibility'] or gate.startswith('red') or gate in ['green', 'fresh-tests'] or gate.startswith('green-repair')
    test_gate = test_gate or gate in ['accounting-red1', 'accounting-red2', 'accounting-red3', 'accounting-green1', 'accounting-green2', 'accounting-green3', 'fresh-accounting', 'owner-red1', 'owner-red2', 'owner-green1', 'fresh-owner']
    test_gate = test_gate or gate in ['peer-startup-red', 'peer-startup', 'fresh-peer-startup', 'fixture-tests', 'fresh-fixture-tests', 'startup-exunit-red']
    test_gate = test_gate or gate in ['session-red1', 'session-red2', 'session-green1', 'fresh-session']
    test_gate = test_gate or gate in ['preflight-red1', 'preflight-green1', 'fresh-preflight']
    test_gate = test_gate or gate in ['transitions-red1', 'transitions-red2', 'transitions-green1', 'transitions-green2', 'fresh-transitions']
    test_gate = test_gate or gate in ['probe-red1', 'probe-red2', 'probe-green1', 'probe-green2', 'fresh-probe', 'pin-response-red1', 'pin-response-green1', 'fresh-pin-response']
    test_gate = test_gate or gate in ['control-forms-red1', 'control-forms-red2', 'control-forms-green1', 'fresh-control-forms', 'startup-reservation-red1', 'startup-reservation-red2', 'startup-reservation-green1', 'fresh-startup-reservation', 'group-live-red1', 'group-live-red2', 'group-live-green1', 'fresh-group-live', 'owner-green2']
    test_gate = test_gate or gate == 'public-endpoint-host1' or gate in ['session-control-red1', 'session-control-green1', 'fresh-session-control', 'startup-reservation-green2']
    if warnings:
        print('unexpected_warnings', warnings)
        raise SystemExit(1)
    if timed_out or not report['process_joined']:
        raise SystemExit(1)
    if gate not in ['format-write','format-test-write','format-new-tests-write','format-session-test-write','format-preflight-test-write'] and not report['source_stable']:
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
