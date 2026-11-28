'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const B=require('../../web/features/infrastructure/bridge_source.js');
const fixture=require('../fixtures/bridges/ganter_native_deck.json');
const center=fixture.center;
function setup(options={}){
    const selected={show:true},roof={},primitives=[selected,roof],calls=[],rays=[];
    let classification=200,height=1450,yields=0,clock=10000;
    class Cartesian3{constructor(x,y,z){Object.assign(this,{x,y,z});}
        static fromDegrees(longitude,latitude,height){return {longitude,latitude,height};}}
    class Ray{constructor(origin,direction){Object.assign(this,{origin,direction});}}
    const C={Cartesian3,Ray,Cartographic:{fromCartesian:p=>p}};
    const feature={tileset:selected,getProperty:key=>({KUNSTBAUTE:classification,UUID:fixture.nativeFeature.UUID,
        NAME:'Ganterbrücke',OBJECTID:45029})[key]};
    const viewer={scene:{primitives:{length:2,get:i=>primitives[i]},pickFromRay:(ray,excluded,width)=>{
        assert.ok(yields>0,'offscreen picking runs after the scene update stack unwinds');
        rays.push({ray,excluded,width});return {object:feature,position:{height}};
    }}};
    const manager=B.create(C,viewer,{getDeckTileset:()=>selected,
        fetcher:async(url,args)=>{calls.push({url,args});return {ok:true,json:async()=>fixture.identify};},
        now:()=>clock,...options,yieldBatch:options.yieldBatch?async signal=>{yields++;await options.yieldBatch(signal);}:options.yieldBatch===undefined&&Object.hasOwn(options,'yieldBatch')?undefined:async()=>{yields++;}});
    return {manager,selected,roof,calls,rays,viewer,setClass:v=>{classification=v;clock+=31000;},
        setHeight:v=>{height=v;clock+=31000;}};
}
test('actual Ganter road axis obtains its bridge classification and height solely from native model hits',async()=>{
    const f=setup();try{
        const result=await f.manager.discover(center);
        assert.equal(result.bridges.length,1);assert.equal(result.bridges[0].source,'ch.swisstopo.swisstlm3d.3d');
        assert.equal(result.bridges[0].profileMethod,'loaded-native-road');
        assert.equal(result.bridges[0].sourceId,fixture.nativeFeature.UUID);
        assert.ok(result.bridges[0].coordinates.length>20);
        assert.ok(result.bridges[0].coordinates.every(p=>p.height===1450));
        assert.ok(f.rays.length<=96);
        assert.ok(f.rays.every(p=>p.excluded.includes(f.roof)&&!p.excluded.includes(f.selected)&&p.ray.origin.height===6000));
        assert.match(decodeURIComponent(f.calls[0].url),/all:ch.swisstopo.swisstlm3d-strassen/);
        const rayCount=f.rays.length;await f.manager.discover(center);
        assert.equal(f.calls.length,1,'recent official axes are reused');
        assert.equal(f.rays.length,rayCount,'a resident native profile does not repeat offscreen rendering');
    }finally{f.manager.dispose();}
});
test('ordinary road or cableway hits cannot turn the unclassified official axis into a bridge',async()=>{
    const f=setup();try{
        for(const code of [100,700,1000,undefined,'unknown']){
            f.setClass(code);assert.equal((await f.manager.discover(center)).bridges.length,0);
        }
        f.setClass('200');assert.equal((await f.manager.discover(center)).bridges.length,1);
        f.setHeight(undefined);assert.equal((await f.manager.discover(center)).bridges.length,0);
    }finally{f.manager.dispose();}
});
test('cache-only, offline and hidden structures do not request official road axes',async()=>{
    for(const option of [{cachedOnly:true},{isOnline:()=>false}]){
        const f=setup(option);try{assert.deepEqual(await f.manager.discover(center),{bridges:[],piers:[]});assert.equal(f.calls.length,0);}
        finally{f.manager.dispose();}
    }
    const f=setup();f.selected.show=false;
    try{assert.equal((await f.manager.discover(center)).bridges.length,0);assert.equal(f.calls.length,0);}
    finally{f.manager.dispose();}
});
test('bridge profiles split at a crossing with a different native UUID',async()=>{
    const f=setup();
    const gap=0.0004;
    f.viewer.scene.pickFromRay=ray=>{const uuid=Math.abs(ray.origin.longitude-center.longitude)<gap?'another-level':fixture.nativeFeature.UUID;
        return {object:{tileset:f.selected,getProperty:key=>({KUNSTBAUTE:200,UUID:uuid})[key]},position:{height:1450}};};
    try{const result=await f.manager.discover(center);assert.ok(result.bridges.length>0);
        for(const b of result.bridges)assert.ok(b.coordinates.every(p=>(Math.abs(p.longitude-center.longitude)<gap)===(b.sourceId==='another-level')),
            'every profile point belongs to the same native feature');}
    finally{f.manager.dispose();}
});
test('aborting before the first deferred pick installs no native profile',async()=>{
    let release;
    const f=setup({yieldBatch:()=>new Promise(resolve=>release=resolve)}),abort=new AbortController();
    const pending=f.manager.discover(center,abort.signal);
    await new Promise(resolve=>setImmediate(resolve));abort.abort();release();
    await assert.rejects(pending,{name:'AbortError'});assert.equal(f.rays.length,0);f.manager.dispose();
});
test('oversized official response is cancelled before the rest downloads',async()=>{
    let cancelled=0;
    const f=setup({fetcher:async()=>({ok:true,body:{getReader:()=>({
        read:async()=>({done:false,value:new Uint8Array(2*1024*1024+1)}),
        cancel:async()=>{cancelled++;},releaseLock(){}})}})});
    try{await assert.rejects(f.manager.discover(center),/budget/);assert.equal(cancelled,1);assert.equal(f.rays.length,0);}
    finally{f.manager.dispose();}
});
test('failed official requests back off while model readiness can still recover',async()=>{
    let requests=0;
    const f=setup({fetcher:async()=>{requests++;throw Error('service unavailable');}});
    try{await assert.rejects(f.manager.discover(center),/unavailable/);
        assert.equal((await f.manager.discover(center)).bridges.length,0);assert.equal(requests,1);}
    finally{f.manager.dispose();}
});

test('native bridge discovery performs no more than one offscreen pick per rendered frame',async()=>{
    let frame=0;const picks=new Map(),f=setup({yieldBatch:async()=>{frame++;}});
    f.viewer.scene.pickFromRay=()=>{picks.set(frame,(picks.get(frame)||0)+1);return {
        object:{tileset:f.selected,getProperty:key=>({KUNSTBAUTE:200,UUID:fixture.nativeFeature.UUID})[key]},
        position:{height:1450}};};
    try{
        const state=await f.manager.discover(center);
        assert.equal(state.bridges.length,1);assert.ok(picks.size>20);
        assert.equal(Math.max(...picks.values()),1);assert.equal(picks.has(0),false);
    }finally{f.manager.dispose();}
});

test('production native scheduling waits for animation frames and cancellation releases a suspended frame',async()=>{
    const oldRequest=globalThis.requestAnimationFrame,oldCancel=globalThis.cancelAnimationFrame;
    let requested=0,cancelled=0;
    globalThis.requestAnimationFrame=()=>++requested;
    globalThis.cancelAnimationFrame=()=>cancelled++;
    const f=setup({yieldBatch:undefined}),abort=new AbortController();
    try{
        const operation=f.manager.discover(center,abort.signal);
        await new Promise(resolve=>setImmediate(resolve));
        assert.equal(requested,1);assert.equal(f.rays.length,0);
        abort.abort();await assert.rejects(operation,{name:'AbortError'});
        assert.equal(cancelled,1);assert.equal(f.rays.length,0);
    }finally{
        f.manager.dispose();
        if(oldRequest===undefined)delete globalThis.requestAnimationFrame;else globalThis.requestAnimationFrame=oldRequest;
        if(oldCancel===undefined)delete globalThis.cancelAnimationFrame;else globalThis.cancelAnimationFrame=oldCancel;
    }
});

test('source-classified native heights reuse stable road-axis probes during flight, but explicit invalidation forces fresh picks',async()=>{
    let clock=10000,frame=0;
    const f=setup({now:()=>clock,isNavigationActive:()=>true,mobile:true,yieldBatch:async()=>{frame++;}});
    f.manager.setDiagnosticsEnabled(true);
    try{
        const first=await f.manager.discover(center);const picks=f.rays.length;
        assert.ok(first.bridges.length>0&&picks>20);
        clock+=31000;
        const second=await f.manager.discover(center);
        assert.deepEqual(second,first);assert.equal(f.rays.length,picks);
        assert.ok(f.manager.diagnostics().nativeHits>20);
        f.manager.invalidate();clock+=1000;
        await f.manager.discover(center);assert.equal(f.rays.length,picks*2);
    }finally{f.manager.dispose();}
});

test('expensive mobile native picks retain one pick per frame without starvation',async()=>{
    let clock=10000,frame=0;const frames=[];
    const f=setup({now:()=>clock,isNavigationActive:()=>true,mobile:true,yieldBatch:async()=>{frame++;}});
    const original=f.viewer.scene.pickFromRay;f.viewer.scene.pickFromRay=(...args)=>{frames.push(frame);clock+=20;return original(...args);};
    f.manager.setDiagnosticsEnabled(true);
    try{await f.manager.discover(center);assert.ok(frames.length>20);
        assert.ok(frames.slice(1).every((v,i)=>v-frames[i]>=1));
        assert.equal(f.manager.diagnostics().nativeCooldownFrames,0);
    }finally{f.manager.dispose();}
});


test('native discovery retries unloaded geometry instead of caching negative ray hits',async()=>{
    let clock=10000;const f=setup({now:()=>clock,isNavigationActive:()=>true,mobile:true});
    const original=f.viewer.scene.pickFromRay;let loaded=false;
    f.viewer.scene.pickFromRay=(...args)=>loaded?original(...args):undefined;
    f.manager.setDiagnosticsEnabled(true);
    try{assert.equal((await f.manager.discover(center)).bridges.length,0);
        assert.equal(f.manager.diagnostics().nativeCacheEntries,0);
        loaded=true;clock+=2100;
        assert.ok((await f.manager.discover(center)).bridges.length>0);
    }finally{f.manager.dispose();}
});

test('indexed native spans keep their stable IDs and do not re-pick covered grid points during overlapping flight',async()=>{
    let clock=10000;const f=setup({incremental:true,isNavigationActive:()=>true,mobile:true,now:()=>clock});
    f.manager.setDiagnosticsEnabled(true);
    try{
        const first=await f.manager.discover(center),picks=f.rays.length;
        assert.ok(first.bridges.length>0);assert.ok(picks<=32);
        clock+=4000;const second=await f.manager.discover({...center,longitude:center.longitude+.0001});
        assert.ok(first.bridges.every(b=>second.bridges.some(x=>x.id===b.id&&JSON.stringify(x.coordinates)===JSON.stringify(b.coordinates))));
        assert.ok(f.manager.diagnostics().nativeIndexedHits>0);
        assert.ok(f.rays.length-picks<=32);
        const count=f.rays.length;clock+=4000;await f.manager.discover(center);
        assert.ok(f.rays.length-count<32,'covered positions require no repeated GPU scan');
        f.manager.invalidate();const before=f.rays.length;await f.manager.discover(center);assert.ok(f.rays.length>before);
    }finally{f.manager.dispose();}
});

test('indexed native spans reject isolated high points and never interpolate across different native IDs',async()=>{
    const f=setup({incremental:true});
    const original=f.viewer.scene.pickFromRay;let index=0,peak=null;
    f.viewer.scene.pickFromRay=(...args)=>{const hit=original(...args);if(++index===3){peak=args[0].origin.longitude;hit.position.height+=12;}return hit;};
    f.manager.setDiagnosticsEnabled(true);
    try{
        const r=await f.manager.discover(center);
        assert.ok(r.bridges.length>0);assert.ok(r.bridges.every(b=>b.coordinates.every(p=>p.height===1450)));
        assert.ok(f.manager.diagnostics().nativeHeightRejected>0);assert.ok(r.invalidatedSections.length>0);
    }finally{f.manager.dispose();}
});

test('indexed native negative observations back off while missing tiles can be retried',async()=>{
    let clock=10000,loaded=false;const f=setup({incremental:true,isNavigationActive:()=>true,now:()=>clock});
    const original=f.viewer.scene.pickFromRay;f.viewer.scene.pickFromRay=(...args)=>loaded?original(...args):undefined;
    f.manager.setDiagnosticsEnabled(true);
    try{
        assert.equal((await f.manager.discover(center)).bridges.length,0);
        loaded=true;clock+=13000;
        assert.ok((await f.manager.discover(center)).bridges.length>0);
        assert.ok(f.manager.diagnostics().nativeIndexedPoints<=4096);
    }finally{f.manager.dispose();}
});

test('route prefetch loads at most three ahead areas without performing GPU picks',async()=>{
    const f=setup({incremental:true});
    try{
        const points=Array.from({length:12},(_,i)=>({...center,longitude:center.longitude+i*.006}));
        await f.manager.prepareRoute(points);
        assert.equal(f.calls.length,3);assert.equal(f.rays.length,0);
        await f.manager.prepareRoute(points);assert.equal(f.calls.length,3);
    }finally{f.manager.dispose();}
});

test('legacy production discovery can still prefetch road axes without GPU work',async()=>{
    const f=setup({incremental:false,prefetchRoads:true});
    try{
        const points=Array.from({length:12},(_,i)=>({...center,longitude:center.longitude+i*.006}));
        await f.manager.prepareRoute(points);assert.equal(f.calls.length,3);assert.equal(f.rays.length,0);
        const result=await f.manager.discover(center);assert.ok(result.bridges.length);
        assert.ok(result.bridges.every(b=>b.nativeStationKey));
    }finally{f.manager.dispose();}
});

test('native pier stations keep identical axis coordinates when the detected profile gets shorter',async()=>{
    const Supports=require('../../web/features/infrastructure/bridge_supports.js'),f=setup();
    try{
        const full=await f.manager.discover(center),first=Supports.stations(full.bridges,center);
        assert.ok(first.length>5);const min=Math.min(...full.bridges[0].coordinates.map(p=>p.longitude));
        const max=Math.max(...full.bridges[0].coordinates.map(p=>p.longitude)),cut=min+(max-min)*.25;
        const original=f.viewer.scene.pickFromRay;f.viewer.scene.pickFromRay=(ray,...args)=>ray.origin.longitude<cut?undefined:original(ray,...args);
        f.manager.invalidate();f.setHeight(1450);const partial=await f.manager.discover(center),next=Supports.stations(partial.bridges,center);
        assert.ok(next.length>0&&next.length<first.length);
        assert.ok(next.every(p=>first.some(q=>q.id===p.id&&q.longitude===p.longitude&&q.latitude===p.latitude)),
            'shortening a detected chunk must not redistribute its stations');
    }finally{f.manager.dispose();}
});

test('initial native preview expands, commits validated axis points and reuses them until source change',async()=>{
    let clock=10000;const f=setup({sessionReuse:true,isNavigationActive:()=>true,now:()=>clock});
    f.manager.setDiagnosticsEnabled(true);
    try{
        const first=await f.manager.discover(center);assert.ok(first.bridges.length>0);
        assert.equal(first.partial,true);const firstPicks=f.rays.length;
        assert.equal(f.manager.diagnostics().nativeSessionCommitted,0,'discovery alone is not ground validation');
        for(const bridge of first.bridges)for(const station of bridge.nativeStations)
            f.manager.commitValidated({...station,sourceId:bridge.sourceId,nativeIdentified:bridge.nativeIdentified});
        clock+=3000;
        const expanded=await f.manager.discover(center);
        assert.equal(expanded.partial,undefined);
        assert.ok(expanded.bridges.flatMap(b=>b.nativeStations).length>first.bridges.flatMap(b=>b.nativeStations).length);
        assert.ok(firstPicks<f.rays.length);
        for(const bridge of expanded.bridges)for(const station of bridge.nativeStations)
            f.manager.commitValidated({...station,sourceId:bridge.sourceId,nativeIdentified:bridge.nativeIdentified});
        const picks=f.rays.length;
        assert.ok(f.manager.diagnostics().nativeSessionCommitted>0);
        assert.equal(f.manager.diagnostics().nativeEarlyProfiles,1);
        clock+=900000;const second=await f.manager.discover(center);
        assert.ok(second.bridges.length);assert.ok(f.rays.length-picks<picks/3,'only uncommitted edge points may be measured again');
        assert.ok(f.manager.diagnostics().nativeSessionHits>0);
        const beforeInvalidation=f.rays.length;f.manager.invalidate();await f.manager.discover(center);assert.ok(f.rays.length>beforeInvalidation);
    }finally{f.manager.dispose();}
});
test('V7 only temporarily caches explicit non-bridge classifications and retries unloaded tiles',async()=>{
    let clock=10000;const f=setup({sessionReuse:true,now:()=>clock});
    f.manager.setDiagnosticsEnabled(true);
    try{
        f.setClass(100);await f.manager.discover(center);const first=f.rays.length;assert.ok(first>0);
        clock+=2100;await f.manager.discover(center);assert.equal(f.rays.length,first);
        assert.ok(f.manager.diagnostics().nativeClassifiedRoadHits>0);
        clock+=16000;f.setClass(200);assert.ok((await f.manager.discover(center)).bridges.length);
        f.manager.invalidate();f.viewer.scene.pickFromRay=()=>undefined;
        await f.manager.discover(center);assert.equal(f.manager.diagnostics().nativeRoadCacheEntries,0);
    }finally{f.manager.dispose();}
});
test('adaptive pick recovery is bypassed until geometry exists and cancellation releases the wait',async()=>{
    let geometry=false;const budget=B.createPickBudget({mobile:true,hasGeometry:()=>geometry,frameMs:()=>50});
    budget.record(40);assert.equal(await budget.wait(),0);
    geometry=true;budget.record(40);const abort=new AbortController();const waiting=budget.wait(abort.signal);abort.abort();
    await assert.rejects(waiting,{name:'AbortError'});
});
