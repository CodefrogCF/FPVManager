'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
const ActualCesium=require('../../web/cesium/index.cjs');
const at=metres=>[8.2,46.8+metres/111319.49079327358];
const route=(extra={})=>({id:'bridge-height-refresh',source:'fixture',sourceId:'bridge-road',
    kind:'tunnel',transport:'road',coordinates:[0,20,40,60,80,100].map(at),
    roadApproaches:[[-4,-8,-12,-16,-20].map(at),[104,108,112,116,120].map(at)],
    roadApproachKinds:['bridge','road'],...extra});
function fixture({onProbe=()=>{}}={}){
    class Options{constructor(options){Object.assign(this,options);}}
    const C={Geometry:Options,GeometryAttribute:Options,GeometryInstance:Options,Primitive:Options,
        PerInstanceColorAppearance:Options,ComponentDatatype:{DOUBLE:1},PrimitiveType:{TRIANGLES:4},
        Cartesian3:ActualCesium.Cartesian3,Ray:ActualCesium.Ray,Cartographic:ActualCesium.Cartographic,
        Color:{fromBytes:(...values)=>values},ColorGeometryInstanceAttribute:{fromColor:color=>color},
        BoundingSphere:{fromVertices:vertices=>({length:vertices.length})}};
    const selected={show:true},roof={},tree={},items=[selected,roof,tree],probes=[],requests=[];
    let clock=1000,deck=501.5,code=200,missing=null,queries=0,insideGround=520,outsideGround=500,nativeId='bridge-uuid',simulating=false;
    const terrain=point=>{
        const metres=(point.latitude-at(0)[1])*111319.49079327358;
        return metres>1&&metres<99?insideGround:outsideGround;
    };
    const viewer={scene:{globe:{getHeight:point=>{
        // getHeight receives Cesium radians; provider requests use degrees.
        return terrain({latitude:point.latitude*180/Math.PI});},clippingPolygons:{length:0}},
        primitives:{get length(){return items.length;},get:i=>items[i],add:p=>{items.push(p);return p;},
            remove:p=>{const i=items.indexOf(p);if(i>=0)items.splice(i,1);return i>=0;}},
        sampleHeightSupported:true,sampleHeight:()=>{throw Error('Unclassified height sampling is forbidden');},
        pickFromRay:(ray,excluded)=>{
            onProbe();
            const p=ActualCesium.Cartographic.fromCartesian(ray.origin),point={
                longitude:p.longitude*180/Math.PI,latitude:p.latitude*180/Math.PI};
            probes.push({point,excluded:excluded.slice()});
            if(missing!=null&&Math.abs(point.latitude-at(missing)[1])<1e-7||deck==null)return undefined;
            const value=typeof deck==='function'?deck(point):deck;
            return {position:C.Cartesian3.fromDegrees(point.longitude,point.latitude,value),
                object:{tileset:selected,getProperty:key=>({KUNSTBAUTE:code,UUID:nativeId,NAME:'Bridge'})[key]}};
        },requestRender(){}}};
    const service=T.create(C,viewer,()=>{},{getDeckTileset:()=>selected,now:()=>clock,isSimulating:()=>simulating,
        sampleTerrain:async points=>{queries++;requests.push(...points);return points.map(terrain);}});
    service.setAutomaticEnabled(true);
    return {service,selected,roof,tree,items,probes,requests,get queries(){return queries;},
        advance:ms=>clock+=ms,setDeck:value=>deck=value,setClass:value=>code=value,setMissing:value=>missing=value,
        setNativeId:value=>nativeId=value,
        setFlightPoint:point=>{simulating=true;viewer.camera={positionCartographic:{longitude:point.longitude*Math.PI/180,
            latitude:point.latitude*Math.PI/180,height:point.height}};},
        setTerrain:(outside,inside)=>{outsideGround=outside;insideGround=inside;},
        scan:r=>service.setAutomaticRoutes([r||route()],{longitude:8.2,latitude:at(50)[1]}),
        dispose:()=>service.dispose()};
}
test('native bridge level .5 m above terrain establishes the actual portal instead of the raster level',async()=>{
    const f=fixture();f.setDeck(500.5);
    try{
        assert.equal((await f.scan()).count,1);
        const entry=f.service.diagnostics().entries[0];
        assert.equal(entry.portalFloorMethods[0],'connected-bridge-surface');
        assert.ok(Math.abs(entry.floorEnds[0]-500.4)<1e-5);
        assert.equal(f.probes.length,5);
        assert.ok(f.probes.every(p=>p.excluded.includes(f.roof)&&p.excluded.includes(f.tree)&&!p.excluded.includes(f.selected)));
    }finally{f.dispose();}
});
test('a cliff-side raster 1.5 m above five native bridge hits cannot override their actual road level',async()=>{
    const f=fixture();f.setTerrain(501.5,520);f.setDeck(500);
    try{
        assert.equal((await f.scan()).count,1);
        const entry=f.service.diagnostics().entries[0];
        assert.equal(entry.portalFloorMethods[0],'connected-bridge-surface');
        assert.ok(Math.abs(entry.floorEnds[0]-499.9)<1e-5);
    }finally{f.dispose();}
});
test('a later 1.5 m native deck refinement refreshes after 20 s without rebuilding every scan',async()=>{
    const f=fixture();try{
        assert.equal((await f.scan()).count,1);const first=f.items.at(-1),initial=f.probes.length;
        f.setDeck(503);f.advance(1000);await f.scan();
        assert.equal(f.probes.length,initial);assert.equal(f.items.at(-1),first);
        f.advance(20000);assert.equal((await f.scan()).count,1);
        const updated=f.service.diagnostics().entries[0];
        assert.equal(updated.portalFloorMethods[0],'connected-bridge-surface');
        assert.ok(Math.abs(updated.floorEnds[0]-502.9)<1e-5);
        assert.equal(f.probes.length,initial+5);assert.notEqual(f.items.at(-1),first);
    }finally{f.dispose();}
});
test('bridge tiles arriving after the first scan replace an unconfirmed terrain anchor on the bounded retry',async()=>{
    const f=fixture();f.setDeck(null);try{
        await f.scan();const initial=f.probes.length;
        f.setDeck(501.5);f.advance(1000);await f.scan();assert.equal(f.probes.length,initial);
        f.advance(20000);assert.equal((await f.scan()).count,1);
        const entry=f.service.diagnostics().entries[0];
        assert.equal(entry.portalFloorMethods[0],'connected-bridge-surface');
        assert.ok(Math.abs(entry.floorEnds[0]-501.4)<1e-5);
    }finally{f.dispose();}
});
test('a 1.5 m native refinement keeps one safe active floor, then adopts the new level when the pilot clears it',async()=>{
    const f=fixture();try{
        await f.scan();const primitive=f.items.at(-1),point={longitude:8.2,latitude:at(4)[1],height:503};
        const oldFloor=f.service.floorAt(point);assert.ok(Number.isFinite(oldFloor));
        f.setFlightPoint({...point,height:oldFloor+.5});f.setDeck(503);f.advance(21000);
        assert.equal((await f.scan()).count,1,'the current body cannot be replaced by a floor above it');
        assert.equal(f.items.at(-1),primitive,'the failed replacement is discarded, leaving one geometry');
        assert.equal(f.items.filter(item=>item!==f.selected&&item!==f.roof&&item!==f.tree).length,1);
        assert.ok(Math.abs(f.service.floorAt({...point,height:oldFloor+.5})-oldFloor)<1e-6,
            'the active floor stays available instead of falling back to mountain terrain');
        f.setFlightPoint({...point,height:oldFloor+2});f.advance(21000);
        assert.equal((await f.scan()).count,1);
        assert.notEqual(f.items.at(-1),primitive);
        assert.ok(f.service.floorAt({...point,height:oldFloor+2})>oldFloor+1.3,
            'the next bounded retry adopts the measured native height once the body fits');
    }finally{f.dispose();}
});
test('a classified 125 m bridge profile is not discarded by the former 90 m height cutoff',async()=>{
    const f=fixture();f.setTerrain(500,650);f.setDeck(625);
    try{
        assert.equal((await f.scan(route({roadApproachKinds:['bridge','bridge']}))).count,1);
        const entry=f.service.diagnostics().entries[0];
        assert.deepEqual(entry.portalFloorMethods,['connected-bridge-surface','connected-bridge-surface']);
        assert.ok(entry.floorEnds.every(height=>Math.abs(height-624.9)<1e-5));
    }finally{f.dispose();}
});
test('four native points and one terrain sample cannot become a mixed bridge profile or remove the resident tunnel',async()=>{
    const f=fixture();try{
        await f.scan();const primitive=f.items.at(-1),floor=f.service.diagnostics().entries[0].floorEnds[0];
        f.setMissing(-12);f.setDeck(503);f.advance(21000);
        assert.equal((await f.scan()).count,1);
        assert.equal(f.items.at(-1),primitive);
        assert.equal(f.service.diagnostics().entries[0].floorEnds[0],floor);
        const count=f.probes.length;f.advance(1000);await f.scan();assert.equal(f.probes.length,count);
        f.setMissing(null);f.advance(20000);await f.scan();
        assert.ok(Math.abs(f.service.diagnostics().entries[0].floorEnds[0]-502.9)<1e-5);
    }finally{f.dispose();}
});
test('native bridge metadata rejects roofs and trees even when their height profile is coherent',async()=>{
    const f=fixture();f.setClass(100);f.setDeck(503);
    try{await f.scan();assert.ok(f.service.diagnostics().entries.every(e=>e.portalFloorMethods[0]!=='connected-bridge-surface'));}
    finally{f.dispose();}
});
test('five native bridge hits without a stable source identifier cannot confirm a road profile',async()=>{
    const f=fixture();f.setNativeId(null);
    try{await f.scan();assert.ok(f.service.diagnostics().entries.every(e=>e.portalFloorMethods[0]!=='connected-bridge-surface'));}
    finally{f.dispose();}
});
test('two native approach packs yield between each group of five offscreen picks',async()=>{
    const realTimeout=globalThis.setTimeout,turns=[];let turn=0;
    globalThis.setTimeout=(callback,delay,...args)=>realTimeout(()=>{turn++;callback(...args);},delay);
    const f=fixture({onProbe:()=>turns.push(turn)});
    try{
        await f.scan(route({roadApproachKinds:['bridge','bridge']}));
        assert.equal(turns.length,10);
        assert.ok(turns[0]>0,'the initial scene update stack unwinds before picking');
        assert.ok(turns[5]>turns[4],'a second five-pick pack occupies a later turn');
    }finally{f.dispose();globalThis.setTimeout=realTimeout;}
});
test('approach kind and geometry changes invalidate a resident route with unchanged tunnel endpoints',async()=>{
    const f=fixture();try{
        const ordinary=route({roadApproachKinds:['road','road']});await f.scan(ordinary);const firstQueries=f.queries;
        const native=route();f.advance(100);await f.scan(native);
        assert.ok(f.queries>firstQueries);
        assert.equal(f.service.diagnostics().entries[0].portalFloorMethods[0],'connected-bridge-surface');
        const queries=f.queries;
        const shifted=route({roadApproaches:[[-5,-9,-13,-17,-21].map(at),native.roadApproaches[1]]});
        f.advance(100);await f.scan(shifted);assert.ok(f.queries>queries);
    }finally{f.dispose();}
});
test('ordinary road models retain their established height cache after 20 s',async()=>{
    const f=fixture();try{
        const ordinary=route({roadApproachKinds:['road','road']});await f.scan(ordinary);const queries=f.queries;
        f.advance(21000);await f.scan(ordinary);assert.equal(f.queries,queries);assert.equal(f.probes.length,0);
    }finally{f.dispose();}
});
