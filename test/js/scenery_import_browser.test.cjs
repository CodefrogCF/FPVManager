'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {browser,runPage}=require('./support/scenery_browser.cjs');
const repo=path.resolve(__dirname,'../..');
test('real Cesium renders a cached, textured georeferenced GLB after page restart',
 {skip:browser?false:'Install Chromium or set FPV_CHROME',timeout:120000},async()=>{
 const requests=[];
 const server=http.createServer((req,res)=>{
  const name=new URL(req.url,'http://localhost').pathname;requests.push(name);
  const file=path.resolve(repo,'.'+decodeURIComponent(name));if(!file.startsWith(repo+path.sep)){res.writeHead(403).end();return;}
  fs.readFile(file,(error,data)=>{if(error){res.writeHead(404).end();return;}
   res.setHeader('Content-Type',name.endsWith('.js')?'application/javascript':name.endsWith('.glb')?'model/gltf-binary':name.endsWith('.png')?'image/png':'text/html');res.end(data);});
 });
 try{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const url=`http://127.0.0.1:${server.address().port}/test/web/scenery_import_smoke.html`;
  const result=await runPage(url);
  assert.equal(result.status,'pass',JSON.stringify(result));assert.equal(result.reloaded,true);assert.equal(result.checks.length,5);
  assert.equal(requests.filter(x=>x.endsWith('imported_triangle.glb')).length,1,'Reload must use stored model bytes');
  assert.equal(requests.filter(x=>x.includes('/scenery-local/')).length,0,'Local scenery never falls back to HTTP');
  console.log('Scenery browser runtime:',JSON.stringify(result));
 }finally{
  server.closeAllConnections();await new Promise(resolve=>server.close(resolve));
 }
});
