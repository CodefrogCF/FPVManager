const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {create,profiles,perspectiveFov}=require('../../web/flight_rendering.js');
const {createVectors}=require('../../web/obstacle_layers.js');
const {createSimulator}=require('../../web/free_flight.js');
// Use the pinned runtime's actual coordinate/matrix math without a DOM/WebGL.
const scope={console,setTimeout,clearTimeout,URL,TextDecoder,TextEncoder,atob,btoa,
    TransformStream,ReadableStream,WritableStream,AbortController,Blob};scope.global=scope;
const C=vm.runInNewContext(fs.readFileSync(require.resolve('../../web/cesium/Cesium.js'),'utf8')+';Cesium',scope);
function fixture(){
    let allocations=0,reference=null,last=null,ray=null,hitDistance=null;
    const MathC={...C};
    for(const name of ['Cartesian3','Cartographic','Matrix4','Ray'])MathC[name]=class extends C[name]{constructor(...args){super(...args);allocations++;}};
    const viewer={resolutionScale:.95,scene:{msaaSamples:8,requestRender(){},globe:{ellipsoid:C.Ellipsoid.WGS84,
        tileCacheSize:100,preloadAncestors:true,preloadSiblings:false,maximumScreenSpaceError:2,
        getHeight:position=>position.latitude*100,
        pick:value=>{ray=value;if(hitDistance==null)return;return C.Cartesian3.add(value.origin,C.Cartesian3.multiplyByScalar(value.direction,hitDistance,new C.Cartesian3()),new C.Cartesian3());}}},
        camera:{setView(value){reference=value;last={position:C.Cartesian3.clone(value.destination),
            direction:value.orientation.direction&&C.Cartesian3.clone(value.orientation.direction),
            up:value.orientation.up&&C.Cartesian3.clone(value.orientation.up),heading:value.orientation.heading};}}};
    return {viewer,adapter:create(MathC,viewer),get allocations(){return allocations;},get reference(){return reference;},get last(){return last;},
        get ray(){return ray;},hit:distance=>hitDistance=distance};
}
test('horizontal FOV adapts to portrait without mixing camera tilt or changing physics',()=>{
    assert.ok(Math.abs(perspectiveFov(90,16/9)-Math.PI/2)<1e-12);
    assert.ok(perspectiveFov(90,9/16)>Math.PI/2);
    for(const bad of [49,141,Infinity,NaN])assert.throws(()=>perspectiveFov(bad,1));
    const p=fixture();
    p.viewer.camera.frustum={fov:Math.PI/3,aspectRatio:16/9};
    p.adapter.applyPose({longitude:8.4,latitude:46.7,height:1300,heading:0,pitch:0,cameraFovDegrees:110});
    assert.ok(Math.abs(p.viewer.camera.frustum.fov-110*Math.PI/180)<1e-12);
    p.viewer.camera.frustum.aspectRatio=9/16;
    p.adapter.applyPose({longitude:8.4,latitude:46.7,height:1300,heading:0,pitch:0,cameraFovDegrees:90});
    assert.ok(p.viewer.camera.frustum.fov>Math.PI/2);
});
test('graphics profiles apply live and restore the exact prior viewer settings',()=>{
    const p=fixture(),saved=p.adapter.captureGraphics();
    for(const name of Object.keys(profiles)){
        p.adapter.applyGraphics(name);
        assert.equal(p.viewer.resolutionScale,profiles[name].resolutionScale);assert.equal(p.viewer.scene.msaaSamples,profiles[name].msaaSamples);
    }
    for(const bad of ['unknown','__proto__',null])assert.throws(()=>p.adapter.applyGraphics(bad));
    p.adapter.restoreGraphics(saved);assert.equal(p.viewer.resolutionScale,.95);assert.equal(p.viewer.scene.msaaSamples,8);
});
test('flight tile budget stays stable across profile changes and sessions without changing detail or preloading',()=>{
    const p=fixture(),globe=p.viewer.scene.globe;
    for(let session=0;session<3;session++){
        const saved=p.adapter.captureGraphics();
        assert.equal(globe.tileCacheSize,100);
        for(const profile of ['balanced','quality','performance','balanced']){
            p.adapter.applyGraphics(profile);
            assert.equal(globe.tileCacheSize,512);
            assert.equal(globe.maximumScreenSpaceError,2,'Terrain detail is preserved');
            assert.equal(globe.preloadAncestors,true);
            assert.equal(globe.preloadSiblings,false,'No additional speculative tile downloads');
        }
        p.adapter.restoreGraphics(saved);assert.equal(globe.tileCacheSize,100);
    }
});
test('flight keeps a larger existing cache and restores a custom globe budget exactly',()=>{
    for(const size of [48,256,1024]){
        const p=fixture();p.viewer.scene.globe.tileCacheSize=size;
        const saved=p.adapter.captureGraphics();
        p.adapter.applyGraphics('performance');assert.equal(p.viewer.scene.globe.tileCacheSize,Math.max(512,size));
        assert.throws(()=>p.adapter.applyGraphics('invalid'));assert.equal(p.viewer.scene.globe.tileCacheSize,Math.max(512,size));
        p.adapter.restoreGraphics(saved);assert.equal(p.viewer.scene.globe.tileCacheSize,size);
    }
});
test('real flight lifecycle restores the tile budget after reset, mode switches, terrain loss and startup failure',async()=>{
    const p=fixture();let ready=true,failPose=false;
    const simulator=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
        captureCamera:()=>({heading:0,graphics:p.adapter.captureGraphics()}),
        restoreCamera:saved=>p.adapter.restoreGraphics(saved.graphics),applyGraphics:p.adapter.applyGraphics,
        applyPose:point=>{if(failPose)throw new Error('fixture pose failure');p.adapter.applyPose(point);},
        isTerrainReady:()=>ready,onState(){}});
    const start=flightMode=>simulator.start({latitude:46.7,longitude:8.4,flightMode},new AbortController().signal);
    for(const mode of ['angle','acro','gps']){
        await start(mode);assert.equal(p.viewer.scene.globe.tileCacheSize,512);
        await simulator.reset();assert.equal(p.viewer.scene.globe.tileCacheSize,512);
    }
    ready=false;simulator.tick(1/60);
    assert.equal(simulator.active,false);assert.equal(p.viewer.scene.globe.tileCacheSize,100);
    ready=true;failPose=true;
    await assert.rejects(start('acro'),/fixture pose failure/);
    assert.equal(p.viewer.scene.globe.tileCacheSize,100);
    failPose=false;await start('angle');simulator.stop();simulator.stop();
    assert.equal(p.viewer.scene.globe.tileCacheSize,100);
});
test('pooled camera math matches the previous ENU transform at different positions and orientations',()=>{
    const p=fixture(),allocations=p.allocations;
    let destination,direction,up;
    for(const longitude of [8.4,-179.9,179.9])for(const latitude of [46.7,-65,80]){
        const point={longitude,latitude,height:1234,direction:{east:.3,north:.4,up:.5},up:{east:.7,north:-.4,up:.1}};
        p.adapter.applyPose(point);
        const expected=C.Cartesian3.fromDegrees(longitude,latitude,1234),transform=C.Transforms.eastNorthUpToFixedFrame(expected);
        const world=v=>C.Matrix4.multiplyByPointAsVector(transform,new C.Cartesian3(v.east,v.north,v.up),new C.Cartesian3());
        assert.ok(C.Cartesian3.equalsEpsilon(p.last.position,expected,1e-12));
        assert.ok(C.Cartesian3.equalsEpsilon(p.last.direction,world(point.direction),1e-12));
        assert.ok(C.Cartesian3.equalsEpsilon(p.last.up,world(point.up),1e-12));
        if(destination){assert.equal(p.reference.destination,destination);assert.equal(p.reference.orientation.direction,direction);assert.equal(p.reference.orientation.up,up);}
        destination=p.reference.destination;direction=p.reference.orientation.direction;up=p.reference.orientation.up;
    }
    p.adapter.applyPose({longitude:8,latitude:47,height:1000,heading:.4,pitch:.2,roll:.1});assert.equal(p.last.heading,.4);
    assert.equal(p.allocations,allocations,'No new adapter vectors/matrices after initialization');
});
test('pooled collision ray retains segment limits and terrain probes reuse their Cartographic',()=>{
    const p=fixture(),allocations=p.allocations,from={longitude:8,latitude:47,height:1000},to={...from,height:1010};
    p.hit(5);assert.equal(p.adapter.terrainCollision(from,to),true);const ray=p.ray;
    p.hit(10.002);assert.equal(p.adapter.terrainCollision(from,to),false);assert.equal(p.ray,ray);
    p.hit(null);assert.equal(p.adapter.terrainCollision(from,to),false);
    assert.equal(p.adapter.terrainCollision(from,from),false);
    for(let i=0;i<100;i++)assert.ok(Number.isFinite(p.adapter.renderedHeight(from)));
    assert.equal(p.allocations,allocations);
});

test('actual Cesium entities keep constant obstacle geometry and follow terrain refinement together',async()=>{
    let ground=600,clock=0,calls=0;
    const viewer={dataSources:new C.DataSourceCollection(),camera:{changed:new C.Event(),moveEnd:new C.Event()},
        scene:{preUpdate:new C.Event(),globe:{tileLoadProgressEvent:new C.Event(),getHeight(){calls++;return ground;}},requestRender(){}}};
    const manager=createVectors(C,viewer,{now:()=>clock});
    const mast=(id,lon,sourceHeight,agl)=>({id,category:'masts',parts:[{kind:'Point',elevated:true,coordinates:[[lon,47,sourceHeight]],heightAgl:agl}]});
    await manager.replace({revision:1,features:[mast('a',8,700,50),mast('b',8.01,710,60),
        {id:'cable',category:'powerLines',parts:[{kind:'LineString',elevated:true,coordinates:[[8,47,700],[8.01,47,710]]}]}]});
    const entities=viewer.dataSources.get(0).entities.values,marker=entities[0],cable=entities[4];
    assert.equal(marker.position.isConstant,true);assert.equal(cable.polyline.positions.isConstant,true);
    const top=()=>marker.position.getValue(C.JulianDate.now()),positions=()=>cable.polyline.positions.getValue(C.JulianDate.now());
    assert.ok(C.Cartesian3.equalsEpsilon(top(),positions()[0],1e-12));assert.equal(calls,2);
    for(let i=0;i<600;i++){clock+=16;viewer.scene.preUpdate.raiseEvent();}assert.equal(calls,2);
    ground=620;clock+=201;viewer.scene.globe.tileLoadProgressEvent.raiseEvent(0);viewer.scene.preUpdate.raiseEvent();
    assert.equal(calls,4);assert.ok(Math.abs(C.Cartographic.fromCartesian(top()).height-670)<1e-6);
    assert.ok(C.Cartesian3.equalsEpsilon(top(),positions()[0],1e-12));
    manager.dispose();assert.equal(viewer.dataSources.length,0);assert.equal(viewer.scene.preUpdate.numberOfListeners,0);
});

test('flight restores the finer topographic detail budget on exit',()=>{
  const p=fixture();p.viewer.scene.globe.maximumScreenSpaceError=1;
  const saved=p.adapter.captureGraphics();p.adapter.applyGraphics('balanced');
  assert.equal(p.viewer.scene.globe.maximumScreenSpaceError,2);
  p.adapter.restoreGraphics(saved);assert.equal(p.viewer.scene.globe.maximumScreenSpaceError,1);
});
