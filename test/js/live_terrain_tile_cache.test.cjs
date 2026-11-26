'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {create}=require('../../web/features/signal/live_terrain_tile_cache.js');

test('default tile timers preserve browser Window receiver semantics without unnecessary fallback',async()=>{
    const nativeSet=globalThis.setTimeout,nativeClear=globalThis.clearTimeout;
    let started=0,cleared=0,fallback=0,cache;
    globalThis.setTimeout=function(fn,ms){'use strict';
        if(this!==undefined&&this!==globalThis)throw TypeError('Illegal invocation');
        started++;return Reflect.apply(nativeSet,globalThis,arguments);
    };
    globalThis.clearTimeout=function(id){'use strict';
        if(this!==undefined&&this!==globalThis)throw TypeError('Illegal invocation');
        cleared++;return Reflect.apply(nativeClear,globalThis,arguments);
    };
    try{
        const C={sampleTerrainMostDetailed:async(_,positions)=>{fallback++;return positions.map(p=>({...p,height:999}));}};
        const provider={availability:{computeMaximumLevelAtPosition:()=>17},
            tilingScheme:{positionToTileXY:()=>({x:0,y:0}),tileXYToRectangle:()=>({})},
            requestTileGeometry:()=>Promise.resolve({interpolateHeight:()=>700})};
        cache=create({C});
        const result=await cache.sample(provider,[{longitude:.1,latitude:.1}],new AbortController().signal);
        assert.equal(result[0].height,700);
        assert.equal(fallback,0,'valid detailed terrain must not fall back because a timer host method was rebound');
        assert.ok(started>0);assert.ok(cleared>0);
    }finally{
        globalThis.setTimeout=nativeSet;globalThis.clearTimeout=nativeClear;
        cache?.reset();
    }
});

function fixture(){
    let calls=0,now=0,highest=7,denied=false,broken=false,interpolationCalls=0;
    const pending=[];
    const C={sampleTerrainMostDetailed:async(_,points)=>points.map(p=>({...p,height:999}))};
    const provider={
        availability:{computeMaximumLevelAtPosition:()=>highest},
        tilingScheme:{
            positionToTileXY:p=>({x:Math.floor(p.longitude),y:Math.floor(p.latitude)}),
            tileXYToRectangle:(x,y)=>({x,y})},
        requestTileGeometry(x,y,level){
            calls++;
            if(denied)return undefined;
            if(broken)return Promise.resolve({interpolateHeight:()=>undefined});
            return Promise.resolve({interpolateHeight:(rectangle,lon,lat)=>{
                interpolationCalls++;
                assert.equal(rectangle.x,x);
                return level*100+Math.floor(lon)+lat;
            }});
        }
    };
    return {C,provider,cache:create({C,clock:()=>now,capacity:2,ttlMs:2000}),
        get calls(){return calls;},get interpolations(){return interpolationCalls;},
        tick(ms){now+=ms;},set level(v){highest=v;},set denied(v){denied=v;},set broken(v){broken=v;},pending};
}
const point=(x,y)=>({longitude:x,latitude:y});
const controller=()=>new AbortController();

test('highest-available tile is reused for DIFFERENT moving-ray coordinates, without lowering the requested level',async()=>{
    const f=fixture(),abort=controller();
    const first=await f.cache.sample(f.provider,[point(8.11,46.7),point(8.14,46.8)],abort.signal);
    assert.deepEqual(first.map(p=>p.height),[754.7,754.8]);
    assert.equal(f.calls,1,'one request for two positions on the same terrain tile');
    const second=await f.cache.sample(f.provider,[point(8.18,46.2)],abort.signal);
    assert.deepEqual(second.map(p=>p.height),[754.2]);
    assert.equal(f.calls,1,'no network request for new coordinates covered by the decoded tile');
    assert.equal(f.interpolations,3,'fresh positions are interpolated from the detailed mesh, not a coarse approximation');
    f.level=8;
    const higher=await f.cache.sample(f.provider,[point(8.18,46.2)],abort.signal);
    assert.deepEqual(higher.map(p=>p.height),[854.2]);
    assert.equal(f.calls,2,'availability improvement must invalidate lower LOD for that coordinate');
});

test('bounding and expiry evict tile geometry; provider changes cannot reuse old heights',async()=>{
    const f=fixture(),signal=controller().signal;
    await f.cache.sample(f.provider,[point(0.1,1.1)],signal);
    await f.cache.sample(f.provider,[point(1.1,1.1)],signal);
    assert.equal(f.cache.cachedTiles,2);
    await f.cache.sample(f.provider,[point(2.1,1.1)],signal);
    assert.equal(f.cache.cachedTiles,2);
    await f.cache.sample(f.provider,[point(0.1,1.1)],signal);
    assert.equal(f.calls,4,'LRU evicts the oldest tile');
    f.tick(2000);
    await f.cache.sample(f.provider,[point(0.2,1.2)],signal);
    assert.equal(f.calls,5,'stale terrain tile is fetched anew');
    f.cache.reset();
    assert.equal(f.cache.cachedTiles,0);
    await f.cache.sample(f.provider,[point(0.2,1.2)],signal);
    assert.equal(f.calls,6);
});

test('fallback always uses Cesium most-detailed sampling when tile API is unavailable or level unknown',async()=>{
    const f=fixture(),signal=controller().signal;
    f.level=0;
    assert.equal((await f.cache.sample(f.provider,[point(8,46)],signal))[0].height,999);
    assert.equal(f.calls,0);
    f.level=7;
    const unavailable={availability:{},requestTileGeometry() {throw Error('should not be called');}};
    assert.equal((await f.cache.sample(unavailable,[point(8,46)],signal))[0].height,999);
    f.broken=true;
    assert.equal((await f.cache.sample(f.provider,[point(8,46)],signal))[0].height,999,
        'invalid tile interpolation cannot assert a terrain height');
    f.cache.reset();f.broken=false;f.denied=true;
    assert.equal((await f.cache.sample(f.provider,[point(8,46)],signal))[0].height,999,
        'Cesium scheduler overload falls back rather than fabricating a clear link');
});

test('aborted result is not returned; an unchanged provider can finish warming its in-memory tile',async()=>{
    const f=fixture();
    let finish;
    f.provider.requestTileGeometry=()=>new Promise(r=>{finish=r;});
    const abort=controller();
    const pending=f.cache.sample(f.provider,[point(8.2,46.2)],abort.signal);
    // Allow the tile request to start.
    await Promise.resolve();
    abort.abort();
    finish({interpolateHeight:()=>500});
    await assert.rejects(pending,/abort/i);
    const second=await f.cache.sample(f.provider,[point(8.4,46.3)],controller().signal);
    assert.equal(second[0].height,500,
        'terrain remains usable when a previous command timed out; no stale assessment was emitted');
});

test('terrain generation change rejects an unfinished old tile and does not contaminate new provider cache',async()=>{
    const f=fixture();
    let finish;
    f.provider.requestTileGeometry=()=>new Promise(r=>{finish=r;});
    const stale=f.cache.sample(f.provider,[point(8.2,46.2)],controller().signal);
    await Promise.resolve();
    f.cache.reset();
    finish({interpolateHeight:()=>500});
    await assert.rejects(stale,/changed/);
    assert.equal(f.cache.cachedTiles,0);
});

test('long-range profiles keep the previous native Cesium most-detailed path and do not evict local tiles',async()=>{
    const f=fixture(),signal=controller().signal;
    await f.cache.sample(f.provider,[point(.1,.1)],signal);
    assert.equal(f.cache.cachedTiles,1);
    const long=await f.cache.sample(f.provider,[point(.1,.1),point(.35,.1)],signal);
    assert.deepEqual(long.map(p=>p.height),[999,999]);
    assert.equal(f.cache.cachedTiles,1);
    assert.equal(f.calls,1);
});

test('3 km moving corridor reuses warm tiles instead of rereading entire scan when tiles exceed RAM budget',async()=>{
    const C={sampleTerrainMostDetailed:async()=>{throw Error('unexpected whole-ray fallback');}};
    let calls=0;
    const width=.0000028; // ~18 m east-west at the equator; 192 tiles cover ~3.4 km
    const provider={
        availability:{computeMaximumLevelAtPosition:()=>17},
        tilingScheme:{
            positionToTileXY:p=>({x:Math.round(p.longitude/width),y:0}),
            tileXYToRectangle:x=>({x})
        },
        requestTileGeometry(x){
            calls++;
            return Promise.resolve({interpolateHeight:()=>x+100});
        }
    };
    const cache=create({C,capacity:96,clock:()=>0});
    const first=Array.from({length:192},(_,i)=>point(i*width,0));
    const initial=await cache.sample(provider,first,controller().signal);
    assert.equal(initial.length,192);
    assert.equal(calls,192);
    assert.equal(cache.cachedTiles,96);
    const second=first.map(p=>point(p.longitude+.0000000001,0));
    const again=await cache.sample(provider,second,controller().signal);
    assert.deepEqual(again.map(p=>p.height),initial.map(p=>p.height));
    assert.equal(calls,288,'only 96 cold tiles were downloaded on the second pass, not all 192');
});

test('one missing high-detail tile falls back only for its own positions, retaining decoded heights from neighbors',async()=>{
    const fallbackSizes=[];
    let requested=0;
    const C={sampleTerrainMostDetailed:async(_,positions)=>{
        fallbackSizes.push(positions.length);
        return positions.map(p=>({...p,height:999}));
    }};
    const provider={
        availability:{computeMaximumLevelAtPosition:()=>17},
        tilingScheme:{
            positionToTileXY:p=>({x:Math.floor(p.longitude*1e6),y:0}),
            tileXYToRectangle:x=>({x})
        },
        requestTileGeometry(x){
            requested++;
            return Promise.resolve({interpolateHeight:()=>x===1?undefined:x+100});
        }
    };
    const cache=create({C,clock:()=>0});
    const pts=[point(.1e-6,0),point(1.1e-6,0),point(1.2e-6,0),point(2.1e-6,0)];
    const first=await cache.sample(provider,pts,controller().signal);
    assert.deepEqual(first.map(p=>p.height),[100,999,999,102]);
    assert.deepEqual(fallbackSizes,[2], 'no full-profile fallback when a single tile is unreadable');
    assert.equal(requested,3);
    const second=await cache.sample(provider,[point(.2e-6,0),point(2.2e-6,0)],controller().signal);
    assert.deepEqual(second.map(p=>p.height),[100,102]);
    assert.equal(requested,3,'the unaffected tiles remained cached');
});

test('new higher-detail availability is verified only for affected tile groups',async()=>{
    const fallbackSizes=[];
    let levelChanged=false;
    const C={sampleTerrainMostDetailed:async(_,positions)=>{
        fallbackSizes.push(positions.length);
        return positions.map(p=>({...p,height:900}));
    }};
    const provider={
        availability:{computeMaximumLevelAtPosition:p=>(levelChanged&&p.longitude>=1e-6)?18:17},
        tilingScheme:{positionToTileXY:p=>({x:Math.floor(p.longitude*1e6),y:0}),tileXYToRectangle:x=>({x})},
        requestTileGeometry(x){
            if(x===1)levelChanged=true;
            return Promise.resolve({interpolateHeight:()=>100+x});
        }
    };
    const cache=create({C,clock:()=>0});
    const result=await cache.sample(provider,[point(.1e-6,0),point(1.1e-6,0),point(2.1e-6,0)],controller().signal);
    assert.deepEqual(result.map(p=>p.height),[100,900,900]);
    assert.deepEqual(fallbackSizes,[2]);
});

test('non-finite native fallback must not be promoted to a confirmed terrain profile',async()=>{
    const C={sampleTerrainMostDetailed:async(_,positions)=>positions.map(p=>({...p,height:undefined}))};
    const provider={
        availability:{computeMaximumLevelAtPosition:()=>17},
        tilingScheme:{positionToTileXY:()=>({x:0,y:0}),tileXYToRectangle:()=>({})},
        requestTileGeometry:()=>Promise.resolve({interpolateHeight:()=>undefined})
    };
    const cache=create({C,clock:()=>0});
    await assert.rejects(cache.sample(provider,[point(.1,.1)],controller().signal),/Incomplete detailed terrain fallback/);
});
function deterministicTimers(){
    let now=0,id=0;const pending=new Map();
    return {clock:()=>now,setTimeout(fn,ms){const key=++id;pending.set(key,{at:now+ms,fn});return key;},
        clearTimeout(key){pending.delete(key);},advance(ms){now+=ms;
            for(;;){const next=[...pending].filter(([,v])=>v.at<=now).sort((a,b)=>a[1].at-b[1].at)[0];
                if(!next)break;pending.delete(next[0]);next[1].fn();}},get size(){return pending.size;}};
}
const flushMicrotasks=async()=>{for(let i=0;i<24;i++)await Promise.resolve();};

test('aborting one profile promptly stops worker launches and never starts a native fallback',async()=>{
    let requests=0,fallback=0;const finish=[];
    const C={sampleTerrainMostDetailed:async(_,points)=>{fallback++;return points.map(p=>({...p,height:900}));}};
    const provider={availability:{computeMaximumLevelAtPosition:()=>17},
        tilingScheme:{positionToTileXY:p=>({x:Math.floor(p.longitude*1e6),y:0}),tileXYToRectangle:()=>({})},
        requestTileGeometry(){requests++;return new Promise(resolve=>finish.push(resolve));}};
    const cache=create({C}),abort=controller();
    const pending=cache.sample(provider,Array.from({length:12},(_,i)=>point(i*1e-6,0)),abort.signal);
    assert.equal(requests,4,'four existing workers may warm shared terrain');
    abort.abort();await assert.rejects(pending,/abort|cancelled/i);
    assert.equal(requests,4,'eight queued groups must not start after cancellation');assert.equal(fallback,0);
    for(const resolve of finish)resolve({interpolateHeight:()=>500});
    await flushMicrotasks();assert.equal(requests,4);assert.equal(cache.cachedTiles,4);
    const fresh=await cache.sample(provider,[point(.2e-6,0)],controller().signal);
    assert.equal(fresh[0].height,500,'completed same-provider work is reusable without stale observations');cache.reset();
});

test('independently bounded tile work is evicted after timeout and a later profile recovers',async()=>{
    const timers=deterministicTimers();let calls=0,finishOld;
    const C={sampleTerrainMostDetailed:async(_,positions)=>positions.map(p=>({...p,height:999}))};
    const provider={availability:{computeMaximumLevelAtPosition:()=>17},
        tilingScheme:{positionToTileXY:()=>({x:0,y:0}),tileXYToRectangle:()=>({})},
        requestTileGeometry(){calls++;return calls===1?new Promise(resolve=>finishOld=resolve):Promise.resolve({interpolateHeight:()=>700});}};
    const cache=create({C,timers,clock:timers.clock,tileTimeoutMs:100});
    const first=cache.sample(provider,[point(.1,.1)],controller().signal);
    timers.advance(100);assert.equal((await first)[0].height,999,'only Cesium detailed fallback may replace a failed tile');
    assert.equal(cache.cachedTiles,0);assert.equal(cache.diagnostics().timeouts,1);
    const recovered=await cache.sample(provider,[point(.1,.1)],controller().signal);
    assert.equal(recovered[0].height,700);assert.equal(calls,2);assert.equal(cache.cachedTiles,1);
    finishOld({interpolateHeight:()=>100});await flushMicrotasks();
    assert.equal((await cache.sample(provider,[point(.11,.11)],controller().signal))[0].height,700);
    assert.equal(calls,2,'late timed-out tile never replaces the fresh tile');assert.equal(timers.size,0);cache.reset();
});

test('provider reset rejects waiting consumers before old I/O completes and cannot launch fallback work',async()=>{
    let finish,fallback=0;
    const C={sampleTerrainMostDetailed:async(_,positions)=>{fallback++;return positions.map(p=>({...p,height:900}));}};
    const provider={availability:{computeMaximumLevelAtPosition:()=>17},
        tilingScheme:{positionToTileXY:()=>({x:0,y:0}),tileXYToRectangle:()=>({})},
        requestTileGeometry:()=>new Promise(resolve=>finish=resolve)};
    const cache=create({C}),stale=cache.sample(provider,[point(.1,.1)],controller().signal);
    cache.reset();await assert.rejects(stale,error=>error.category==='SUPERSEDED');
    assert.equal(fallback,0);assert.equal(cache.cachedTiles,0);
    finish({interpolateHeight:()=>100});await flushMicrotasks();assert.equal(cache.cachedTiles,0);
});

test('station tiles survive moving-ray eviction within the existing cache budget',async()=>{
    const width=.00001,station=point(0,0),calls=new Map();
    const C={sampleTerrainMostDetailed:async()=>{throw Error('unexpected fallback');}};
    const provider={availability:{computeMaximumLevelAtPosition:()=>17},tilingScheme:{positionToTileXY:p=>({x:Math.round(p.longitude/width),y:0}),tileXYToRectangle:x=>({x})},requestTileGeometry(x){calls.set(x,(calls.get(x)??0)+1);return Promise.resolve({interpolateHeight:()=>x+100});}};
    const cache=create({C,capacity:8,clock:()=>0});cache.setStation(station);
    const ray=[point(0,0),point(width,0),...Array.from({length:12},(_,i)=>point((i+10)*width,0))];
    await cache.sample(provider,ray,controller().signal);
    assert.equal(cache.cachedTiles,8);assert.equal(cache.diagnostics().stationCachedTiles,2);
    const next=[point(.0000001,0),point(width+.0000001,0),...Array.from({length:12},(_,i)=>point((i+30)*width,0))];
    await cache.sample(provider,next,controller().signal);assert.equal(calls.get(0),1);assert.equal(calls.get(1),1);assert.equal(cache.cachedTiles,8);
    cache.setStation({longitude:1,latitude:0});assert.equal(cache.diagnostics().stationCachedTiles,0);
    cache.reset();assert.equal(cache.cachedTiles,0);
});

test('long ray reuses only station tiles and rechecks finer availability after native bulk discovery',async()=>{
    let calls=0,bulk=0,level=17,refine=false;
    const C={sampleTerrainMostDetailed:async(_,points)=>{bulk++;if(refine)level=18;return points.map(p=>({...p,height:999}));}};
    const provider={availability:{computeMaximumLevelAtPosition:()=>level},tilingScheme:{positionToTileXY:p=>({x:Math.floor(p.longitude*100000),y:0}),tileXYToRectangle:()=>({})},requestTileGeometry(){calls++;return Promise.resolve({interpolateHeight:()=>700});}};
    const cache=create({C});cache.setStation({longitude:0,latitude:0});
    const ray=[point(0,0),point(.02,0),point(.03,0)];
    assert.deepEqual((await cache.sample(provider,ray,controller().signal)).map(p=>p.height),[700,999,999]);
    assert.deepEqual((await cache.sample(provider,[point(.0000001,0),...ray.slice(1)],controller().signal)).map(p=>p.height),[700,999,999]);
    assert.equal(calls,1);assert.equal(bulk,2);refine=true;
    assert.deepEqual((await cache.sample(provider,ray,controller().signal)).map(p=>p.height),[999,999,999]);assert.equal(bulk,4);
});
