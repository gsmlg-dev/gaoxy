import json
from pathlib import Path
import sys
import time

root = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
sys.path.insert(0, str(root / 'integration/http_fetch_contract'))
from managed_h2_fixed_qualification import Process, PEER, PYTHON, PACKAGES

evidence = Path(Path('/tmp/gaoxy-h2-fixed-evidence-path').read_text().strip())
directory = evidence / ('peer-startup-diagnostic1-' + str(time.time_ns()))
directory.mkdir()
results = []
for index, protocol in enumerate(['h2c', 'tls'] * 4):
    begin = time.monotonic()
    peer = Process([str(PYTHON), str(PEER), '--protocol', protocol, '--manual'], directory / f'{index}-{protocol}.log')
    try:
        ready = peer.event('ready', 25)
        elapsed = round((time.monotonic() - begin) * 1000)
        assert ready['identity']['packages'] == PACKAGES
        peer.send({'op': 'stop'})
        joined = peer.event('joined', 5)
        assert joined == {'event': 'joined', 'accepts': 0, 'requests': 0, 'forced': 0, 'live': 0, 'failed': False}
        peer.join()
        results.append({'index': index, 'protocol': protocol, 'startup_ms': elapsed, 'ready': ready, 'joined': joined})
    finally:
        peer.dispose()
(directory / 'diagnosis.json').write_text(json.dumps({'results': results, 'status': 'PASS', 'kind': 'FIXTURE_STARTUP_ONLY', 'network_acceptance': 'NOT_RUN'}, indent=2) + '\n')
print(json.dumps({'directory': str(directory), 'startup_ms': [r['startup_ms'] for r in results], 'startup_over_5000': sum(r['startup_ms'] > 5000 for r in results), 'joins': len(results)}))
