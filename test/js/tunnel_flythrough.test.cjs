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
    assert.equal(m.sections[0].floorMetersWgs84,510.6);
    assert.ok(m.sections[1].floorMetersWgs84<510.6);
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
