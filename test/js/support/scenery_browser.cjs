'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict'),{spawn}=require('node:child_process');
const browser=[process.env.FPV_CHROME,'C:/Program Files/Google/Chrome/Application/chrome.exe','C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe','/usr/bin/google-chrome','/usr/bin/chromium'].find(x=>x&&fs.existsSync(x));
async function runPage(url,{timeoutMs=45000}={}){
 if(!browser)throw Error('Install Chromium or set FPV_CHROME');
 const profile=fs.mkdtempSync(path.join(os.tmpdir(),'fpv-provider-browser-'));let child,socket;
 try{
  const endpoint=await new Promise((resolve,reject)=>{
   child=spawn(browser,['--headless','--no-first-run','--no-default-browser-check','--disable-extensions','--no-proxy-server','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--user-data-dir='+profile,'--remote-debugging-port=0',url],{windowsHide:true,stdio:['ignore','ignore','pipe']});
   let stderr='';const timer=setTimeout(()=>reject(Error('Chromium startup timed out: '+stderr)),15000);
   child.stderr.on('data',x=>{stderr=(stderr+x).slice(-3000);const match=stderr.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match){clearTimeout(timer);resolve(match[1]);}});
   child.once('error',e=>{clearTimeout(timer);reject(e);});child.once('exit',code=>{clearTimeout(timer);reject(Error('Chromium exited '+code+': '+stderr));});
  });
  const origin='http://127.0.0.1:'+new URL(endpoint).port;let target;
  for(let i=0;i<100&&!target;i++){target=(await(await fetch(origin+'/json/list')).json()).find(x=>x.type==='page'&&x.url.startsWith(new URL(url).origin));if(!target)await new Promise(r=>setTimeout(r,50));}
  assert.ok(target,'Runtime browser page is missing');socket=new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
  let sequence=0;const replies=new Map();socket.addEventListener('message',event=>{const message=JSON.parse(event.data);if(message.id){const pending=replies.get(message.id);replies.delete(message.id);message.error?pending?.reject(Error(message.error.message)):pending?.resolve(message.result);}});
  const evaluate=expression=>new Promise((resolve,reject)=>{const id=++sequence;replies.set(id,{resolve,reject});socket.send(JSON.stringify({id,method:'Runtime.evaluate',params:{expression,returnByValue:true}}));});
  const deadline=Date.now()+timeoutMs;
  while(Date.now()<deadline){const status=await evaluate('document.body?.dataset.status');
   if(['pass','fail'].includes(status.result?.value)){const content=(await evaluate('document.getElementById("result").textContent')).result.value;return JSON.parse(content);}
   await new Promise(r=>setTimeout(r,100));
  }
  throw Error('Runtime timed out: '+JSON.stringify(await evaluate('document.getElementById("result")?.textContent')));
 }finally{
  socket?.close();child?.kill();const target=path.resolve(profile);
  assert.ok(target.startsWith(path.resolve(os.tmpdir())+path.sep)&&path.basename(target).startsWith('fpv-provider-browser-'));
  try{fs.rmSync(target,{recursive:true,force:true});}catch(_){/* Chromium shutdown may retain a temporary lock. */}
 }
}
module.exports={browser,runPage};
