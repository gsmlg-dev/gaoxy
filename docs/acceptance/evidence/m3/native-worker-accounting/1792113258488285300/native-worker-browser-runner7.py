#!/usr/bin/env python3
"""E5 direct-native complete-cohort TLS/ALPN H2 then H1 browser gates.
No third-party Python packages. Node must provide WebSocket, as prior harnesses do.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import queue
import signal
import socket
import subprocess
import sys
import threading
import tempfile
import time
import traceback

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
HOST = Path(__file__).resolve().with_name('native-worker-browser-host6.exs')
MARKER = 'Gaoxy checked Generation browser capture'
HTML = ('<!doctype html><html><head><title>Gaoxy checked Generation</title>'
        '<link rel="icon" href="data:,"></head><body><h1 id="checked">' + MARKER + '</h1></body></html>').encode()

# A separate raw socket peer process, independent of Gaoxy/HTTP Fetch.
def peer():
    listener = socket.socket()
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(('127.0.0.1', 0))
    listener.listen(8)
    listener.settimeout(.1)
    stopping = threading.Event()
    response_allowed = threading.Event()
    rows, workers, errors = [], [], []
    lock = threading.Lock()
    def emit(value):
        with lock:
            print(json.dumps(value), flush=True)
    def serve(conn):
        try:
            with conn:
                conn.settimeout(20)
                pending = b''
                responses_sent = 0
                while not stopping.is_set():
                    while b'\r\n\r\n' not in pending:
                        try:
                            data = conn.recv(4096)
                        except ConnectionResetError:
                            # Retirement can reset an idle keep-alive connection.
                            # A reset during parsing or response send still fails.
                            assert pending == b'' and responses_sent > 0
                            emit(dict(event='idle_connection_closed', terminal='reset',
                                      completed_responses=responses_sent))
                            return
                        if not data:
                            assert pending == b'', 'EOF inside a partial request'
                            return
                        pending += data
                        if len(pending) > 65536:
                            raise AssertionError('raw peer request header bound')
                    head, pending = pending.split(b'\r\n\r\n', 1)
                    lines = head.split(b'\r\n')
                    method, target, version = lines[0].decode('ascii').split(' ')
                    assert version == 'HTTP/1.1'
                    assert (method, target) in [('HEAD', '/health'), ('GET', '/checked')]
                    fields = []
                    for line in lines[1:]:
                        name, separator, value = line.partition(b':')
                        assert separator and name and name == name.strip(), 'invalid header field'
                        assert all(33 <= byte <= 126 and byte != 58 for byte in name), 'invalid header name'
                        fields.append((name.lower(), value.strip()))
                    assert not any(name == b'transfer-encoding' for name, _ in fields), 'unexpected request transfer coding'
                    lengths = [value for name, value in fields if name == b'content-length']
                    assert len(lengths) <= 1, 'duplicate request content length'
                    assert not lengths or (lengths[0].isdigit() and int(lengths[0]) == 0), 'unexpected request body'
                    assert pending == b'', 'unconsumed request bytes before response barrier'
                    with lock:
                        rows.append(dict(method=method, target=target, version=version))
                        assert len(rows) <= 2
                    emit(dict(event='request', method=method, target=target, version=version))
                    if method == 'GET':
                        assert response_allowed.wait(20), 'complete GET response-release deadline'
                    body = b'' if method == 'HEAD' else HTML
                    conn.sendall(b'HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n'
                                 b'Content-Length: ' + str(len(body)).encode() + b'\r\nConnection: keep-alive\r\n\r\n' + body)
                    responses_sent += 1
                assert pending == b'', 'normal stop with a partial request'
        except Exception:
            errors.append(traceback.format_exc())
    def control():
        for line in sys.stdin:
            command = json.loads(line)
            if command == {'op': 'release_response'}:
                assert not response_allowed.is_set(), 'response released twice'
                response_allowed.set()
            else:
                assert command == {'op': 'stop'}
                stopping.set()
                return
        raise AssertionError('peer control EOF before stop')
    control_thread = threading.Thread(target=control)
    control_thread.start()
    emit(dict(event='ready', port=listener.getsockname()[1]))
    while not stopping.is_set():
        try:
            conn, _ = listener.accept()
        except socket.timeout:
            continue
        worker = threading.Thread(target=serve, args=(conn,))
        workers.append(worker)
        assert len(workers) <= 4
        worker.start()
    listener.close()
    for worker in workers:
        worker.join(22)
        assert not worker.is_alive(), 'raw peer socket worker join deadline'
    control_thread.join(1)
    assert not control_thread.is_alive()
    assert not errors, errors
    assert rows == [dict(method='HEAD', target='/health', version='HTTP/1.1'),
                    dict(method='GET', target='/checked', version='HTTP/1.1')], rows
    emit(dict(event='joined', requests=rows, workers=len(workers), live=0, failed=False))

BROWSER = r'''
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {spawn} = require('node:child_process');
const readline = require('node:readline');
(async () => {
 const [origin, directory, protocol, spki] = process.argv.slice(1);
 assert(['h2','http/1.1'].includes(protocol));
 const originURL=new URL(origin);
 assert.equal(originURL.hostname,'127.0.0.1');assert.match(originURL.port,/^[0-9]+$/);
 assert.equal(originURL.protocol,protocol==='h2'?'https:':'http:');
 assert.equal(originURL.origin,origin);
 const profile = await fs.mkdtemp(path.join(os.tmpdir(), 'gaoxy-native-worker-browser-'));
 const chrome = spawn('google-chrome', ['--headless=new','--no-first-run','--no-default-browser-check',
  '--disable-background-networking','--disable-component-update','--disable-sync','--disable-extensions',
  '--remote-debugging-port=0',`--user-data-dir=${profile}`,
  ...(protocol==='h2'?[`--ignore-certificate-errors-spki-list=${spki}`]:[]),'about:blank'], {stdio:['ignore','ignore','pipe']});
 let stderr = '', socket, serial = 0, passed = false, closeRequested = false;
 let chromeError;
 chrome.on('error', e => { chromeError = e; });
 const exited = new Promise(resolve => chrome.once('exit', (code, signal) => resolve({code, signal})));
 chrome.stderr.on('data', bytes => { stderr = (stderr + bytes.toString()).slice(-65536); });
 const pending = new Map(), events = [];
 const emit = v => process.stdout.write(JSON.stringify(v)+'\n');
 const bounded = (promise, ms, label) => {
  let timer;
  return Promise.race([promise,new Promise((_, reject) => {timer=setTimeout(()=>reject(Error(label)),ms);})])
   .finally(()=>clearTimeout(timer));
 };
 async function until(predicate, label) {
  const end = Date.now()+15000;
  while (!await predicate()) {
   assert(Date.now()<end && !chromeError && chrome.exitCode===null, label+': '+stderr);
   await new Promise(resolve=>setTimeout(resolve,10));
  }
 }
 function request(method, params={}) {
  const id=++serial;
  return bounded(new Promise((resolve,reject)=>{pending.set(id,{resolve,reject});socket.send(JSON.stringify({id,method,params}));}),15000,method)
   .finally(()=>pending.delete(id));
 }
 const input = readline.createInterface({input:process.stdin});
 const stop = new Promise(resolve=>input.once('line', line=>{assert.equal(JSON.parse(line).op,'exit');resolve();}));
 try {
  let port;
  await until(async()=>{
   try { port=Number((await fs.readFile(path.join(profile,'DevToolsActivePort'),'utf8')).split('\n')[0]); }
   catch(e){assert.equal(e.code,'ENOENT');} return !!port;
  },'Chrome startup deadline');
  const targets=await bounded(fetch(`http://127.0.0.1:${port}/json/list`).then(r=>r.json()),5000,'CDP discovery deadline');
  const page=targets.find(t=>t.type==='page'&&t.url==='about:blank');assert(page);
  socket=new WebSocket(page.webSocketDebuggerUrl);
  socket.addEventListener('message', message=>{
   const value=JSON.parse(message.data);
   if(value.id){const p=pending.get(value.id);if(p){value.error?p.reject(Error(JSON.stringify(value.error))):p.resolve(value.result);}}
   else {assert(events.length<2048,'CDP event bound');events.push(value);}
  });
  socket.addEventListener('close',()=>{for(const p of pending.values())p.reject(Error('CDP closed'));pending.clear();});
  await bounded(new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});}),5000,'CDP open deadline');
  await request('Page.enable');await request('Network.enable');await request('Runtime.enable');
  await request('Network.setBlockedURLs',{urls:['*favicon.ico']});
  const version=await request('Browser.getVersion');
  const nav=await request('Page.navigate',{url:origin+'/checked'});assert(!nav.errorText,nav.errorText);
  let response;
  await until(()=>{
   response=events.find(e=>e.method==='Network.responseReceived'&&e.params.response.url===origin+'/checked')?.params;
   return response&&events.some(e=>e.method==='Network.loadingFinished'&&e.params.requestId===response.requestId);
  },'page load deadline');
  assert.equal(response.response.protocol,protocol);assert.equal(response.response.status,200);assert.equal(response.type,'Document');
  if(protocol==='h2')assert.match(response.response.securityDetails.protocol,/^TLS/);
  const result=await request('Runtime.evaluate',{expression:'({title:document.title,text:document.querySelector("#checked")?.textContent,url:location.href})',returnByValue:true});
  assert(!result.exceptionDetails);assert.deepEqual(result.result.value,{title:'Gaoxy checked Generation',text:'Gaoxy checked Generation browser capture',url:origin+'/checked'});
  const visible=await request('Runtime.evaluate',{expression:'(()=>{const e=document.querySelector("#checked"),r=e.getBoundingClientRect();return r.width>0&&r.height>0&&getComputedStyle(e).visibility==="visible";})()',returnByValue:true});
  assert(!visible.exceptionDetails);assert.equal(visible.result.value,true);
  assert(!events.some(e=>e.method==='Runtime.exceptionThrown'||e.method==='Runtime.consoleAPICalled'));
  const screenshot=await request('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
  await fs.writeFile(path.join(directory,'browser.png'),Buffer.from(screenshot.data,'base64'));
  await fs.writeFile(path.join(directory,'browser-events.json'),JSON.stringify(events,null,2)+'\n');
  emit({event:'probe',status:'PASS',version,node:process.version,document:result.result.value,visible:true,network:response});
  await bounded(stop,20000,'browser close command deadline');
  closeRequested=true;
  let closeReply='confirmed';
  try { await request('Browser.close'); }
  catch(e) { assert.equal(e.message,'CDP closed'); closeReply='CDP closed while graceful browser shutdown was pending'; }
  const join=await bounded(exited,10000,'Chrome graceful join deadline');assert.equal(join.code,0);assert.equal(join.signal,null);
  emit({event:'chrome_closed',close_reply:closeReply,process:join});
  passed=true;
 } finally {
  input.close();socket?.close();
  if(chrome.exitCode===null&&chrome.signalCode===null&&!chromeError){
   chrome.kill('SIGTERM');
   try{await bounded(exited,5000,'Chrome TERM join deadline');}
   catch(e){chrome.kill('SIGKILL');await bounded(exited,5000,'Chrome KILL join deadline');}
  }
  await fs.writeFile(path.join(directory,'chrome-stderr.log'),stderr);
  await fs.rm(profile,{recursive:true,force:true});
  emit({event:'joined',passed,close_requested:closeRequested,profile_removed:true,chrome_exit:chrome.exitCode,chrome_signal:chrome.signalCode});
 }
})().catch(e=>{console.error(e.stack);process.exitCode=1;});
'''

class Actor:
    def __init__(self, command, logfile, prefix=''):
        self.command, self.prefix = command, prefix
        self.log = logfile.open('x')
        self.events, self.seen, self.backlog = queue.Queue(), [], []
        self.process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, bufsize=1, start_new_session=True)
        self.reader = threading.Thread(target=self.read)
        self.reader.start()
        self.forced = False
    def read(self):
        for line in self.process.stdout:
            self.log.write(line)
            self.log.flush()
            if line.startswith(self.prefix):
                try:
                    event = json.loads(line[len(self.prefix):])
                except json.JSONDecodeError:
                    continue
                self.seen.append(event)
                self.events.put(event)
        self.events.put({'event': 'process_eof'})
    def send(self, value):
        self.process.stdin.write(json.dumps(value)+'\n')
        self.process.stdin.flush()
    def event(self, name, timeout=25):
        for index, event in enumerate(self.backlog):
            if event.get('event') == name:
                return self.backlog.pop(index)
        end = time.monotonic()+timeout
        while time.monotonic() < end:
            event = self.events.get(timeout=max(.001, end-time.monotonic()))
            assert event.get('event') != 'process_eof', (self.command, self.process.poll())
            if event.get('event') == name:
                return event
            self.backlog.append(event)
        raise TimeoutError('missing '+name)
    def join(self):
        assert self.process.wait(timeout=15) == 0, self.command
        self.reader.join(5)
        assert not self.reader.is_alive(), 'actor log reader join deadline'
    def dispose(self):
        def group_alive():
            try:
                os.killpg(self.process.pid, 0)
                return True
            except ProcessLookupError:
                return False
        if self.process.poll() is None or group_alive():
            self.forced = True
            try:
                os.killpg(self.process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass  # The owned group completed between the liveness check and signal.
            try:
                self.process.wait(timeout=7)
            except subprocess.TimeoutExpired:
                os.killpg(self.process.pid, signal.SIGKILL)
                self.process.wait(timeout=7)
            if group_alive():
                try:
                    os.killpg(self.process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
        self.reader.join(5)
        end = time.monotonic() + 3
        while group_alive() and time.monotonic() < end:
            time.sleep(.02)
        assert not group_alive(), 'owned process group did not join'
        assert not self.reader.is_alive(), 'actor log reader did not join'
        self.log.close()
        return dict(command=self.command, pid=self.process.pid, exit=self.process.returncode,
                    forced=self.forced, reader_joined=True, owned_group_gone=True)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inventory():
    paths = [path for folder in ('apps', 'config') for path in (ROOT/folder).rglob('*')
             if path.is_file() and path.suffix in ('.ex', '.exs') and not any(
                 part in ('deps', '_build') for part in path.relative_to(ROOT).parts)]
    paths += [ROOT/'mix.exs', ROOT/'mix.lock', ROOT/'scripts/generate-fixtures.sh', HOST, HOST.with_name('native-worker-browser-cohort3.exs'), Path(__file__).resolve()]
    return {str(path): digest(path) for path in sorted(paths)}


def certificate_spki(certificates):
    openssl = os.environ.get('OPENSSL_BIN', 'openssl')
    public_key = subprocess.run([openssl, 'x509', '-in', str(certificates/'cert.pem'),
                                 '-pubkey', '-noout'], check=True, capture_output=True, timeout=10).stdout
    der = subprocess.run([openssl, 'pkey', '-pubin', '-outform', 'DER'], input=public_key,
                         check=True, capture_output=True, timeout=10).stdout
    return base64.b64encode(hashlib.sha256(der).digest()).decode('ascii')

def run_case(mode, evidence, certificates, spki, cases, joins):
    evidence.mkdir()
    row = dict(case='native-'+mode+'-worker-checked-generation-browser', status='FAIL', mode=mode)
    cases.append(row)
    actors = []
    try:
        upstream = Actor([sys.executable, '-B', str(Path(__file__).resolve()), '--peer'], evidence/'peer.log')
        actors.append(upstream)
        peer_ready = upstream.event('ready')
        command = ['nix', 'develop', '--command', 'env', 'ERL_FLAGS=+S 2:2', 'MIX_ENV=test',
                   'mix', 'run', str(HOST), str(peer_ready['port']), str(evidence), mode, str(certificates)]
        host = Actor(command, evidence/'host.log', 'NATIVE_WORKER_BROWSER ')
        actors.append(host)
        ready = host.event('ready', 120)
        assert ready['mode'] == mode
        protocol = 'h2' if mode == 'h2' else 'http/1.1'
        origin = ('https' if mode == 'h2' else 'http')+'://127.0.0.1:'+str(ready['port'])
        browser = Actor(['node', '-e', BROWSER, origin, str(evidence), protocol, spki], evidence/'browser.log')
        actors.append(browser)
        captured = host.event('captured')
        assert captured['mode'] == mode and captured['original_owner_effects'] == 2
        assert len(captured['pins']) == 2 and captured['reservation'] > 0
        def check_cohort(cut, target_bytes):
            roles = cut['roles']
            assert cut['active'] == len(roles)
            assert len({item['lease'] for item in roles}) == len(roles)
            assert len({item['pid'] for item in roles}) == len(roles)
            assert cut['target_bytes'] == target_bytes
            assert cut['retained_bytes'] == sum(item['bytes'] for item in roles)
            target = [item for item in roles if item['pid'] == captured['holder']]
            assert len(target) == 1 and target[0]['bytes'] == target_bytes
            for item in roles:
                if item['pid'] == captured['holder']:
                    assert item['role'] == ('request_worker' if mode == 'h2' else 'connection')
                elif item['role'] == 'connection':
                    assert item['bytes'] == (captured['worker_accounting']['connection_bytes'] if mode == 'h2' else 0)
                else:
                    assert mode == 'h2' and item['role'] == 'writer'
                    assert item['bytes'] == captured['worker_accounting']['writer_bytes']
        target_bytes = captured['retained'] + captured['reservation']
        check_cohort(captured['cohort'], target_bytes)
        assert captured['gate_bytes'] == captured['cohort']['retained_bytes']
        assert len(captured['original_cohorts']) == 2
        for cut in captured['original_cohorts']:
            check_cohort(cut, target_bytes)
        assert captured['original_gate_bytes'] == [cut['retained_bytes'] for cut in captured['original_cohorts']]
        if mode == 'h2':
            accounting = captured['worker_accounting']
            assert accounting['bytes'] == captured['retained']
            assert accounting['worker_bytes'] == accounting['bytes']+captured['reservation']
            assert len(accounting['rows']) == 95
            assert accounting['downstream_alpn'] == 'h2' and accounting['secure']
            assert accounting['worker_bytes'] == target_bytes
            assert captured['native_ids']['worker'] != captured['native_ids']['connection']
        else:
            assert captured['worker_accounting'] is None
            assert target_bytes == captured['retained']+captured['reservation']
        custody = host.event('session_custody')
        assert custody['derived'] and custody['native'] == captured['holder']
        assert custody['session'] != captured['holder'] and custody['cleanup_bytes'] > 0
        assert custody['public_t8_fields'] == 8 and custody['acquirer'] == captured['holder']
        health = upstream.event('request')
        assert health['method'] == 'HEAD' and health['target'] == '/health'
        request = upstream.event('request')
        assert request['method'] == 'GET' and request['target'] == '/checked'
        upstream.send({'op': 'release_response'})
        probe = browser.event('probe')
        assert probe['status'] == 'PASS' and probe['visible'] and probe['network']['response']['protocol'] == protocol
        assert probe['network']['response']['status'] == 200
        assert probe['document'] == dict(title='Gaoxy checked Generation', text=MARKER, url=origin+'/checked')
        host.send({'op': 'request_clean'})
        request_clean = host.event('request_clean')
        assert request_clean['session_joined']
        assert custody == dict(event='session_custody', **request_clean['custody'])
        if mode == 'h2':
            assert request_clean['native_worker_joined']
        host.send({'op': 'authorize_browser_close'})
        close_authorized = host.event('browser_close_authorized')
        assert close_authorized['mode'] == mode and close_authorized['connection_alive']
        expected_connection = (captured['native_ids']['connection'] if mode == 'h2'
                               else captured['holder'])
        assert close_authorized['connection'] == expected_connection
        browser.send({'op': 'exit'})
        browser_join = browser.event('joined')
        assert browser_join['passed'] and browser_join['profile_removed']
        assert browser_join['chrome_exit'] == 0 and browser_join['chrome_signal'] is None
        browser.join()
        host.send({'op': 'stop'})
        clean = host.event('closed_browser_clean')
        assert clean['connection_joined'] and clean['connection_reason'] == '{:shutdown, :peer_closed}'
        assert clean['observer_joined'] and clean['cohort_joins']
        assert len({item['pid'] for item in clean['cohort_joins']}) == len(clean['cohort_joins'])
        assert all(item['genuine_terminal'] for item in clean['cohort_joins'])
        assert any(item['pid'] == captured['native_ids']['connection'] for item in clean['cohort_joins'])
        assert clean['service'] == dict(active=0, retained_bytes=0, cleanup_pending=0, cleanup_failed=None)
        stopped = host.event('stopped')
        assert stopped['cleanup_confirmed'] and stopped['source_stable'] and stopped['captures'] == 1
        assert stopped['session_joined'] and stopped['native_actors_joined']
        upstream.send({'op': 'stop'})
        peer_join = upstream.event('joined')
        assert peer_join['live'] == 0 and not peer_join['failed']
        upstream.join()
        host.send({'op': 'exit'})
        host.process.stdin.close()
        host.event('exited')
        host.join()
        assert json.loads((evidence/'host-loaded-before.json').read_text()) == json.loads((evidence/'host-loaded-after.json').read_text())
        assert (evidence/'browser.png').stat().st_size > 0
        row.update(status='PASS', captured=captured, browser=probe, session_custody=custody,
                   request_cleanup=request_clean, closed_browser_cleanup=clean, stopped=stopped,
                   browser_join=browser_join, peer_join=peer_join)
    except Exception:
        row['failure'] = traceback.format_exc()
        raise
    finally:
        cleanup_errors = []
        for actor in reversed(actors):
            try:
                joined = actor.dispose()
                joined['case'] = mode
                joins.append(joined)
            except Exception:
                cleanup_errors.append(traceback.format_exc())
                joins.append(dict(case=mode,command=actor.command,pid=actor.process.pid,
                                  exit=actor.process.poll(),forced=True,cleanup_failed=True))
        if cleanup_errors or any(item['forced'] or item['exit'] != 0 for item in joins if item['case'] == mode):
            row['status'] = 'FAIL'
            row['cleanup_errors'] = cleanup_errors
            raise AssertionError('owned browser/host/peer shutdown failed or required forcing')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--evidence-dir', '--evidence', dest='evidence', type=Path, required=True)
    args = parser.parse_args()
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    joins, cases, failure = [], [], None
    before = inventory()
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    started = time.monotonic()
    passed = False
    try:
        # Ephemeral TEST certificates only; no leaf private key is an evidence artifact.
        with tempfile.TemporaryDirectory(prefix='gaoxy-native-worker-test-certs-') as certificate_path:
            certificates = Path(certificate_path)
            fixture = subprocess.run(['bash', str(ROOT/'scripts/generate-fixtures.sh'), str(certificates)],
                                     cwd=ROOT, capture_output=True, text=True, check=True, timeout=30)
            (evidence/'certificate-tool.log').write_text(fixture.stdout+fixture.stderr)
            spki = certificate_spki(certificates)
            (evidence/'test-certificate-identity.json').write_text(json.dumps(
                dict(leaf_sha256=digest(certificates/'cert.pem'),ca_sha256=digest(certificates/'ca.pem'),
                     chrome_spki_allowlist=spki,ephemeral_test_only=True), indent=2)+'\n')
            for mode in ('h2','h1'):
                run_case(mode,evidence/mode,certificates,spki,cases,joins)
        assert not certificates.exists(), 'ephemeral test certificate directory remains'
        passed = len(cases) == 2 and all(row['status'] == 'PASS' for row in cases)
    except Exception:
        failure = traceback.format_exc()
    finally:
        after = inventory()
        passed = passed and before == after and all(not row['forced'] and row['exit'] == 0 for row in joins)
        result = dict(status='PASS' if passed else 'FAIL', head=head, executed=len(cases), cases=cases,
                      elapsed_ms=round((time.monotonic()-started)*1000), source_before=before,
                      source_after=after, source_stable=before == after, failure=failure, joins=joins,
                      entry_counters='group39/root51/stage9/Astra2of2; diagnosticfails4 separate; handled pre-admission metadata close correction')
        result['artifact_sha256'] = {str(path.relative_to(evidence)): digest(path)
                                    for path in sorted(evidence.rglob('*')) if path.is_file()}
        (evidence/'qualification.json').write_text(json.dumps(result, indent=2)+'\n')
        print(json.dumps({key: value for key, value in result.items()
                          if key not in ('source_before','source_after','cases')}, indent=2))
    return 0 if passed else 1

if __name__ == '__main__':
    if sys.argv[1:] == ['--peer']:
        peer()
    else:
        sys.exit(main())

