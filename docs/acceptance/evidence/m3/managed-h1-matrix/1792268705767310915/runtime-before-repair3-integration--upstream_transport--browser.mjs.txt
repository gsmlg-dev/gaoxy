// Adapted from integration/http_fetch_contract/managed_h2_fixed_browser.mjs.
// CDP receipts only: no NetLog, private traces, or blanket certificate bypass.
import assert from 'node:assert/strict';
import {mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawn} from 'node:child_process';
import {createInterface} from 'node:readline';
import {createHash} from 'node:crypto';

const [directory, row, protocol, spki] = process.argv.slice(2);
assert(directory && /^group-h[12]-tls$/.test(row));
assert(['http/1.1', 'h2'].includes(protocol));
assert(spki === '-' || /^[A-Za-z0-9+/]{43}=$/.test(spki));
const START = 10000, BARRIER = 5000, CASE = 20000;
const profile = await mkdtemp(join(tmpdir(), 'gaoxy-h1-matrix-browser-'));
const chromeArgv = ['--headless=new', '--no-first-run', '--no-default-browser-check',
  '--disable-background-networking', '--disable-component-update', '--disable-sync',
  '--disable-extensions', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
  ...(spki === '-' ? [] : [`--ignore-certificate-errors-spki-list=${spki}`]), 'about:blank'];
const chrome = spawn('google-chrome', chromeArgv, {stdio: ['ignore', 'ignore', 'pipe']});
const chromeExit = new Promise(resolve => {
  chrome.once('exit', (code, signal) => resolve({code, signal}));
  chrome.once('error', error => resolve({code: null, signal: null, error: String(error)}));
});
let stderr = '', socket, input, serial = 0, passed = false, deadline = Date.now() + START;
let interrupted = false, forced = false;
const pending = new Map(), events = [];
chrome.stderr.on('data', data => { stderr = (stderr + data.toString()).slice(-65536); });
process.on('SIGTERM', () => { interrupted = true; input?.close(); });
const emit = value => process.stdout.write(JSON.stringify(value) + '\n');
const left = limit => Math.max(1, Math.min(limit, deadline - Date.now()));
const bounded = (promise, milliseconds, label) => new Promise((resolve, reject) => {
  const timer = setTimeout(() => reject(Error(`browser deadline: ${label}`)), milliseconds);
  promise.then(value => { clearTimeout(timer); resolve(value); }, error => { clearTimeout(timer); reject(error); });
});
function request(method, params = {}) {
  assert(socket?.readyState === WebSocket.OPEN, 'CDP socket unavailable');
  const id = ++serial;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(Error(`CDP deadline: ${method}`)); }, left(BARRIER));
    pending.set(id, {resolve, reject, timer});
    socket.send(JSON.stringify({id, method, params}));
  });
}
async function waitFor(predicate, label) {
  const expires = Math.min(deadline, Date.now() + BARRIER);
  while (!predicate()) {
    assert(!interrupted && Date.now() < expires, `browser barrier deadline: ${label}`);
    await new Promise(resolve => setTimeout(resolve, 10));
  }
}
async function evaluate(expression) {
  const value = await request('Runtime.evaluate', {expression, awaitPromise: true, returnByValue: true});
  assert(!value.exceptionDetails, JSON.stringify(value.exceptionDetails));
  return value.result.value;
}
try {
  let port;
  while (!port) {
    try { port = Number((await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]); }
    catch (error) { assert.equal(error.code, 'ENOENT'); }
    assert(!interrupted && chrome.exitCode === null && Date.now() < deadline, 'Chrome startup deadline: ' + stderr);
    if (!port) await new Promise(resolve => setTimeout(resolve, 10));
  }
  const targets = await bounded(fetch(`http://127.0.0.1:${port}/json/list`,
    {signal: AbortSignal.timeout(left(BARRIER))}).then(value => value.json()), left(BARRIER), 'target list');
  const target = targets.find(value => value.type === 'page' && value.url === 'about:blank');
  assert(target, 'isolated Chrome target missing');
  socket = new WebSocket(target.webSocketDebuggerUrl);
  socket.addEventListener('close', () => {
    for (const item of pending.values()) { clearTimeout(item.timer); item.reject(Error('CDP socket closed')); }
    pending.clear();
  });
  socket.addEventListener('message', message => {
    try {
      const value = JSON.parse(message.data);
      if (value.id) {
        const item = pending.get(value.id);
        if (item) {
          pending.delete(value.id); clearTimeout(item.timer);
          if (value.error) item.reject(Error(JSON.stringify(value.error))); else item.resolve(value.result);
        }
      } else {
        assert(events.length < 4096, 'CDP event bound exceeded');
        events.push(value);
      }
    } catch (error) { emit({event: 'failure', reason: String(error)}); process.exitCode = 1; input?.close(); }
  });
  await bounded(new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, {once: true});
    socket.addEventListener('error', reject, {once: true});
  }), left(BARRIER), 'CDP open');
  for (const domain of ['Page', 'Network', 'Runtime', 'Log']) await request(domain + '.enable');
  await request('Network.setCacheDisabled', {cacheDisabled: true});
  await request('Network.setBlockedURLs', {urls: ['*favicon.ico']});
  await request('Emulation.setDeviceMetricsOverride', {width: 1280, height: 800, deviceScaleFactor: 1, mobile: false});
  emit({event: 'ready', row, protocol, node: process.version, version: await request('Browser.getVersion'),
    chrome_pid: chrome.pid, chrome_argv: ['google-chrome', ...chromeArgv], target_id: target.id,
    trust: spki === '-' ? 'cleartext-loopback' : 'test-certificate-spki-only', spki});
  input = createInterface({input: process.stdin});
  for await (const line of input) {
    const command = JSON.parse(line);
    if (command.op === 'exit') { passed = true; break; }
    assert.equal(command.op, 'page');
    assert(['pageA', 'pageB'].includes(command.page));
    const origin = command.origin;
    assert(protocol === 'h2' ? /^https:\/\/localhost:[0-9]{1,5}$/.test(origin) :
      /^http:\/\/127\.0\.0\.1:[0-9]{1,5}$/.test(origin));
    deadline = Date.now() + CASE;
    const start = events.length, url = origin + '/' + command.page;
    const navigation = await request('Page.navigate', {url});
    assert(!navigation.errorText, navigation.errorText);
    const head = () => events.slice(start).find(event => event.method === 'Network.responseReceived' &&
      event.params.response.url === url && event.params.type === 'Document')?.params;
    await waitFor(() => head() && events.slice(start).some(event => event.method === 'Network.loadingFinished' &&
      event.params.requestId === head().requestId), 'document completion');
    await waitFor(() => events.slice(start).some(event => event.method === 'Page.loadEventFired'),
      'document load');
    const response = head();
    assert.equal(response.response.protocol, protocol);
    assert.equal(response.response.status, 200);
    assert.equal(response.loaderId, navigation.loaderId);
    const observed = await evaluate(`({url: location.href, title: document.title,
      text: document.querySelector('#receipt')?.textContent, body: document.body.innerText})`);
    assert.deepEqual(observed, {url, title: command.title, text: command.text, body: command.text});
    const received = await request('Network.getResponseBody', {requestId: response.requestId});
    const bytes = Buffer.from(received.body, received.base64Encoded ? 'base64' : 'utf8');
    const sha256 = createHash('sha256').update(bytes).digest('hex');
    assert.equal(sha256, command.body_sha256);
    const diagnostics = events.slice(start).filter(event => ['Runtime.consoleAPICalled',
      'Runtime.exceptionThrown'].includes(event.method) || event.method === 'Log.entryAdded' &&
      ['error', 'warning'].includes(event.params.entry.level));
    assert.equal(diagnostics.length, 0, JSON.stringify(diagnostics));
    const screenshot = `${row}-${command.page}.png`;
    const image = Buffer.from((await request('Page.captureScreenshot',
      {format: 'png', captureBeyondViewport: false})).data, 'base64');
    await writeFile(join(directory, screenshot), image, {flag: 'wx'});
    emit({event: 'page', status: 'PASS', row, page: command.page, observed, navigation,
      network: {requestId: response.requestId, loaderId: response.loaderId,
        url: response.response.url, status: response.response.status, protocol: response.response.protocol,
        connectionId: response.response.connectionId, connectionReused: response.response.connectionReused,
        remoteIPAddress: response.response.remoteIPAddress, remotePort: response.response.remotePort,
        fromDiskCache: response.response.fromDiskCache || false,
        fromServiceWorker: response.response.fromServiceWorker || false},
      body: {body64: bytes.toString('base64'), body_bytes: bytes.length, body_sha256: sha256},
      screenshot: {path: screenshot, bytes: image.length, sha256: createHash('sha256').update(image).digest('hex')},
      diagnostics, root_visual_inspection: 'NOT RUN'});
  }
  assert(passed && !interrupted, 'browser input ended without explicit exit');
} catch (error) {
  emit({event: 'failure', reason: String(error.stack)});
  process.exitCode = 1;
} finally {
  input?.close();
  deadline = Date.now() + START;
  if (socket?.readyState === WebSocket.OPEN) {
    try { await request('Browser.close'); } catch { /* Chrome may close CDP before replying. */ }
    socket.close();
  }
  let joined;
  try { joined = await bounded(chromeExit, left(BARRIER), 'normal Chrome join'); }
  catch {
    forced = true; chrome.kill('SIGKILL');
    try { joined = await bounded(chromeExit, left(BARRIER), 'forced Chrome join'); }
    catch (error) { joined = {error: String(error)}; }
  }
  await writeFile(join(directory, row + '-chrome-stderr.log'), stderr, {flag: 'wx'});
  await rm(profile, {recursive: true, force: true});
  const normal = joined.code === 0 && joined.signal === null && !joined.error;
  emit({event: 'joined', passed: passed && !process.exitCode && normal && !forced,
    forced, process: joined, isolated_profile_removed: true});
  if (forced || !normal) process.exitCode = 1;
}
