'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const Actual=require('../../web/cesium/index.cjs');
const T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
for(const name of ['HTMLCanvasElement','HTMLImageElement','ImageBitmap','OffscreenCanvas','HTMLVideoElement'])
    globalThis[name]??=class {};
const origin=[8.4,46.8],metres=111319.49079327358;
const coordinate=(x,y=0)=>[origin[0]+x/(metres*Math.cos(origin[1]*Math.PI/180)),origin[1]+y/metres];
const pose=(x,y=0,height=502)=>({longitude:coordinate(x,y)[0],latitude:coordinate(x,y)[1],height});
const route=(id,points,kind='underpass')=>({id,name:id,kind,transport:'road',source:'Scheduling fixture',coordinates:points});
const routes=Array.from({length:4},(_,i)=>route(`bore-${i}`,[coordinate(i*100),coordinate(i*100+40)]));
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(options={}){
    const items=[],builds=[];
    class Primitive{constructor(value){Object.assign(this,value);builds.push(this);}destroy(){this.destroyed=true;}}
    const C={...Actual,Primitive,PolylineCollection:null,MaterialAppearance:null};
    const viewer={scene:{globe:{getHeight:()=>500},primitives:{add:p=>{items.push(p);return p;},remove:p=>{
        const index=items.indexOf(p);if(index>=0){items.splice(index,1);p.destroy?.();return true;}return false;}},requestRender(){}}};
    const service=T.create(C,viewer,()=>{},{sampleTerrain:async points=>points.map(()=>500),isSimulating:()=>true,...options});
    service.setPerformanceProfile('performance');service.setAutomaticEnabled(true);
    return {service,items,builds,viewer};
}

test('flight loads retain all requested tunnels while admitting one full mesh per rendered opportunity',async()=>{
    const perFrame=[];let previous=0,f;
    f=fixture({yieldToFrame:async()=>{perFrame.push(f.builds.length-previous);previous=f.builds.length;}});
    try{
        assert.equal((await f.service.setAutomaticRoutes(routes,pose(0))).count,4);
        perFrame.push(f.builds.length-previous);
        assert.deepEqual(perFrame,[1,1,1,1]);
        assert.equal(f.items.length,4);
        for(let i=0;i<4;i++){
            assert.ok(Math.abs(f.service.floorAt(pose(i*100+20))-499.9)<.001,'flight floor is retained for every model');
            assert.equal(f.service.intersects(pose(i*100+20),pose(i*100+20,4)),true,'wall collisions retain exact geometry');
        }
    }finally{f.service.dispose();}
});

test('default flight scheduler waits through a browser render callback before building the next tunnel',async()=>{
    const originalRAF=globalThis.requestAnimationFrame,originalCancel=globalThis.cancelAnimationFrame,callbacks=[];
    globalThis.requestAnimationFrame=callback=>{callbacks.push(callback);return callbacks.length;};
    globalThis.cancelAnimationFrame=()=>{};
    const f=fixture();let done=false;
    try{
        const pending=f.service.setAutomaticRoutes(routes.slice(0,2),pose(0)).then(value=>{done=true;return value;});
        await flush();
        assert.equal(f.builds.length,1);assert.equal(done,false);assert.equal(callbacks.length,1);
        // Merely finishing the terrain Promise cannot consume a second model.
        // The simulator/browser gets a complete render opportunity first.
        callbacks.shift()(16);
        assert.equal(f.builds.length,1);
        assert.equal((await pending).count,2);assert.equal(f.builds.length,2);
    }finally{f.service.dispose();globalThis.requestAnimationFrame=originalRAF;globalThis.cancelAnimationFrame=originalCancel;}
});

test('a superseded request discards staged flight meshes after a render yield without leaking resources',async()=>{
    let resume;
    const f=fixture({yieldToFrame:()=>new Promise(resolve=>{resume=resolve;})});
    try{
        const pending=f.service.setAutomaticRoutes(routes,pose(0));await flush();
        assert.equal(f.builds.length,1);assert.equal(f.items.length,1);
        f.service.setAutomaticEnabled(false);resume();
        assert.equal((await pending).cancelled,true);
        assert.equal(f.items.length,0);assert.ok(f.builds.every(p=>p.destroyed));
        assert.equal(f.service.diagnostics().count,0);
    }finally{f.service.dispose();}
});

test('cached source vertices retain exactly the same flat-shaded triangle coordinates while bounding conversions',()=>{
    const model=T.procedural(route('long-window',Array.from({length:96},(_,i)=>coordinate(i*18,Math.sin(i*.16)*8))),
        Array(96).fill(500),{profile:'vaulted'});
    let conversions=0;
    class Cartesian3 extends Actual.Cartesian3{
        static fromDegrees(...args){conversions++;return Actual.Cartesian3.fromDegrees(...args);}
    }
    const surfaces=T.surfaceGeometries({...Actual,Cartesian3},model),outlines=T.rings(model);
    assert.ok(conversions<3000,'shared source positions are converted once, not for all ~8500 triangle corners');
    const floor=surfaces.find(s=>s.kind==='road').geometry.attributes.position.values;
    for(let section=0;section<95;section++){
        const a=outlines[section],b=outlines[section+1],expected=[a[0],a[1],b[1],a[0],b[1],b[0]]
            .flatMap(p=>{const q=Actual.Cartesian3.fromDegrees(...p);return [q.x,q.y,q.z];});
        assert.deepEqual(Array.from(floor.slice(section*18,section*18+18)),expected);
    }
});

function setCamera(f,point){
    f.viewer.camera={positionCartographic:{longitude:point.longitude*Math.PI/180,
        latitude:point.latitude*Math.PI/180,height:point.height}};
}
function countedSines(action){
    const original=Math.sin;let calls=0;
    Math.sin=value=>{calls++;return original(value);};
    try{return {value:action(),calls};}finally{Math.sin=original;}
}
test('the occupied new corridor is collision-ready before commit while unrelated viewport tunnels remain lazy',async()=>{
    let opportunities=0;
    const f=fixture({yieldToFrame:async()=>{opportunities++;}});
    setCamera(f,pose(20));
    try{
        assert.equal((await f.service.setAutomaticRoutes(routes.slice(0,2),pose(20))).count,2);
        assert.equal(opportunities,2,'one geometry separation and one occupied-collider preparation slot');
        const warm=countedSines(()=>f.service.intersects(pose(20),pose(21)));
        assert.equal(warm.value,false);
        assert.equal(warm.calls,4,'first physics query converts only its two endpoints, never the full tube');
        const cold=countedSines(()=>f.service.intersects(pose(120),pose(121)));
        assert.equal(cold.value,false);
        assert.ok(cold.calls>40,'the unrelated tunnel was not eagerly prepared');
    }finally{f.service.dispose();}
});

test('collision preparation uses the final junction lining and keeps the resident until cancellation resolves',async()=>{
    let pause=false,resume,opportunities=0;
    const f=fixture({yieldToFrame:()=>{opportunities++;return pause?new Promise(resolve=>{resume=resolve;}):Promise.resolve();}});
    const receiver=route('receiver',[coordinate(-100),coordinate(0),coordinate(100)]);
    const branch=route('branch',[coordinate(0),coordinate(0,50)]);
    setCamera(f,pose(-20));
    try{
        assert.equal((await f.service.setAutomaticRoutes([receiver,branch],pose(-20))).count,2);
        const warm=countedSines(()=>f.service.intersects(pose(-20),pose(-19)));
        assert.equal(warm.value,false);assert.equal(warm.calls,4,'the final receiver with its junction cut was warmed');
        assert.equal(f.service.intersects(pose(0),pose(0,4)),false,'final branch mouth is physically open');
        const resident=f.items.slice();pause=true;
        const changed=route('next-window',[coordinate(-20,-100),coordinate(-20,100)]);
        const pending=f.service.setAutomaticRoutes([changed],pose(-20));await flush();
        assert.ok(resume,'the newly occupied collider gets a separate preparation slot');
        assert.ok(resident.every(p=>f.items.includes(p)),'resident lining is retained while preparation is suspended');
        assert.equal(f.service.intersects(pose(0),pose(0,4)),false,'resident cut remains unchanged during the yield');
        f.service.dispose();resume();
        assert.equal((await pending).cancelled,true);assert.equal(f.items.length,0);
        assert.ok(opportunities>=3);
    }finally{f.service.dispose();}
});
