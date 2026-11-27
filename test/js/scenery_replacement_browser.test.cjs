'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {browser,runPage}=require('./support/scenery_browser.cjs'),C=require('../../web/cesium/index.cjs'),repo=path.resolve(__dirname,'../..');
// Self-generated CC0 geometry; no external scenery data.
function buildings(){
 const vertices=[],ids=[];for(const [id,x]of [[0,-12],[1,12]])for(const p of [[x-6,-6,10],[x+6,-6,10],[x+6,6,10],[x-6,-6,10],[x+6,6,10],[x-6,6,10]]){vertices.push(...p);ids.push(id);}
 const positions=Buffer.from(new Float32Array(vertices).buffer),batches=Buffer.from(new Uint16Array(ids).buffer),bin=Buffer.concat([positions,batches]),doc={asset:{version:'2.0'},scene:0,scenes:[{nodes:[0]}],nodes:[{mesh:0}],meshes:[{primitives:[{attributes:{POSITION:0,_BATCHID:1},material:0}]}],materials:[{doubleSided:true,pbrMetallicRoughness:{baseColorFactor:[1,0,0,1],metallicFactor:0,roughnessFactor:1},extensions:{KHR_materials_unlit:{}}}],extensionsUsed:['KHR_materials_unlit'],buffers:[{byteLength:bin.length}],bufferViews:[{buffer:0,byteLength:positions.length},{buffer:0,byteOffset:positions.length,byteLength:batches.length}],accessors:[{bufferView:0,componentType:5126,count:12,type:'VEC3',min:[-18,-6,10],max:[18,6,10]},{bufferView:1,componentType:5123,count:12,type:'SCALAR'}]};
 const json=Buffer.from(JSON.stringify(doc)),padded=Buffer.alloc(Math.ceil(json.length/4)*4,32);json.copy(padded);const header=Buffer.alloc(20);header.write('glTF');header.writeUInt32LE(2,4);header.writeUInt32LE(28+padded.length+bin.length,8);header.writeUInt32LE(padded.length,12);header.write('JSON',16);const chunk=Buffer.alloc(8);chunk.writeUInt32LE(bin.length);chunk.write('BIN\0',4);const glb=Buffer.concat([header,padded,chunk,bin]);
 const feature=Buffer.from('{"BATCH_LENGTH":2}'),featureLength=Math.ceil((28+feature.length)/8)*8-28,featurePadded=Buffer.alloc(featureLength,32);feature.copy(featurePadded);
 const metadata=Buffer.from('{"uuid":["building-1","building-2"]}'),meta=Buffer.alloc(Math.ceil(metadata.length/8)*8,32);metadata.copy(meta);const b=Buffer.alloc(28);b.write('b3dm');b.writeUInt32LE(1,4);b.writeUInt32LE(28+featureLength+meta.length+glb.length,8);b.writeUInt32LE(featureLength,12);b.writeUInt32LE(meta.length,20);return Buffer.concat([b,featurePadded,meta,glb]);
}
test('actual Cesium clips base buildings/terrain, keeps surrounding geometry and restores masks and stable features',
 {skip:browser?false:'Install Chromium or set FPV_CHROME',timeout:150000},async()=>{
 const data=buildings(),transform=C.Matrix4.pack(C.Transforms.eastNorthUpToFixedFrame(C.Cartesian3.fromDegrees(13.8,52.4)),[]);
 const doc={asset:{version:'1.0',gltfUpAxis:'Z'},geometricError:100,root:{transform,boundingVolume:{box:[0,0,5,25,0,0,0,15,0,0,0,15]},geometricError:0,content:{uri:'buildings.b3dm'}}};
 const server=http.createServer((req,res)=>{const name=new URL(req.url,'http://localhost').pathname;
  if(name==='/replacement-fixture/tileset.json'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(doc));return;}
  if(name==='/replacement-fixture/buildings.b3dm'){res.setHeader('Content-Type','application/octet-stream');res.end(data);return;}
  const file=path.resolve(repo,'.'+decodeURIComponent(name));if(!file.startsWith(repo+path.sep)){res.writeHead(403).end();return;}
  fs.readFile(file,(error,bytes)=>{if(error){res.writeHead(404).end();return;}res.setHeader('Content-Type',name.endsWith('.js')?'application/javascript':name.endsWith('.wasm')?'application/wasm':'text/html');res.end(bytes);});});
 try{await new Promise(r=>server.listen(0,'127.0.0.1',r));const result=await runPage('http://127.0.0.1:'+server.address().port+'/test/web/scenery_replacement_smoke.html',{timeoutMs:75000});assert.equal(result.status,'pass',JSON.stringify(result));console.log('Replacement browser:',JSON.stringify(result));}
 finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
});
