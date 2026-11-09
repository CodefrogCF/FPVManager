'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {createTerrainManager}=require('../../web/terrain_service.js');
const T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function deferred(){let resolve;const promise=new Promise(r=>{resolve=r;});return {promise,resolve};}

const at=(index,metres)=>[8.2+index*.0002,46.8+metres/111319.49079327358];
const route=index=>({id:`sampling-regression:${index}`,source:'integration fixture',sourceId:String(index),
    name:`Separate bore ${index}`,kind:'tunnel',transport:'road',
    coordinates:[0,20,40,60,80,100].map(distance=>at(index,distance)),
    roadApproaches:[[-4,-8,-12,-16,-20].map(distance=>at(index,distance)),
        [104,108,112,116,120].map(distance=>at(index,distance))]});

async function fixture(probe=async points=>points.map(()=>500)){
    let clock=1000,calls=0;const signals=[],requests=[],added=[];
    const terrain=createTerrainManager({
        createProvider:async()=>({requestTileGeometry:async()=>({}),
            errorEvent:{addEventListener:()=>()=>{}},
            sampleHeights:points=>{calls++;requests.push(...points);return probe(points,calls);}}),
        createFallback:()=>({flat:true}),applyProvider:()=>{},onStatus:()=>{}});
    await terrain.retry();
    class Options{constructor(options){Object.assign(this,options);}}
    const C={Geometry:Options,GeometryAttribute:Options,GeometryInstance:Options,Primitive:Options,
        PerInstanceColorAppearance:Options,ComponentDatatype:{DOUBLE:1},PrimitiveType:{TRIANGLES:4},
        Cartesian3:{fromDegrees:(longitude,latitude,height=0)=>({x:longitude,y:latitude,z:height})},
        Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},
        Color:{fromBytes:(...values)=>values},ColorGeometryInstanceAttribute:{fromColor:color=>color},
        BoundingSphere:{fromVertices:vertices=>({length:vertices.length})}};
    const viewer={scene:{globe:{getHeight:()=>560,clippingPolygons:{length:0}},
        primitives:{add:value=>{added.push(value);return value;},
            remove:value=>{const index=added.indexOf(value);if(index>=0)added.splice(index,1);return index>=0;}},
        requestRender(){}}};
    const tunnels=T.create(C,viewer,()=>{},{now:()=>clock,ready:()=>terrain.status().state==='ready',
        // Keep the production service boundary: an automatic scan supplies no
        // command signal, yet the terrain manager still guards its generation.
        sampleTerrain:(points,signal)=>{
            signals.push(signal);
            return terrain.sample(provider=>provider.sampleHeights(points),signal);
        }});
    tunnels.setAutomaticEnabled(true);
    return {terrain,tunnels,added,signals,requests,get calls(){return calls;},
        advance(){clock+=21000;},dispose(){tunnels.dispose();terrain.dispose();}};
}

test('automatic scans load 39 valid tunnels through the real terrain service without a command signal',async()=>{
    const f=await fixture();
    try{
        const result=await f.tunnels.setAutomaticRoutes(Array.from({length:39},(_,i)=>route(i)),
            {longitude:8.2038,latitude:46.8004});
        assert.equal(result.sampleFailed,0,'background terrain calls must reach the real provider');
        assert.equal(result.skipped,0);
        assert.equal(result.count,39,'valid routes must not collapse to the few using rendered heights');
        assert.equal(f.added.length,39);
        assert.equal(f.calls,13,'39 routes are sampled in 13 batches of 3');
        assert.ok(f.signals.length&&f.signals.every(signal=>signal===undefined),
            'this exercises the missing optional signal seen in the application');
        const diagnostics=f.tunnels.diagnostics();
        assert.equal(diagnostics.error,null);
        assert.equal(diagnostics.entries.length,39);
        for(const entry of diagnostics.entries){
            assert.deepEqual(entry.portalFloorMethods,['connected-road-grade','connected-road-grade']);
            assert.ok(entry.floorEnds.every(height=>Math.abs(height-499.9)<1e-6),
                'fresh road heights override the 560 m rendered cliff');
        }
        assert.equal(f.terrain.status().state,'ready');
    }finally{f.dispose();}
});

test('disposing terrain cancels a background tunnel query without a command signal or late geometry',async()=>{
    const pending=deferred();const f=await fixture(points=>pending.promise.then(()=>points.map(()=>500)));
    try{
        const scan=f.tunnels.setAutomaticRoutes([route(0)],{longitude:8.2,latitude:46.8004});
        await tick();
        assert.equal(f.calls,1,'provider sampling starts before disposal');
        f.terrain.dispose();
        const result=await scan;
        assert.equal(result.count,0);
        assert.equal(result.sampleFailed,1);
        assert.match(f.tunnels.diagnostics().error,/cancelled|changed/i);
        assert.doesNotMatch(f.tunnels.diagnostics().error,/throwIfAborted|undefined/);
        pending.resolve();await tick();
        assert.equal(f.tunnels.status().autoCount,0);
        assert.equal(f.added.length,0);
    }finally{pending.resolve();f.dispose();}
});

test('provider replacement cancels an automatic scan and a later scan recovers all road heights',async()=>{
    const pending=deferred();
    const f=await fixture((points,calls)=>calls===1?pending.promise.then(()=>points.map(()=>700)):
        Promise.resolve(points.map(()=>500)));
    try{
        const first=f.tunnels.setAutomaticRoutes([route(0)],{longitude:8.2,latitude:46.8004});
        await tick();
        assert.equal(f.calls,1);
        await f.terrain.retry();
        const rejected=await first;
        assert.equal(rejected.count,0);
        assert.equal(rejected.sampleFailed,1);
        assert.match(f.tunnels.diagnostics().error,/cancelled|changed/i);
        pending.resolve();await tick();
        assert.equal(f.added.length,0,'old provider completion cannot install a late tunnel');
        f.advance();
        const recovered=await f.tunnels.setAutomaticRoutes([route(0)],{longitude:8.2,latitude:46.8004});
        assert.equal(recovered.count,1);
        assert.equal(recovered.sampleFailed,0);
        assert.equal(f.tunnels.diagnostics().error,null);
        assert.ok(f.tunnels.diagnostics().entries[0].floorEnds.every(height=>Math.abs(height-499.9)<1e-6));
    }finally{pending.resolve();f.dispose();}
});
