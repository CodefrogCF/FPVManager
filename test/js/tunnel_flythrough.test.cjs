'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
const F=require('../../web/free_flight.js');
const ActualCesium=require('../../web/cesium/index.cjs');
for(const name of ['HTMLCanvasElement','HTMLImageElement','ImageBitmap','OffscreenCanvas','HTMLVideoElement'])
    globalThis[name]??=class {};
const source={id:'road:101:0',source:'ch.swisstopo.swisstlm3d-strassen',sourceId:'101',
    coordinates:[[8.2,46.8],[8.20007,46.8],[8.20014,46.8],[8.20021,46.8]]};
const model=()=>T.procedural(source,[510,510,511,511],{widthMeters:6,heightMeters:5});
const point=(s,dx=0,z=s.floorMetersWgs84+2.5)=>({longitude:s.longitude,
    latitude:s.latitude+dx/111320,height:z});
function fake(){
    const added=[],removed=[],events=[];
    class Geometry{constructor(options){Object.assign(this,options);}}
    class GeometryAttribute{constructor(options){Object.assign(this,options);}}
    class Primitive{constructor(options){Object.assign(this,options);}}
    class Cartesian3 extends ActualCesium.Cartesian3 {
        static fromDegrees(lon,lat,h=0){return new Cartesian3(lon*1000,lat*1000,h);}
    }
    const C={
        Cartesian3,Cartesian4:ActualCesium.Cartesian4,EncodedCartesian3:ActualCesium.EncodedCartesian3,
        Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},
        Transforms:ActualCesium.Transforms,ClippingPlane:ActualCesium.ClippingPlane,
        ClippingPlaneCollection:ActualCesium.ClippingPlaneCollection,Material:ActualCesium.Material,
        Geometry,GeometryAttribute,Primitive,
        GeometryInstance:class{constructor(options){Object.assign(this,options)}},
        ComponentDatatype:{DOUBLE:1},PrimitiveType:{TRIANGLES:4},
        BoundingSphere:{fromVertices:values=>({count:values.length})},
        Color:{fromBytes:(...c)=>c},
        ColorGeometryInstanceAttribute:{fromColor:color=>color},
        PerInstanceColorAppearance:class{constructor(options){Object.assign(this,options)}},
        ClippingPolygon:class{constructor(options){Object.assign(this,options)}},
        ClippingPolygonCollection:class{constructor(options){this.polygons=options.polygons;this.length=this.polygons.length}},
    };
    C.ClippingPolygonCollection.isSupported=()=>true;
    const old={length:0};const globe={clippingPolygons:old};
    const viewer={scene:{globe,primitives:{add:p=>{added.push(p);return p;},remove:p=>{removed.push(p);const i=added.indexOf(p);if(i>=0)added.splice(i,1);}},requestRender(){}}};
    const service=T.create(C,viewer,(type,data)=>events.push({type,...data}),
        {ready:()=>true,sampleTerrain:async()=>[510,510,511,511]});
    return {C,viewer,old,added,removed,events,service};
}
test('synthetic tunnel has bounded sections, no surveyed clearance and portal elevation is synthetic',()=>{
    const m=model();assert.equal(m.quality,'simulation-only');assert.equal(m.portalsVerified,false);
    assert.equal(m.clearanceVerified,false);assert.equal(m.elevationReference,'WGS84_ELLIPSOID');
    assert.equal(m.sections[0].floorMetersWgs84,509.9);
    assert.ok(m.sections[1].floorMetersWgs84>=m.sections[0].floorMetersWgs84);
    assert.equal(T.rings(m).length,4);
    assert.equal(T.rings(m)[1].length,4);
    assert.ok(m.label.includes('SIMULATION ONLY'));
});
test('invalid or unbounded geometry and missing or inconsistent terrain never become a tunnel',()=>{
    assert.throws(()=>T.procedural({...source,coordinates:[[11,46],[8,46]]},[500,500]),/Invalid/);
    assert.throws(()=>T.procedural(source,[500,500]),/Unsupported/);
    assert.throws(()=>T.procedural(source,[500,NaN,510,510]),/Terrain data missing/);
    assert.throws(()=>T.procedural(source,[500,500,500,500],{widthMeters:100}),/dimensions/);
    assert.throws(()=>T.validateSections([{longitude:8,latitude:47,floorMetersWgs84:500,widthMeters:6,heightMeters:4}]),/2–96/);
    assert.throws(()=>T.validateSections([{longitude:8,latitude:47,floorMetersWgs84:500,widthMeters:6,heightMeters:4},
        {longitude:8,latitude:47,floorMetersWgs84:500,widthMeters:6,heightMeters:4}]),/segment/);
});
test('import requires explicit WGS84 height reference and retains unverified provenance',()=>{
    const m=model();
    assert.throws(()=>T.importSections({version:1,source:'Local source',sections:m.sections}),/WGS84/);
    const imported=T.importSections({version:1,source:'User supplied CAD export',identity:'t2',
        elevationReference:'WGS84_ELLIPSOID',sections:m.sections});
    assert.equal(imported.quality,'external-unverified');
    assert.equal(imported.clearanceVerified,false);
    assert.match(imported.label,/NOT VERIFIED/);
});
test('interior, floor, ceiling and side walls participate in simulated collisions',()=>{
    const m=model(),s=m.sections[1];const a=point(s);
    assert.equal(T.inside(m,a),true);
    assert.equal(T.inside(m,point(s,0,s.floorMetersWgs84-.1)),false);
    assert.equal(T.collision(m,a,point(s,0,s.floorMetersWgs84+5.2)),true,'ceiling');
    assert.equal(T.collision(m,a,point(s,3.8)),true,'wall');
    assert.equal(T.collision(m,a,point(s,0,s.floorMetersWgs84-.2)),true,'floor');
    assert.equal(T.collision(m,a,point(m.sections[2])),false,'valid travel');
});
test('triangulated geometry includes all four interior-visible surfaces',()=>{
    const f=fake(),m=model();const g=T.geometry(f.C,m);
    assert.equal(g.indices.length,4*3*6);
    assert.ok(g.attributes.position.values instanceof Float64Array);
    assert.ok(g.indices instanceof Uint16Array);
});
test('activate and stop restore existing terrain clipping and release the model',async()=>{
    const f=fake();const result=await f.service.prepare(source,{widthMeters:6,heightMeters:5});
    assert.equal(result.quality,'simulation-only');
    assert.equal(f.added.length,1);
    assert.ok(f.viewer.scene.globe.material,'slope-aware aperture installed');
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
    assert.equal(f.service.status().ready,true);
    const spawn=f.service.firstPose();assert.ok(spawn.height>spawn.ground);
    f.service.activate();
    assert.equal(f.service.flight,true);
    assert.equal(f.service.floorAt(spawn),spawn.ground);
    f.service.stop();assert.equal(f.service.status().ready,false);
    assert.equal(f.added.length,0);assert.equal(f.removed.length,1);
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
    assert.equal(f.viewer.scene.globe.material,undefined);
    assert.equal(f.service.floorAt(spawn),null);
    f.service.dispose();
});
test('terrain clipping unsupported or already owned by another layer fails closed',async()=>{
    const f=fake();f.viewer.scene.context={webgl2:false};
    await assert.rejects(f.service.prepare(source),/not supported/);
    assert.equal(f.added.length,0);assert.equal(f.service.status().ready,false);
    const q=fake();q.viewer.scene.globe.clippingPolygons={length:1};
    await assert.rejects(q.service.prepare(source),/owns the globe/);
});
test('disposed and superseded terrain requests do not create late geometry',async()=>{
    const f=fake();let finish;
    const delayed=T.create(f.C,f.viewer,()=>{}, {sampleTerrain:()=>new Promise(resolve=>{finish=resolve;})});
    const request=delayed.prepare(source);await new Promise(r=>setImmediate(r));
    delayed.dispose();finish([510,510,510,510]);
    await assert.rejects(request,/superseded/);
    assert.equal(f.added.length,0);
});
test('native simulator can enter a synthetic tunnel without taking over user input',async()=>{
    const f=fake();await f.service.prepare(source);const spawn=f.service.firstPose();
    let captured=0,restored=0;const sim=F.createSimulator({
        sampleHeight:async()=>510,renderedHeight:p=>f.service.floorAt(p)??510,
        terrainCollision:(a,b)=>f.service.intersects(a,b),captureCamera:()=>{captured++;return {heading:0}},
        restoreCamera:()=>{restored++},applyPose:()=>{},isTerrainReady:()=>true,onState:()=>{},
    });
    await sim.start({latitude:spawn.latitude,longitude:spawn.longitude,flightMode:'acro'},new AbortController().signal);
    f.service.activate();sim.enterTunnel(spawn);
    assert.equal(sim.status().active,true);
    assert.equal(sim.status().mode,'acro');
    assert.equal(sim.status().height,spawn.height);
    assert.equal(sim.status().agl,spawn.height-spawn.ground);
    assert.equal(sim.status().playback,false);
    sim.stop();f.service.stop();assert.equal(restored,1);assert.equal(captured,1);
});
test('changing cross-section height and width along a bend retains smooth collision profile',()=>{
    const m=model(),s=m.sections.map((value,i)=>({...value,
        latitude:value.latitude+(i>1?(i-1)*.00002:0),
        widthMeters:5+i,heightMeters:4+i*.3}));
    const adjusted=T.importSections({version:1,source:'Imported testing model',
        elevationReference:'WGS84_ELLIPSOID',sections:s});
    const a={longitude:(s[1].longitude+s[2].longitude)/2,
        latitude:(s[1].latitude+s[2].latitude)/2,
        height:(s[1].floorMetersWgs84+s[2].floorMetersWgs84)/2+2.4};
    const p=T.closest(adjusted,a);
    assert.ok(p.width>5&&p.width<9);
    assert.ok(p.height>4&&p.height<6);
    assert.equal(T.inside(adjusted,a),true);
    assert.equal(T.collision(adjusted,a,{...a,height:p.floor+p.height+1}),true);
});
test('renderer recreation does not keep the original terrain clipped or duplicate geometry',async()=>{
    const f=fake(),first=f.service;
    await first.prepare(source);assert.equal(f.added.length,1);
    first.dispose();assert.equal(f.added.length,0);
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
    const second=T.create(f.C,f.viewer,()=>{}, {sampleTerrain:async()=>[510,510,511,511]});
    await second.prepare(source);
    assert.equal(f.added.length,1);
    second.dispose();
    assert.equal(f.added.length,0);
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
});
test('simulated tunnel impact uses its own contact reason, not a terrain measurement claim',async()=>{
    const sim=F.createSimulator({sampleHeight:async()=>510,renderedHeight:()=>510,
        terrainCollision:()=>false,modeledCollision:()=>true,
        captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},
        isTerrainReady:()=>true,onState:()=>{}});
    await sim.start({latitude:46.8,longitude:8.2,flightMode:'gps'},new AbortController().signal);
    sim.key('w',true);sim.tick(.1);
    assert.match(sim.status().reason,/Simulated tunnel surface contact/);
    assert.equal(sim.status().active,true);
    sim.stop();
});

test('swept sphere contacts the actual wall from outside, not only on leaving the interior',()=>{
    const m=model(),s=m.sections[1],outside=point(s,4.4),inside=point(s);
    assert.equal(T.inside(m,outside),false);
    assert.equal(T.collision(m,outside,inside),true,'outside-to-inside wall crossing');
    assert.equal(T.collision(m,inside,outside),true,'inside-to-outside wall crossing');
    assert.equal(T.collision(m,point(s,4.4),point(m.sections[2],4.4)),false,
        'parallel travel outside model is not a collision');
});

test('open portal is freely passable on centerline, but sidewall at portal remains solid',()=>{
    const m=T.importSections({version:1,elevationReference:'WGS84_ELLIPSOID',
        source:'Fixture cross sections',sections:[
            {longitude:8.2,latitude:46.8,floorMetersWgs84:500,widthMeters:6,heightMeters:5},
            {longitude:8.2001,latitude:46.8,floorMetersWgs84:500,widthMeters:6,heightMeters:5},
            {longitude:8.2002,latitude:46.8,floorMetersWgs84:500,widthMeters:6,heightMeters:5},
        ]});
    const entry={longitude:8.19995,latitude:46.8,height:502.5};
    const inner={longitude:8.20004,latitude:46.8,height:502.5};
    assert.equal(T.collision(m,entry,inner),false,'open portal along tunnel axis');
    assert.equal(T.collision(m,inner,entry),false,'open portal exit');
    assert.equal(T.collision(m,{...entry,latitude:46.800055},inner),true,
        'crossing the model wall near the portal edge');
});

test('continuous sweep catches roof, floor and wall even when both endpoints are outside',()=>{
    const m=model(),s=m.sections[1],floor=s.floorMetersWgs84;
    assert.equal(T.collision(m,point(s,0,floor+8),point(s,0,floor-4)),true,'roof and floor');
    assert.equal(T.collision(m,point(s,-7),point(s,7)),true,'both side walls');
    assert.equal(T.collision(m,point(s,0,floor+8),point(m.sections[2],0,floor+8)),false,
        'outside, above the roof');
});

test('vaulted mesh generates tessellated roof with exact shared collision geometry',()=>{
    const base=model();
    const vaulted=T.importSections({version:1,elevationReference:'WGS84_ELLIPSOID',
        profile:'vaulted',source:'Synthetic test profile',sections:base.sections});
    assert.equal(vaulted.profile,'vaulted');
    const ring=T.rings(vaulted);
    assert.ok(ring[0].length>4);
    assert.equal(ring[0].length,ring[1].length);
    const f=fake(),rendered=T.geometry(f.C,vaulted),physical=T.collisionMesh(vaulted);
    assert.equal(rendered.indices.length/3,physical.triangleCount);
    assert.equal(rendered.indices.length/3,(vaulted.sections.length-1)*ring[0].length*2);
    const s=vaulted.sections[1],top=s.floorMetersWgs84+s.heightMeters;
    assert.equal(T.collision(vaulted,point(s,0,top-1.5),point(s,0,top+.2)),true,
        'arched ceiling contact, not only rectangular AABB');
    assert.equal(T.collision(vaulted,point(s,2.6,top-0.2),point(s,2.6,top-.2)),false,
        'air outside curved roof is not a collision');
    assert.equal(T.inside(vaulted,point(s,2.6,top-.2)),false,'vaulted headroom is narrower');
    assert.throws(()=>T.importSections({version:1,elevationReference:'WGS84_ELLIPSOID',
        profile:'unsafe',source:'Fixture',sections:base.sections}),/profile/);
});

test('scene collision option applies to prepared tunnel meshes outside explicit tunnel flight',async()=>{
    const f=fake();await f.service.prepare(source,{profile:'vaulted'});
    const s=f.service.model.sections[1],a=point(s),b=point(s,4);
    assert.equal(f.service.intersects(a,b),false,'opt-in disabled by default');
    f.service.setCollisionEnabled(true);
    assert.equal(f.service.intersects(a,b),true);
    assert.equal(f.service.intersects(a,{longitude:NaN,latitude:0,height:0}),false); // invalid endpoint is noncolliding
    f.service.setCollisionEnabled(false);
    assert.equal(f.service.intersects(a,b),false);
    f.service.activate();assert.equal(f.service.intersects(a,b),true,'tunnel flight always collides');
    f.service.stop();assert.equal(f.service.intersects(a,b),false);
});

test('long replay jumps fail closed near a loaded tunnel but not across distant empty areas',()=>{
    const m=model(),s=m.sections[1];
    assert.equal(T.collision(m,
        {longitude:8.0,latitude:46.8,height:510},
        {longitude:8.001,latitude:46.8,height:510}),false,
        'distant teleport is not incorrectly treated as a tunnel impact');
    assert.equal(T.collision(m,
        {longitude:8.198,latitude:46.8,height:s.floorMetersWgs84+2},
        {longitude:8.202,latitude:46.8,height:s.floorMetersWgs84+2}),true,
        'teleport crossing tunnel geometry is stopped');
});

test('prepared tunnel keeps horizontal terrain intact during preview and simulated flight',async()=>{
    const f=fake();await f.service.prepare(source,{profile:'vaulted'});
    assert.ok(f.viewer.scene.globe.material,'slope-aware portal aperture');
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
    f.service.activate();
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old,'no full-height corridor excavation');
    f.service.stop();assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
});

test('automatic official tunnel axes create bounded simulated 3D mesh, terrain cut and wall collision without JSON',async()=>{
    const f=fake();
    f.service.setAutomaticEnabled(true);
    const route={...source,kind:'tunnel'};
    const response=await f.service.setAutomaticRoutes([route],{longitude:8.2001,latitude:46.8});
    assert.equal(response.count,1);
    assert.equal(f.added.length,1);
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,0,'flat covered roads must not excavate unnecessary portals');
    assert.equal(f.service.status().ready,false,'auto scene must not silently start manual flight');
    assert.equal(f.service.status().autoCount,1);
    const m=model(),s=m.sections[1];
    assert.ok(Number.isFinite(f.service.floorAt(point(s))), 'automatic floor overrides terrain only inside a model');
    assert.equal(f.service.floorAt({...point(s),height:s.floorMetersWgs84+30}),null);
    // Auto-tunnel collision follows the tunnel opt-in independently of general building collision.
    assert.equal(f.service.status().collisionEnabled,false);
    assert.equal(f.service.intersects(point(s),point(s,4)),true,'automatic side wall contacts');
    assert.equal(f.service.intersects(point(s),point(m.sections[2])),false,'open interior remains flyable');
    await f.service.setAutomaticRoutes([route],{longitude:8.2001,latitude:46.8});
    assert.equal(f.added.length,1,'subsequent query replaces primitives rather than leaking them');
    f.service.setAutomaticEnabled(false);
    assert.equal(f.added.length,0);
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
    f.service.dispose();
});

test('auto pipeline discards stale terrain requests on disable',async()=>{
    const f=fake();let finish;
    const delayed=T.create(f.C,f.viewer,()=>{}, {ready:()=>true,
        sampleTerrain:()=>new Promise(resolve=>{finish=resolve;})});
    delayed.setAutomaticEnabled(true);
    const requested=delayed.setAutomaticRoutes([{...source,kind:'tunnel'}],{longitude:8.2,latitude:46.8});
    await new Promise(r=>setImmediate(r));
    delayed.setAutomaticEnabled(false);
    finish([510,510,511,511]);
    await requested;
    assert.equal(delayed.status().autoCount,0);
    assert.equal(f.added.length,0);
    delayed.dispose();
});

test('automatic tunnel budget selects 56 normally and 96 in quality; clipping stays bounded to eight',async()=>{
    const f=fake();
    const service=T.create(f.C,f.viewer,()=>{}, {ready:()=>true,
        sampleTerrain:async points=>points.map(()=>510)});
    service.setAutomaticEnabled(true);
    const routes=Array.from({length:110},(_,i)=>({...source,kind:'tunnel',id:`osm:dynamic:${i}`,
        coordinates:[[8.2+i*.00003,46.8],[8.20007+i*.00003,46.8]]}));
    const first=await service.setAutomaticRoutes(routes,{longitude:8.2,latitude:46.8});
    assert.equal(first.count,56);
    assert.equal(service.status().autoCount,56);
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,0,'flat-road previews need no terrain holes');
    assert.equal(f.added.length,56);
    service.setPerformanceProfile('quality');
    // setPerformanceProfile schedules the rebuild on an async terrain path.
    for(let i=0;i<200&&service.status().autoCount<96;i++)await new Promise(r=>setTimeout(r,4));
    assert.equal(service.status().autoCount,96);
    assert.equal(f.added.length,96,'reused meshes are not duplicated');
    service.dispose();assert.equal(f.added.length,0);
});

test('invalid first ranked route cannot starve valid nearby tunnel and reports a reason',async()=>{
    const f=fake();f.C.ClippingPolygonCollection.isSupported=()=>false;
    const events=[];
    const service=T.create(f.C,f.viewer,(type,data)=>events.push({type,data}), {
        sampleTerrain:async points=>points.map(p=>p.longitude<8.2?NaN:510),ready:()=>false,
    });
    service.setAutomaticEnabled(true);
    const broken={...source,id:'missing-terrain',kind:'tunnel',
        coordinates:[[8.199,46.8],[8.1991,46.8]]};
    const good={...source,id:'valid',kind:'tunnel'};
    const result=await service.setAutomaticRoutes([broken,good],{longitude:8.199,latitude:46.8});
    assert.equal(result.count,1);
    assert.equal(result.skipped,1);
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,0,
        'clipping remains untouched if WebGL support is missing');
    const status=events.filter(e=>e.type==='tunnel-auto-mesh-status').at(-1).data;
    assert.match(status.error,/No usable terrain/);
    assert.equal(status.count,1);
    service.dispose();
});

test('scene-resident axis terrain is reused but road probes request a consistent detailed profile',async()=>{
    const f=fake();let requests=0;
    f.C.Cartographic={fromDegrees:(longitude,latitude)=>({longitude,latitude})};
    f.viewer.scene.globe.getHeight=()=>510;
    const service=T.create(f.C,f.viewer,()=>{}, {sampleTerrain:async()=>{requests++;throw Error('Unexpected network');}});
    service.setAutomaticEnabled(true);
    const r={...source,kind:'tunnel'};
    await service.setAutomaticRoutes([r],{longitude:8.2,latitude:46.8});
    const first=f.added[0];
    await service.setAutomaticRoutes([r],{longitude:8.2,latitude:46.8});
    assert.equal(requests,1,'road approach LOD is refreshed once, then resident mesh is reused');
    assert.equal(f.added[0],first);
    assert.equal(f.added.length,1);
    service.setAutomaticEnabled(false);
    assert.equal(f.added.length,0);
    service.dispose();
});

test('failed terrain sampling does not leave the 3D tunnel status silently at zero',async()=>{
    const f=fake(),events=[];
    const service=T.create(f.C,f.viewer,(type,data)=>events.push({type,data}), {
        sampleTerrain:async()=>{throw Error('terrain source temporarily unavailable');}
    });
    service.setAutomaticEnabled(true);
    const result=await service.setAutomaticRoutes([{...source,kind:'tunnel'}]);
    assert.equal(result.count,0);
    const status=events.filter(e=>e.type==='tunnel-auto-mesh-status').at(-1).data;
    assert.equal(status.skipped,1);
    assert.match(status.error,/terrain/i);
    service.dispose();
});

test('portal guides are optional rendering only and are disposed together with mesh',async()=>{
    const f=fake();
    f.C.Material={fromType:(_type,config)=>config};
    f.C.PolylineCollection=class{constructor(){this.lines=[];}add(line){this.lines.push(line);}};
    f.service.setAutomaticEnabled(true);
    await f.service.setAutomaticRoutes([{...source,kind:'tunnel'}]);
    assert.equal(f.added.length,2,'one tunnel primitive, one shared portal collection');
    const portal=f.added.find(p=>p.lines);
    assert.equal(portal.lines.length,2,'open ends shown, never capped by geometry');
    f.service.dispose();
    assert.equal(f.added.length,0);
});

test('schematic route stays underground through a mountain instead of following the hilltop',()=>{
    const route={...source,kind:'tunnel'};
    const m=T.procedural(route,[1000,1140,1160,1000],{widthMeters:6,heightMeters:5,profile:'vaulted'});
    assert.ok(Math.abs(m.sections[0].floorMetersWgs84-999.9)<.001);
    assert.ok(Math.abs(m.sections.at(-1).floorMetersWgs84-999.9)<.001);
    assert.ok(m.sections[1].floorMetersWgs84<1010,'tube must not climb to the intermediate terrain surface');
    assert.ok(m.sections[2].floorMetersWgs84<1010,'no floating tunnel across the hillside');
    const mid=point(m.sections[1]);
    assert.ok(T.inside(m,mid));
    assert.equal(T.collision(m,mid,point(m.sections[2])),false,'open interior remains unobstructed');
});

test('auto preview clips only portals, flight clips one nearby corridor and returns to preview',async()=>{
    const f=fake();f.service.dispose();
    let flying=false,clock=1000,frame=null;
    f.viewer.camera={positionCartographic:null};
    f.viewer.scene.preUpdate={addEventListener(fn){frame=fn;return ()=>{frame=null;}}};
    const service=T.create(f.C,f.viewer,()=>{}, {isSimulating:()=>flying,now:()=>clock,
        sampleTerrain:async points=>points.map(()=>1100)});
    service.setAutomaticEnabled(true);
    assert.equal((await service.setAutomaticRoutes([{...source,kind:'tunnel'}],
        {longitude:8.2001,latitude:46.8})).count,1);
    const preview=f.viewer.scene.globe.clippingPolygons;
    assert.equal(preview.length,0,'no terrain cut around flat road at rest');
    const p=source.coordinates[1],m=T.procedural(source,[1100,1100,1100,1100],{profile:'vaulted'});
    f.viewer.camera.positionCartographic={longitude:p[0]*Math.PI/180,latitude:p[1]*Math.PI/180,
        height:m.sections[1].floorMetersWgs84+2};
    flying=true;clock+=500;frame();
    const flight=f.viewer.scene.globe.material;
    assert.ok(flight,'only the relevant tunnel receives a slope-aware aperture');
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,0);
    flying=false;clock+=500;frame();
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,0,'returns to no clipping after flight');
    service.dispose();
    assert.equal(frame,null,'preUpdate listener is released');
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
});

test('FPV flight receives altitude-aware tunnel floor probes and does not collide with the terrain above it',async()=>{
    const f=fake(); f.service.setAutomaticEnabled(true);
    const r={...source,kind:'tunnel'};
    const svc=T.create(f.C,f.viewer,()=>{}, {
        sampleTerrain:async points=>points.map((_,i)=>[1000,1200,1200,1000][i])});
    svc.setAutomaticEnabled(true);
    await svc.setAutomaticRoutes([r],{longitude:8.2001,latitude:46.8});
    const model=T.procedural(r,[1000,1200,1200,1000],{widthMeters:6,heightMeters:5,profile:'vaulted'});
    const sample=[];
    const sim=F.createSimulator({sampleHeight:async()=>1000,
        renderedHeight:p=>{sample.push(p);return svc.floorAt(p)??1200;},
        modeledCollision:(a,b)=>svc.intersects(a,b),
        terrainCollision:(a,b)=>!(svc.floorAt(a)!=null||svc.floorAt(b)!=null),
        captureCamera:()=>({heading:Math.PI/2}),restoreCamera:()=>{},applyPose:()=>{},
        isTerrainReady:()=>true,onState:()=>{}});
    await sim.start({latitude:r.coordinates[0][1],longitude:r.coordinates[0][0],agl:2,flightMode:'gps'},
        new AbortController().signal);
    sim.key('w',true);
    for(let i=0;i<15;i++)sim.tick(.1);
    assert.ok(sample.length>0);
    assert.ok(sample.every(p=>Number.isFinite(p.height)),'every terrain probe carries the current flight elevation');
    assert.ok(sim.status().position.longitude>r.coordinates[0][0], 'flight advances toward tunnel interior');
    assert.equal(sim.status().reason,null,'mountain surface must not block valid tunnel passage');
    const a=point(model.sections[1]);
    assert.equal(svc.segmentInside(a,point(model.sections[2])),true);
    assert.equal(svc.segmentInside(a,point(model.sections[2],5)),false,'outside must not disable normal collision checks');
    sim.stop();svc.dispose();f.service.dispose();
});

test('steep terrain keeps both portal floor elevations anchored and smooths interior',()=>{
    const r={...source,kind:'tunnel'};
    const ground=[1250,1251,1420,1250];
    const m=T.procedural(r,ground,{widthMeters:6,heightMeters:5,profile:'vaulted'});
    assert.ok(Math.abs(m.sections[0].floorMetersWgs84-1249.9)<1e-5);
    assert.ok(Math.abs(m.sections.at(-1).floorMetersWgs84-1249.9)<1e-5);
    assert.ok(m.sections.every(s=>Number.isFinite(s.floorMetersWgs84)));
    assert.equal(T.inside(m,point(m.sections[1])),true);
});

test('procedural road has distinct floor walls roof and visual-only orientation markings',()=>{
    const f=fake(),m=T.procedural({...source,kind:'tunnel'},[510,515,516,510],{profile:'vaulted'});
    const layers=T.surfaceGeometries(f.C,m);
    assert.deepEqual(layers.map(l=>l.kind),['road','walls','ceiling','marking','wall-band']);
    assert.equal(new Set(layers.map(l=>l.color.join(','))).size,5);
    assert.ok(layers.every(l=>l.geometry.indices.length>0));
    assert.equal(T.collisionMesh(m).triangleCount,T.geometry(f.C,m).indices.length/3,
        'decoration must not introduce new collision surfaces');
});

test('automatic tunnel portal footprints stay short and floor materials are batched',async()=>{
    const f=fake();f.service.setAutomaticEnabled(true);
    await f.service.setAutomaticRoutes([{...source,kind:'tunnel'}],{longitude:8.2001,latitude:46.8});
    const primitive=f.added.find(p=>p.geometryInstances);
    assert.ok(primitive);
    assert.equal(primitive.geometryInstances.length,7,'five material groups plus two hollow portal surrounds');
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,0,
        'non-buried preview must not cut roads or fields');
    f.service.dispose();
});


test('implausible gorge crossings do not become floating tunnel meshes',()=>{
    assert.throws(()=>T.procedural({...source,kind:'tunnel'},[1250,900,1420,1250],
        {profile:'vaulted'}),/terrain depression/i);
});

test('two close parallel OSM carriageways become one wider synthetic passage',async()=>{
    const a={id:'osm:101:0',name:'Bodenstrasse',kind:'underpass',transport:'road',
        source:'OpenStreetMap',sourceId:'way/101',coordinates:[[8.2,46.8],[8.201,46.8]]};
    const b={...a,id:'osm:102:0',sourceId:'way/102',
        coordinates:[[8.201,46.800036],[8.2,46.800036]]};
    const grouped=T.mergeParallelRoutes([a,b].map(route=>({id:route.id,key:route.id,route})));
    assert.equal(grouped.merged,1);
    assert.equal(grouped.entries.length,1);
    const combined=grouped.entries[0].route;
    assert.ok(combined.widthMeters>9&&combined.widthMeters<12);
    assert.equal(combined.mergedRouteIds.length,2);
    assert.ok(combined.coordinates[0][1]>a.coordinates[0][1]&&
        combined.coordinates[0][1]<b.coordinates[0][1]);
    const f=fake();const service=T.create(f.C,f.viewer,()=>{}, {
        sampleTerrain:async points=>points.map(()=>500)});
    service.setAutomaticEnabled(true);
    const result=await service.setAutomaticRoutes([a,b],{longitude:8.2005,latitude:46.8});
    assert.equal(result.count,1,'both roadways share a single visible tunnel');
    assert.equal(result.merged,1);
    assert.equal(f.added.filter(entry=>entry.geometryInstances).length,1);
    service.dispose();
});

test('independent parallel bores, diverging lanes and crossings are never fused',()=>{
    const base={id:'a',name:'Road tunnel',kind:'tunnel',transport:'road',
        coordinates:[[8.2,46.8],[8.201,46.8]]};
    const pair=(b)=>T.mergeParallelRoutes([base,{...base,id:'b',...b}]
        .map(route=>({id:route.id,key:route.id,route})));
    assert.equal(pair({coordinates:[[8.2,46.80009],[8.201,46.80009]]}).merged,0,
        'separate bores more than 7.5 metres apart stay separate');
    assert.equal(pair({coordinates:[[8.2,46.80003],[8.201,46.80015]]}).merged,0,
        'diverging centerlines should not be blended');
    assert.equal(pair({coordinates:[[8.2005,46.7995],[8.2005,46.8005]]}).merged,0,
        'crossing tracks are not parallel carriageways');
    assert.equal(pair({name:'Other tunnel',coordinates:[[8.2,46.80003],[8.201,46.80003]]}).merged,0,
        'explicit different names do not get combined');
});

test('portal floors anchor to nearby approach heights rather than cliff-edge samples',()=>{
    const r={...source,kind:'underpass'};
    const m=T.procedural(r,[500,504,504,500],{profile:'vaulted',
        portalApproachHeights:[502,502.4,501.3,501.6]});
    assert.ok(Math.abs(m.sections[0].floorMetersWgs84-502.02)<.05);
    assert.ok(Math.abs(m.sections.at(-1).floorMetersWgs84-501.29)<.05);
    assert.equal(m.portalClipMask[0],false,'a shallow underpass does not excavate its approach');
});

test('covered OSM passages render above ground without underground roof or portal clipping',async()=>{
    const r={id:'osm:covered:0',name:'Covered passage',source:'OpenStreetMap',
        sourceId:'way/121',kind:'underpass',transport:'road',
        coordinates:[[8.2,46.8],[8.20016,46.8],[8.20032,46.8]]};
    const m=T.procedural(r,[500,500,500],{profile:'vaulted'});
    assert.equal(m.kind,'covered-way');
    assert.deepEqual(m.portalClipMask,[false,false]);
    assert.equal(m.sections.length,3);
    const f=fake(),svc=T.create(f.C,f.viewer,()=>{}, {
        sampleTerrain:async points=>points.map(()=>500)});
    svc.setAutomaticEnabled(true);
    assert.equal((await svc.setAutomaticRoutes([r],{longitude:8.20016,latitude:46.8})).count,1);
    assert.equal(svc.diagnostics().entries[0].kind,'covered-way');
    svc.dispose();
});

test('long flat tagged tunnel is rejected instead of floating above the terrain',()=>{
    const route={id:'flat',kind:'tunnel',transport:'road',coordinates:
        [[8.2,46.8],[8.20032,46.8],[8.20064,46.8],[8.20096,46.8]]};
    assert.throws(()=>T.procedural(route,[500,500,500,500],{heightMeters:5,profile:'vaulted'}),
        /roof cannot fit below terrain/i);
});

test('covered mountain tunnel has roof beneath ground and local portal clipping',()=>{
    const route={id:'mountain',kind:'tunnel',transport:'road',coordinates:
        [[8.2,46.8],[8.20032,46.8],[8.20064,46.8],[8.20096,46.8]]};
    const m=T.procedural(route,[500,515,515,500],{heightMeters:5,profile:'vaulted'});
    assert.deepEqual(m.portalClipMask,[true,true]);
    assert.ok(m.sections[1].floorMetersWgs84+5+.65 <= 515);
    assert.ok(m.sections[2].floorMetersWgs84+5+.65 <= 515);
    const f=fake();const svc=T.create(f.C,f.viewer,()=>{}, {
        sampleTerrain:async points=>points.map(p=>p.longitude>8.2002&&p.longitude<8.20076?515:500)});
    svc.setAutomaticEnabled(true);
    return svc.setAutomaticRoutes([route]).then(result=>{
        assert.equal(result.count,1);
        assert.equal(f.viewer.scene.globe.clippingPolygons.length,0,
            'portal clipping never creates unbounded terrain polygons');
        svc.dispose();
    });
});

test('cropped alpine tunnel uses remote original endpoint grade, not mountain-top crop ends',async()=>{
    const coordinates=Array.from({length:42},(_,i)=>[8.2+i*.0007,46.8]);
    const route={id:'long-alpine',name:'Alpine tunnel',kind:'tunnel',transport:'road',coordinates};
    const f=fake(),svc=T.create(f.C,f.viewer,()=>{}, {
        sampleTerrain:async points=>points.map(p=>(p.longitude<=8.201||p.longitude>=8.227)?1000:1450)});
    svc.setAutomaticEnabled(true);
    const result=await svc.setAutomaticRoutes([route],{longitude:8.214,latitude:46.8});
    assert.equal(result.count,1,'cropped mountain segment remains renderable');
    const inside={longitude:8.214,latitude:46.8,height:1002};
    assert.ok(svc.floorAt(inside)!==null,'floor follows the real endpoints beneath the mountain');
    assert.equal(svc.floorAt({...inside,height:1452}),null,
        'rendered terrain above the tube is not treated as a tunnel floor');
    assert.ok(f.viewer.scene.globe.clippingPolygons.length<=1,
        'an actual source-way endpoint may be clipped, but a cropped end may not');
    const guide=svc.diagnostics().entries[0];
    assert.ok(guide.portals.includes(false), 'a cropped boundary is never a real portal');
    assert.ok(guide.previewClips.every((clip,i)=>!clip||guide.portals[i]),
        'clipping is permitted only at genuine source-way endpoints');
    svc.dispose();
});

test('repeated matching viewport scans cannot cancel a pending tunnel terrain query',async()=>{
    const f=fake();let finish,calls=0;
    const svc=T.create(f.C,f.viewer,()=>{}, {sampleTerrain:points=>{
        calls++;return new Promise(resolve=>{finish=()=>resolve(points.map(()=>510));});
    }});
    svc.setAutomaticEnabled(true);
    const route={...source,kind:'tunnel'};
    const first=svc.setAutomaticRoutes([route],{longitude:8.2001,latitude:46.8});
    await new Promise(r=>setImmediate(r));
    const duplicate=await svc.setAutomaticRoutes([route],{longitude:8.2001,latitude:46.8});
    assert.equal(duplicate.pending,true,'identical request reuses in-flight work');
    assert.equal(calls,1,'no redundant terrain request');
    finish();
    assert.equal((await first).count,1);
    assert.equal(f.added.filter(p=>p.geometryInstances).length,1);
    svc.dispose();
});

test('small viewport movement and brief missing index tile retain the resident primitive',async()=>{
    const f=fake(),svc=T.create(f.C,f.viewer,()=>{}, {
        sampleTerrain:async points=>points.map(()=>510)});
    svc.setAutomaticEnabled(true);
    const r={...source,kind:'tunnel'};
    await svc.setAutomaticRoutes([r],{longitude:8.2001,latitude:46.8});
    const primitive=f.added[0];
    const moved={...r,coordinates:r.coordinates.map(p=>[p[0]+.00001,p[1]])};
    assert.equal((await svc.setAutomaticRoutes([moved],{longitude:8.20011,latitude:46.8})).count,1);
    assert.equal(f.added[0],primitive,'small viewport resampling keeps mesh and collision model');
    assert.equal((await svc.setAutomaticRoutes([],{longitude:8.20011,latitude:46.8})).count,1,
        'short empty tile scan should not make a nearby model blink');
    assert.equal(f.added[0],primitive);
    assert.equal((await svc.setAutomaticRoutes([],{longitude:8.24,latitude:46.8})).count,0,
        'out-of-range models must be released');
    svc.dispose();
});

test('slightly offset parallel OSM carriageways merge deterministically',()=>{
    const a={id:'osm:300:0',name:'A1',kind:'underpass',transport:'road',
        coordinates:[[8.2,46.8],[8.201,46.8]]};
    const b={...a,id:'osm:301:0',coordinates:[[8.20109,46.800036],[8.20009,46.800036]]};
    const build=routes=>T.mergeParallelRoutes(routes.map(route=>({id:route.id,key:route.id,route})));
    const ab=build([a,b]),ba=build([b,a]);
    assert.equal(ab.merged,1);
    assert.equal(ba.merged,1);
    assert.equal(ab.entries[0].id,ba.entries[0].id,'source discovery order does not change mesh identity');
    assert.ok(ab.entries[0].route.widthMeters>8);
});

test('bridge-to-cliff portals never preview-cut a vertical terrain column',()=>{
    const route={id:'bridge-cliff',kind:'tunnel',transport:'road',
        coordinates:[[8.2,46.8],[8.20032,46.8],[8.20064,46.8],[8.20096,46.8]],
        roadApproachKinds:['bridge','road'],bridgeDeckSampled:[true,false],
        roadApproaches:[[[8.19995,46.8],[8.19990,46.8],[8.19985,46.8],
            [8.1998,46.8],[8.19975,46.8]],null]};
    const model=T.procedural(route,[500,515,515,500],{
        profile:'vaulted',portalApproachHeights:[500,500,500,500,500,500,500],
        portalContextHeights:[500,500,500,500]});
    assert.equal(model.portalClipMask[0],false,
        'bridge connection must not carve a height-unbounded cliff cut');
    assert.equal(model.portalClipMask[1],true,
        'nonbridge end can still clip when its terrain is well constrained');
    assert.ok(T.inside(model,point(model.sections[1])),
        'clipping policy must not alter the tunnel collision mesh');
});

test('dangerous sideways cliff relief disables only portal preview cuts, not the tunnel volume',()=>{
    const route={id:'cliff',kind:'tunnel',transport:'road',coordinates:
        [[8.2,46.8],[8.20032,46.8],[8.20064,46.8],[8.20096,46.8]]};
    const m=T.procedural(route,[500,515,515,500],{
        profile:'vaulted',portalApproachHeights:[500,500,500,500],
        portalContextHeights:[500,509,500,500]});
    assert.deepEqual(m.portalClipMask,[false,true],
        'steep portal cut disabled; stable portal may still be clipped');
    assert.ok(T.inside(m,point(m.sections[1])),'geometry and collision remain intact');
});

test('unavailable portal-side terrain never authorizes a deep idle clipping column',()=>{
    const route={id:'cliff',kind:'tunnel',transport:'road',coordinates:
        [[8.2,46.8],[8.20032,46.8],[8.20064,46.8],[8.20096,46.8]]};
    const m=T.procedural(route,[500,515,515,500],{
        profile:'vaulted',portalApproachHeights:[500,500,500,500],
        portalContextHeights:[null,500,500,500]});
    assert.deepEqual(m.portalClipMask,[false,true]);
});

test('underpass that floats high above a valley is not fabricated from 2D roads',()=>{
    const route={id:'raised',kind:'underpass',transport:'road',coordinates:
        [[8.2,46.8],[8.20032,46.8],[8.20064,46.8],[8.20096,46.8]]};
    assert.throws(()=>T.procedural(route,[500,470,470,500],{profile:'vaulted'}),/elevated/);
});

test('local developer diagnostic snapshot reports stable geometry identities without telemetry',async()=>{
    const f=fake();f.service.setAutomaticEnabled(true);
    await f.service.setAutomaticRoutes([{...source,kind:'tunnel'}]);
    const detail=f.service.diagnostics();
    assert.equal(detail.count,1);
    assert.equal(detail.entries.length,1);
    assert.deepEqual(detail.entries[0].members,[source.id]);
    assert.equal(typeof detail.entries[0].previewClips[0],'boolean');
    assert.ok(!('flightPosition' in detail));
    f.service.dispose();
});


test('long alpine tunnel advances source window rather than reusing stale 1.8 km mesh',async()=>{
    const coordinates=Array.from({length:125},(_,i)=>[8.2+i*.0005,46.8]);
    const route={id:'gotthard-regression',kind:'tunnel',transport:'road',
        source:'Offline Swiss OSM tunnel index',coordinates};
    const f=fake(),svc=T.create(f.C,f.viewer,()=>{}, {
        sampleTerrain:async points=>points.map(p=>p.longitude<8.201||p.longitude>8.26?1000:1430)});
    svc.setAutomaticEnabled(true);
    assert.equal((await svc.setAutomaticRoutes([route],{longitude:8.209,latitude:46.8})).count,1);
    const first=f.added[0];
    assert.equal(svc.floorAt({longitude:8.209,latitude:46.8,height:1002})!==null,true);
    assert.equal((await svc.setAutomaticRoutes([route],{longitude:8.235,latitude:46.8})).count,1);
    assert.notEqual(f.added[0],first,'same source ID must not reuse obsolete corridor');
    assert.equal(svc.floorAt({longitude:8.235,latitude:46.8,height:1002})!==null,true,
        'new window provides floor at subsequent kilometres');
    assert.equal(f.added.length,1,'old geometry is released only after replacement is ready');
    svc.dispose();
});

test('long-tunnel flight asks for a source-aligned forward segment near artificial end',async()=>{
    const coords=Array.from({length:124},(_,i)=>[8.2+i*.0005,46.8]);
    const route={id:'multi-km-alpine',kind:'tunnel',transport:'road',coordinates:coords};
    const f=fake();let clock=10000;
    const svc=T.create(f.C,f.viewer,()=>{}, {now:()=>clock,isSimulating:()=>true,
        sampleTerrain:async points=>points.map(p=>p.longitude<8.201||p.longitude>8.259?1000:1430)});
    svc.setAutomaticEnabled(true);
    await svc.setAutomaticRoutes([route],{longitude:8.209,latitude:46.8});
    const debug=svc.diagnostics().entries[0];
    assert.equal(debug.portals[1],false,'window end is not a surveyed source portal');
    const last=debug.ends[1];
    const near={longitude:last[0]-.00075,latitude:last[1],height:1002};
    const target=svc.flightCoverageTarget(near);
    assert.ok(target,'near-window flight must request a look-ahead area');
    assert.ok(target.longitude>last[0],'target follows the real OSM way beyond the window');
    clock+=800;
    assert.equal(svc.flightCoverageTarget(near),null,'duplicate requests are throttled');
    svc.dispose();
});

test('simulator stops below ground at artificial tunnel end instead of teleporting upward',async()=>{
    const F=require('../../web/free_flight.js');
    const cutoff=8.200065;
    const sim=F.createSimulator({sampleHeight:async()=>500,
        renderedHeight:p=>p.longitude<=cutoff?500:1300,
        onSurfaceDiscontinuity:({position,previousGround,nextGround,height})=>
            position.longitude>8.20005&&nextGround-previousGround>100&&height<nextGround,
        modeledCollision:()=>false,terrainCollision:()=>false,
        captureCamera:()=>({heading:Math.PI/2}),restoreCamera:()=>{},applyPose:()=>{},
        isTerrainReady:()=>true,onState:()=>{}});
    await sim.start({longitude:8.2,latitude:46.8,agl:2,flightMode:'gps'},new AbortController().signal);
    sim.key('w',true);
    for(let i=0;i<130;i++)sim.tick(.1);
    assert.ok(sim.status().height<510,'flight altitude was never raised to mountain terrain');
    assert.match(sim.status().reason,/Tunnel continuation loading/);
    assert.equal(sim.status().active,true,'simulation stays active and can resume after loading');
    sim.stop();
});

test('16-km sparse tunnel source yields bounded overlapping sections and no fake portal caps',async()=>{
    // Same order of magnitude as the Gotthard road tunnel's OSM way:
    // ~90 source vertices over 16+ km, but never one 16-km GPU mesh.
    const coordinates=Array.from({length:91},(_,i)=>[8.6-i*.00009,46.528+i*.00155]);
    const route={id:'synthetic-16km-source',kind:'tunnel',transport:'road',coordinates,
        source:'Test centreline only'};
    const f=fake(),svc=T.create(f.C,f.viewer,()=>{}, {
        sampleTerrain:async points=>points.map(p=>p.latitude<46.529||p.latitude>46.666?1000:1500)});
    svc.setAutomaticEnabled(true);
    const first=await svc.setAutomaticRoutes([route],{longitude:8.599,latitude:46.531});
    assert.equal(first.count,1,'sparse 16-km source must not be discarded for an oversized segment');
    const before=svc.diagnostics().entries[0];
    assert.ok(before.sections>20&&before.sections<=T.MAX_SECTIONS);
    assert.deepEqual(before.portals,[true,false],
        'the genuine first source end is a portal but the artificial continuation is not');
    const firstPrimitive=f.added[0];
    const second=await svc.setAutomaticRoutes([route],{longitude:8.596,latitude:46.582});
    assert.equal(second.count,1,'multi-kilometre continuation is independently loadable');
    assert.notEqual(f.added[0],firstPrimitive,'next section must not reuse expired first mesh');
    assert.ok(svc.diagnostics().entries[0].sections<=T.MAX_SECTIONS);
    assert.equal(f.added.length,1,'no unbounded accumulation of resident meshes');
    svc.dispose();
});

test('active pilot stays on old tunnel segment if replacement geometry is not available',async()=>{
    const f=fake(),r={...source,id:'occupied',kind:'tunnel'};
    let clock=10000;
    f.viewer.camera={positionCartographic:{longitude:8.2001*Math.PI/180,
        latitude:46.8*Math.PI/180,height:512.1}};
    const svc=T.create(f.C,f.viewer,()=>{}, {now:()=>clock,isSimulating:()=>true,
        sampleTerrain:async points=>points.map(()=>510)});
    svc.setAutomaticEnabled(true);
    assert.equal((await svc.setAutomaticRoutes([r],{longitude:8.2001,latitude:46.8})).count,1);
    const resident=f.added[0];
    clock+=30000;
    const missed=await svc.setAutomaticRoutes([],{longitude:8.8,latitude:46.9});
    assert.equal(missed.count,1,'do not evict a currently occupied tunnel on a missing-source scan');
    assert.equal(f.added[0],resident);
    assert.match(svc.diagnostics().error,/corridor retained/i);
    f.viewer.camera.positionCartographic={longitude:8.8*Math.PI/180,
        latitude:46.9*Math.PI/180,height:512.1};
    clock+=30000;
    assert.equal((await svc.setAutomaticRoutes([],{longitude:8.9,latitude:46.9})).count,0,
        'resident geometry is eventually released when no flight occupies it');
    svc.dispose();
});

test('approach road grade can correct a portal terrain cell more than six metres too high',()=>{
    const route={...source,kind:'tunnel'};
    const m=T.procedural(route,[515,520,520,514],{profile:'vaulted',
        portalApproachHeights:[502,502.5,503,503.2]});
    assert.ok(Math.abs(m.sections[0].floorMetersWgs84-502.025)<.2);
    assert.ok(Math.abs(m.sections.at(-1).floorMetersWgs84-502.95)<.2);
    assert.equal(m.portalsVerified,false,'road heights remain inferred, not surveyed');
});

test('bounded coherent road approach samples recover portal floor below a raised terrain cell',()=>{
    const route={...source,kind:'tunnel'};
    const model=T.procedural(route,[535,546,546,535],{
        profile:'vaulted',portalApproachHeights:[509,509.5,510,510.2]});
    assert.ok(Math.abs(model.sections[0].floorMetersWgs84-509.025)<.2);
    assert.ok(Math.abs(model.sections.at(-1).floorMetersWgs84-509.95)<.2);
    assert.equal(model.portalsVerified,false);
});

test('sparse Gotthard-scale way prefetches source-aligned overlapping windows beyond 3.8 km',async()=>{
    // The production Swiss index has long OSM segments. Choosing the nearest
    // SOURCE VERTEX used to jump past the current window, leaving a gap that
    // caused a terrain impact. This regression requires segment projection.
    const route={id:'gotthard-sparse-test',kind:'tunnel',transport:'road',
        coordinates:[[8.2,46.8],[8.254,46.8],[8.308,46.8],[8.362,46.8],[8.416,46.8]]};
    const f=fake();let clock=10000;
    const svc=T.create(f.C,f.viewer,()=>{}, {now:()=>clock,isSimulating:()=>true,
        sampleTerrain:async points=>points.map(p=>p.longitude<8.201||p.longitude>8.415?1000:1600)});
    svc.setAutomaticEnabled(true);
    let center={longitude:8.222,latitude:46.8};
    const first=await svc.setAutomaticRoutes([route],center);
    assert.equal(first.count,1);
    let endBefore=null;
    for(let hop=0;hop<8;hop++){
        const resident=svc.diagnostics().entries[0];
        assert.ok(resident,`mesh present at hop ${hop}`);
        const start=resident.ends[0][0],end=resident.ends[1][0];
        assert.ok(end>start);
        if(endBefore!==null)assert.ok(end>endBefore+0.001,`prefetch advanced at hop ${hop}`);
        endBefore=end;
        const flightPoint={longitude:end-.0006,latitude:46.8,height:1002};
        clock+=1000;
        const target=svc.flightCoverageTarget(flightPoint);
        assert.ok(target,`prefetch target available at hop ${hop}`);
        // 550m downstream of the actual trimmed END: neither an OSM node
        // 4km away nor a straight-line extrapolation through a bend.
        const projectedAdvance=(target.longitude-end)*111320*Math.cos(46.8*Math.PI/180);
        assert.ok(projectedAdvance>450&&projectedAdvance<650,
            `prefetch step ${hop} must advance ~550 m from the window end, got ${projectedAdvance}`);
        center=target;
        await svc.setAutomaticRoutes([route],center);
        const next=svc.diagnostics().entries[0];
        const overlap=(end-next.ends[0][0])*111320*Math.cos(46.8*Math.PI/180);
        assert.ok(overlap>200,`next window overlaps preceding by ${overlap.toFixed(0)} m`);
    }
    assert.ok((endBefore-8.2)*111320*Math.cos(46.8*Math.PI/180)>3800,
        'continuous modeled coverage extends beyond previous 3.8-km limit');
    svc.dispose();
});

test('flight prefetch retains full OSM way when viewport source list changes',async()=>{
    const route={id:'sparse-way-owned-by-mesh',kind:'tunnel',transport:'road',
        coordinates:[[8.2,46.8],[8.25,46.8],[8.3,46.8]]};
    const f=fake();let clock=10000;
    const svc=T.create(f.C,f.viewer,()=>{}, {now:()=>clock,isSimulating:()=>true,
        sampleTerrain:async points=>points.map(p=>p.longitude<8.201||p.longitude>8.299?1000:1500)});
    svc.setAutomaticEnabled(true);
    await svc.setAutomaticRoutes([route],{longitude:8.22,latitude:46.8});
    const resident=svc.diagnostics().entries[0];
    f.viewer.camera={positionCartographic:{longitude:(resident.ends[1][0]-.0006)*Math.PI/180,
        latitude:46.8*Math.PI/180,height:1002}};
    clock+=30000;
    await svc.setAutomaticRoutes([],{longitude:8.7,latitude:46.8});
    clock+=1000;
    const target=svc.flightCoverageTarget({longitude:resident.ends[1][0]-.0006,
        latitude:46.8,height:1002});
    assert.ok(target,'model-owned full source enables continuation after an empty viewport scan');
    svc.dispose();
});

test('unfinished artificial tunnel boundary is guarded just beyond mesh, not at real portal',async()=>{
    const route={id:'bounded-safety-guard',kind:'tunnel',transport:'road',
        coordinates:[[8.2,46.8],[8.25,46.8],[8.3,46.8]]};
    const f=fake();const svc=T.create(f.C,f.viewer,()=>{}, {
        sampleTerrain:async points=>points.map(p=>p.longitude<8.201||p.longitude>8.299?1000:1600)});
    svc.setAutomaticEnabled(true);
    await svc.setAutomaticRoutes([route],{longitude:8.22,latitude:46.8});
    const end=svc.diagnostics().entries[0].ends[1][0];
    const metersToLon=m=>m/(111320*Math.cos(46.8*Math.PI/180));
    const beyond={longitude:end+metersToLon(17),latitude:46.8,height:1002};
    assert.equal(svc.floorAt(beyond),null,'artificial segment has no fabricated floor beyond its mesh');
    assert.equal(svc.artificialBoundaryNear(beyond),true,
        'the pending continuation is recognized beyond the visible end');
    assert.equal(svc.artificialBoundaryNear({...beyond,latitude:46.8+metersToLon(45)}),false,
        'unrelated nearby open air must not be treated as a tunnel continuation');
    svc.dispose();
});

test('south-to-north Gotthard-style travel follows reversed source order for >4 km',async()=>{
    // The Swiss catalogue's Gotthard road way is ordered north -> south,
    // while the reported flight begins at the southern portal.
    const route={id:'gotthard-reversed-source',kind:'tunnel',transport:'road',
        coordinates:[[8.2,46.940],[8.2,46.905],[8.2,46.870],[8.2,46.835],[8.2,46.800]]};
    const f=fake();let clock=10000;
    const svc=T.create(f.C,f.viewer,()=>{}, {now:()=>clock,isSimulating:()=>true,
        sampleTerrain:async points=>points.map(p=>p.latitude<46.801||p.latitude>46.939?1000:1600)});
    svc.setAutomaticEnabled(true);
    await svc.setAutomaticRoutes([route],{longitude:8.2,latitude:46.815});
    let firstStart=svc.diagnostics().entries[0].ends[0][1];
    for(let hop=0;hop<9;hop++){
        const resident=svc.diagnostics().entries[0],start=resident.ends[0][1];
        clock+=1000;
        const target=svc.flightCoverageTarget({longitude:8.2,
            latitude:start-.0006,height:1002});
        assert.ok(target,`reversed flight prefetches at hop ${hop}`);
        const advance=(target.latitude-start)*111320;
        assert.ok(advance>450&&advance<650,
            `look-ahead uses source segment, not a distant north-south vertex; advance=${advance}`);
        await svc.setAutomaticRoutes([route],target);
        const dbg=svc.diagnostics();const next=dbg.entries[0];
        assert.ok(next&&(next.ends[0][1]-start)*111320>200,'next mesh advances toward source start');
        assert.ok((resident.ends[0][1]-next.ends[1][1])*111320>200,
            'the new window overlaps the previously loaded tunnel');
    }
    assert.ok((svc.diagnostics().entries[0].ends[0][1]-firstStart)*111320>4000);
    svc.dispose();
});

test('five sampled road elevations extrapolate portal grade and ignore one roof-height outlier',()=>{
    const r={...source,kind:'tunnel',roadApproaches:[
        Array.from({length:5},(_,i)=>[8.2-(i+1)*.00005,46.8]),
        Array.from({length:5},(_,i)=>[8.20021+(i+1)*.00005,46.8])]};
    const m=T.procedural(r,[535,540,540,535],{profile:'vaulted',
        portalApproachHeights:[503,503.5,540,504.5,505, 504,504.3,504.6,504.9,505.2]});
    assert.ok(Math.abs(m.sections[0].floorMetersWgs84-502.4)<.35,
        'road approach grade is extrapolated to the portal, not averaged with a roof tile');
    assert.ok(Math.abs(m.sections.at(-1).floorMetersWgs84-503.6)<.35);
    assert.deepEqual(m.portalFloorMethods,['connected-road-grade','connected-road-grade']);
    assert.equal(m.portalsVerified,false);
});

test('five inconsistent approach elevations safely fall back to terrain rather than inventing road height',()=>{
    const r={...source,kind:'underpass'};
    const m=T.procedural(r,[510,511,511,510],{profile:'vaulted',
        portalApproachHeights:[520,480,540,470,530, 500,520,480,530,490]});
    assert.equal(m.portalFloorMethods[0],'terrain-fallback');
    assert.equal(m.portalFloorMethods[1],'terrain-fallback');
    assert.ok(m.sections[0].floorMetersWgs84>505);
});

test('automatic mesh samples actual connected approach geometry, never indoor tangent when road exists',async()=>{
    const f=fake();f.service.dispose();
    const collected=[];
    const startRoad=Array.from({length:5},(_,i)=>[8.2-(i+1)*.00005,46.80002+i*.000001]);
    const endRoad=Array.from({length:5},(_,i)=>[8.20021+(i+1)*.00005,46.80002]);
    const route={...source,kind:'underpass',roadApproaches:[startRoad,endRoad]};
    const svc=T.create(f.C,f.viewer,()=>{}, {sampleTerrain:async points=>{
        collected.push(...points);return points.map(()=>510);
    }});
    svc.setAutomaticEnabled(true);
    const output=await svc.setAutomaticRoutes([route],
        {longitude:8.2001,latitude:46.8});
    assert.equal(output.count,1);
    for(const [lon,lat] of [...startRoad,...endRoad])
        assert.ok(collected.some(p=>Math.abs(p.longitude-lon)<.0000001&&
            Math.abs(p.latitude-lat)<.0000001),`road approach point ${lon},${lat} requested`);
    svc.dispose();
});

test('legacy tunnel index samples approach points OUTSIDE both endpoint axes',async()=>{
    const f=fake();f.service.dispose();const collected=[];
    const svc=T.create(f.C,f.viewer,()=>{}, {sampleTerrain:async points=>{
        collected.push(...points);return points.map(()=>510);
    }});
    svc.setAutomaticEnabled(true);
    assert.equal((await svc.setAutomaticRoutes([{...source,kind:'underpass'}],
        {longitude:8.2001,latitude:46.8})).count,1);
    assert.ok(collected.some(p=>p.longitude<source.coordinates[0][0]-.0001),
        'samples before the start portal really leave the tunnel');
    assert.ok(collected.some(p=>p.longitude>source.coordinates.at(-1)[0]+.0001),
        'samples beyond the far portal really leave the tunnel');
    svc.dispose();
});


test('unconnected tangent samples cannot pull a portal floor forty metres below the terrain',()=>{
    const r={...source,kind:'underpass'};
    const m=T.procedural(r,[535,540,540,535],{profile:'vaulted',
        portalApproachHeights:[503,503.5,504,504.5,505, 504,504.3,504.6,504.9,505.2]});
    assert.deepEqual(m.portalRoadConnected,[false,false]);
    assert.ok(m.sections[0].floorMetersWgs84>525,
        'a virtual straight-line extension is not a measured road approach');
    assert.equal(m.portalFloorMethods[0],'terrain-fallback');
});

test('successive 1.8 km tunnel windows reconcile their overlapping floor elevation',()=>{
    const section=(longitude,floor)=>({longitude,latitude:46.8,
        floorMetersWgs84:floor,widthMeters:6,heightMeters:5});
    const old={partial:true,sections:[0,1,2,3,4,5].map(i=>section(8.2+i*.0001,500))};
    const next={partial:true,sections:[3,4,5,6,7,8].map(i=>section(8.2+i*.0001,505))};
    const result=T.alignContinuation(next,old);
    assert.equal(result.aligned,true);
    assert.ok(result.samples>=2);
    assert.ok(Math.abs(result.differenceMeters+5)<1e-5);
    assert.ok(Math.abs(T.closest(next,{longitude:8.2005,latitude:46.8,height:503}).floor-500)<.001);
    const distant={partial:true,sections:[12,13,14].map(i=>section(8.2+i*.0001,505))};
    assert.equal(T.alignContinuation(distant,old).aligned,false);
    const conflict={partial:true,sections:[3,4,5,6].map(i=>section(8.2+i*.0001,540))};
    assert.equal(T.alignContinuation(conflict,old).reason,'elevation-conflict');
});

test('connected bridge approach uses a coherent elevated scene deck only when available',async()=>{
    const f=fake(),scene=f.viewer.scene;
    scene.globe.getHeight=()=>510;
    f.C.Cartographic={fromDegrees:(longitude,latitude)=>({longitude,latitude})};
    scene.sampleHeightSupported=true;
    scene.sampleHeight=()=>513;
    const service=T.create(f.C,f.viewer,()=>{}, {sampleTerrain:async positions=>positions.map(()=>510)});
    service.setAutomaticEnabled(true);
    const road=Array.from({length:5},(_,i)=>[8.2-(i+1)*.000055,46.8]);
    const route={id:'osm:600:0',kind:'tunnel',transport:'road',name:'Bridge portal',
        coordinates:[[8.2,46.8],[8.20025,46.8]],roadApproaches:[road,null],
        roadApproachKinds:['bridge',null]};
    const outcome=await service.setAutomaticRoutes([route],{longitude:8.2001,latitude:46.8});
    assert.equal(outcome.count,1);
    const entry=service.diagnostics().entries[0];
    assert.equal(entry.portalFloorMethods[0],'connected-bridge-surface');
    assert.ok(entry.floorEnds[0]>511,'bridge deck raises the portal above valley terrain');
    service.dispose();f.service.dispose();
});

test('a real portal receives a height-bounded vaulted clipping volume, no artificial segment caps',()=>{
    const C=require('../../web/cesium/index.cjs');
    const m=T.procedural({...source,kind:'tunnel'},[510,511,520,510],{profile:'vaulted'});
    const spec=T.boundedClipSpec(m,0);
    assert.ok(spec);
    assert.equal(spec.before,8);
    assert.equal(spec.after,26);
    assert.ok(spec.above<7&&spec.below<1.3,'the volume is limited to the modeled road and roof');
    const cut=T.clippingVolume(C,spec);
    assert.equal(cut.length,11);
    assert.equal(cut.unionClippingRegions,false,'vaulted planes intersect, not unite');
    assert.ok(C.Matrix4.equalsEpsilon(cut.modelMatrix,C.Transforms.eastNorthUpToFixedFrame(
        C.Cartesian3.fromDegrees(spec.longitude,spec.latitude,spec.floor)),1e-7));
    const coords=Array.from({length:cut.length},(_,i)=>cut.get(i));
    const signed=(x,y,z)=>coords.map(plane=>plane.normal.x*x+
        plane.normal.y*y+plane.normal.z*z+plane.distance);
    const center=signed(0,0,2);
    assert.ok(center.every(v=>v<0),'road-level center is inside all six clipping halfspaces');
    assert.ok(signed(0,0,spec.above+1).some(v=>v>0),'cliff above roof is NOT clipped');
    const alongSide=(x,z)=>signed(-spec.forward.north*x,spec.forward.east*x,z);
    assert.ok(alongSide(0,spec.above-.15).every(v=>v<0),
        'the crown of the vault is open near the roof');
    assert.ok(alongSide(spec.halfWidth*.9,spec.above-.15).some(v=>v>0),
        'the same height at the shoulders is solid rock, not a rectangular cut');
    assert.ok(alongSide(spec.halfWidth*.9,spec.above-spec.roofRise-.3).every(v=>v<0),
        'lower sidewall remains open for entrance');

    assert.ok(signed(0,0,-spec.below-1).some(v=>v>0),'valley below road is NOT clipped');
    const side=-spec.forward.north*(spec.halfWidth+1);
    const north=spec.forward.east*(spec.halfWidth+1);
    assert.ok(signed(side,north,2).some(v=>v>0),'rock beside portal is NOT clipped');
    const partial={...m,portalEnds:[false,true],partial:true};
    assert.equal(T.boundedClipSpec(partial,0),null,'cropped OSM end never gets a fake portal hole');
    assert.ok(T.boundedClipSpec(partial,1),'real end remains eligible');
});

test('schematic portal surround leaves the vaulted opening hollow and collision unchanged',()=>{
    const C=require('../../web/cesium/index.cjs');
    const m=T.procedural({...source,kind:'tunnel'},[510,511,520,510],{profile:'vaulted'});
    const before=T.collisionMesh(m).triangleCount;
    const surrounds=T.portalSurroundGeometries(C,m);
    assert.equal(surrounds.length,2);
    assert.ok(surrounds.every(s=>s.kind==='portal-surround'&&s.geometry.indices.length>0));
    assert.equal(T.collisionMesh(m).triangleCount,before,'portal trim must never be a collision bulkhead');
    const cropped={...m,portalEnds:[false,true],partial:true};
    assert.equal(T.portalSurroundGeometries(C,cropped).length,1,
        'the 1.8-km Gotthard window has no synthetic end-cap');
});

test('bridge-to-cliff portal uses clipped vertical bounds and restores owned globe state',async()=>{
    const C=require('../../web/cesium/index.cjs');
    const f=fake();f.service.dispose();
    // Reuse actual Cesium constructors while keeping a GPU-free fake scene.
    const previous={length:0},oldPolygons=f.viewer.scene.globe.clippingPolygons;
    f.viewer.scene.globe.clippingPlanes=previous;
    f.viewer.camera={positionCartographic:{longitude:8.2*Math.PI/180,
        latitude:46.8*Math.PI/180,height:1002}};
    const svc=T.create(C,f.viewer,()=>{}, {sampleTerrain:async points=>points.map(()=>1000)});
    svc.setAutomaticEnabled(true);
    const route={...source,kind:'tunnel',roadApproachKinds:['bridge',null]};
    const result=await svc.setAutomaticRoutes([route],{longitude:8.2001,latitude:46.8});
    assert.equal(result.count,1);
    assert.equal(svc.diagnostics().entries[0].previewClips[0],false,
        'old 2D polygon would be unsafe at a bridge-to-cliff transition');
    assert.equal(svc.diagnostics().entries[0].portalRoadConnected.length,2);
    const bridge=svc.diagnostics().entries[0];
    const bridgeModel=T.procedural(route,[1000,1000,1000,1000],{profile:'vaulted'});
    assert.equal(T.boundedClipSpec(bridgeModel,0).before,10,
        'a bridge-to-tunnel road has a slightly longer, height-bounded approach notch');
    assert.equal(f.viewer.scene.globe.clippingPlanes,previous,
        'native plane clipping never removes road fragments');
    assert.ok(f.viewer.scene.globe.material instanceof C.Material);
    assert.equal(svc.diagnostics().boundedApertureActive,true);
    assert.equal(f.viewer.scene.globe.clippingPolygons,oldPolygons);
    svc.dispose();
    assert.equal(f.viewer.scene.globe.clippingPlanes,previous,
        'the globe plane owner must be restored on disable/dispose');
});

test('third-party clipping planes are not replaced by an automatic portal',async()=>{
    const C=require('../../web/cesium/index.cjs');const f=fake();f.service.dispose();
    const existing={length:2};f.viewer.scene.globe.clippingPlanes=existing;
    f.viewer.scene.context={webgl2:true};
    f.viewer.camera={positionCartographic:{longitude:8.2*Math.PI/180,
        latitude:46.8*Math.PI/180,height:1002}};
    const svc=T.create(C,f.viewer,()=>{}, {sampleTerrain:async points=>points.map(()=>1000)});
    svc.setAutomaticEnabled(true);
    await svc.setAutomaticRoutes([{...source,kind:'tunnel',roadApproachKinds:['bridge',null]}],
        {longitude:8.2001,latitude:46.8});
    assert.equal(f.viewer.scene.globe.clippingPlanes,existing);
    assert.equal(svc.diagnostics().boundedApertureActive,false);
    svc.dispose();
});

test('active tunnel flight replaces long vertical polygon cut with a moving bounded box',async()=>{
    const C=require('../../web/cesium/index.cjs');
    const f=fake();f.service.dispose();let flying=false,frame=null,clock=1000;
    f.viewer.scene.globe.clippingPlanes={length:0};
    f.viewer.scene.preUpdate={addEventListener(fn){frame=fn;return ()=>{frame=null;}}};
    f.viewer.camera={positionCartographic:{longitude:8.2*Math.PI/180,
        latitude:46.8*Math.PI/180,height:1002}};
    const svc=T.create(C,f.viewer,()=>{}, {now:()=>clock,isSimulating:()=>flying,
        sampleTerrain:async points=>points.map(()=>1000)});
    svc.setAutomaticEnabled(true);
    await svc.setAutomaticRoutes([{...source,kind:'tunnel'}],
        {longitude:8.2001,latitude:46.8});
    assert.equal(svc.diagnostics().boundedAperturePlanes,0);
    assert.equal(svc.diagnostics().groundProtected,true);
    const group=f.added.find(p=>p instanceof C.PrimitiveCollection);
    assert.ok(group,'detailed graphics retain one atomic scene object');
    assert.equal(group.length,2,'textured tunnel and painted road markings use separate passes');
    assert.equal(group.get(0).geometryInstances.length,6,
        'textured base retains road, walls, ceiling, wall bands and two portal surrounds');
    assert.equal(group.get(1).geometryInstances.length,1,
        'centre markings remain visible above asphalt in their own opaque primitive');
    // Fly past the portal: the local clipping box follows the interior pose.
    f.viewer.camera.positionCartographic={longitude:8.20012*Math.PI/180,
        latitude:46.8*Math.PI/180,height:1002};
    flying=true;clock+=500;frame();
    const cut=f.viewer.scene.globe.material;
    assert.ok(cut instanceof C.Material);
    assert.equal(svc.diagnostics().boundedApertureActive,true);
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,0,
        'no unbounded 2D terrain polygon is combined with the bounded volume');
    const mid=C.Cartesian3.fromDegrees(8.20012,46.8,1002);
    assert.ok(svc.apertureSpecs().some(spec=>{
        const volume=T.clippingVolume(C,spec),local=C.Matrix4.multiplyByPoint(
            C.Matrix4.inverse(volume.modelMatrix,new C.Matrix4()),mid,new C.Cartesian3());
        const contains=Array.from({length:volume.length},(_,i)=>volume.get(i))
            .every(plane=>C.Cartesian3.dot(plane.normal,local)+plane.distance<0);
        volume.destroy();return contains;
    }),'the selected overlapping masks cover the occupied tunnel segment');
    svc.dispose();
    assert.equal(frame,null);
});

test('procedural tunnel GLSL avoids reserved identifiers and keeps material input intact',()=>{
    const source=T.TUNNEL_MATERIAL_SOURCE;
    // GLSL ES reserves `input`: Cesium builds a Material on Node, but the
    // driver's fragment shader compilation would fail on Android WebGL.
    assert.doesNotMatch(source,/\bczm_materialInput\s+input\b/);
    assert.doesNotMatch(source,/\binput\s*\./);
    assert.match(source,/czm_material\s+czm_getMaterial\(czm_materialInput\s+materialInput\)/);
    assert.match(source,/czm_getDefaultMaterial\(materialInput\)/);
    assert.match(source,/\bmaterialInput\.st\./);
});

test('quality tunnel detail creates real Cesium material with UVs and normals, while collision stays unchanged',()=>{
    const C=require('../../web/cesium/index.cjs');
    const m=T.procedural({...source,kind:'tunnel',transport:'road'},[510,510,511,511],
        {widthMeters:6,heightMeters:5,profile:'vaulted'});
    const collisionBefore=T.collisionMesh(m).triangleCount;
    const surfaces=T.texturedSurfaceGeometries(C,m);
    assert.ok(surfaces.length>=5);
    assert.ok(surfaces.some(s=>s.kind==='road'));
    assert.ok(surfaces.some(s=>s.kind==='walls'));
    assert.ok(surfaces.some(s=>s.kind==='ceiling'));
    assert.ok(surfaces.every(s=>s.geometry.attributes.st.values instanceof Float32Array));
    assert.ok(surfaces.every(s=>s.geometry.attributes.normal.values instanceof Float32Array));
    assert.ok(surfaces.every(s=>s.geometry.attributes.st.values.length===
        s.geometry.attributes.position.values.length/3*2));
    const material=new C.Material({fabric:{type:'FPVProceduralTunnelSurface',source:T.TUNNEL_MATERIAL_SOURCE}});
    const appearance=new C.MaterialAppearance({material,translucent:false,closed:false,faceForward:true});
    assert.equal(appearance.material.type,'FPVProceduralTunnelSurface');
    assert.equal(appearance.materialSupport.vertexFormat.st,true);
    assert.equal(T.collisionMesh(m).triangleCount,collisionBefore);
});

test('portal cut can reach a flying approach without deep full-height terrain clipping',()=>{
    const m=T.procedural({...source,kind:'tunnel',transport:'road',roadApproachKinds:['bridge',null]},
        [510,510,511,511],{profile:'vaulted'});
    const preview=T.boundedClipSpec(m,0);
    const approach=T.boundedClipSpec(m,0,{before:23,after:18});
    assert.equal(preview.before,10);
    assert.equal(approach.before,23);
    assert.equal(approach.after,18);
    const C=require('../../web/cesium/index.cjs');
    const volume=T.clippingVolume(C,{...approach,below:2.5,above:approach.above+1});
    assert.equal(volume.length,11);
    assert.equal(volume.unionClippingRegions,false);
});

test('schematic railway tunnel does not elevate its interior above sampled ground',()=>{
    const rail={id:'rail:500',kind:'tunnel',transport:'railway',
        coordinates:[[8.2,46.8],[8.2001,46.8],[8.2002,46.8],[8.2003,46.8]]};
    const m=T.procedural(rail,[510,515,520,510],{heightMeters:5});
    assert.equal(m.transport,'railway');
    assert.ok(m.sections[1].floorMetersWgs84+5<=515+.6);
    assert.ok(m.sections[2].floorMetersWgs84+5<=520+.6);
    const unsupported={...rail,coordinates:[[8.2,46.8],[8.2001,46.8],[8.2002,46.8],[8.2003,46.8]]};
    assert.throws(()=>T.procedural(unsupported,[510,499,499,510],{heightMeters:5}),
        /Tunnel roof|Rail tunnel|depression|grade|emerge/);
});

test('graphics profiles select textured tunnel primitives or lightweight compatibility colors',async()=>{
    const actual=require('../../web/cesium/index.cjs');
    const road={...source,kind:'tunnel',transport:'road'};
    for(const profile of ['balanced','quality','performance','compatibility']){
        const f=fake();
        f.C.Material=actual.Material;
        f.C.MaterialAppearance=actual.MaterialAppearance;
        f.C.ComponentDatatype.FLOAT=actual.ComponentDatatype.FLOAT;
        f.service.setPerformanceProfile(profile);
        f.service.setAutomaticEnabled(true);
        const result=await f.service.setAutomaticRoutes([road],{longitude:8.2001,latitude:46.8});
        assert.equal(result.count,1);
        const primitive=f.added.find(p=>p instanceof f.C.Primitive);
        assert.ok(primitive);
        if(profile==='balanced'||profile==='quality'){
            assert.ok(primitive.appearance instanceof actual.MaterialAppearance);
            const geometry=primitive.geometryInstances[0].geometry;
            assert.ok(geometry.attributes.st,'UVs drive the detailed material');
        }else{
            assert.ok(primitive.appearance instanceof f.C.PerInstanceColorAppearance);
            assert.equal(primitive.geometryInstances[0].geometry.attributes.st,undefined);
        }
        f.service.dispose();
    }
});

test('bridge-to-rock portal expands only its local vaulted entrance cut when FPV approaches from outside',async()=>{
    const C=require('../../web/cesium/index.cjs');
    const f=fake();f.service.dispose();
    let flying=false,clock=1000,frame=()=>{};
    const prior={length:0},polygons=f.viewer.scene.globe.clippingPolygons;
    f.viewer.scene.globe.clippingPlanes=prior;
    f.viewer.scene.context={webgl2:true};
    f.viewer.scene.preUpdate={addEventListener(fn){frame=fn;return ()=>{};}};
    f.viewer.camera={positionCartographic:{longitude:8.2*Math.PI/180,
        latitude:46.8*Math.PI/180,height:1002}};
    const service=T.create(C,f.viewer,()=>{}, {isSimulating:()=>flying,now:()=>clock,
        sampleTerrain:async points=>points.map(()=>1000)});
    service.setAutomaticEnabled(true);
    await service.setAutomaticRoutes([{...source,kind:'tunnel',transport:'road',
        roadApproachKinds:['bridge',null]}],{longitude:8.2001,latitude:46.8});
    assert.equal(service.diagnostics().boundedApertureActive,true);
    const idle=f.viewer.scene.globe.material;
    const idleBefore=idle.uniforms.apertureBounds.y;
    // Around 15 m before the start of the source centerline: outside the bore.
    f.viewer.camera.positionCartographic.longitude=(8.2-.00018)*Math.PI/180;
    flying=true;clock+=1000;frame();
    const approaching=f.viewer.scene.globe.material;
    assert.equal(approaching,idle,'outside approach updates the same material without rebuilding Globe shaders');
    assert.ok(approaching instanceof C.Material);
    assert.equal(approaching.uniforms.apertureBounds.y>=9,true,
        'flight approach has more than the idle 10 m lead-in');
    assert.ok(approaching.uniforms.apertureBounds.y>idleBefore,'the bounded approach length still changes in place');
    assert.equal(f.viewer.scene.globe.clippingPolygons,polygons,
        'rock slope must not receive an additional unbounded clipping polygon');
    service.dispose();
    assert.equal(f.viewer.scene.globe.clippingPlanes,prior);
});


test('portal clipping retains a six-plane box for truly rectangular explicit profiles',()=>{
    const C=require('../../web/cesium/index.cjs');
    const m=T.procedural({...source,kind:'tunnel'},[510,511,520,510],{profile:'rectangular'});
    const spec=T.boundedClipSpec(m,0);
    assert.equal(spec.shape,'rectangular');
    assert.equal(T.clippingVolume(C,spec).length,6);
});

test('detailed tunnel road retains former dark asphalt and solid, depth-writing walls',async()=>{
    const shader=T.TUNNEL_MATERIAL_SOURCE;
    assert.match(shader,/vec3\(48\.0,54\.0,60\.0\)\/255\.0\*asphalt/);
    assert.match(shader,/m\.alpha=1\.0/);
    const C=require('../../web/cesium/index.cjs');
    const f=fake();
    f.C.Material=C.Material;f.C.MaterialAppearance=C.MaterialAppearance;
    f.C.ComponentDatatype.FLOAT=C.ComponentDatatype.FLOAT;
    f.service.setPerformanceProfile('balanced');f.service.setAutomaticEnabled(true);
    const res=await f.service.setAutomaticRoutes([{...source,kind:'tunnel'}],
        {longitude:8.2001,latitude:46.8});
    assert.equal(res.count,1);
    const primitive=f.added.find(p=>p instanceof f.C.Primitive);
    assert.equal(primitive.appearance.translucent,false);
    assert.equal(primitive.appearance.material.isTranslucent(),false,
        'the custom material must select the opaque pass independently of appearance.translucent');
    assert.equal(primitive.appearance.isTranslucent(),false);
    assert.equal(primitive.appearance.getRenderState().depthMask,true,
        'Cesium must retain depth writes after resolving material translucency');
    assert.equal(primitive.appearance.getRenderState().blending.enabled,false);
    assert.equal(primitive.appearance.renderState.depthMask,true);
    assert.equal(primitive.appearance.renderState.cull.enabled,false);
    f.service.dispose();
});


test('tunnel markings use a visible independent opaque decal pass with true Cesium primitives',async()=>{
    const C=require('../../web/cesium/index.cjs');
    const f=fake();f.service.dispose();
    f.viewer.scene.context={webgl2:true};
    f.viewer.scene.globe.clippingPlanes={length:0};
    const svc=T.create(C,f.viewer,()=>{}, {ready:()=>true,
        sampleTerrain:async points=>points.map(()=>510)});
    svc.setAutomaticEnabled(true);
    const result=await svc.setAutomaticRoutes([{...source,kind:'tunnel'}],
        {longitude:8.2001,latitude:46.8});
    assert.equal(result.count,1);
    const collection=f.added.find(p=>p instanceof C.PrimitiveCollection);
    assert.ok(collection);
    assert.equal(collection.length,2);
    const base=collection.get(0),markings=collection.get(1);
    assert.equal(base.appearance.translucent,false);
    assert.equal(base.appearance.material.isTranslucent(),false);
    assert.equal(base.appearance.isTranslucent(),false);
    assert.equal(base.appearance.getRenderState().depthMask,true);
    assert.equal(base.appearance.getRenderState().blending.enabled,false);
    assert.equal(markings.appearance.translucent,false);
    assert.equal(markings.appearance.renderState.depthMask,true);
    assert.ok(markings.geometryInstances[0].geometry.indices.length>0);
    const first=markings.geometryInstances[0].geometry.attributes.position.values;
    const height=C.Cartographic.fromCartesian(new C.Cartesian3(first[0],first[1],first[2])).height;
    assert.ok(height>509.95,'paint is raised above the asphalt to avoid terrain z-fighting');
    svc.dispose();
});

test('normal globe view selects clipping by its visible center instead of the distant orbit camera',async()=>{
    const C=require('../../web/cesium/index.cjs');
    const f=fake();f.service.dispose();
    f.viewer.scene.globe.clippingPlanes={length:0};
    f.viewer.scene.canvas={width:900,height:1600};
    f.viewer.scene.globe.pick=()=>C.Cartesian3.fromDegrees(8.2,46.8,510);
    f.viewer.camera={positionCartographic:{longitude:8.4*Math.PI/180,
        latitude:46.8*Math.PI/180,height:2200},
        getPickRay:screen=>({screen})};
    const svc=T.create(C,f.viewer,()=>{}, {sampleTerrain:async points=>points.map(()=>510)});
    svc.setAutomaticEnabled(true);
    const result=await svc.setAutomaticRoutes([{...source,kind:'tunnel'}],
        {longitude:8.2001,latitude:46.8});
    assert.equal(result.count,1);
    assert.equal(svc.diagnostics().boundedApertureActive,true,
        'looking at a portal from far away should still clip the portal');
    assert.equal(svc.diagnostics().boundedAperturePlanes,0);
    svc.dispose();
});

test('railway tunnel never generates an asphalt road center line',()=>{
    const f=fake();
    const r={...source,kind:'tunnel',transport:'railway'};
    const m=T.procedural(r,[510,530,530,510],{profile:'vaulted'});
    assert.equal(T.surfaceGeometries(f.C,m).some(surface=>surface.kind==='marking'),false);
    f.service.dispose();
});
