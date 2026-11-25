'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),http=require('node:http'),{spawn}=require('node:child_process');
const repo=path.resolve(__dirname,'../..');
const browser=[process.env.FPV_CHROME,'C:/Program Files/Google/Chrome/Application/chrome.exe','C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe','/usr/bin/google-chrome','/usr/bin/chromium'].find(x=>x&&fs.existsSync(x));
test('real Cesium renders a cached, textured georeferenced GLB after page restart',
 {skip:browser?false:'Install Chromium or set FPV_CHROME',timeout:60000},async()=>{
 const requests=[];
 const server=http.createServer((req,res)=>{
  const name=new URL(req.url,'http://localhost').pathname;requests.push(name);
  const file=path.resolve(repo,'.'+decodeURIComponent(name));if(!file.startsWith(repo+path.sep)){res.writeHead(403).end();return;}
  fs.readFile(file,(error,data)=>{if(error){res.writeHead(404).end();return;}
   res.setHeader('Content-Type',name.endsWith('.js')?'application/javascript':name.endsWith('.glb')?'model/gltf-binary':name.endsWith('.png')?'image/png':'text/html');res.end(data);});
 });
 const profile=fs.mkdtempSync(path.join(os.tmpdir(),'fpv-scenery-browser-'));let child,socket;
 try{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const url=`http://127.0.0.1:${server.address().port}/test/web/scenery_import_smoke.html`;
  const endpoint=await new Promise((resolve,reject)=>{
   child=spawn(browser,['--headless','--no-first-run','--no-default-browser-check','--disable-extensions','--no-proxy-server',
    '--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--user-data-dir='+profile,'--remote-debugging-port=0',url],{windowsHide:true,stdio:['ignore','ignore','pipe']});
   let stderr='';const timer=setTimeout(()=>reject(Error('Chromium startup timed out: '+stderr)),15000);
   child.stderr.on('data',x=>{stderr=(stderr+x).slice(-4000);const match=stderr.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(match){clearTimeout(timer);resolve(match[1]);}});
   child.once('error',e=>{clearTimeout(timer);reject(e);});child.once('exit',code=>{clearTimeout(timer);reject(Error('Chromium exited '+code+': '+stderr));});
  });
  const origin='http://127.0.0.1:'+new URL(endpoint).port;
  let target;for(let i=0;i<100&&!target;i++){target=(await(await fetch(origin+'/json/list')).json()).find(x=>x.type==='page'&&x.url.includes('scenery_import_smoke'));if(!target)await new Promise(r=>setTimeout(r,50));}
  assert.ok(target,'Scenery browser page is missing');socket=new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
  let sequence=0;const replies=new Map();socket.addEventListener('message',event=>{const m=JSON.parse(event.data);if(m.id){const pending=replies.get(m.id);replies.delete(m.id);m.error?pending?.reject(Error(m.error.message)):pending?.resolve(m.result);}});
  function evaluate(expression){return new Promise((resolve,reject)=>{const id=++sequence;replies.set(id,{resolve,reject});socket.send(JSON.stringify({id,method:'Runtime.evaluate',params:{expression,returnByValue:true}}));});}
  let output='';const deadline=Date.now()+45000;
  while(Date.now()<deadline){const status=await evaluate('document.body?.dataset.status');
   if(['pass','fail'].includes(status.result?.value)){output=(await evaluate('document.documentElement.outerHTML')).result.value;break;}
   await new Promise(r=>setTimeout(r,100));
  }
  assert.ok(output,'Scenery runtime did not finish: '+JSON.stringify(await evaluate('document.getElementById("result")?.textContent')));
  const raw=output.match(/<pre id="result">([\s\S]*?)<\/pre>/)?.[1];assert.ok(raw,'Browser result is missing');
  const result=JSON.parse(raw.replaceAll('&quot;','"').replaceAll('&lt;','<').replaceAll('&gt;','>').replaceAll('&amp;','&'));
  assert.equal(result.status,'pass',JSON.stringify(result));assert.equal(result.reloaded,true);assert.equal(result.checks.length,5);
  assert.equal(requests.filter(x=>x.endsWith('imported_triangle.glb')).length,1,'Reload must use stored model bytes');
  assert.equal(requests.filter(x=>x.includes('/scenery-local/')).length,0,'Local scenery never falls back to HTTP');
  console.log('Scenery browser runtime:',JSON.stringify(result));
 }finally{
  socket?.close();child?.kill();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));
  const target=path.resolve(profile);assert.ok(target.startsWith(path.resolve(os.tmpdir())+path.sep)&&path.basename(target).startsWith('fpv-scenery-browser-'));
  try{fs.rmSync(target,{recursive:true,force:true});}catch(_){/* Chromium may retain a temporary profile lock during shutdown. */}
 }
});
