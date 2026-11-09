'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs'),T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
const F=require('../../web/free_flight.js');
for(const name of ['HTMLCanvasElement','HTMLImageElement','ImageBitmap','OffscreenCanvas','HTMLVideoElement'])globalThis[name]??=class {};
const longitude=8.6,latitude=46.7,scale=111319.49079327358;
const point=(along,across=0,height=502)=>({longitude:longitude+across/(scale*Math.cos(latitude*Math.PI/180)),
    latitude:latitude+along/scale,height});
const section=(along,floor=500)=>({...point(along),floorMetersWgs84:floor,widthMeters:6,heightMeters:5});
const model={kind:'tunnel',profile:'vaulted',portalEnds:[true,true],sections:[section(0),section(140,514)]};
function event(){const listeners=new Set();return {addEventListener:f=>{listeners.add(f);return()=>listeners.delete(f);},
    fire:()=>{for(const f of listeners)f();}};}

test('a true portal approach follows the selected bounded cut and inward road grade at either end',()=>{
    for(const end of [0,1]){
        const spec=T.boundedClipSpec(model,end),along=end?146:-6,floor=end?514.6:499.4;
        const p=point(along,0,floor+2);
        assert.equal(T.inside(model,p),false,'source-bounded inside remains unchanged');
        assert.ok(Math.abs(T.portalApproachFloor(model,p,end,spec)-floor)<1e-8);
        assert.equal(T.portalApproachFloor(model,point(end?149:-9,0,floor+2),end,spec),null,
            'the ordinary 8 m clipping notch cannot grant a longer terrain exemption');
        assert.equal(T.portalApproachFloor({...model,portalEnds:[false,false]},p,end,spec),null,
            'artificial window and underground junction endpoints have no surface entry corridor');
    }
    const spec=T.boundedClipSpec(model,0,{before:23});
    assert.ok(Math.abs(T.portalApproachFloor(model,point(-22,0,499.8),0,spec)-497.8)<1e-8);
    assert.equal(T.portalApproachFloor(model,point(-23.1,0,499.7),0,spec),null);
});

test('entry clearance stays within the physical bore and rejects rock beside, below and above its arch',()=>{
    const flat={...model,sections:[section(0),section(140)]},spec=T.boundedClipSpec(flat,0);
    assert.equal(T.portalApproachFloor(flat,point(-4,2.9),0,spec),null,'body cannot fit beside a physical wall');
    assert.equal(T.portalApproachFloor(flat,point(-4,0,505.1),0,spec),null,'visual clipping padding is not body clearance');
    assert.equal(T.portalApproachFloor(flat,point(-4,0,499.7),0,spec,.25,true),null);
    assert.equal(T.portalApproachFloor(flat,point(-4,0,499.9),0,spec),null,'a full body is not below the floor');
    assert.equal(T.portalApproachFloor(flat,point(-4,0,499.9),0,spec,.25,true),500,
        'height probes retain the physical floor for an ordinary floor-contact stop');
    assert.equal(T.portalApproachFloor(flat,point(-4,0,550),0,spec),null,'surface road over the roof is unaffected');
    assert.equal(T.portalApproachFloor(flat,point(-4),0,{...spec,longitude:spec.longitude+.01}),null,
        'another visible tunnel aperture cannot open this model');
});

async function setup({bridge=false,farFloor=500}={}){
    const preUpdate=event(),primitives=[];
    let clock=1000,simulating=false;
    const viewer={camera:{positionCartographic:{longitude:longitude*Math.PI/180,latitude:latitude*Math.PI/180,height:502}},
        scene:{context:{webgl2:true},preUpdate,globe:{clippingPolygons:{length:0},clippingPlanes:{length:0}},
            requestRender(){},primitives:{add:p=>{primitives.push(p);return p;},
                remove:p=>{const i=primitives.indexOf(p);if(i>=0)primitives.splice(i,1);}}}};
    const terrain=p=>{
        const along=(p.latitude-latitude)*scale;
        return along< -1?(bridge?480:500):along>139?farFloor:550;
    };
    const source={id:'entry',kind:'tunnel',transport:'road',coordinates:[point(0),point(70),point(140)]
        .map(p=>[p.longitude,p.latitude]),roadApproaches:[[-4,-8,-12,-16,-20],[144,148,152,156,160]]
        .map(path=>path.map(along=>{const p=point(along);return [p.longitude,p.latitude];}))};
    if(bridge){
        source.roadApproachKinds=['bridge','road'];
        viewer.scene.sampleHeightSupported=true;
        viewer.scene.sampleHeight=()=>500;
    }
    const service=T.create(C,viewer,()=>{},{sampleTerrain:async points=>points.map(terrain),
        now:()=>clock,isSimulating:()=>simulating});
    service.setAutomaticEnabled(true);
    const result=await service.setAutomaticRoutes([source],point(0));
    assert.equal(result.count,1,JSON.stringify(service.diagnostics()));
    return {viewer,service,terrain,preUpdate,advance(p){
        simulating=true;clock+=1000;viewer.camera.positionCartographic={longitude:p.longitude*Math.PI/180,
            latitude:p.latitude*Math.PI/180,height:p.height};preUpdate.fire();
    }};
}

test('automatic entry floor and segment exemption track only the active 8–24 m portal aperture',async()=>{
    const f=await setup();
    try{
        assert.ok(Math.abs(f.service.floorAt(point(-7))-499.9)<1e-8);
        assert.equal(f.service.floorAt(point(-9)),null);
        assert.equal(f.service.segmentInside(point(-7),point(2)),true,'crossing the source endpoint stays traversable');
        assert.equal(f.service.intersects(point(-7),point(2)),false,'the lining has no entrance cap');
        f.advance(point(-20));
        const active=f.service.apertureSpecs().find(s=>s.forward.north>.9);
        assert.ok(active.before>=22.9&&active.before<=24);
        assert.ok(Math.abs(f.service.floorAt(point(-20))-499.9)<1e-8);
        assert.equal(f.service.segmentInside(point(-20),point(-19.5)),true);
        assert.equal(f.service.floorAt(point(-24.1)),null);
        assert.equal(f.service.floorAt(point(-4,2.9)),null);
        assert.equal(f.service.floorAt(point(-4,0,550)),null);
        assert.equal(f.service.segmentInside(point(-4,0,550),point(1,0,550)),false);
        assert.equal(f.service.intersects(point(-2,2.9),point(2,2.9)),true,'geometric lining still stops wall contact');
        const material=f.viewer.scene.globe.material;
        f.viewer.scene.globe.material={externalOwner:true};
        assert.equal(f.service.floorAt(point(-4)),null,'an inactive aperture does not exempt terrain');
        assert.equal(f.service.segmentInside(point(-4),point(1)),false);
        f.viewer.scene.globe.material=material;
    }finally{f.service.dispose();}
});

test('the simulator advances every half-metre height probe from a raised cliff approach through an open source portal',async()=>{
    const f=await setup();
    const probePoints=[];
    const sim=F.createSimulator({sampleHeight:async()=>500,
        renderedHeight:p=>{probePoints.push(p);return f.service.floorAt(p)??550;},
        modeledCollision:(a,b)=>f.service.intersects(a,b)?'tunnel':false,
        terrainCollision:()=>false,captureCamera:()=>({heading:0}),restoreCamera(){},applyPose(){},
        applyGraphics(){},isTerrainReady:()=>true,onState(){}});
    try{
        await sim.start({...point(-7),flightMode:'gps',agl:2,maxSpeed:6},new AbortController().signal);
        sim.stick(1,0);
        for(let i=0;i<240;i++)sim.tick(1/60);
        const state=sim.status(),along=(state.position.latitude-latitude)*scale;
        assert.ok(along>5,JSON.stringify(state));
        assert.ok(Math.abs(state.height-502)<1e-8,'approach terrain cannot snap the drone onto the hill');
        assert.equal(state.reason,null);
        assert.ok(probePoints.some(p=>p.latitude<latitude)&&probePoints.some(p=>p.latitude>latitude),
            'height probes cross both sides of the actual source endpoint');
    }finally{sim.stop();f.service.dispose();}
});

test('a measured flat bridge approach does not inherit the falling internal bore grade',()=>{
    const falling={...model,sections:[section(0),section(20,498)]},
        bore=T.boundedClipSpec(falling,0,{before:23}),spec={...bore,approachGrade:0};
    assert.ok(Math.abs(bore.grade+.1)<1e-8);
    assert.equal(T.portalApproachFloor(falling,point(-20,0,500.5),0,bore,.25,true),null,
        'extrapolating the internal fall backward invents a 2 m step above the flat bridge');
    assert.equal(T.portalApproachFloor(falling,point(-20,0,500.5),0,spec),500,
        'the actual connected approach remains at 500 m');
    assert.equal(T.portalApproachFloor(falling,point(-20,0,498.5),0,spec,.25,true),null,
        'correcting the grade does not permit a body 1.5 m below the physical bridge floor');
});

test('near-floor contact retains the same local floor across the lip without granting floor penetration',async()=>{
    const f=await setup();
    try{
        for(const along of [-.1,0,.1]){
            assert.ok(Math.abs(f.service.floorAt(point(along,0,499.8))-499.9)<1e-8,
                `light floor contact ${along} m from the lip cannot fall back to mountain terrain`);
            assert.equal(f.service.floorAt(point(along,0,499.5)),null,'more than 0.25 m below the floor remains invalid');
        }
        assert.equal(f.service.segmentInside(point(-.1,0,499.8),point(.1,0,499.8)),false,
            'floor contact is a height probe, not body containment');
        assert.equal(f.service.intersects(point(.1,0,500.5),point(.1,0,499.8)),true,
            'the actual floor triangles still stop a downward sweep');
    }finally{f.service.dispose();}
});

test('a pilot at bridge plus 0.5 m enters a falling bore without a false raised approach floor',async()=>{
    const f=await setup({bridge:true,farFloor:486});
    f.advance(point(-20,0,500.5));
    const sourceSpec=f.service.apertureSpecs().find(spec=>spec.forward.north>.9);
    assert.ok(sourceSpec.grade<-.09,'the interior bore really falls by 2 m over its first 20 m');
    assert.ok(Math.abs(sourceSpec.approachGrade)<1e-8,'the sampled bridge approach remains level');
    const sim=F.createSimulator({sampleHeight:async()=>500,
        renderedHeight:p=>f.service.floorAt(p)??550,
        modeledCollision:(a,b)=>f.service.intersects(a,b)?'tunnel':false,
        terrainCollision:()=>false,captureCamera:()=>({heading:0}),restoreCamera(){},applyPose(){},
        applyGraphics(){},isTerrainReady:()=>true,onState(){}});
    try{
        assert.ok(Math.abs(f.service.floorAt(point(-20,0,500.5))-499.9)<1e-8);
        await sim.start({...point(-7),flightMode:'gps',agl:1,maxSpeed:6},new AbortController().signal);
        sim.enterTunnel({...point(-7,0,500.5),heading:0,ground:500});
        sim.stick(1,0);
        for(let i=0;i<240;i++)sim.tick(1/60);
        const state=sim.status(),along=(state.position.latitude-latitude)*scale;
        assert.ok(along>5,JSON.stringify(state));
        assert.ok(Math.abs(state.height-500.5)<1e-8,'the invented internal-grade ramp cannot lift the pilot above the bridge');
        assert.equal(state.reason,null);
    }finally{sim.stop();f.service.dispose();}
});
