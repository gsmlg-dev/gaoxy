import ast
import datetime
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


name = sys.argv[1]
destination = Path('.audit/m5') / (name + '.json')
assert not destination.exists(), destination
record = {
    'timestamp_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'command': [sys.executable, '.audit/m5/final-static.py', name],
    'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'script_sha256': digest(__file__),
    'lock_sha256': digest('mix.lock'),
    'checks': {},
}
code = 1
try:
    documents = [
        'docs/acceptance/m5-websocket-over-h2-h3.md',
        'docs/plans/m5-websocket-over-h2-h3.md',
        'docs/designs/m5-websocket-over-h2-h3.md',
        'docs/native-http.md', 'docs/http3.md', 'docs/capabilities.md',
        'docs/implementation-status.md', 'implement-plan.md',
        'examples/phoenix_native/README.md',
        'integration/websocket_multiplexed/README.md',
        'vendor/websock_adapter/GAOXY.md',
    ]
    missing = []
    checked = 0
    for name in documents:
        path = Path(name)
        for match in re.finditer(r'\[[^\]\n]*\]\(([^)\n]+)\)', path.read_text()):
            target = match.group(1).strip().split(' ', 1)[0].strip('<>')
            if re.match(r'^[A-Za-z][A-Za-z0-9+.-]*:', target) or target.startswith('#'):
                continue
            reference = unquote(target.split('#', 1)[0])
            if reference:
                checked += 1
                if not (path.parent / reference).exists():
                    missing.append([name, reference])
    assert not missing, missing
    record['checks']['document_links'] = {
        'status': 'PASS', 'documents': len(documents), 'relative_links': checked,
        'documents_sha256': {name: digest(name) for name in documents},
    }

    custody = json.loads(Path('.audit/m5/g5-source-custody.json').read_text())
    changes = [name for name, expected in custody['source_files_sha256'].items()
               if not Path(name).is_file() or digest(name) != expected]
    assert not changes, changes
    assert record['lock_sha256'] == custody['lock_sha256']
    record['checks']['scoped_source_custody'] = {
        'status': 'PASS', 'paths_checked': len(custody['source_files_sha256']),
        'custody_sha256': digest('.audit/m5/g5-source-custody.json'),
    }
    browsers = []
    for row in custody['browser_profiles']:
        path = Path(row['report'])
        assert digest(path) == row['sha256'], path
        report = json.loads(path.read_text())
        assert report['status'] == 'PASS' and report['executed'] == report['required'] == 12
        for name, expected in report['source']['files_sha256'].items():
            source = Path(name)
            if source.parts[0] in ('apps', 'vendor', 'integration', 'examples') and (
                source.suffix in ('.ex', '.exs', '.py', '.js', '.lock', '.patch')
                or name == 'vendor/websock_adapter/SOURCE.json'
            ):
                assert source.is_file() and digest(source) == expected, (path, name)
        browsers.append({'protocol': row['protocol'], 'sha256': row['sha256'],
                         'status': 'PASS', 'executed': 12})
    record['checks']['final_browser_source_custody'] = browsers

    ast.parse(Path('integration/websocket_multiplexed/browser.py').read_text())
    record['checks']['browser_python_syntax'] = 'PASS'
    format_receipt = json.loads(Path('.audit/m5/g5-final-format-repair1.json').read_text())
    command = format_receipt['command']
    environment = __import__('os').environ.copy()
    environment.update(json.loads(Path('.audit/m5/nix-env.json').read_text()))
    environment.update(MIX_ENV='test', ERL_FLAGS='+S 2:2')
    result = subprocess.run(command, env=environment, capture_output=True, timeout=120)
    log = Path('.audit/m5') / (destination.stem + '-format.log')
    assert not log.exists()
    log.write_bytes(result.stdout + result.stderr)
    record['checks']['exact_elixir_format'] = {
        'command': command, 'exit_code': result.returncode,
        'paths': len(command) - 3, 'log_sha256': digest(log),
        'locked_environment_sha256': digest('.audit/m5/nix-env.json'),
    }
    assert result.returncode == 0, result.stdout + result.stderr

    result = subprocess.run(['git', 'diff', '--check'], capture_output=True)
    record['checks']['diff_check'] = {
        'command': ['git', 'diff', '--check'], 'exit_code': result.returncode,
        'output': (result.stdout + result.stderr).decode(errors='replace'),
    }
    assert result.returncode == 0, result.stdout + result.stderr
    evidence = {}
    for root in ('docs/acceptance/evidence/m5/g4', 'docs/acceptance/evidence/m5/g5'):
        for path in Path(root).rglob('*'):
            if not path.is_file():
                continue
            assert path.name != 'key.pem' and path.suffix != '.pyc'
            assert '__pycache__' not in path.parts
            assert not re.search(rb'-----BEGIN (?:[A-Z]+ )*PRIVATE KEY-----', path.read_bytes()), path
            evidence[str(path)] = digest(path)
    record['checks']['evidence_private_key_scan'] = {'status': 'PASS', 'files': len(evidence)}
    record['evidence_sha256'] = evidence
    record['status'] = 'PASS'
    code = 0
except Exception as error:
    record['status'] = 'FAIL'
    record['error'] = repr(error)
finally:
    record['exit_code'] = code
    destination.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({k: v for k, v in record.items() if k != 'evidence_sha256'}, indent=2))
sys.exit(code)
