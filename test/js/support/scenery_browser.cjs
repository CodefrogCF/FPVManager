'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),assert=require('node:assert/strict'),{spawn}=require('node:child_process');
const browser=[process.env.FPV_CHROME,'C:/Program Files/Google/Chrome/Application/chrome.exe','C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe','/usr/bin/google-chrome','/usr/bin/chromium','/usr/bin/chromium-browser'].find(x=>x&&fs.existsSync(x));
async function runPage(url,{timeoutMs=45000,windowSize,disableGpu=false}={}){
 if(!browser)throw Error('Install Chromium or set FPV_CHROME');
 const profile=fs.mkdtempSync(path.join(os.tmpdir(),'fpv-provider-browser-'));let child,socket;
 try{
  const endpoint=await new Promise((resolve,reject)=>{
   child=spawn(browser,['--headless','--no-first-run','--no-default-browser-check','--disable-extensions','--no-proxy-server',...(disableGpu?['--disable-gpu']:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']),...(windowSize?['--window-size='+windowSize.width+','+windowSize.height]:[]),'--user-data-dir='+profile,'--remote-debugging-port=0',url],{windowsHide:true,stdio:['ignore','ignore','pipe']});
   let stderr='';const timer=setTimeout(()=>reject(Error('Chromium startup timed out: '+stderr)),15000);
   child.stderr.on('data',x=>{stderr=(stderr+x).slice(-3000);const match=stderr.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match){clearTimeout(timer);resolve(match[1]);}});
   child.once('error',e=>{clearTimeout(timer);reject(e);});child.once('exit',code=>{clearTimeout(timer);reject(Error('Chromium exited '+code+': '+stderr));});
  });
  const origin='http://127.0.0.1:'+new URL(endpoint).port;let target;
  for(let i=0;i<100&&!target;i++){target=(await(await fetch(origin+'/json/list')).json()).find(x=>x.type==='page'&&x.url.startsWith(new URL(url).origin));if(!target)await new Promise(r=>setTimeout(r,50));}
  assert.ok(target,'Runtime browser page is missing');socket=new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
  let sequence=0;const replies=new Map();socket.addEventListener('message',event=>{const message=JSON.parse(event.data);if(message.id){const pending=replies.get(message.id);replies.delete(message.id);message.error?pending?.reject(Error(message.error.message)):pending?.resolve(message.result);}});
  const command=(method,params)=>new Promise((resolve,reject)=>{const id=++sequence;
   const timer=setTimeout(()=>{replies.delete(id);reject(Error('DevTools command timed out: '+method));},5000);
   replies.set(id,{resolve:value=>{clearTimeout(timer);resolve(value);},reject:error=>{clearTimeout(timer);reject(error);}});
   try{socket.send(JSON.stringify({id,method,params}));}catch(error){replies.delete(id);clearTimeout(timer);reject(error);}
  });
  const evaluate=expression=>command('Runtime.evaluate',{expression,returnByValue:true});
  if(windowSize)await command('Emulation.setDeviceMetricsOverride',{...windowSize,deviceScaleFactor:1,mobile:true});
  const deadline=Date.now()+timeoutMs;
  while(Date.now()<deadline){const snapshot=(await evaluate(`({status:document.body?.dataset.status,
    result:document.getElementById('result')?.textContent,url:document.URL,ready:document.readyState,
    title:document.title,body:document.body?.innerText?.slice(0,500)})`)).result?.value;
   if(['pass','fail'].includes(snapshot?.status)){const result=JSON.parse(snapshot.result);assert.equal(result.status,snapshot.status,'Browser page status must agree with the result');return result;}
   if(snapshot?.ready==='complete'&&(snapshot.url?.startsWith('chrome-error:')||(snapshot.url===url&&snapshot.result===undefined)))throw Error('Browser could not load test page or result element: '+JSON.stringify(snapshot));
   await new Promise(r=>setTimeout(r,100));
  }
  throw Error('Runtime timed out: '+JSON.stringify((await evaluate(`({url:document.URL,title:document.title,status:document.body?.dataset.status,result:document.getElementById('result')?.textContent,body:document.body?.innerText?.slice(0,500)})`)).result?.value));
 }finally{
  socket?.close();child?.kill();const target=path.resolve(profile);
  assert.ok(target.startsWith(path.resolve(os.tmpdir())+path.sep)&&path.basename(target).startsWith('fpv-provider-browser-'));
  try{fs.rmSync(target,{recursive:true,force:true});}catch(_){/* Chromium shutdown may retain a temporary lock. */}
 }
}
module.exports={browser,runPage};
