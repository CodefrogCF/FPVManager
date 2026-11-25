'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {browser,runPage}=require('./support/scenery_browser.cjs'),C=require('../../web/cesium/index.cjs');
const repo=path.resolve(__dirname,'../..');
test('real Cesium streams OGC 1.0/1.1 providers with source transforms, flight unloads and CORS errors',
 {skip:browser?false:'Install Chromium or set FPV_CHROME',timeout:60000},async()=>{
 const requests=[],glb=fs.readFileSync(path.join(repo,'test/fixtures/scenery/imported_triangle.glb'));
 const feature=Buffer.from('{"BATCH_LENGTH":0}'),featureLength=Math.ceil((28+feature.length)/8)*8-28,header=Buffer.alloc(28);header.write('b3dm');header.writeUInt32LE(1,4);header.writeUInt32LE(28+featureLength+glb.length,8);header.writeUInt32LE(featureLength,12);
 const padded=Buffer.alloc(featureLength,32);feature.copy(padded);const b3dm=Buffer.concat([header,padded,glb]);
 const transform=C.Matrix4.pack(C.Transforms.eastNorthUpToFixedFrame(C.Cartesian3.fromDegrees(13.8,52.4,100)),[]);
 const doc=version=>({asset:{version,copyright:'Synthetic fixture, CC0-1.0'},geometricError:100,root:{transform,boundingVolume:{box:[0,0,5,20,0,0,0,20,0,0,0,20]},geometricError:0,content:{uri:version==='1.0'?'triangle.b3dm':'triangle.glb'}}});
 const provider=http.createServer((req,res)=>{
  requests.push({url:req.url,headers:req.headers});const name=new URL(req.url,'http://localhost').pathname;
  if(name!=='/cors.json')res.setHeader('Access-Control-Allow-Origin','*');res.setHeader('Cache-Control','no-store');
  if(name==='/missing.json'){res.writeHead(404).end();return;}
  if(name.endsWith('.glb')||name.endsWith('.b3dm')){res.setHeader('Content-Type','application/octet-stream');res.end(name.endsWith('.glb')?glb:b3dm);return;}
  res.setHeader('Content-Type','application/json');const send=()=>res.end(JSON.stringify(doc(name==='/root10.json'?'1.0':'1.1')));
  if(name==='/slow11.json')setTimeout(send,500);else send();
 });
 const host=http.createServer((req,res)=>{
  const name=new URL(req.url,'http://localhost').pathname,file=path.resolve(repo,'.'+decodeURIComponent(name));
  if(!file.startsWith(repo+path.sep)){res.writeHead(403).end();return;}
  fs.readFile(file,(error,data)=>{if(error){res.writeHead(404).end();return;}res.setHeader('Content-Type',name.endsWith('.js')?'application/javascript':name.endsWith('.wasm')?'application/wasm':'text/html');res.end(data);});
 });
 try{
  await new Promise(r=>provider.listen(0,'127.0.0.1',r));await new Promise(r=>host.listen(0,'127.0.0.1',r));
  const fixtureBase='http://127.0.0.1:'+provider.address().port;
  const url='http://127.0.0.1:'+host.address().port+'/test/web/scenery_tileset_smoke.html?fixtureBase='+encodeURIComponent(fixtureBase);
  const result=await runPage(url);assert.equal(result.status,'pass',JSON.stringify(result));assert.equal(result.checks.length,15);
  assert.ok(requests.some(r=>r.url.endsWith('triangle.glb')));assert.ok(requests.some(r=>r.url.endsWith('triangle.b3dm')));
  assert.ok(requests.every(r=>!Object.keys(r.headers).some(k=>k.startsWith('x-fpv'))&&!r.headers.cookie&&!r.headers.referer));
  console.log('Remote provider browser:',JSON.stringify(result));
 }finally{provider.closeAllConnections();host.closeAllConnections();await Promise.all([new Promise(r=>provider.close(r)),new Promise(r=>host.close(r))]);}
});
