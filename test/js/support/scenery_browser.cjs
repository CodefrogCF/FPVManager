'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict'),{spawn}=require('node:child_process');
const browser=[process.env.FPV_CHROME,'C:/Program Files/Google/Chrome/Application/chrome.exe','C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe','/usr/bin/google-chrome','/usr/bin/chromium','/usr/bin/chromium-browser'].find(x=>x&&fs.existsSync(x));
async function pollPage(evaluate,url,timeoutMs,{now=Date.now,pause=ms=>new Promise(r=>setTimeout(r,ms))}={}){
  const deadline=now()+timeoutMs;let lastSnapshot,pollTimeouts=0;
  while(now()<deadline){
   let snapshot;
   try{snapshot=(await evaluate(`({status:document.body?.dataset.status,progress:document.body?.dataset.progress,
    result:document.getElementById('result')?.textContent,url:document.URL,ready:document.readyState,
    title:document.title})`,Math.min(5000,Math.max(1,deadline-now())))).result?.value;}
   catch(error){if(error.code!=='CDP_TIMEOUT')throw error;pollTimeouts++;continue;}
   lastSnapshot=snapshot;
   if(['pass','fail'].includes(snapshot?.status)){const result=JSON.parse(snapshot.result);assert.equal(result.status,snapshot.status,'Browser page status must agree with the result');return result;}
   if(snapshot?.ready==='complete'&&(snapshot.url?.startsWith('chrome-error:')||(snapshot.url===url&&snapshot.result===undefined))){
    // Only read layout-dependent innerText on a load error, never during GPU work.
    let body;try{if(now()<deadline)body=(await evaluate('document.body?.innerText?.slice(0,500)',Math.min(5000,Math.max(1,deadline-now())))).result?.value;}catch(error){if(error.code!=='CDP_TIMEOUT')throw error;}
    throw Error('Browser could not load test page or result element: '+JSON.stringify({...snapshot,body}));
   }
   await pause(Math.min(100,Math.max(0,deadline-now())));
  }
  // No extra CDP request after the deadline: a stalled renderer cannot extend the test.
  throw Error('Runtime timed out: '+JSON.stringify({lastSnapshot,pollTimeouts}));
}
// Keep startup separate from the actual renderer runtime budget.
const STARTUP_TIMEOUT_MS=45000;
async function runPage(url,{timeoutMs=45000,windowSize,disableGpu=false}={}){
 if(!browser)throw Error('Install Chromium or set FPV_CHROME');
 const profile=fs.mkdtempSync(path.join(os.tmpdir(),'fpv-provider-browser-'));let child,socket;
 try{
  const endpoint=await new Promise((resolve,reject)=>{
   child=spawn(browser,['--headless','--no-first-run','--no-default-browser-check','--disable-extensions','--no-proxy-server',...(disableGpu?['--disable-gpu']:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']),...(windowSize?['--window-size='+windowSize.width+','+windowSize.height]:[]),'--user-data-dir='+profile,'--remote-debugging-port=0',url],{windowsHide:true,stdio:['ignore','ignore','pipe']});
   let stderr='';const timer=setTimeout(()=>reject(Error('Chromium startup timed out after '+STARTUP_TIMEOUT_MS+'ms ('+browser+'): '+stderr)),STARTUP_TIMEOUT_MS);
   child.stderr.on('data',x=>{stderr=(stderr+x).slice(-8000);const match=stderr.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match){clearTimeout(timer);resolve(match[1]);}});
   child.once('error',e=>{clearTimeout(timer);reject(e);});child.once('exit',(code,signal)=>{clearTimeout(timer);reject(Error('Chromium exited '+(signal||code)+': '+stderr));});
  });
  const origin='http://127.0.0.1:'+new URL(endpoint).port;let target;
  for(let i=0;i<100&&!target;i++){target=(await(await fetch(origin+'/json/list')).json()).find(x=>x.type==='page'&&x.url.startsWith(new URL(url).origin));if(!target)await new Promise(r=>setTimeout(r,50));}
  assert.ok(target,'Runtime browser page is missing');socket=new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
  let sequence=0;const replies=new Map();socket.addEventListener('message',event=>{const message=JSON.parse(event.data);if(message.id){const pending=replies.get(message.id);replies.delete(message.id);message.error?pending?.reject(Error(message.error.message)):pending?.resolve(message.result);}});
  const command=(method,params,commandTimeoutMs=5000)=>new Promise((resolve,reject)=>{const id=++sequence;
   const timer=setTimeout(()=>{replies.delete(id);const error=Error('DevTools command timed out: '+method);error.code='CDP_TIMEOUT';reject(error);},commandTimeoutMs);
   replies.set(id,{resolve:value=>{clearTimeout(timer);resolve(value);},reject:error=>{clearTimeout(timer);reject(error);}});
   try{socket.send(JSON.stringify({id,method,params}));}catch(error){replies.delete(id);clearTimeout(timer);reject(error);}
  });
  const evaluate=(expression,commandTimeoutMs)=>command('Runtime.evaluate',{expression,returnByValue:true},commandTimeoutMs);
  if(windowSize)await command('Emulation.setDeviceMetricsOverride',{...windowSize,deviceScaleFactor:1,mobile:true});
  return await pollPage(evaluate,url,timeoutMs);
 }finally{
  socket?.close();
  // Wait for Chromium to exit before the next serial browser test starts.
  if(child?.pid&&child.exitCode===null&&child.signalCode===null){
   await new Promise(resolve=>{
    const done=()=>{clearTimeout(timer);child.removeListener('exit',done);resolve();};
    const timer=setTimeout(()=>{child.kill('SIGKILL');done();},5000);
    child.once('exit',done);if(!child.kill())done();
   });
  }
  const target=path.resolve(profile);
  assert.ok(target.startsWith(path.resolve(os.tmpdir())+path.sep)&&path.basename(target).startsWith('fpv-provider-browser-'));
  try{fs.rmSync(target,{recursive:true,force:true});}catch(_){/* Chromium shutdown may retain a temporary lock. */}
 }
}
module.exports={browser,runPage,pollPage};
