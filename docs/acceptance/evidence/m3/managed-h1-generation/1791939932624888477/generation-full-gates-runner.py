import hashlib
import json
import pathlib
import subprocess
import sys
import time

root = pathlib.Path.cwd()
evidence = pathlib.Path('/tmp/gaoxy-h1-generation-evidence-path').read_text()
evidence = pathlib.Path(evidence)
source_files = [
    'apps/gaoxy_proxy/lib/gaoxy/proxy/upstream_transports.ex',
    'apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex',
    'apps/gaoxy_proxy/lib/gaoxy/proxy/http/session.ex',
    'apps/gaoxy_proxy/lib/gaoxy/proxy/group_endpoint.ex',
    'apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs',
    'apps/gaoxy_proxy/test/upstream_transport_generation_test.exs',
    'apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs',
    'apps/gaoxy_proxy/test/upstream_group_probe_test.exs',
]
test_files = [
    'apps/gaoxy_proxy/test/upstream_transport_handoff_test.exs',
    'apps/gaoxy_proxy/test/upstream_transport_generation_test.exs',
    'apps/gaoxy_proxy/test/upstream_transport_generation_failure_test.exs',
    'apps/gaoxy_proxy/test/upstream_transports_test.exs',
    'apps/gaoxy_proxy/test/upstream_transports_options_test.exs',
    'apps/gaoxy_proxy/test/managed_h1_preparation_test.exs',
    'apps/gaoxy_proxy/test/upstream_transport_identity_test.exs',
    'apps/gaoxy_proxy/test/upstream_transport_proxy_test.exs',
    'apps/gaoxy_proxy/test/upstream_group_transport_test.exs',
    'apps/gaoxy_proxy/test/upstream_group_transport_proxy_test.exs',
    'apps/gaoxy_proxy/test/upstream_group_transport_probe_test.exs',
    'apps/gaoxy_proxy/test/upstream_group_proxy_test.exs',
    'apps/gaoxy_proxy/test/upstream_group_probe_test.exs',
    'apps/gaoxy_proxy/test/http_fetch_completion_test.exs',
    'apps/gaoxy/test/lifecycle_participant_test.exs',
    'apps/gaoxy/test/lifecycle_fault_test.exs',
    'apps/gaoxy/test/lifecycle_ownership_test.exs',
    'apps/gaoxy/test/lifecycle_acceptance_test.exs',
]
compatibility_files = [
    'apps/gaoxy_http/test/generation_test.exs',
    'apps/gaoxy_http/test/generation_loader_test.exs',
    'apps/gaoxy_http/test/generation_resources_test.exs',
    'apps/gaoxy_http/test/generation_release_deadline_test.exs',
    'apps/gaoxy_http/test/router_test.exs',
    'apps/gaoxy_http/test/router_network_test.exs',
]
commands = [
    ('FORMAT_CHECK', ['unbuffer', 'mix', 'format', '--check-formatted', *source_files]),
    ('STRICT_COMPILE', ['unbuffer', 'mix', 'compile', '--warnings-as-errors']),
    ('UNFILTERED_AFFECTED_TESTS', ['unbuffer', 'mix', 'test', '--warnings-as-errors', '--max-cases', '1', *test_files]),
    ('GENERATION_ROUTER_COMPATIBILITY', ['unbuffer', 'mix', 'test', '--warnings-as-errors', '--max-cases', '1', *compatibility_files]),
]
results = []
for name, command in commands:
    print(json.dumps({'gate': name, 'command': command}), flush=True)
    started = time.monotonic()
    result = subprocess.run(command, cwd=root)
    results.append({'gate': name, 'command': command, 'actual_exit': result.returncode,
                    'elapsed_ms': round((time.monotonic() - started) * 1000)})
    if result.returncode:
        break
receipt = {
    'kind': 'COMPLETE_GENERATION_SCOPED_GATES',
    'status': 'PASS' if len(results) == 4 and all(r['actual_exit'] == 0 for r in results) else 'FAIL',
    'runner_sha256': hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),
    'gates': results,
}
(evidence / ('generation-complete-child-gates-' + str(time.time_ns()) + '.json')).write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2), flush=True)
sys.exit(next((r['actual_exit'] for r in results if r['actual_exit']), 0))
