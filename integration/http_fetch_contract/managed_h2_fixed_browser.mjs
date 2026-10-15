import assert from 'node:assert/strict';
import {mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {createInterface} from 'node:readline';

const [directory, spki, fixture] = process.argv.slice(2);
assert(directory && /^[A-Za-z0-9+/]{43}=$/.test(spki) && /^[a-z-]+$/.test(fixture));
const profile = await mkdtemp(join(tmpdir(), 'gaoxy-fixed-h2-browser-'));
const chrome = spawn('google-chrome', ['--headless=new', '--no-first-run',
  '--no-default-browser-check', '--disable-background-networking', '--disable-component-update',
  '--disable-sync', '--disable-extensions', '--remote-debugging-port=0',
  `--user-data-dir=${profile}`, `--ignore-certificate-errors-spki-list=${spki}`, 'about:blank'],
  {stdio: ['ignore', 'ignore', 'pipe']});
const processExit = new Promise(resolve => chrome.once('exit', (code, signal) => resolve({code, signal})));
let stderr = '', socket, serial = 0, input, interrupted = false, lastNavigation;
chrome.stderr.on('data', data => { stderr = (stderr + data.toString()).slice(-65536); });
const pending = new Map(), events = [];
process.on('SIGTERM', () => {
  interrupted = true;
  input?.close();
  socket?.close();
  chrome.kill('SIGTERM');
});
function request(method, params = {}) {
  const id = ++serial;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`CDP deadline: ${method}`)); }, 15000);
    pending.set(id, {resolve, reject, timer});
    socket.send(JSON.stringify({id, method, params}));
  });
}
function emit(value) { process.stdout.write('BROWSER_H2 ' + JSON.stringify(value) + '\n'); }
async function evaluate(expression) {
  const result = await request('Runtime.evaluate', {expression, awaitPromise: true, returnByValue: true});
  assert(!result.exceptionDetails, JSON.stringify(result.exceptionDetails));
  return result.result.value;
}
async function waitFor(predicate, label) {
  const expires = Date.now() + 15000;
  while (!predicate()) {
    assert(!interrupted && Date.now() < expires, `browser barrier deadline: ${label}`);
    await new Promise(resolve => setTimeout(resolve, 10));
  }
}
function response(path, origin) {
  return events.filter(event => event.method === 'Network.responseReceived' &&
    event.params.response.url === origin + path).at(-1)?.params;
}
async function navigate(origin, path) {
  const result = await request('Page.navigate', {url: origin + path});
  lastNavigation = {url: origin + path, result};
  assert(!result.errorText, result.errorText);
  await waitFor(() => {
    const head = response(path, origin);
    return head && events.some(event => event.method === 'Network.loadingFinished' &&
      event.params.requestId === head.requestId);
  }, path);
  return response(path, origin);
}
let passed = false;
try {
  let port;
  const expires = Date.now() + 15000;
  while (!port) {
    try { port = Number((await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]); }
    catch (error) { assert(error.code === 'ENOENT', String(error)); }
    if (!port) {
      assert(chrome.exitCode === null && Date.now() < expires, 'Chrome startup failed: ' + stderr);
      await new Promise(resolve => setTimeout(resolve, 10));
    }
  }
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const page = targets.find(target => target.type === 'page' && target.url === 'about:blank');
  assert(page, 'missing isolated browser page');
  socket = new WebSocket(page.webSocketDebuggerUrl);
  socket.addEventListener('close', () => {
    for (const item of pending.values()) {
      clearTimeout(item.timer); item.reject(new Error('isolated Chrome socket closed'));
    }
    pending.clear();
  });
  socket.addEventListener('message', message => {
    const value = JSON.parse(message.data);
    if (value.id) {
      const item = pending.get(value.id);
      if (item) {
        pending.delete(value.id); clearTimeout(item.timer);
        if (value.error) item.reject(new Error(JSON.stringify(value.error)));
        else item.resolve(value.result);
      }
    } else {
      assert(events.length < 8192, 'browser event bound exceeded');
      events.push(value);
    }
  });
  await new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, {once: true});
    socket.addEventListener('error', reject, {once: true});
  });
  await request('Page.enable');
  await request('Network.enable');
  await request('Runtime.enable');
  await request('Log.enable');
  await request('Network.setBlockedURLs', {urls: ['*favicon.ico']});
  await request('Emulation.setDeviceMetricsOverride', {width: 1280, height: 800, deviceScaleFactor: 1, mobile: false});
  emit({event: 'ready', fixture, version: await request('Browser.getVersion'), node: process.version,
    trust: 'test-certificate-spki-only', spki});
  input = createInterface({input: process.stdin});
  for await (const line of input) {
    const command = JSON.parse(line);
    if (command.op === 'exit') { passed = true; break; }
    assert(/^https:\/\/localhost:[0-9]{1,5}$/.test(command.origin));
    const origin = command.origin;
    const start = events.length;
    if (command.op === 'probe') {
      const head = await navigate(origin, '/probe');
      assert.equal(head.response.protocol, 'h2'); assert.equal(head.response.status, 200);
      const visible = await evaluate(`({title: document.title, text: document.querySelector('#probe')?.textContent})`);
      assert.deepEqual(visible, {title: 'Gaoxy managed H2', text: 'managed H2 probe'});
      const streamed = await evaluate(`(async () => {
        const r = await fetch('/stream'); const reader = r.body.getReader();
        let chunks = [], bytes = 0;
        while (true) { const v = await reader.read(); if (v.done) break;
          bytes += v.value.length; if (bytes > 1048576) throw Error('browser body bound'); chunks.push(v.value); }
        const body = new Uint8Array(bytes); let offset = 0;
        for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.length; }
        return {status: r.status, bytes, text: new TextDecoder().decode(body),
          sha256: Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', body)),
            value => value.toString(16).padStart(2, '0')).join('')}; })()`);
      assert.equal(streamed.status, 200); assert.equal(streamed.bytes, 18 + 65536);
      assert.equal(streamed.text, 'managed-h2-stream:' + 's'.repeat(65536));
      const early = await evaluate(`(async () => { const r = await fetch('/early',
        {method: 'POST', body: 'browser-upload'}); return {status: r.status, text: await r.text()}; })()`);
      assert.deepEqual(early, {status: 413, text: 'early-final'});
      await waitFor(() => response('/early', origin) && response('/stream', origin), 'fetch network evidence');
      for (const path of ['/stream', '/early']) assert.equal(response(path, origin).response.protocol, 'h2');
      await evaluate(`document.body.append(Object.assign(document.createElement('p'),
        {id: 'verified', textContent: 'stream: 65554 bytes; early: 413 early-final'}))`);
      const screenshot = await request('Page.captureScreenshot', {format: 'png', captureBeyondViewport: false});
      await writeFile(join(directory, 'browser-probe.png'), Buffer.from(screenshot.data, 'base64'));
      const outcomes = {probe: visible, stream: {status: streamed.status, bytes: streamed.bytes,
        sha256: streamed.sha256}, early};
      await writeFile(join(directory, 'browser-probe-events.json'), JSON.stringify(events.slice(start), null, 2));
      emit({event: 'probe', status: 'PASS', outcomes,
        network: ['/probe', '/stream', '/early'].map(path => response(path, origin)),
        browser_log: events.slice(start).filter(event => event.method === 'Log.entryAdded'),
        console: events.slice(start).filter(event => event.method === 'Runtime.consoleAPICalled' ||
          event.method === 'Runtime.exceptionThrown')});
    } else {
      assert.equal(command.op, 'negative');
      const url = origin + '/must-not-replay';
      const navigation = await request('Page.navigate', {url});
      lastNavigation = {url, result: navigation};
      assert.equal(navigation.errorText, 'net::ERR_HTTP_RESPONSE_CODE_FAILURE');
      await waitFor(() => {
        const head = response('/must-not-replay', origin);
        return head && events.some(event => event.method === 'Network.loadingFailed' &&
          event.params.requestId === head.requestId) &&
          events.some(event => event.method === 'Page.frameNavigated' &&
            event.params.frame.loaderId === navigation.loaderId &&
            event.params.frame.url === 'chrome-error://chromewebdata/');
      }, 'negative response and Chrome error document');
      const head = response('/must-not-replay', origin);
      assert.equal(head.response.protocol, 'h2'); assert.equal(head.response.status, 502);
      assert.equal(head.type, 'Document'); assert.equal(head.loaderId, navigation.loaderId);
      assert.equal(head.response.headers['content-length'], '0');
      const failed = events.find(event => event.method === 'Network.loadingFailed' &&
        event.params.requestId === head.requestId).params;
      assert.equal(failed.errorText, navigation.errorText); assert.equal(failed.canceled, false);
      const frame = (await request('Page.getFrameTree')).frameTree.frame;
      assert.equal(frame.url, 'chrome-error://chromewebdata/');
      assert.equal(frame.unreachableUrl, url); assert.equal(frame.loaderId, head.loaderId);
      const document = await evaluate(`({url: location.href, title: document.title,
        error: document.querySelector('.error-code')?.textContent.trim()})`);
      assert.deepEqual(document, {url: 'chrome-error://chromewebdata/', title: 'localhost', error: 'HTTP ERROR 502'});
      const caseEvents = events.slice(start);
      assert(!caseEvents.some(event => event.method === 'Runtime.exceptionThrown'));
      assert(!caseEvents.some(event => event.method === 'Runtime.consoleAPICalled'));
      const browserLog = caseEvents.filter(event => event.method === 'Log.entryAdded');
      assert.equal(browserLog.length, 1);
      assert.equal(browserLog[0].params.entry.source, 'network');
      assert.equal(browserLog[0].params.entry.level, 'error');
      assert.equal(browserLog[0].params.entry.networkRequestId, head.requestId);
      assert.equal(browserLog[0].params.entry.text, 'Failed to load resource: the server responded with a status of 502 ()');
      const screenshot = await request('Page.captureScreenshot', {format: 'png', captureBeyondViewport: false});
      await writeFile(join(directory, command.name + '-browser.png'), Buffer.from(screenshot.data, 'base64'));
      await writeFile(join(directory, command.name + '-browser-events.json'), JSON.stringify(caseEvents, null, 2));
      emit({event: 'negative', name: command.name, status: 'PASS', document, navigation, failed,
        server_body: {declared_bytes: 0}, network: head, frame, browser_log: browserLog,
        console: caseEvents.filter(event => event.method === 'Runtime.consoleAPICalled')});
    }
  }
  assert(passed, 'browser stdin ended before explicit exit');
} catch (error) {
  let diagnostic;
  try {
    if (lastNavigation?.result.errorText) {
      await waitFor(() => events.some(event => event.method === 'Page.frameNavigated' &&
        event.params.frame.url === 'chrome-error://chromewebdata/'), 'failed navigation error document');
    }
    diagnostic = {navigation: lastNavigation, frame: await request('Page.getFrameTree'),
      document: await evaluate('({url: location.href, title: document.title, text: document.body?.textContent, html: document.documentElement?.outerHTML})')};
  } catch (diagnosticError) { diagnostic = {navigation: lastNavigation, reason: String(diagnosticError)}; }
  await writeFile(join(directory, fixture + '-failure-events.json'), JSON.stringify(events, null, 2));
  await writeFile(join(directory, fixture + '-failure-document.json'), JSON.stringify(diagnostic, null, 2));
  emit({event: 'failure', reason: String(error.stack)});
  process.exitCode = 1;
} finally {
  input?.close();
  if (socket?.readyState === WebSocket.OPEN) {
    try { await request('Browser.close'); } catch {}
    socket.close();
  }
  const joined = await Promise.race([processExit,
    new Promise(resolve => setTimeout(() => resolve(null), 5000))]);
  let forced = false;
  if (!joined) { forced = true; chrome.kill('SIGKILL'); await processExit; }
  await writeFile(join(directory, fixture + '-chrome-stderr.log'), stderr);
  await rm(profile, {recursive: true, force: true});
  emit({event: 'joined', passed, forced, process: joined || await processExit, isolated_profile_removed: true});
  if (forced) process.exitCode = 1;
}
