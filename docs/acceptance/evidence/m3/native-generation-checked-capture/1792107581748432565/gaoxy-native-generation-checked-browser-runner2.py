#!/usr/bin/env python3
"""NOT RUN proposal: one actual native H1 checked capture via Chrome CDP.
No third-party Python packages. Node must provide WebSocket, as prior harnesses do.
"""
import argparse
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
import time
import traceback

ROOT = Path('/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation')
HOST = Path(__file__).resolve().with_name('gaoxy-native-generation-checked-browser-host1.exs')
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
                    method, target, version = head.split(b'\r\n', 1)[0].decode('ascii').split(' ')
                    assert version == 'HTTP/1.1'
                    assert (method, target) in [('HEAD', '/health'), ('GET', '/checked')]
                    with lock:
                        rows.append(dict(method=method, target=target, version=version))
                        assert len(rows) <= 2
                    emit(dict(event='request', method=method, target=target, version=version))
                    body = b'' if method == 'HEAD' else HTML
                    conn.sendall(b'HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n'
                                 b'Content-Length: ' + str(len(body)).encode() + b'\r\nConnection: keep-alive\r\n\r\n' + body)
                    responses_sent += 1
        except Exception:
            errors.append(traceback.format_exc())
    def control():
        command = json.loads(sys.stdin.readline())
        assert command == {'op': 'stop'}
        stopping.set()
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
 const [origin, directory] = process.argv.slice(1);
 assert(/^http:\/\/127\.0\.0\.1:[0-9]+$/.test(origin));
 const profile = await fs.mkdtemp(path.join(os.tmpdir(), 'gaoxy-checked-browser-'));
 const chrome = spawn('google-chrome', ['--headless=new','--no-first-run','--no-default-browser-check',
  '--disable-background-networking','--disable-component-update','--disable-sync','--disable-extensions',
  '--remote-debugging-port=0',`--user-data-dir=${profile}`,'about:blank'], {stdio:['ignore','ignore','pipe']});
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
  assert.equal(response.response.protocol,'http/1.1');assert.equal(response.response.status,200);assert.equal(response.type,'Document');
  const result=await request('Runtime.evaluate',{expression:'({title:document.title,text:document.querySelector("#checked")?.textContent,url:location.href})',returnByValue:true});
  assert(!result.exceptionDetails);assert.deepEqual(result.result.value,{title:'Gaoxy checked Generation',text:'Gaoxy checked Generation browser capture',url:origin+'/checked'});
  assert(!events.some(e=>e.method==='Runtime.exceptionThrown'||e.method==='Runtime.consoleAPICalled'));
  const screenshot=await request('Page.captureScreenshot',{format:'png'});
  await fs.writeFile(path.join(directory,'browser.png'),Buffer.from(screenshot.data,'base64'));
  await fs.writeFile(path.join(directory,'browser-events.json'),JSON.stringify(events,null,2)+'\n');
  emit({event:'probe',status:'PASS',version,node:process.version,document:result.result.value,network:response});
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
    paths += [ROOT/'mix.exs', ROOT/'mix.lock', HOST, Path(__file__).resolve()]
    return {str(path): digest(path) for path in sorted(paths)}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--evidence', type=Path, required=True)
    args = parser.parse_args()
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    actors, joins, cases, failure = [], [], [], None
    before = inventory()
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    started = time.monotonic()
    passed = False
    try:
        upstream = Actor([sys.executable, '-B', str(Path(__file__).resolve()), '--peer'], evidence/'peer.log')
        actors.append(upstream)
        peer_ready = upstream.event('ready')
        command = ['nix', 'develop', '--command', 'env', 'ERL_FLAGS=+S 2:2', 'MIX_ENV=test',
                   'mix', 'run', str(HOST), str(peer_ready['port']), str(evidence)]
        host = Actor(command, evidence/'host.log', 'CHECKED_BROWSER ')
        actors.append(host)
        ready = host.event('ready', 120)
        browser = Actor(['node', '-e', BROWSER, 'http://127.0.0.1:'+str(ready['port']), str(evidence)], evidence/'browser.log')
        actors.append(browser)
        captured = host.event('captured')
        probe = browser.event('probe')
        assert probe['status'] == 'PASS'
        assert captured['original_owner_effects'] == 2 and len(captured['pins']) == 2
        assert captured['reservation'] > 0 and captured['gate_bytes'] == captured['retained'] + captured['reservation']
        assert captured['original_gate_bytes'] == [captured['gate_bytes']] * 2
        host.send({'op': 'request_clean'})
        request_clean = host.event('request_clean')
        browser.send({'op': 'exit'})
        browser_join = browser.event('joined')
        assert browser_join['passed'] and browser_join['profile_removed']
        assert browser_join['chrome_exit'] == 0 and browser_join['chrome_signal'] is None
        browser.join()
        host.send({'op': 'stop'})
        clean = host.event('closed_browser_clean')
        stopped = host.event('stopped')
        assert stopped['cleanup_confirmed'] and stopped['source_stable'] and stopped['captures'] == 1
        upstream.send({'op': 'stop'})
        peer_join = upstream.event('joined')
        assert peer_join['live'] == 0 and not peer_join['failed']
        upstream.join()
        host.send({'op': 'exit'})
        host.process.stdin.close()
        host.event('exited')
        host.join()
        assert json.loads((evidence/'host-loaded-before.json').read_text()) == json.loads((evidence/'host-loaded-after.json').read_text())
        assert inventory() == before
        cases.append(dict(case='native-h1-checked-generation-browser', status='PASS', captured=captured,
                          browser=probe, request_cleanup=request_clean, closed_browser_cleanup=clean,
                          stopped=stopped, browser_join=browser_join, peer_join=peer_join))
        passed = True
    except Exception:
        failure = traceback.format_exc()
    finally:
        for actor in reversed(actors):
            try:
                joins.append(actor.dispose())
            except Exception:
                passed = False
                failure = (failure or '') + traceback.format_exc()
        after = inventory()
        passed = passed and before == after and all(not row['forced'] and row['exit'] == 0 for row in joins)
        result = dict(status='PASS' if passed else 'FAIL', head=head, executed=len(cases), cases=cases,
                      elapsed_ms=round((time.monotonic()-started)*1000), source_before=before,
                      source_after=after, source_stable=before == after, failure=failure, joins=joins,
                      counters='entry failedGREEN6/aborted1/prod1/fixture5/group30/root34/Astra2of2')
        result['artifact_sha256'] = {path.name: digest(path) for path in sorted(evidence.iterdir()) if path.is_file()}
        (evidence/'qualification.json').write_text(json.dumps(result, indent=2)+'\n')
        print(json.dumps({key: value for key, value in result.items() if key not in ('source_before','source_after','cases')}, indent=2))
    return 0 if passed else 1

if __name__ == '__main__':
    if sys.argv[1:] == ['--peer']:
        peer()
    else:
        sys.exit(main())
