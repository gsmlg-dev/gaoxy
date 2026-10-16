
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {spawn} = require('node:child_process');
const readline = require('node:readline');
(async () => {
 const [origin, directory, protocol, spki, netlogPath] = process.argv.slice(1);
 assert(['h2','http/1.1'].includes(protocol));
 const originURL=new URL(origin);
 assert.equal(originURL.hostname,'127.0.0.1');assert.match(originURL.port,/^[0-9]+$/);
 assert.equal(originURL.protocol,protocol==='h2'?'https:':'http:');
 assert.equal(originURL.origin,origin);
 const profile = await fs.mkdtemp(path.join(os.tmpdir(), 'gaoxy-native-worker-browser-'));
 const chrome = spawn(process.env.GAOXY_CHROME_BIN || 'chromium', ['--headless=new','--no-first-run','--no-default-browser-check',
  '--disable-background-networking','--disable-component-update','--disable-sync','--disable-extensions',
  '--remote-debugging-port=0',`--user-data-dir=${profile}`,
  `--log-net-log=${netlogPath}`,'--net-log-capture-mode=Default',
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
  const target=c.target, title='Gaoxy group H2 Generation '+label, marker='Gaoxy checked group H2 Generation '+label;
  const nav=await request('Page.navigate',{url:origin+target});
  const diagnosticRequestIds=new Set(events.filter(e=>e.method==='Network.requestWillBeSent'&&e.params.request.url===origin+target).map(e=>e.params.requestId));
  if(nav.errorText)emit({event:'navigation_error_observed_v1',schema:1,label,error:nav.errorText.slice(0,128),
   response_heads:events.filter(e=>e.method==='Network.responseReceived'&&e.params.response.url===origin+target).slice(-4).map(e=>({status:e.params.response.status,protocol:e.params.response.protocol})),
   extra_statuses:events.filter(e=>e.method==='Network.responseReceivedExtraInfo'&&diagnosticRequestIds.has(e.params.requestId)).slice(-4).map(e=>({status:e.params.statusCode}))});
  assert(!nav.errorText,nav.errorText);
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
