#!/usr/bin/env python3
"""Isolated Chrome DevTools acceptance against native Gaoxy TLS/H2."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import traceback

from managed_h2_fixed_qualification import (HOST, PEER, PYTHON, Process, ROOT,
                                          candidate_identity_check, inventory, require,
                                          rejection_cleanup, rejection_observation, toolchain_identity)
from h2_02110_qualification import identity_check

BROWSER = Path(__file__).with_suffix('.mjs')


def certificate_spki(cert):
    pubkey = subprocess.check_output(['openssl', 'x509', '-in', cert, '-pubkey', '-noout'])
    der = subprocess.run(['openssl', 'pkey', '-pubin', '-outform', 'DER'], input=pubkey,
                         capture_output=True, check=True).stdout
    return base64.b64encode(hashlib.sha256(der).digest()).decode()


def start_browser(directory, name, spki, actors, identities):
    browser = Process(['node', str(BROWSER), str(directory), spki, name],
                      directory / (name + '-browser.log'), 'BROWSER_H2 ')
    actors.append(browser)
    identities.append(browser.event('ready'))
    return browser


def finish_browser(browser, joins):
    browser.send(dict(op='exit'))
    joined = browser.event('joined')
    require(joined['passed'] and not joined['forced'] and joined['isolated_profile_removed'],
            'browser did not join its isolated fixture')
    browser.join()
    joins.append(joined)
    return joined


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--evidence', type=Path, required=True)
    directory = parser.parse_args().evidence.resolve()
    directory.mkdir(parents=True, exist_ok=False)
    before, actors, cases = inventory(), [], []
    browser_identities, browser_joins = [], []
    host_script = directory / 'browser-managed-h2-host.exs'
    host_script.write_text(HOST)
    command = ['nix', 'develop', '--command', 'env', 'ERL_FLAGS=+S 2:2', 'MIX_ENV=test',
               'mix', 'run', str(host_script), str(directory)]
    started_at, passed, failure, toolchain = time.monotonic(), False, None, None
    try:
        toolchain = toolchain_identity()
        host = Process(command, directory / 'host.log', 'FIXED_H2_HOST ')
        actors.append(host)
        host.event('ready', 90)
        peer = Process([str(PYTHON), str(PEER), '--protocol', 'tls'], directory / 'positive-peer.log')
        actors.append(peer)
        ready = peer.event('ready')
        spki = certificate_spki(ready['cert'])
        browser = start_browser(directory, 'positive', spki, actors, browser_identities)
        tls = dict(downstream='h2', downstream_tls=True, cert=ready['cert'], key=ready['key'])
        host.send(dict(op='start', protocol='tls', port=ready['port'], ca=ready['ca'], **tls))
        started = host.event('started')
        browser.send(dict(op='probe', origin='https://localhost:' + str(started['port'])))
        probe = browser.event('probe')
        require(probe['status'] == 'PASS' and not probe['console'], 'browser console/probe failure')
        requests = [peer.event('request') for _ in range(3)]
        require([request['target'] for request in requests] == ['/probe', '/stream', '/early'],
                'browser probe request/replay mismatch')
        require(len({request['connection'] for request in requests}) == 1, 'browser upstream reuse mismatch')
        upstream_tls = next(event for event in peer.seen if event.get('event') == 'tls')
        require(upstream_tls['alpn'] == 'h2' and upstream_tls['sni'] == 'localhost', 'upstream TLS identity mismatch')
        host.send(dict(op='request_clean'))
        request_clean = host.event('request_clean')
        require(len(request_clean['originals']) == 3 and
                all(item['result'] == ':ok' for item in request_clean['originals']),
                'browser original request completion missing while native socket is open')
        browser_join = finish_browser(browser, browser_joins)
        # Chrome owns the downstream sockets. Joining its isolated process
        # closes those native connection/Writer leases before the zero ledger.
        host.send(dict(op='clean'))
        clean = host.event('clean')
        require(clean['originals'] == request_clean['originals'],
                'browser close changed the exact original completions')
        host.send(dict(op='stop'))
        stopped = host.event('stopped')
        require(stopped['cleanup_confirmed'] and not stopped['forced_test_disposal'], 'browser positive retirement failed')
        physical = peer.event(('eof', 'connection_reset'))
        peer.send(dict(op='stop'))
        joined = peer.event('joined')
        require(joined['requests'] == 3 and joined['forced'] == 0 and joined['live'] == 0 and not joined['failed'],
                'browser positive peer final count/join mismatch')
        peer.join()
        cases.append(dict(case='browser-native-h2-to-tls-h2', status='PASS', browser=probe,
                          requests=requests, request_cleanup=request_clean, cleanup=clean,
                          retired=stopped, physical_termination=physical, browser_join=browser_join,
                          joined=joined))
        wrong_trust = directory / 'wrong-trust'
        subprocess.run(['bash', str(ROOT / 'scripts/generate-fixtures.sh'), str(wrong_trust)],
                       check=True, capture_output=True, text=True, timeout=25)
        for name in ('wrong-ca', 'wrong-name'):
            negative = Process([str(PYTHON), str(PEER), '--protocol', 'tls'], directory / (name + '-peer.log'))
            actors.append(negative)
            negative_ready = negative.event('ready')
            host.send(dict(op='start', protocol='tls', port=negative_ready['port'],
                           downstream='h2', downstream_tls=True,
                           cert=negative_ready['cert'], key=negative_ready['key'],
                           ca=str(wrong_trust / 'ca.pem') if name == 'wrong-ca' else negative_ready['ca'],
                           hostname='wrong.invalid' if name == 'wrong-name' else 'localhost'))
            started = host.event('started')
            browser = start_browser(directory, name, certificate_spki(negative_ready['cert']),
                                    actors, browser_identities)
            browser.send(dict(op='negative', name=name, origin='https://localhost:' + str(started['port'])))
            outcome = browser.event('negative')
            require(outcome['status'] == 'PASS' and outcome['server_body'] == {'declared_bytes': 0} and
                    outcome['document'] == {'url': 'chrome-error://chromewebdata/', 'title': 'localhost',
                                            'error': 'HTTP ERROR 502'} and not outcome['console'],
                    'browser bounded upstream rejection mismatch')
            observed = rejection_observation(host)
            browser_join = finish_browser(browser, browser_joins)
            host.send(dict(op='stop'))
            stopped = host.event('stopped')
            negative.send(dict(op='stop'))
            joined = negative.event('joined')
            require(joined['requests'] == 0 and joined['forced'] == 0 and joined['live'] == 0 and not joined['failed'],
                    'browser TLS rejection replay/join failure')
            require(any(event.get('event') == 'handshake_failed' for event in negative.seen),
                    'browser TLS rejection has no peer evidence')
            cleanup_proof = rejection_cleanup(observed, stopped)
            negative.join()
            cases.append(dict(case='browser-' + name, status='PASS', browser=outcome, observed=observed,
                              cleanup=stopped, joined=joined, browser_join=browser_join,
                              cleanup_proof=cleanup_proof,
                              cleanup_status='PASS' if stopped['cleanup_confirmed'] else 'UNCONFIRMED_WITH_RETAINED_FAILURE'))
        host.send(dict(op='exit'))
        host.event('exited')
        host.join()
        identity_check(json.loads((directory / 'host-loaded-before.json').read_text()),
                       json.loads((directory / 'host-loaded-after.json').read_text()))
        candidate_identity_check(directory)
        require(before == inventory(), 'source changed during browser qualification')
        require([case['case'] for case in cases] ==
                ['browser-native-h2-to-tls-h2', 'browser-wrong-ca', 'browser-wrong-name'],
                'required browser cases not executed')
        require(len(browser_joins) == 3, 'isolated browser fixtures did not all join')
        passed = True
    except Exception:
        failure = traceback.format_exc()
    finally:
        for actor in actors:
            actor.dispose()
        after = inventory()
        result = dict(status='PASS' if passed else 'FAIL', command=command,
                      head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                      elapsed_ms=round((time.monotonic() - started_at) * 1000), executed=len(cases), cases=cases,
                      source_before=before, source_after=after, source_stable=before == after, failure=failure,
                      browser_identities=browser_identities, browser_joins=browser_joins,
                      toolchain=toolchain,
                      artifact_hashes={str(path.relative_to(directory)): hashlib.sha256(path.read_bytes()).hexdigest()
                                       for path in sorted(directory.glob('*')) if path.is_file()})
        (directory / 'qualification.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps({key: value for key, value in result.items() if key not in ('source_before', 'source_after', 'cases')}, indent=2))
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
