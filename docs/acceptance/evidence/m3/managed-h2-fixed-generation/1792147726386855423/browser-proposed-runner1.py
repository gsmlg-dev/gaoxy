#!/usr/bin/env python3
"""SOURCE-ONLY complete runner draft; NOT COMPILED/EXECUTED OR APPROVED.
Preserves E1 Actor/process-group/readers/adopted-child custody and CDP close.
No syntax/runtime qualification was performed. See matching proposal for gaps.
"""
import argparse
import ctypes
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
HOST = Path(__file__).resolve().with_name('gaoxy-fixed-h2-generation-browser-host-draft1.exs')
COHORT = ROOT/'docs/acceptance/evidence/m3/native-worker-accounting/1792113258488285300/native-worker-browser-cohort3.exs'
PEER = ROOT/'apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py'
PEER_PYTHON = '/tmp/gaoxy-m3-h2-soak-venv/bin/python'
TARGETS = {'old':'/old%2Fpath?raw=%2F', 'new':'/new%2Fpath?raw=%2F'}
def document(label):
    title = 'Gaoxy fixed H2 Generation '+label
    marker = 'Gaoxy checked fixed H2 Generation '+label
    html = ('<!doctype html><html><head><title>'+title+'</title>'
            '<link rel="icon" href="data:,"></head><body><h1 id="checked">'+marker+'</h1></body></html>').encode()
    return title, marker, html

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
 const chrome = spawn(process.env.GAOXY_CHROME_BIN || 'chromium', ['--headless=new','--no-first-run','--no-default-browser-check',
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
 const commands=[], waiters=[];
 input.on('line',line=>{const c=JSON.parse(line);if(waiters.length)waiters.shift()(c);else commands.push(c);});
 const command=()=>bounded(commands.length?Promise.resolve(commands.shift()):new Promise(resolve=>waiters.push(resolve)),20000,'browser command deadline');
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
  emit({event:'browser_ready',version,node:process.version});
  for(const label of ['old','new']) {
  const c=await command();assert.deepEqual(c,{op:'navigate',label,target:label==='old'?'/old%2Fpath?raw=%2F':'/new%2Fpath?raw=%2F'});
  const target=c.target, title='Gaoxy fixed H2 Generation '+label, marker='Gaoxy checked fixed H2 Generation '+label;
  const nav=await request('Page.navigate',{url:origin+target});assert(!nav.errorText,nav.errorText);
  let response;
  await until(()=>{
   response=events.find(e=>e.method==='Network.responseReceived'&&e.params.response.url===origin+target)?.params;
   return response&&events.some(e=>e.method==='Network.loadingFinished'&&e.params.requestId===response.requestId);
  },'page load deadline');
  assert.equal(response.response.protocol,protocol);assert.equal(response.response.status,200);assert.equal(response.type,'Document');
  if(protocol==='h2')assert.match(response.response.securityDetails.protocol,/^TLS/);
  const result=await request('Runtime.evaluate',{expression:'({title:document.title,text:document.querySelector("#checked")?.textContent,url:location.href})',returnByValue:true});
  assert(!result.exceptionDetails);assert.deepEqual(result.result.value,{title,text:marker,url:origin+target});
  const visible=await request('Runtime.evaluate',{expression:'(()=>{const e=document.querySelector("#checked"),r=e.getBoundingClientRect();return r.width>0&&r.height>0&&getComputedStyle(e).visibility==="visible";})()',returnByValue:true});
  assert(!visible.exceptionDetails);assert.equal(visible.result.value,true);
  assert(!events.some(e=>e.method==='Runtime.exceptionThrown'||e.method==='Runtime.consoleAPICalled'));
  const screenshot=await request('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
  await fs.writeFile(path.join(directory,label+'-browser.png'),Buffer.from(screenshot.data,'base64'));
  await fs.writeFile(path.join(directory,label+'-browser-events.json'),JSON.stringify(events,null,2)+'\n');
  emit({event:'probe',status:'PASS',label,version,node:process.version,document:result.result.value,visible:true,network:response});
  }
  assert.deepEqual(await command(),{op:'exit'});
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

ACTOR_PROCESSES = {}
ADOPTED_JOINS = []

def adopted_children():
    values = Path(f'/proc/{os.getpid()}/task/{os.getpid()}/children').read_text().split()
    return {int(value) for value in values
            if int(value) not in ACTOR_PROCESSES or
            ACTOR_PROCESSES[int(value)].returncode is not None}

def reap_adopted():
    # Chrome may orphan internal children. Reap their genuine terminal statuses;
    # never consume a fixture Actor's Popen wait or signal an already-dead child.
    for pid in adopted_children():
        try:
            joined, status = os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            continue
        if joined:
            ADOPTED_JOINS.append(dict(pid=joined, wait_status=status,
                                      exit=os.waitstatus_to_exitcode(status)))
    return adopted_children()

class Actor:
    def __init__(self, command, logfile, prefix=''):
        self.command, self.prefix = command, prefix
        self.log = logfile.open('x')
        self.events, self.seen, self.backlog = queue.Queue(), [], []
        self.process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, bufsize=1, start_new_session=True)
        ACTOR_PROCESSES[self.process.pid] = self.process
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
            reap_adopted()
            try:
                os.killpg(self.process.pid, 0)
                return True
            except ProcessLookupError:
                return False
        if self.process.poll() is not None:
            end = time.monotonic() + 3
            while group_alive() and time.monotonic() < end:
                time.sleep(.02)
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
    paths += [ROOT/'mix.exs', ROOT/'mix.lock', ROOT/'scripts/generate-fixtures.sh', HOST, COHORT, PEER, Path(__file__).resolve()]
    return {str(path): digest(path) for path in sorted(paths)}


def certificate_spki(certificates):
    openssl = os.environ.get('OPENSSL_BIN', 'openssl')
    public_key = subprocess.run([openssl, 'x509', '-in', str(certificates/'cert.pem'),
                                 '-pubkey', '-noout'], check=True, capture_output=True, timeout=10).stdout
    der = subprocess.run([openssl, 'pkey', '-pubin', '-outform', 'DER'], input=public_key,
                         check=True, capture_output=True, timeout=10).stdout
    return base64.b64encode(hashlib.sha256(der).digest()).decode('ascii')

def event_one_of(actor, names, timeout=25):
    # Preserve Actor implementation unchanged; use its bounded queue/backlog.
    for index, value in enumerate(actor.backlog):
        if value.get('event') in names:
            return actor.backlog.pop(index)
    end = time.monotonic()+timeout
    while time.monotonic() < end:
        value = actor.events.get(timeout=max(.001,end-time.monotonic()))
        assert value.get('event') not in ('process_eof','failure'), value
        if value.get('event') in names:
            return value
        actor.backlog.append(value)
    raise TimeoutError('missing '+repr(names))

def assert_capture(captured, mode, label):
    assert captured['mode'] == mode and captured['label'] == label
    assert captured['original_owner_effects'] == 1
    assert len(captured['pins']) == 1 and captured['pins'][0]['fields'] == 8
    assert captured['pins'][0]['provider'] == 'Elixir.Gaoxy.Proxy.UpstreamTransports'
    assert captured['reservation'] > 0
    target_bytes = captured['retained']+captured['reservation']
    def check_cohort(cut):
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
    check_cohort(captured['cohort'])
    assert captured['gate_bytes'] == captured['cohort']['retained_bytes']
    assert len(captured['original_cohorts']) == 1
    for cut in captured['original_cohorts']:
        check_cohort(cut)
    assert captured['original_gate_bytes'] == [cut['retained_bytes'] for cut in captured['original_cohorts']]
    if mode == 'h2':
        accounting = captured['worker_accounting']
        assert accounting['bytes'] == captured['retained']
        assert accounting['worker_bytes'] == target_bytes
        assert len(accounting['rows']) == 95
        assert accounting['downstream_alpn'] == 'h2' and accounting['secure']
        assert captured['native_ids']['worker'] != captured['native_ids']['connection']
    else:
        assert captured['worker_accounting'] is None


def run_case(mode, upstream_protocol, evidence, certificates, spki, cases, joins):
    evidence.mkdir()
    case = mode+'-'+upstream_protocol
    row = dict(case=case, status='FAIL', mode=mode, upstream_protocol=upstream_protocol)
    cases.append(row)
    actors, peers, captures, observations = [], {}, {}, []
    try:
        for label in ('old','new'):
            actor = Actor([PEER_PYTHON,'-B',str(PEER),'--staged-start','--manual',
                           '--protocol','tls' if upstream_protocol == 'http2' else 'h2c'],
                          evidence/(label+'-peer.log'))
            actors.append(actor)
            actor.event('prepared',25)
            actor.send({'op':'start'})
            ready = actor.event('ready',5)
            assert ready['protocol'] == ('tls' if upstream_protocol == 'http2' else 'h2c')
            assert ready['identity']['source_sha256'] == digest(PEER)
            peers[label] = (actor,ready)
        assert peers['old'][0].process.pid != peers['new'][0].process.pid
        assert peers['old'][1]['port'] != peers['new'][1]['port']
        manifest = evidence/'peer-ready.json'
        manifest.write_text(json.dumps({k:v[1] for k,v in peers.items()})+'\n')
        command = ['nix','develop','--command','env','ERL_FLAGS=+S 2:2','MIX_ENV=test',
                   'mix','run',str(HOST),str(manifest),str(evidence),mode,str(certificates),upstream_protocol]
        host = Actor(command,evidence/'host.log','NATIVE_WORKER_BROWSER ')
        actors.append(host)
        ready = host.event('ready',120)
        assert ready['mode'] == mode and ready['upstream_protocol'] == upstream_protocol
        protocol = 'h2' if mode == 'h2' else 'http/1.1'
        origin = ('https' if mode == 'h2' else 'http')+'://127.0.0.1:'+str(ready['port'])
        browser = Actor(['node','-e',BROWSER,origin,str(evidence),protocol,spki],evidence/'browser.log')
        actors.append(browser)
        browser.event('browser_ready')
        for label in ('old','new'):
            browser.send(dict(op='navigate',label=label,target=TARGETS[label]))
            captured = host.event('captured')
            assert_capture(captured,mode,label)
            captures[label] = captured
            if label == 'old':
                cas = host.event('cas')
                assert cas['old_admission_closed'] and cas['old_source_alive']
                assert cas['old_custodian_alive'] and cas['fresh_old_denied']
                assert cas['snapshot_changed'] and cas['preparation_released_by_holder']
            if label == 'old':
                assert all(not any(e.get('event') in ('request','accept') for e in p.seen) for p,_ in peers.values())
            host.send(dict(op='dispatch',label=label))
            peer, peer_ready = peers[label]
            accept = peer.event('accept')
            request = peer.event('request')
            headers = dict(request['headers'])
            assert request['target'] == TARGETS[label] and request['ended']
            assert headers[':path'] == TARGETS[label] and headers[':method'] == 'GET'
            assert headers[':authority'] == 'localhost:'+str(peer_ready['port'])
            assert headers[':scheme'] == ('https' if upstream_protocol == 'http2' else 'http')
            assert request['connection'] == accept['connection']
            tls = None
            if upstream_protocol == 'http2':
                tls = peer.event('tls')
                assert tls['connection'] == request['connection'] and tls['alpn'] == 'h2' and tls['sni'] == 'localhost'
            custody = host.event('session_custody')
            assert custody['label'] == label and custody['derived']
            assert custody['native'] == captured['holder'] and custody['session'] != captured['holder']
            assert custody['public_t8_fields'] == 8 and custody['acquirer'] == captured['holder']
            assert custody['cleanup_bytes'] > 0
            host.send(dict(op='prove_bound',label=label))
            bound = host.event('bound')
            assert bound['label'] == label and bound['original_completion_equal'] and bound['pending']
            assert bound['source_genuine'] and bound['child_genuine'] and bound['token_genuine']
            assert bound['session'] == custody['session']
            title, marker, html = document(label)
            command_id = case+'-'+label+'-response'
            peer.send(dict(op='respond',connection=request['connection'],stream=request['stream'],
                           fields=[['content-type','text/html; charset=utf-8'],['cache-control','no-store']],
                           body64=base64.b64encode(html).decode(),command_id=command_id))
            ack = peer.event('command')
            assert ack['command_id'] == command_id and ack['op'] == 'respond'
            assert ack['connection'] == request['connection'] and ack['stream'] == request['stream']
            held = host.event('returned_source_held')
            assert held['label'] == label and held['original_completion_ok'] and held['session_joined']
            assert held['child_gone'] and held['token_gone'] and held['source_genuine']
            assert held['custodian_alive'] and not held['retirement_requested']
            host.send(dict(op='release_return',label=label))
            if label == 'old':
                retired = host.event('old_retired')
                assert retired['source_gone'] and retired['record_gone'] and retired['custodian_normal_down']
                physical = event_one_of(peer,('eof','connection_reset'))
                assert physical['connection'] == request['connection']
            probe = browser.event('probe')
            assert probe['label'] == label and probe['status'] == 'PASS' and probe['visible']
            assert probe['network']['response']['protocol'] == protocol
            assert probe['network']['response']['status'] == 200
            assert probe['document'] == dict(title=title,text=marker,url=origin+TARGETS[label])
            host.send(dict(op='request_clean',label=label))
            clean = host.event('request_clean')
            assert clean['label'] == label and clean['session_joined'] and clean['original_source_gone']
            assert custody == dict(event='session_custody', **clean['custody'])
            if mode == 'h2':
                assert clean['native_worker_joined']
            assert clean['complete_cohort_validated'] and clean['connection_alive']
            observations.append(dict(label=label,captured=captured,custody=custody,bound=bound,
                                     held=held,request=request,peer_pid=peer.process.pid,
                                     peer_ready=peer_ready,tls=tls,browser=probe,request_clean=clean))
        # Identity includes ACTUAL peer process/ready port, not just stream/conn1.
        assert (observations[0]['peer_pid'],observations[0]['peer_ready']['port']) != (observations[1]['peer_pid'],observations[1]['peer_ready']['port'])
        host.send({'op':'authorize_browser_close'})
        close_authorized = host.event('browser_close_authorized')
        assert close_authorized['mode'] == mode and close_authorized['connection_alive']
        expected_connection = (captures['new']['native_ids']['connection'] if mode == 'h2' else captures['new']['holder'])
        assert close_authorized['connection'] == expected_connection
        browser.send({'op':'exit'})
        browser_join = browser.event('joined')
        assert browser_join['passed'] and browser_join['profile_removed'] and browser_join['close_requested']
        assert browser_join['chrome_exit'] == 0 and browser_join['chrome_signal'] is None
        browser.join()
        host.send({'op':'stop'})
        clean = host.event('closed_browser_clean')
        assert clean['connection_joined'] and clean['connection_reason'] == '{:shutdown, :peer_closed}'
        assert clean['observer_joined'] and clean['cohort_joins']
        assert len({v['pid'] for v in clean['cohort_joins']}) == len(clean['cohort_joins'])
        assert all(v['genuine_terminal'] for v in clean['cohort_joins'])
        for captured in captures.values():
            assert any(v['pid'] == captured['native_ids']['connection'] for v in clean['cohort_joins'])
        assert clean['service'] == dict(active=0,retained_bytes=0,cleanup_pending=0,cleanup_failed=None)
        stopped = host.event('stopped')
        assert stopped['cleanup_confirmed'] and stopped['source_stable'] and stopped['captures'] == 2
        assert stopped['sessions_joined'] == 2 and stopped['native_actors_joined']
        assert stopped['custodians_normal_down'] == 2 and stopped['owner_normal_down']
        assert stopped['instance_normal_down'] and stopped['listener_rebound']
        new_physical = event_one_of(peers['new'][0], ('eof','connection_reset'))
        assert new_physical['connection'] == observations[1]['request']['connection']
        peer_joins = {}
        for label,(peer,_) in peers.items():
            peer.send({'op':'stop'})
            joined = peer.event('joined')
            assert joined['requests'] == 1 and joined['accepts'] == 1
            assert joined['forced'] == 0 and joined['live'] == 0 and not joined['failed']
            peer.join()
            peer_joins[label] = joined
        host.send({'op':'exit'})
        host.process.stdin.close()
        host.event('exited')
        host.join()
        assert json.loads((evidence/'host-loaded-before.json').read_text()) == json.loads((evidence/'host-loaded-after.json').read_text())
        for label in ('old','new'):
            assert (evidence/(label+'-browser.png')).stat().st_size > 0
        row.update(status='PASS',observations=observations,closed_browser_cleanup=clean,
                   stopped=stopped,browser_join=browser_join,peer_joins=peer_joins)
    except Exception:
        row['failure'] = traceback.format_exc()
        raise
    finally:
        cleanup_errors = []
        for actor in reversed(actors):
            try:
                joined = actor.dispose()
                joined['case'] = case
                joins.append(joined)
            except Exception:
                cleanup_errors.append(traceback.format_exc())
                joins.append(dict(case=case,command=actor.command,pid=actor.process.pid,
                                  exit=actor.process.poll(),forced=True,cleanup_failed=True))
        if cleanup_errors or any(v['forced'] or v['exit'] != 0 for v in joins if v['case'] == case):
            row['status'] = 'FAIL'
            row['cleanup_errors'] = cleanup_errors
            raise AssertionError('owned browser/host/peer shutdown failed or required forcing')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--evidence-dir', '--evidence', dest='evidence', type=Path, required=True)
    args = parser.parse_args()
    evidence = args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=False)
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(36, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'PR_SET_CHILD_SUBREAPER')
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
                for upstream_protocol in ('h2c','http2'):
                    run_case(mode,upstream_protocol,evidence/(mode+'-'+upstream_protocol),certificates,spki,cases,joins)
        assert not certificates.exists(), 'ephemeral test certificate directory remains'
        passed = len(cases) == 4 and all(row['status'] == 'PASS' for row in cases)
    except Exception:
        failure = traceback.format_exc()
    finally:
        end = time.monotonic() + 10
        while reap_adopted() and time.monotonic() < end:
            time.sleep(.02)
        remaining = sorted(reap_adopted())
        after = inventory()
        passed = passed and not remaining and before == after and all(not row['forced'] and row['exit'] == 0 for row in joins)
        result = dict(status='PASS' if passed else 'FAIL', head=head, executed=len(cases), cases=cases,
                      elapsed_ms=round((time.monotonic()-started)*1000), source_before=before,
                      source_after=after, source_stable=before == after, failure=failure, joins=joins,
                      adopted_joins=ADOPTED_JOINS, adopted_remaining=remaining,
                      entry_counters='group41/root55/Astra2of2; successor failedGREEN0; source-only draft NOT RUN')
        result['artifact_sha256'] = {str(path.relative_to(evidence)): digest(path)
                                    for path in sorted(evidence.rglob('*')) if path.is_file()}
        (evidence/'qualification.json').write_text(json.dumps(result, indent=2)+'\n')
        print(json.dumps({key: value for key, value in result.items()
                          if key not in ('source_before','source_after','cases')}, indent=2))
    return 0 if passed else 1

if __name__ == '__main__':
    sys.exit(main())

