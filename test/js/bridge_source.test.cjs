'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const B=require('../../web/bridge_source.js');
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
        yieldBatch:async()=>{yields++;},now:()=>clock,...options});
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
    const f=setup();let hits=0;
    f.viewer.scene.pickFromRay=()=>{const uuid=++hits%8===0?'another-level':fixture.nativeFeature.UUID;
        return {object:{tileset:f.selected,getProperty:key=>({KUNSTBAUTE:200,UUID:uuid})[key]},position:{height:1450}};};
    try{const result=await f.manager.discover(center);assert.ok(result.bridges.length>1);
        assert.ok(result.bridges.every(b=>b.coordinates.length<15));}
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
