'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
const F=require('../../web/free_flight.js');
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
    const C={
        Cartesian3:{fromDegrees:(lon,lat,h=0)=>({x:lon*1000,y:lat*1000,z:h})},
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
    assert.notEqual(f.viewer.scene.globe.clippingPolygons,f.old);
    assert.equal(f.service.status().ready,true);
    const spawn=f.service.firstPose();assert.ok(spawn.height>spawn.ground);
    f.service.activate();
    assert.equal(f.service.flight,true);
    assert.equal(f.service.floorAt(spawn),spawn.ground);
    f.service.stop();assert.equal(f.service.status().ready,false);
    assert.equal(f.added.length,0);assert.equal(f.removed.length,1);
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
    assert.equal(f.service.floorAt(spawn),null);
    f.service.dispose();
});
test('terrain clipping unsupported or already owned by another layer fails closed',async()=>{
    const f=fake();f.C.ClippingPolygonCollection.isSupported=()=>false;
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

test('small portal cuts are replaced with full corridor clipping only during simulated flight',async()=>{
    const f=fake();await f.service.prepare(source,{profile:'vaulted'});
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,2,'only portal approaches clipped at rest');
    f.service.activate();
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,1,'corridor clipped during underground flight');
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

test('automatic tunnel budget selects 32 normally and 64 in quality; clipping stays bounded to eight',async()=>{
    const f=fake();
    const service=T.create(f.C,f.viewer,()=>{}, {ready:()=>true,
        sampleTerrain:async points=>points.map(()=>510)});
    service.setAutomaticEnabled(true);
    const routes=Array.from({length:68},(_,i)=>({...source,kind:'tunnel',id:`osm:dynamic:${i}`,
        coordinates:[[8.2+i*.00003,46.8],[8.20007+i*.00003,46.8]]}));
    const first=await service.setAutomaticRoutes(routes,{longitude:8.2,latitude:46.8});
    assert.equal(first.count,32);
    assert.equal(service.status().autoCount,32);
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,0,'flat-road previews need no terrain holes');
    assert.equal(f.added.length,32);
    service.setPerformanceProfile('quality');
    // setPerformanceProfile schedules the rebuild on an async terrain path.
    for(let i=0;i<100&&service.status().autoCount<64;i++)await new Promise(r=>setTimeout(r,4));
    assert.equal(service.status().autoCount,64);
    assert.equal(f.added.length,64,'reused meshes are not duplicated');
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

test('scene-resident terrain avoids redundant network heights and viewport reuses meshes',async()=>{
    const f=fake();let requests=0;
    f.C.Cartographic={fromDegrees:(longitude,latitude)=>({longitude,latitude})};
    f.viewer.scene.globe.getHeight=()=>510;
    const service=T.create(f.C,f.viewer,()=>{}, {sampleTerrain:async()=>{requests++;throw Error('Unexpected network');}});
    service.setAutomaticEnabled(true);
    const r={...source,kind:'tunnel'};
    await service.setAutomaticRoutes([r],{longitude:8.2,latitude:46.8});
    const first=f.added[0];
    await service.setAutomaticRoutes([r],{longitude:8.2,latitude:46.8});
    assert.equal(requests,0);
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
    const flight=f.viewer.scene.globe.clippingPolygons;
    assert.equal(flight.length,1,'only the relevant tunnel is opened for active flight');
    assert.ok(flight.polygons[0].positions.length>4);
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
    assert.equal(primitive.geometryInstances.length,5,'one primitive, five visually distinct material groups');
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
        assert.equal(f.viewer.scene.globe.clippingPolygons.length,2,
            'only plausible mountainside portals are clipped');
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
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,0,
        'artificial crop boundaries never excavate portals');
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
