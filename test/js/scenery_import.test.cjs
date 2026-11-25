'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),{webcrypto,createHash}=require('node:crypto');
const M=require('../../web/features/scenery/scenery_manager.js');
const base=require('../../web/assets/scenery/catalog.json').sceneries[0];
const bytes=new TextEncoder().encode('synthetic locally validated GLB bytes');
const key=createHash('sha256').update(bytes).digest('hex')+'.glb';
const asset={kind:'glb',path:'managed/'+key,managed:true,backend:'cache',cacheRoot:'https://app.test/fpv/scenery-local/v1/',estimatedBytes:1000};
function environment(response=new Response(bytes)){
 const calls=[],revoked=[];
 return {calls,revoked,baseUrl:'https://app.test/fpv/assets/web/globe.html',crypto:webcrypto,
   cacheStorage:{async open(name){calls.push(name);return {async match(url){calls.push(url);return response;}};}},
   urls:{createObjectURL(blob){assert.equal(blob.size,bytes.length);return 'blob:test';},revokeObjectURL:url=>revoked.push(url)}};
}
function scene(){return {id:'local-import',name:'Imported <triangle>',author:'Synthetic author',license:'CC0-1.0',attribution:'Synthetic tests',heightDatum:'WGS84 ellipsoid',alignment:structuredClone(base.alignment),sourceUrl:null,assets:[{...asset}],physicalCollisionsEnabled:false,
  heightAlignmentMode:'fixed',requireGroundCalibration:false};}
test('local source URL is optional; managed storage metadata is retained and validated',()=>{
 const item=scene();assert.equal(M.validate({schemaVersion:1,sceneries:[item]})[0].assets[0].backend,'cache');
 for(const mutate of [x=>x.assets[0].path='managed/a.glb',x=>delete x.assets[0].managed,x=>x.assets[0].backend='network',x=>x.assets[0].estimatedBytes=Infinity]){
  const bad=scene();mutate(bad);assert.throws(()=>M.validate({schemaVersion:1,sceneries:[bad]}));
 }
});
test('browser cache lookup is scoped, verified and produces an idempotently released Blob URL',async()=>{
 const e=environment(),resource=await M.managedModelUrl(asset,e);assert.equal(resource.url,'blob:test');
 assert.deepEqual(e.calls,['fpvmanager-scenery-v1:'+asset.cacheRoot,asset.cacheRoot+key]);
 resource.release();resource.release();assert.deepEqual(e.revoked,['blob:test']);
});
test('native managed paths stay on the loopback asset server',async()=>{
 const e=environment();const resource=await M.managedModelUrl({...asset,backend:'server'},e);
 assert.equal(resource.url,'./assets/scenery/managed/'+key);assert.equal(e.calls.length,0);
});
test('missing, corrupted and cross-origin cache resources fail without network fallback',async()=>{
 await assert.rejects(M.managedModelUrl(asset,environment(null)),/unavailable/);
 await assert.rejects(M.managedModelUrl(asset,environment(new Response(new Uint8Array([1])))),/checksum/);
 await assert.rejects(M.managedModelUrl({...asset,cacheRoot:'https://other.test/scenery-local/v1/'},environment()),/origin/);
 await assert.rejects(M.managedModelUrl({...asset,cacheRoot:'https://app.test/arbitrary/'},environment()),/origin/);
 await assert.rejects(M.managedModelUrl(asset,{...environment(),crypto:{}}),/secure browser/);
});
test('streamed cache reads stop at the import size budget',async()=>{
 let cancelled=false;const response=new Response(new ReadableStream({pull(c){c.enqueue(new Uint8Array(8*1024*1024));},cancel(){cancelled=true;}}));
 await assert.rejects(M.managedModelUrl(asset,environment(response)),/64 MiB/);assert.equal(cancelled,true);
});
function runtime(options={}){
 const models=[],events=[];let tick,clock=0,release=0;
 class Matrix4{}Matrix4.fromRotationTranslation=x=>x;Matrix4.multiply=(a,b)=>({a,b});
 const C={Cartesian3:{fromDegrees:(...v)=>v},Transforms:{eastNorthUpToFixedFrame:x=>x},Matrix3:{fromRotationZ:x=>x},Matrix4,
  Math:{toRadians:v=>v*Math.PI/180},Color:class{},Credit:class{constructor(html){this.html=html;}}};
 const viewer={scene:{primitives:{add:m=>models.push(m),remove:m=>{models.splice(models.indexOf(m),1);m.destroy?.();}},preUpdate:{addEventListener:fn=>{tick=fn;return()=>{};}},requestRender(){}}};
 const manager=M.create(C,viewer,{fetchCatalog:async()=>({schemaVersion:1,sceneries:[scene()]}),position:()=>({...base.alignment,height:100}),now:()=>clock,
  managedUrl:async()=>({url:'blob:local',release(){release++;}}),modelFactory:async()=>({ready:true,destroy(){}}),onStatus:s=>events.push(s),...options});
 return {manager,models,events,get releases(){return release;},tick(){clock+=1000;tick?.();}};
}
const flush=()=>new Promise(resolve=>setImmediate(resolve));
test('relative placement samples its own geographic anchor and never supplies zero for missing terrain',async()=>{
 const C={Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})}};
 let points;
 assert.equal(await M.sampleAnchorGround(C,{}, {longitude:-122.3,latitude:47.6},{sample:async p=>{points=p;return [{height:120}];}}),120);
 assert.deepEqual(points,[{longitude:-122.3,latitude:47.6}]);
 await assert.rejects(M.sampleAnchorGround(C,{}, {longitude:0,latitude:0},{sample:async()=>[{height:undefined}]}),/unavailable/);
 await assert.rejects(M.sampleAnchorGround(C,{scene:{globe:{tilesLoaded:false}}},{longitude:0,latitude:0},{regional:true}),/not resident/);
});
test('managed models release Blob URLs when disabled or model creation fails',async()=>{
 const f=runtime();try{await f.manager.initialize();await flush();f.tick();assert.equal(f.models.length,1);f.manager.setEnabled('local-import',false);assert.equal(f.releases,1);}finally{f.manager.dispose();}
 const bad=runtime({modelFactory:async()=>{throw Error('Invalid model');}});try{await bad.manager.initialize();await flush();assert.equal(bad.manager.snapshot()[0].state,'error');assert.equal(bad.releases,1);}finally{bad.manager.dispose();}
});
test('late managed file lookup releases its URL without attaching a superseded model',async()=>{
 let resolve,released=0;const pending=new Promise(r=>resolve=r);const f=runtime({managedUrl:()=>pending});
 await f.manager.initialize();f.manager.dispose();resolve({url:'blob:late',release(){released++;}});await flush();assert.equal(released,1);assert.equal(f.models.length,0);
});
test('load timeout releases a Blob URL before a stalled model factory returns',async()=>{
 let finish,destroyed=false;const pending=new Promise(r=>finish=r),timers=new Map();let sequence=0;
 const f=runtime({modelFactory:()=>pending,setTimer:fn=>{timers.set(++sequence,fn);return sequence;},clearTimer:id=>timers.delete(id)});
 try{await f.manager.initialize();await flush();assert.equal(f.releases,0);assert.equal(timers.size,1);
  timers.values().next().value();assert.equal(f.manager.snapshot()[0].state,'error');assert.equal(f.releases,1);
  finish({ready:true,destroy(){destroyed=true;}});await flush();assert.equal(f.releases,1);assert.equal(destroyed,true);assert.equal(f.models.length,0);
 }finally{f.manager.dispose();}
});
test('asynchronous texture/GPU errors release local resources immediately',async()=>{
 let fail,removed=false;const f=runtime({modelFactory:async()=>({ready:true,errorEvent:{addEventListener(fn){fail=fn;return()=>{removed=true;};}},destroy(){}})});
 try{await f.manager.initialize();await flush();fail(Error('Texture decoding failed'));assert.equal(f.manager.snapshot()[0].state,'error');assert.equal(f.releases,1);assert.equal(removed,true);assert.equal(f.models.length,0);}finally{f.manager.dispose();}
});
test('a stalled relative-height calculation becomes recoverable and ignores late heights',async()=>{
 const timers=new Map();let seq=0,resolve;const key={};const pending=new Promise(r=>resolve=r);
 const item={...scene(),heightAlignmentMode:'terrain',requireGroundCalibration:true,groundReferenceLocalUp:0,heightOffsetM:5};
 const f=runtime({fetchCatalog:async()=>({schemaVersion:1,sceneries:[item]}),terrainKey:()=>key,sampleGround:()=>pending,
   setTimer:fn=>{timers.set(++seq,fn);return seq;},clearTimer:id=>timers.delete(id)});
 try{await f.manager.initialize();await flush();f.tick();await flush();assert.equal(f.models[0].show,false);
   // Once GPU ready, only the in-progress height calculation's timer remains.
   assert.equal(timers.size,1);timers.values().next().value();assert.equal(f.manager.snapshot()[0].state,'error');assert.equal(f.models.length,0);
   resolve(150);await flush();assert.equal(f.manager.snapshot()[0].state,'error');assert.equal(f.releases,1);
 }finally{f.manager.dispose();}
});
test('active managed assets enforce the decoded resource budget',async()=>{
 const item=scene();item.assets=[{...asset,estimatedBytes:100*1024*1024},{...asset,estimatedBytes:100*1024*1024}];
 let loaded=0;const f=runtime({fetchCatalog:async()=>({schemaVersion:1,sceneries:[item]}),managedUrl:async()=>{loaded++;throw Error('Must reject before lookup');}});
 try{await f.manager.initialize();await flush();assert.equal(f.manager.snapshot()[0].state,'error');assert.match(f.manager.snapshot()[0].message,/resource budget/);assert.equal(loaded,0);}finally{f.manager.dispose();}
});
test('local credits escape metadata and do not invent a source hyperlink',async()=>{
 let credit;const f=runtime({modelFactory:async(_url,_config,c)=>{credit=c.html;return {ready:true,destroy(){}};}});
 try{await f.manager.initialize();await flush();assert.ok(!credit.includes('href='));assert.ok(credit.includes('Imported &lt;triangle&gt;'));}finally{f.manager.dispose();}
});
