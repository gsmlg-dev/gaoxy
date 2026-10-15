#!/usr/bin/env python3
"""The canonical three isolated Chrome cases against actual managed H2 groups."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import traceback

from managed_h2_fixed_qualification import (HOST, PYTHON, Process, ROOT,
    candidate_identity_check, inventory, rejection_cleanup, rejection_observation,
    require, toolchain_identity)
from managed_h2_fixed_browser import (BROWSER, certificate_spki, finish_browser, start_browser)
from h2_02110_qualification import identity_check

PEER = ROOT / 'apps/gaoxy_proxy/test/support/managed_h2_group_browser_peer.py'
RESERVE = 16_478_862


def exact_reservations(value, originals):
    receipts = value['admission_receipts']
    require(receipts and len(receipts) <= 1024 and
            [row['sequence'] for row in receipts] == list(range(1, len(receipts) + 1)),
            'group Service live receipt sequence missing')
    for snapshot in receipts:
        require(snapshot['total_invariant'] and
                snapshot['retained_bytes'] == snapshot['lease_bytes'] + snapshot['cleanup_bytes'] and
                snapshot['lease_bytes'] == sum(row['bytes'] for row in snapshot['leases']) and
                snapshot['cleanup_bytes'] == sum(row['bytes'] for row in snapshot['cleanups']),
                'group Service live byte invariant failed')
    holds = {row['token'] for snap in receipts for row in snap['cleanups']}
    require(len(holds) == len(originals), 'group request/Service original cleanup count differs')
    attached = []
    for token in holds:
        rows = [(snap, row) for snap in receipts for row in snap['cleanups'] if row['token'] == token]
        require(all(row['bytes'] == RESERVE for _, row in rows),
                'group request was not charged full16478862')
        actual = [(snap, row) for snap, row in rows if not row['receipt'] and any(
            lease['lease'] == row['lease'] and lease['cleanup'] == token and lease['request_active']
            for lease in snap['leases'])]
        require(actual, 'full group reservation lacked actual attached active lease')
        attached.append(dict(snapshot=actual[0][0], cleanup=actual[0][1]))
    return attached


def exact_group_evidence(value, originals, *, terminal=False):
    evidence = value['terminal_group_evidence'] if terminal else value['group_evidence']
    require(evidence and evidence['failure'] is None and evidence['rejected'] == 0 and
            0 < evidence['received'] <= 1024 and evidence['high_water'] <= 1024 and
            evidence['received'] == len(evidence['rows']) and
            [row['sequence'] for row in evidence['rows']] == list(range(1, len(evidence['rows']) + 1)),
            'group/T live evidence collector lost a raw state or exceeded its bound')
    require({row['kind'] for row in evidence['owners']} == {'group', 'transport'},
            'actual G/T observer ownership missing')
    if terminal:
        require(all(row['closed'] and row['reason'] == ':normal' for row in evidence['owners']),
                'G/T evidence was not fenced by actual owner joins')
        require(evidence['outstanding'] == 0, 'terminal G/T raw states were left unobserved')
    group_rows = [row for row in evidence['rows'] if row['kind'] == 'group']
    transport_rows = [row for row in evidence['rows'] if row['kind'] == 'transport']
    require(group_rows and transport_rows, 'actual G/T live timelines incomplete')
    for row in group_rows:
        require(row['total_invariant'] and row['config_bytes'] == sum(group['bytes'] for group in row['groups']) and
                row['control_bytes'] == sum(control['control_bytes'] for control in row['controls']) and
                row['control_bytes'] <= 16_777_216,
                'G exact configuration/control ledger invariant changed')
        require(all(group['serialized_payload_bytes'] <= group['bytes'] <= 12_582_912
                    for group in row['groups']), 'G retained configuration grew outside reservation')
        require(all(0 < control['control_bytes'] <= (196608 if control['kind'] == 'pin' else 32768)
                    for control in row['controls']), 'G individual control envelope changed')
    for row in transport_rows:
        total = sum(record['payload_bytes'] for category in ('resources', 'tokens', 'pins')
                    for record in row[category])
        require(total == row['owned_serialized_payload_bytes'] <= 4_194_304,
                'T actual retained payload sum changed')
    for original in originals:
        g_holds = [control for row in group_rows for control in row['controls']
                   if control['kind'] == 'selection' and control['token'] == original['group_token']]
        t_holds = [token for row in transport_rows for token in row['tokens']
                   if token['token'] == original['token']]
        require(any(hold['completion'] and hold['completion']['identity'] == original['completion']
                    for hold in g_holds) and
                any(hold['completion'] and hold['completion']['identity'] == original['completion']
                    for hold in t_holds), 'G/T did not bind the same actual original completion')
    if not terminal:
        probes = evidence['probe_originals']
        require(len(probes) == 1 and probes[0]['result'] == ':ok' and len(probes[0]['transport_tokens']) == 1,
                'initial real healthy Probe original lacked exact G/T completion confirmation')
        probe = probes[0]
        require(any(control['kind'] == 'probe' and control['token'] == probe['group_token'] and
                    control['probe_bytes'] == RESERVE and control['completion'] and
                    control['completion']['identity'] == probe['completion']
                    for row in group_rows for control in row['controls']),
                'real initial Probe lacked full reservation and actual G original bind')
        require(any(token['token'] == probe['transport_tokens'][0] and token['completion'] and
                    token['completion']['identity'] == probe['completion']
                    for row in transport_rows for token in row['tokens']),
                'initial actual T Probe completion differs from G original')
    return evidence


def group_rejection_cleanup(observed, stopped):
    # Reuse every existing fixed original/Service/T/public-stop assertion.
    # The only changed byte contract is the whole group request reservation.
    proof = rejection_cleanup(observed, stopped, reservation=RESERVE)
    original = observed['originals'][0]
    exact_group_evidence(observed, observed['originals'])
    exact_group_evidence(stopped, stopped['originals'], terminal=True)
    before, retained = observed['group'], stopped['retained_group']
    require(observed['group_evidence']['rows'] ==
            stopped['terminal_group_evidence']['rows'][:len(observed['group_evidence']['rows'])],
            'public stop lost immutable G/T observation prefix')
    if original['result'] == ':ok':
        require(before['tokens'] == before['probes'] == before['probe_bytes'] == 0,
                'confirmed group TLS original retained G requests')
        require(retained['tokens'] == retained['probes'] == retained['pins'] ==
                retained['config_bytes'] == retained['control_bytes'] == retained['probe_bytes'] == 0,
                'confirmed public stop did not clear actual G ledgers')
    else:
        for label, value in (('observed', before), ('after_public_stop', retained)):
            matches = [hold for hold in value['holds'] if hold['kind'] == 'selection' and
                       hold['token'] == original['group_token']]
            require(value['tokens'] == 1 and len(matches) == 1 and
                    matches[0]['completion'] == original['completion'] and
                    matches[0]['result'] == '{:error, :cleanup_unconfirmed}' and
                    matches[0]['control_bytes'] > 0 and value['control_bytes'] >= matches[0]['control_bytes'],
                    label + ' lost G original/control charge despite unconfirmed cleanup')
        require(not stopped['cleanup_confirmed'] and stopped['forced_test_disposal'] and
                any(row['pid'] == before['owner'] and
                    row['outcome'] == 'TEST_OWNED_DISPOSAL_AFTER_UNCONFIRMED_PUBLIC_STOP'
                    for row in stopped['test_disposals']),
                'unconfirmed G owner was not explicitly labeled as test-owned disposal')
    return proof


def start_peer(directory, name, actors):
    command = [str(PYTHON), str(PEER)]
    if name != 'positive':
        command += ['--negative', name]
    peer = Process(command, directory / (name + '-peer.log'))
    actors.append(peer)
    ready = peer.event('ready', 45)
    group_ready = peer.event('group_browser_ready')
    require(ready['identity']['group_browser_peer_sha256'] == hashlib.sha256(PEER.read_bytes()).hexdigest(),
            'actual group peer source identity changed')
    return peer, ready, group_ready


def start_host(host, ready, group_ready):
    host.send(dict(op='start', group=True, protocol='tls', port=ready['port'], ca=group_ready['trust'],
                   downstream='h2', downstream_tls=True, cert=ready['cert'], key=ready['key']))
    started = host.event('started')
    require(started['full_request_reservation'] == RESERVE and
            started['group']['members'][0]['health'] == 'healthy' and
            started['group']['probes'] == started['group']['probe_bytes'] == 0,
            'group browser started before real HEAD health/completion acceptance')
    return started


def initial_head(peer):
    health = peer.event('request')
    require(health['target'] == '/health' and [':method', 'HEAD'] in health['headers'] and health['ended'],
            'initial group health request was not the exact actual HEAD')
    tls = next(event for event in peer.seen if event.get('event') == 'tls')
    require(tls['alpn'] == 'h2' and tls['sni'] == 'localhost', 'initial actual peer ALPN/SNI mismatch')
    return health


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--evidence', type=Path, required=True)
    directory = parser.parse_args().evidence.resolve()
    directory.mkdir(parents=True, exist_ok=False)
    before, actors, cases = inventory(), [], []
    browser_identities, browser_joins = [], []
    host_script = directory / 'browser-managed-h2-group-host.exs'
    host_script.write_text(HOST)
    command = ['nix', 'develop', '--command', 'env', 'ERL_FLAGS=+S 2:2', 'MIX_ENV=test',
               'mix', 'run', str(host_script), str(directory)]
    started_at, passed, failure, toolchain = time.monotonic(), False, None, None
    try:
        toolchain = toolchain_identity()
        host = Process(command, directory / 'host.log', 'FIXED_H2_HOST ')
        actors.append(host)
        host.event('ready', 90)
        peer, ready, group_ready = start_peer(directory, 'positive', actors)
        browser = start_browser(directory, 'positive', certificate_spki(ready['cert']), actors, browser_identities)
        started = start_host(host, ready, group_ready)
        health = initial_head(peer)
        browser.send(dict(op='probe', origin='https://localhost:' + str(started['port'])))
        probe = browser.event('probe')
        require(probe['status'] == 'PASS' and not probe['console'], 'browser console/probe failure')
        requests = [peer.event('request') for _ in range(3)]
        require([request['target'] for request in requests] == ['/probe', '/stream', '/early'],
                'browser probe request/replay mismatch')
        require({request['connection'] for request in [health, *requests]} == {health['connection']},
                'group health/browser requests did not reuse one physical upstream H2 connection')
        host.send(dict(op='request_clean'))
        request_clean = host.event('request_clean')
        require(len(request_clean['originals']) == 3 and
                all(item['result'] == ':ok' for item in request_clean['originals']),
                'browser G/T original completion missing while native socket is open')
        reservations = exact_reservations(request_clean, request_clean['originals'])
        exact_group_evidence(request_clean, request_clean['originals'])
        browser_join = finish_browser(browser, browser_joins)
        host.send(dict(op='clean'))
        clean = host.event('clean')
        require(clean['originals'] == request_clean['originals'], 'browser close changed exact G/T originals')
        host.send(dict(op='stop'))
        stopped = host.event('stopped')
        require(stopped['cleanup_confirmed'] and not stopped['forced_test_disposal'],
                'browser group positive retirement failed')
        exact_group_evidence(stopped, request_clean['originals'], terminal=True)
        physical = peer.event(('eof', 'connection_reset'))
        peer.send(dict(op='stop'))
        joined = peer.event('joined')
        require(joined['requests'] == 4 and joined['accepts'] == 1 and joined['forced'] == 0 and
                joined['live'] == 0 and not joined['failed'], 'browser positive peer final count/join mismatch')
        peer.join()
        cases.append(dict(case='browser-group-native-h2-to-tls-h2', status='PASS', browser=probe,
            health=health, requests=requests, exact_service_reservations=reservations,
            request_cleanup=request_clean, cleanup=clean, retired=stopped,
            physical_termination=physical, browser_join=browser_join, joined=joined))
        for name in ('wrong-ca', 'wrong-name'):
            negative, ready, group_ready = start_peer(directory, name, actors)
            started = start_host(host, ready, group_ready)
            health = initial_head(negative)
            goaway = negative.event('command', predicate=lambda event: event.get('op') == 'goaway')
            require(goaway['connection'] == health['connection'] and
                    goaway['stream'] == goaway['last_stream'] == health['stream'] and goaway['code'] == 0,
                    'initial health GOAWAY did not name the exact accepted connection/stream')
            physical = negative.event('eof', predicate=lambda event: event['connection'] == health['connection'])
            negative.send(dict(op='rotate_tls'))
            rotation = negative.event('tls_rotated')
            require(rotation['initial_worker_joined'] and rotation['requests_before_rotation'] == 1 and
                    rotation['kind'] == name and
                    rotation['initial_certificate_sha256'] != rotation['replacement_certificate_sha256'],
                    'negative test did not perform genuine post-health TLS certificate rotation')
            browser = start_browser(directory, name, certificate_spki(ready['cert']), actors, browser_identities)
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
            require(joined['requests'] == 1 and joined['forced'] == 0 and joined['live'] == 0 and not joined['failed'],
                    'browser TLS rejection replay/join failure')
            failed_handshakes = [event for event in negative.seen if event.get('event') == 'handshake_failed']
            require(failed_handshakes and all(event['connection'] != health['connection'] for event in failed_handshakes),
                    'browser TLS rejection has no genuine post-health failed handshake')
            proof = group_rejection_cleanup(observed, stopped)
            negative.join()
            cases.append(dict(case='browser-group-' + name, status='PASS', browser=outcome,
                health=health, health_goaway=goaway, health_physical_termination=physical, rotation=rotation,
                failed_handshakes=failed_handshakes, observed=observed, cleanup=stopped, joined=joined,
                browser_join=browser_join, cleanup_proof=proof, cleanup_status=proof['cleanup_status']))
        host.send(dict(op='exit'))
        host.event('exited')
        host.join()
        identity_check(json.loads((directory / 'host-loaded-before.json').read_text()),
                       json.loads((directory / 'host-loaded-after.json').read_text()))
        candidate_identity_check(directory)
        require(before == inventory(), 'source changed during browser qualification')
        require([case['case'] for case in cases] == ['browser-group-native-h2-to-tls-h2',
                'browser-group-wrong-ca', 'browser-group-wrong-name'], 'required group browser cases not executed')
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
            browser_identities=browser_identities, browser_joins=browser_joins, toolchain=toolchain,
            browser_source=str(BROWSER), browser_source_sha256=hashlib.sha256(BROWSER.read_bytes()).hexdigest(),
            artifact_hashes={str(path.relative_to(directory)): hashlib.sha256(path.read_bytes()).hexdigest()
                            for path in sorted(directory.glob('*')) if path.is_file()})
        (directory / 'qualification.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps({key: value for key, value in result.items()
                          if key not in ('source_before', 'source_after', 'cases')}, indent=2))
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
