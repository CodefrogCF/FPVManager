'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {browser,runPage}=require('./support/scenery_browser.cjs'),repo=path.resolve(__dirname,'../..');
test('real browser validates offline FPC in workers, renders physics geometry and recovers from cache errors',
 {skip:browser?false:'Install Chromium or set FPV_CHROME',timeout:60000},async()=>{
 let fixtureReads=0,cacheHttp=0;const server=http.createServer((req,res)=>{const name=new URL(req.url,'http://localhost').pathname,file=path.resolve(repo,'.'+decodeURIComponent(name));
  if(name.endsWith('collision_room.fpc'))fixtureReads++;if(name.includes('/scenery-local/'))cacheHttp++;
  if(!file.startsWith(repo+path.sep)){res.writeHead(403).end();return;}
  fs.readFile(file,(error,data)=>{if(error){res.writeHead(404).end();return;}res.setHeader('Content-Type',name.endsWith('.js')?'application/javascript':name.endsWith('.wasm')?'application/wasm':name.endsWith('.fpc')?'application/octet-stream':'text/html');res.end(data);});});
 try{await new Promise(r=>server.listen(0,'127.0.0.1',r));const result=await runPage('http://127.0.0.1:'+server.address().port+'/test/web/scenery_collision_smoke.html');assert.equal(result.status,'pass',JSON.stringify(result));assert.equal(result.reloaded,true);assert.equal(fixtureReads,1);assert.equal(cacheHttp,0);console.log('Collision browser:',JSON.stringify(result));}
 finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
});
