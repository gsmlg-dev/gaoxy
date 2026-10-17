#!/usr/bin/env python3
"""Two actual group native-H1/H2 -> TLS-H1 browser rows; compile separately first.

Run from a qualified shell: python -B integration/upstream_transport/browser.py
--evidence-dir NEW_DIRECTORY. Root visual inspection is a separate acceptance.
"""
import argparse
import base64
import ctypes
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import queue
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import threading
import time
import traceback

ROOT = Path(__file__).resolve().parents[2]
BRIDGE = ROOT / 'integration/upstream_transport/fixture.exs'
BROWSER = Path(__file__).with_suffix('.mjs')
START, BARRIER, CASE, OUTER = 10, 5, 20, 600
SOURCE = ('integration/upstream_transport/browser.py', 'integration/upstream_transport/browser.mjs',
          'integration/upstream_transport/fixture.exs', 'integration/upstream_transport/run.py',
          'apps/gaoxy_proxy/test/support/managed_h1_matrix_fixture.exs',
          'apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py', 'mix.exs', 'mix.lock')


def require(value, reason):
    if not value:
        raise AssertionError(reason)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def sources():
    return {name: {'bytes': (ROOT / name).stat().st_size, 'sha256': sha((ROOT / name).read_bytes())}
            for name in SOURCE}


def bytes_receipt(data):
    return dict(body64=base64.b64encode(data).decode(), body_bytes=len(data), body_sha256=sha(data))


def tool_identity(name):
    path = shutil.which(name)
    if path is None:
        return None
    resolved = Path(path).resolve()
    return dict(path=path, resolved=str(resolved), sha256=sha(resolved.read_bytes()))


def child_subreaper():
    require(sys.platform == 'linux', 'owned browser child reaping requires Linux')
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(36, 1, 0, 0, 0) != 0:  # PR_SET_CHILD_SUBREAPER
        raise OSError(ctypes.get_errno(), 'PR_SET_CHILD_SUBREAPER')
    enabled = ctypes.c_int()
    if libc.prctl(37, ctypes.byref(enabled), 0, 0, 0) != 0:  # PR_GET_CHILD_SUBREAPER
        raise OSError(ctypes.get_errno(), 'PR_GET_CHILD_SUBREAPER')
    require(enabled.value == 1, 'browser coordinator is not a child subreaper')
    return dict(pid=os.getpid(), enabled=True)


class Actor:
    """One owned process group, finite JSON bridge, bounded diagnostic log."""
    def __init__(self, argv, directory, name, actors):
        self.argv, self.name = argv, name
        self.events, self.rows, self.threads = queue.Queue(maxsize=4096), [], []
        self.closed, self.forced, self.exit_code = False, False, None
        self.reaped = []
        self.deadline = None
        self.process, self.log = None, None
        self.lock = threading.Lock()
        actors.append(self)
        self.log = (directory / (name + '.jsonl')).open('x')
        # Keep ownership visible before spawn; deliver an outer timeout only after
        # Popen and reader-thread ownership have been retained by this actor.
        old_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGALRM})
        try:
            self.process = subprocess.Popen(argv, cwd=ROOT, stdin=subprocess.PIPE,
                                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                            text=True, bufsize=1, start_new_session=True)
            for stream, label in ((self.process.stdout, 'stdout'), (self.process.stderr, 'stderr')):
                thread = threading.Thread(target=self.read, args=(stream, label), daemon=True)
                self.threads.append(thread)
                thread.start()
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, old_mask)

    def record(self, value):
        with self.lock:
            require(len(self.rows) < 8192, self.name + ' actor receipt bound exceeded')
            row = dict(sequence=len(self.rows) + 1, monotonic_ns=time.monotonic_ns(), **value)
            self.rows.append(row)
            self.log.write(json.dumps(row) + '\n')
            self.log.flush()

    def read(self, stream, label):
        try:
            while True:
                line = stream.readline(2_097_153)
                if not line:
                    break
                require(len(line) <= 2_097_152, self.name + ' line bound exceeded')
                try:
                    value = json.loads(line)
                except json.JSONDecodeError:
                    value = dict(diagnostic=line.rstrip()[:4096])
                self.record(dict(direction=label, value=value))
                if label == 'stdout' and isinstance(value, dict) and 'diagnostic' not in value:
                    self.events.put_nowait(value)
        except Exception as error:
            self.events.put_nowait(dict(event='failure', reason=repr(error)))
        finally:
            stream.close()

    def send(self, value):
        require(self.deadline is None or time.monotonic() < self.deadline,
                self.name + ' case deadline before command')
        require(self.process.poll() is None, self.name + ' exited before command')
        self.record(dict(direction='command', value=value))
        self.process.stdin.write(json.dumps(value) + '\n')
        self.process.stdin.flush()

    def event(self, expected=None, timeout=BARRIER):
        expires = time.monotonic() + timeout
        if self.deadline is not None:
            expires = min(expires, self.deadline)
        while True:
            remaining = expires - time.monotonic()
            require(remaining > 0, self.name + ' event deadline: ' + str(expected))
            try:
                value = self.events.get(timeout=min(remaining, 0.05))
            except queue.Empty:
                require(self.process.poll() is None, self.name + ' exited before event')
                continue
            require(value.get('event') not in ('failure', 'error'), self.name + ': ' + str(value))
            require(expected is None or value.get('event') == expected,
                    self.name + ' unexpected event: ' + str(value))
            return value

    def call(self, value, expected=None, timeout=BARRIER):
        self.send(value)
        return self.event(expected, timeout)

    def group_alive(self):
        if self.process is None:
            return False
        try:
            os.killpg(self.process.pid, 0)
            return True
        except ProcessLookupError:
            return False

    def reap_adopted(self, expires, phase):
        # Popen retains the named leader's wait; only then collect adopted
        # children in this actor's original, isolated process group.
        if self.process is None or self.process.returncode is None:
            return
        while time.monotonic() < expires:
            try:
                pid, status = os.waitpid(-self.process.pid, os.WNOHANG)
            except ChildProcessError:
                return
            if pid == 0:
                return
            self.reaped.append(dict(pid=pid, owned_pgid=self.process.pid,
                                    wait_status=status, exit=os.waitstatus_to_exitcode(status), phase=phase))

    def await_group(self, expires, phase):
        while True:
            self.reap_adopted(expires, phase)
            if not self.group_alive():
                return True
            remaining = expires - time.monotonic()
            if remaining <= 0:
                return False
            time.sleep(min(0.05, remaining))

    def join(self):
        expires = min(time.monotonic() + START, self.deadline or float('inf'))
        self.exit_code = self.process.wait(timeout=max(0, expires - time.monotonic()))
        require(self.await_group(expires, 'normal'), self.name + ' owned process group not joined')
        for thread in self.threads:
            thread.join(timeout=max(0, expires - time.monotonic()))
        require(not any(thread.is_alive() for thread in self.threads), self.name + ' log thread not joined')
        require(self.exit_code == 0 and not self.forced, self.name + ' nonzero/forced exit')
        self.process.stdin.close()
        self.log.close()
        self.closed = True
        return dict(argv=self.argv, pid=self.process.pid, owned_pgid=self.process.pid,
                    exit=self.exit_code, forced=False, threads_joined=True, reaped=list(self.reaped))

    def dispose(self):
        expires = time.monotonic() + START
        errors = []

        def failed(error):
            if repr(error) not in errors:
                errors.append(repr(error))

        def group_alive():
            try:
                return self.group_alive()
            except Exception as error:
                failed(error)
                return True

        def await_group(deadline, phase):
            try:
                return self.await_group(deadline, phase)
            except Exception as error:
                failed(error)
                return False

        def signal_group(value):
            try:
                os.killpg(self.process.pid, value)
            except ProcessLookupError:
                pass
            except Exception as error:
                failed(error)

        # Give the leader and adopted children a normal join before any signal.
        normal_expires = min(expires, time.monotonic() + BARRIER, self.deadline or float('inf'))
        if self.process is not None:
            try:
                self.exit_code = self.process.wait(timeout=max(0, normal_expires - time.monotonic()))
            except subprocess.TimeoutExpired:
                pass
            except Exception as error:
                failed(error)
        await_group(normal_expires, 'normal')
        if group_alive():
            self.forced = True
            # Keep TERM and KILL/reap inside the original shutdown budget.
            term_expires = time.monotonic() + max(0, expires - time.monotonic()) / 2
            signal_group(signal.SIGTERM)
            if self.process.poll() is None:
                try:
                    self.process.wait(timeout=max(0, term_expires - time.monotonic()))
                except subprocess.TimeoutExpired:
                    pass
                except Exception as error:
                    failed(error)
            await_group(term_expires, 'term')
            if group_alive():
                signal_group(signal.SIGKILL)
        if self.process is not None:
            try:
                self.exit_code = self.process.wait(timeout=max(0, expires - time.monotonic()))
            except Exception as error:
                failed(error)
        await_group(expires, 'forced' if self.forced else 'normal')
        for thread in self.threads:
            try:
                if thread.is_alive():
                    thread.join(timeout=max(0, expires - time.monotonic()))
            except Exception as error:
                failed(error)
        joined = ((self.process is None or self.process.returncode is not None) and
                  not group_alive() and not any(thread.is_alive() for thread in self.threads))
        for stream in (self.process.stdin if self.process is not None else None,
                       self.process.stdout if self.process is not None and joined else None,
                       self.process.stderr if self.process is not None and joined else None,
                       self.log if joined else None):
            if stream is not None:
                try:
                    stream.close()
                except Exception as error:
                    failed(error)
        result = dict(name=self.name, owned_pgid=self.process.pid if self.process is not None else None,
                      forced=self.forced, exit=self.exit_code, joined=joined, reaped=list(self.reaped))
        if errors:
            result['failure'] = errors
        return result


def spki(public_certificate):
    # Read only the public certificate; the fixture owns its test-only private key.
    public = subprocess.run(['openssl', 'x509', '-in', public_certificate, '-pubkey', '-noout'],
                            capture_output=True, check=True, timeout=BARRIER).stdout
    der = subprocess.run(['openssl', 'pkey', '-pubin', '-outform', 'DER'], input=public,
                         capture_output=True, check=True, timeout=BARRIER).stdout
    return base64.b64encode(hashlib.sha256(der).digest()).decode()


def handshake(ready, downstream):
    started = time.monotonic_ns()
    with socket.create_connection(('127.0.0.1', ready['port']), timeout=BARRIER) as raw:
        if downstream == 'h2':
            context = ssl.create_default_context(cafile=ready['ca'])
            context.set_alpn_protocols(['h2'])
            with context.wrap_socket(raw, server_hostname='localhost') as connected:
                require(connected.selected_alpn_protocol() == 'h2', 'readiness actual TLS ALPN differs')
                return dict(kind='verified-tls', alpn=connected.selected_alpn_protocol(),
                            certificate_sha256=sha(connected.getpeercert(binary_form=True)),
                            endpoint=connected.getpeername(), started_ns=started, finished_ns=time.monotonic_ns())
        return dict(kind='tcp-connected', endpoint=raw.getpeername(), started_ns=started,
                    finished_ns=time.monotonic_ns())


def fixture_event(host, **match):
    value = host.call(dict(op='event', match=match))
    require(all(value.get(key) == expected for key, expected in match.items()), 'fixture selector identity mismatch')
    return value


def page_body(row, page):
    title = 'Gaoxy ' + row + ' ' + page
    text = 'Managed TLS-H1 upstream: ' + row + ' ' + page
    body = ('<!doctype html><html><head><meta charset="utf-8"><title>' + title +
            '</title><link rel="icon" href="data:,"></head><body><main id="receipt">' +
            text + '</main></body></html>').encode()
    return title, text, body


def row_case(host, directory, downstream, actors):
    row_id = 'group-' + downstream + '-tls'
    row = dict(mount='group', downstream=downstream, upstream='tls')
    if downstream == 'h2':
        row['downstream_tls'] = True
    started = host.call(dict(op='start', row=row), 'ready', START)
    require(started['row'] == row, 'fixture started wrong browser row')
    readiness = handshake(started, downstream)
    health = fixture_event(host, event='request', role='health', target='/health')
    require(health['method'] == 'HEAD', 'group health is not actual HEAD')
    accepted = fixture_event(host, event='accepted', connection=health['connection'])
    require(accepted['wire'] == 'tls-h1' and accepted['sni'] == 'localhost' and accepted['alpn'] is None,
            'group upstream did not use expected actual TLS-H1 listener')
    host.call(dict(op='clean'))
    browser = Actor(['node', str(BROWSER), str(directory), row_id,
                     'h2' if downstream == 'h2' else 'http/1.1',
                     spki(started['server_cert']) if downstream == 'h2' else '-'], directory, row_id + '-browser', actors)
    browser_ready = browser.event('ready', START)
    pages = []
    expires = time.monotonic() + CASE
    host.deadline = browser.deadline = expires
    for page in ('pageA', 'pageB'):
        require(time.monotonic() < expires, row_id + ' case deadline')
        title, text, body = page_body(row_id, page)
        browser.send(dict(op='page', origin=started['downstream_url'], page=page,
                          title=title, text=text, body_sha256=sha(body)))
        request = fixture_event(host, event='request', role='application', target='/' + page)
        require(request['method'] == 'GET' and request['connection'] == health['connection'],
                'application request changed actual upstream connection/method')
        upload = fixture_event(host, event='upload_end', connection=request['connection'], request=request['request'])
        require(all(upload[key] == value for key, value in bytes_receipt(b'').items()) and upload['trailers'] == [],
                'browser GET carried unexpected upstream body/trailers')
        pending = host.call(dict(op='pending'))
        require(pending['pending'] and pending['identity']['completion'], 'actual original pending receipt missing')
        wire = (b'HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\n'
                + b'Content-Length: ' + str(len(body)).encode() + b'\r\n\r\n' + body)
        sent = host.call(dict(op='upstream', connection=request['connection'], request=request['request'],
                              action='send', body64=base64.b64encode(wire).decode(), ended=True), 'command')
        require(all(sent[key] == value for key, value in bytes_receipt(wire).items()) and sent['ended'],
                'raw upstream send byte identity changed')
        observed = browser.event('page', max(0.001, min(BARRIER, expires - time.monotonic())))
        require(observed['status'] == 'PASS' and observed['row'] == row_id and observed['page'] == page and
                observed['body'] == bytes_receipt(body) and observed['network']['status'] == 200 and
                observed['network']['protocol'] == ('h2' if downstream == 'h2' else 'http/1.1') and
                not observed['network']['fromDiskCache'] and not observed['network']['fromServiceWorker'],
                'browser response/protocol/body identity differs')
        completed = host.call(dict(op='request_clean'))
        require(completed['completion_joined'] and completed['identity'] == pending['identity'],
                'same original completion did not join')
        pages.append(dict(page=page, request=request, upload=upload, pending=pending,
                          upstream_response=sent, browser=observed, completed=completed))
    require(len({entry['request']['request'] for entry in pages}) == 2, 'application request IDs duplicated')
    browser.send(dict(op='exit'))
    browser_join = browser.event('joined', START)
    require(browser_join['passed'] and not browser_join['forced'] and
            browser_join['isolated_profile_removed'], 'browser normal join failed')
    browser_process = browser.join()
    require(time.monotonic() < expires, row_id + ' case deadline')
    require([entry['request']['request'] for entry in pages] ==
            [health['request'] + 1, health['request'] + 2], 'upstream application sequence/replay differs')
    clean = host.call(dict(op='clean'))
    require(clean['completion_joined'] and clean['service'] ==
            dict(active=0, cleanup_pending=0, retained_bytes=0, cleanup_failed=None) and
            clean['transport']['request_tokens'] == clean['transport']['helpers'] == 0,
            'final service/transport cleanup failed')
    stopped = host.call(dict(op='stop'), 'joined', START)
    require(stopped['accepted'] == 1 and stopped['forced'] == stopped['live'] == 0,
            'fixture upstream reused/retires incorrectly')
    host.deadline = browser.deadline = None
    return dict(case=row_id, status='PASS', ready=started, readiness=readiness, initial_health=health,
                upstream_accepted=accepted, browser_ready=browser_ready, pages=pages,
                browser_join=browser_join, browser_process=browser_process, clean=clean, stopped=stopped)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-dir', required=True, type=Path)
    args = parser.parse_args()
    directory = args.evidence_dir.resolve()
    directory.mkdir(parents=True, exist_ok=False)
    start = time.monotonic()
    actors, cases, cleanup = [], [], []
    attempted, current_case = [], None
    before, after, environment, failure = None, None, None, None
    passed, executed, host_finished = False, 0, False
    host = None
    command = ['mix', 'run', '--no-compile', '--no-start', str(BRIDGE.relative_to(ROOT))]
    old_alarm = signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError('outer600s deadline')))
    signal.alarm(OUTER)
    try:
        subreaper = child_subreaper()
        before = sources()
        environment = dict(python=sys.version, executable=sys.executable,
                           child_subreaper=subreaper,
                           executable_sha256=sha(Path(sys.executable).read_bytes()), argv=sys.argv,
                           cwd=str(ROOT), env={key: os.environ.get(key) for key in ('MIX_ENV', 'ERL_FLAGS')},
                           packages={name: importlib.metadata.version(name) for name in ('h2', 'hpack', 'hyperframe')},
                           tools={name: tool_identity(name) for name in ('mix', 'node', 'google-chrome', 'openssl')})
        require(environment['env']['MIX_ENV'] == 'test', 'run from qualified MIX_ENV=test shell')
        require(all(environment['tools'].values()), 'qualified tool unavailable')
        host = Actor(command, directory, 'fixture-host', actors)
        host.event('fixture_ready', START)
        for downstream in ('h1', 'h2'):
            executed += 1
            current_case = 'group-' + downstream + '-tls'
            attempted.append(current_case)
            result = row_case(host, directory, downstream, actors)
            cases.append(result)
            print(json.dumps(dict(case=result['case'], status='PASS')), flush=True)
            current_case = None
        host.call(dict(op='finish'), 'finished', START)
        host.join()
        host_finished = True
        after = sources()
        require(before == after, 'scoped source changed during browser execution')
        require([row['case'] for row in cases] == ['group-h1-tls', 'group-h2-tls'], 'browser row registry incomplete')
        passed = True
    except Exception:
        failure = traceback.format_exc()
        if current_case is not None:
            print(json.dumps(dict(case=current_case, status='FAIL', reason=failure)), flush=True)
    finally:
        signal.alarm(0)
        if host is not None and not host_finished and host.process.poll() is None:
            try:
                host.deadline = None
                host.send(dict(op='stop'))
                cleanup.append(dict(name='fixture-stop-after-failure', result=host.event(timeout=START)))
                host.call(dict(op='finish'), 'finished', START)
                host.join()
            except Exception as error:
                cleanup.append(dict(name='fixture-normal-cleanup-attempt', failure=repr(error)))
        for actor in reversed(actors):
            try:
                cleanup.append(actor.dispose())
            except Exception as error:
                cleanup.append(dict(name=actor.name, failure=repr(error), joined=False))
        signal.signal(signal.SIGALRM, old_alarm)
        passed = passed and all(not value.get('forced') and value.get('joined', True) and
                                not value.get('failure') for value in cleanup)
        result = dict(status='PASS' if passed else 'FAIL', executed=executed, passed=len(cases),
                      failed=0 if passed else max(1, executed - len(cases)),
                      not_run=['group-' + d + '-tls' for d in ('h1', 'h2')][executed:],
                      attempted=attempted, failed_case=current_case,
                      command=command, environment=environment, source_before=before, source_after=after,
                      elapsed_ms=round((time.monotonic() - start) * 1000),
                      timeouts_seconds=dict(startup=START, shutdown=START, case=CASE, barrier=BARRIER, outer=OUTER),
                      cases=cases, cleanup=cleanup, failure=failure, root_visual_inspection='NOT RUN',
                      scope='two browser group native-H1/H2 to TLS-H1 rows; separate from 16-case matrix and Task6/M3')
        (directory / 'browser-qualification.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps({key: result[key] for key in ('status', 'executed', 'passed', 'failed', 'not_run',
                                                      'root_visual_inspection', 'failure')}, indent=2), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
