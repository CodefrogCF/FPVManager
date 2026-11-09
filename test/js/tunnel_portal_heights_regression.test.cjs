'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
const at=metres=>[8.2,46.8+metres/111319.49079327358];
const route=(extra={})=>({id:'portal-road',source:'fixture',sourceId:'road',
    kind:'tunnel',transport:'road',coordinates:[0,20,40,60,80,100].map(at),
    roadApproaches:[[-4,-8,-12,-16,-20].map(at),[104,108,112,116,120].map(at)],...extra});
const settings=values=>({profile:'vaulted',portalApproachHeights:values});
const flatRoad=Array(10).fill(500);
function pipeline(sampleTerrain,renderedHeight=()=>560){
    class Options{constructor(options){Object.assign(this,options);}}
    const C={Geometry:Options,GeometryAttribute:Options,GeometryInstance:Options,Primitive:Options,
        PerInstanceColorAppearance:Options,ComponentDatatype:{DOUBLE:1},PrimitiveType:{TRIANGLES:4},
        Cartesian3:{fromDegrees:(longitude,latitude,height=0)=>({x:longitude,y:latitude,z:height})},
        Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},
        Color:{fromBytes:(...values)=>values},ColorGeometryInstanceAttribute:{fromColor:color=>color},
        BoundingSphere:{fromVertices:vertices=>({length:vertices.length})}};
    const viewer={scene:{globe:{getHeight:renderedHeight,clippingPolygons:{length:0}},
        primitives:{add:value=>value,remove:()=>true},requestRender(){}}};
    const service=T.create(C,viewer,()=>{},{sampleTerrain});
    service.setAutomaticEnabled(true);
    return service;
}

test('actual create pipeline replaces stale rendered cliff approaches with detailed road heights',async()=>{
    const requested=[];
    const service=pipeline(async points=>{
        requested.push(...points);
        return points.map(()=>500);
    });
    try{
        const result=await service.setAutomaticRoutes([route()],{longitude:8.2,latitude:at(50)[1]});
        assert.equal(result.count,1);
        const entry=service.diagnostics().entries[0];
        assert.ok(entry.floorEnds.every(floor=>Math.abs(floor-499.9)<1e-6));
        assert.deepEqual(entry.portalFloorMethods,['connected-road-grade','connected-road-grade']);
        for(const [longitude,latitude] of route().roadApproaches.flat())
            assert.ok(requested.some(p=>Math.abs(p.longitude-longitude)<1e-10&&
                Math.abs(p.latitude-latitude)<1e-10),'all five actual road points are refreshed at each end');
    }finally{service.dispose();}
});

test('missing detailed road heights cannot be replaced by a coherent majority from stale cliff tiles',async()=>{
    const service=pipeline(async points=>points.map(p=>
        Math.abs(p.latitude-at(-4)[1])<1e-10||Math.abs(p.latitude-at(104)[1])<1e-10?500:null),
    p=>p.latitude>at(1)[1]&&p.latitude<at(99)[1]?600:560);
    try{
        const result=await service.setAutomaticRoutes([route()],{longitude:8.2,latitude:at(50)[1]});
        assert.equal(result.count,0,'incomplete detailed road data defers the portal instead of floating at 560 m');
        assert.match(service.diagnostics().error,/approach road elevation is inconsistent/);
    }finally{service.dispose();}
});

test('connected five-point road grade overrides a cliff more than forty metres above the road',()=>{
    const m=T.procedural(route(),[565,570,580,580,570,565],settings(flatRoad));
    assert.deepEqual(m.portalFloorMethods,['connected-road-grade','connected-road-grade']);
    assert.ok(m.sections.every(s=>Math.abs(s.floorMetersWgs84-499.9)<1e-6));
});

test('coherent connected road grade can rise above a low raster cell at the portal',()=>{
    const m=T.procedural(route(),[480,530,540,540,530,480],settings(flatRoad));
    assert.ok(Math.abs(m.sections[0].floorMetersWgs84-499.9)<1e-6);
    assert.ok(Math.abs(m.sections.at(-1).floorMetersWgs84-499.9)<1e-6);
});

test('inconsistent connected five-point evidence defers the portal instead of restoring cliff height',()=>{
    assert.throws(()=>T.procedural(route(),[535,550,560,560,550,535],
        settings([520,480,540,470,530,...flatRoad.slice(5)])),/approach road elevation is inconsistent/);
});

test('three cliff samples cannot outvote two coherent outer road samples',()=>{
    assert.throws(()=>T.procedural(route(),[560,570,580,580,570,560],
        settings([560,560,560,500,500,...flatRoad.slice(5)])),/approach road elevation is inconsistent/);
});

test('legacy tangent uses all five samples to recover a modest cliff-cell error',()=>{
    const m=T.procedural(route({roadApproaches:null}),[525,550,560,560,550,525],
        settings([540,530,500,500,500,540,530,500,500,500]));
    assert.deepEqual(m.portalFloorMethods,['tangent-grade-estimate','tangent-grade-estimate']);
    assert.ok(Math.abs(m.sections[0].floorMetersWgs84-499.9)<1e-6);
});

test('a rejected five-point tangent check cannot be bypassed by its first two coherent samples',()=>{
    const m=T.procedural(route({kind:'underpass',roadApproaches:null}),Array(6).fill(510),
        settings([520,520,540,470,530,520,520,540,470,530]));
    assert.deepEqual(m.portalFloorMethods,['terrain-fallback','terrain-fallback']);
    assert.ok(Math.abs(m.sections[0].floorMetersWgs84-509.9)<1e-6);
});

test('serial gallery and tunnel keep one road level while cover checks follow the source intervals',()=>{
    const r=route({coordinates:[0,20,40,60,80,100,120,140,160,180,200].map(at),
        roadApproaches:[[-4,-8,-12,-16,-20].map(at),[204,208,212,216,220].map(at)],
        coveredIntervals:[{start:0,end:60,kind:'underpass'},{start:60,end:200,kind:'tunnel'}]});
    const m=T.procedural(r,[500,500,500,500,520,525,530,525,520,515,500],settings(flatRoad));
    assert.ok(m.sections.every(s=>Math.abs(s.floorMetersWgs84-499.9)<1e-6),
        'exposed gallery is not forced below its terrain surface');
    assert.equal(m.portalClipMask[0],false,'gallery entrance does not acquire a rock aperture');
});

test('cropped long tunnel waits for original endpoint heights instead of anchoring to mountain crop edges',()=>{
    const r=route({partial:true,portalEnds:[false,false],profileStartDistance:1000,
        profileTotalDistance:5000});
    assert.throws(()=>T.procedural(r,[800,850,900,900,850,800],settings(flatRoad)),
        /Original tunnel endpoint elevations unavailable/);
    assert.throws(()=>T.procedural(r,[800,850,900,900,850,800],{
        ...settings(flatRoad),globalEndpointHeights:[500,null]}),
        /Original tunnel endpoint elevations unavailable/);
});
