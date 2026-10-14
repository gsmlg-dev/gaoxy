import hashlib
import json
import pathlib
import subprocess
import sys
import time

root = pathlib.Path.cwd()
evidence = pathlib.Path(pathlib.Path('/tmp/gaoxy-h2-preparation-evidence-path').read_text().strip())
source_files = [
    'apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_preparation.ex',
    'apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_reservation.ex',
    'apps/gaoxy_proxy/test/managed_h2_preparation_test.exs',
    'apps/gaoxy_proxy/test/managed_h2_reservation_test.exs',
    'integration/http_fetch_contract/h2_0214_functional_supplement.exs',
]
test_files = [
    'apps/gaoxy_proxy/test/managed_h2_preparation_test.exs',
    'apps/gaoxy_proxy/test/managed_h2_reservation_test.exs',
    'apps/gaoxy_proxy/test/managed_h1_preparation_test.exs',
    'apps/gaoxy_proxy/test/managed_h1_accounting_test.exs',
    'apps/gaoxy_proxy/test/upstream_transports_options_test.exs',
    'apps/gaoxy_proxy/test/http_fetch_completion_test.exs',
]
commands = [
    ('FORMAT_CHECK', ['unbuffer', 'mix', 'format', '--check-formatted', *source_files]),
    ('STRICT_COMPILE', ['unbuffer', 'mix', 'compile', '--warnings-as-errors']),
    ('UNFILTERED_PREPARATION_COMPATIBILITY', ['unbuffer', 'mix', 'test', '--warnings-as-errors', '--max-cases', '1', *test_files]),
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
    'kind': 'COMPLETE_H2_PREPARATION_SCOPED_GATES',
    'status': 'PASS' if len(results) == len(commands) and all(r['actual_exit'] == 0 for r in results) else 'FAIL',
    'runner_sha256': hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),
    'gates': results,
}
(evidence / ('h2-complete-child-gates-' + str(time.time_ns()) + '.json')).write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2), flush=True)
sys.exit(next((r['actual_exit'] for r in results if r['actual_exit']), 0))
