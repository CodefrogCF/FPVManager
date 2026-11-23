'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs');
const T=require('../../web/features/scene/scene_environment.js').FPVTunnelFlythrough;
for(const name of ['HTMLCanvasElement','HTMLImageElement','ImageBitmap','OffscreenCanvas','HTMLVideoElement'])
    globalThis[name]??=class {};

const lat=46.7,lon=8.6,scale=111319.49079327358;
const coordinate=(distance,offset=0)=>[lon+offset/(scale*Math.cos(lat*Math.PI/180)),lat+distance/scale];
const route=(transport='road')=>({id:`minimal-${transport}`,kind:'tunnel',transport,
    coordinates:[coordinate(0),coordinate(60),coordinate(120)]});
const model=(transport='road',profile='vaulted')=>
    T.procedural(route(transport),[500,545,500],{profile,widthMeters:6,heightMeters:5});
const xyz=(p)=>C.Cartesian3.fromDegrees(...p);
const autoRoute=(transport='road')=>({...route(transport),
    coordinates:[0,30,60,90,120].map(distance=>coordinate(distance))});

function noFrontCap(surfaces,m){
    // In contrast to the original facade annulus, every generated lining
    // triangle must span part of the bore: no triangle may lie entirely in
    // either endpoint's cross-sectional plane.
    for(const end of [0,1]){
        const section=end===0?m.sections[0]:m.sections.at(-1),
            adjacent=end===0?m.sections[1]:m.sections.at(-2);
        const origin=C.Cartesian3.fromDegrees(section.longitude,section.latitude,section.floorMetersWgs84);
        const neighbor=C.Cartesian3.fromDegrees(adjacent.longitude,adjacent.latitude,adjacent.floorMetersWgs84);
        const normal=C.Cartesian3.normalize(C.Cartesian3.subtract(neighbor,origin,new C.Cartesian3()),new C.Cartesian3());
        for(const surface of surfaces){
            assert.notEqual(surface.kind,'portal-surround','no oversized rock/concrete front material');
            const vertices=surface.geometry.attributes.position.values;
            for(let index=0;index<vertices.length;index+=9){
                const signed=[];
                for(let v=0;v<3;v++){
                    const i=index+v*3,point=new C.Cartesian3(vertices[i],vertices[i+1],vertices[i+2]);
                    signed.push(C.Cartesian3.dot(C.Cartesian3.subtract(point,origin,new C.Cartesian3()),normal));
                }
                assert.ok(signed.some(distance=>Math.abs(distance)>.035),
                    `${surface.kind} contains a solid triangle across the ${end?'exit':'entry'} plane`);
            }
        }
    }
}

test('road and railway portals, vaulted and rectangular, have open mouths in all material modes',()=>{
    for(const transport of ['road','railway'])for(const profile of ['vaulted','rectangular']){
        const m=model(transport,profile),collisionBefore=T.collisionMesh(m).triangleCount;
        for(const generator of [T.surfaceGeometries,T.texturedSurfaceGeometries]){
            const surfaces=generator(C,m);
            assert.ok(surfaces.length>=3);
            noFrontCap(surfaces,m);
            for(const kind of ['road','walls','ceiling'])assert.ok(surfaces.some(s=>s.kind===kind));
            if(transport==='road')assert.ok(surfaces.some(s=>s.kind==='marking'&&s.geometry.indices.length>0));
            else assert.ok(surfaces.every(s=>s.kind!=='marking'));
        }
        assert.equal(T.collisionMesh(m).triangleCount,collisionBefore,
            'removing visual front triangles must not change tunnel collision');
        const r=T.rings(m);
        assert.equal(r.length,m.sections.length);
        assert.ok(r[0].length>=4);
    }
});

test('steep portals and cropped source windows never create synthetic front faces',()=>{
    const m=model(),cropped={...m,portalEnds:[false,true],partial:true};
    for(const target of [m,cropped])for(const generator of [T.surfaceGeometries,T.texturedSurfaceGeometries])
        noFrontCap(generator(C,target),target);
    assert.equal(T.geometry(C,m).indices.length,T.geometry(C,cropped).indices.length,
        'culling a source portal must not change flyable bore geometry');
});

const terrain=positions=>positions.map(p=>{
    const distance=(p.latitude-lat)*scale;
    return distance>15&&distance<105?545:500;
});

function fixture(){
    const items=[];
    class PolylineCollection{
        constructor(){this.lines=[];}
        add(line){this.lines.push(line);return line;}
    }
    const cesium={...C,PolylineCollection},viewer={scene:{context:{webgl2:true},
        globe:{clippingPlanes:{length:0},clippingPolygons:{length:0},getHeight:()=>undefined},
        primitives:{add(p){items.push(p);return p;},remove(p){const i=items.indexOf(p);
            if(i>=0)items.splice(i,1);return i>=0;}},requestRender(){}}};
    return {items,cesium,viewer};
}

test('automatic portals retain only the existing orange outline aligned to the bore',async()=>{
    for(const transport of ['road','railway']){
        const f=fixture(),source=autoRoute(transport),service=T.create(f.cesium,f.viewer,()=>{},
            {sampleTerrain:async positions=>terrain(positions)});
        service.setPerformanceProfile('balanced');service.setAutomaticEnabled(true);
        try{
            const result=await service.setAutomaticRoutes([source],{longitude:lon,latitude:lat});
            assert.equal(result.count,1,JSON.stringify(service.diagnostics()));
            const guide=f.items.find(item=>Array.isArray(item.lines));
            assert.ok(guide,'endpoint outlines must remain visible');
            assert.equal(guide.lines.length,2);
            const tunnel=T.procedural(source,[500,545,545,545,500],{profile:'vaulted',widthMeters:6,heightMeters:5});
            for(const end of [0,1]){
                const line=guide.lines[end];
                assert.equal(line.width,3);
                assert.ok(line.material instanceof C.Material);
                assert.equal(line.material.uniforms.color.red,1);
                assert.ok(line.material.uniforms.color.green>.65&&line.material.uniforms.color.green<.7);
                const ring=T.rings(tunnel)[end===0?0:tunnel.sections.length-1];
                assert.equal(line.positions.length,ring.length+1);
                for(let i=0;i<ring.length;i++)assert.ok(C.Cartesian3.distance(line.positions[i],xyz(ring[i]))<.05,
                    `orange outline must match the physical ${transport} bore at vertex ${i}`);
                assert.ok(C.Cartesian3.distance(line.positions[0],line.positions.at(-1))<1e-8,
                    'the border closes at the edge, not across the opening');
            }
            const solids=f.items.filter(item=>item instanceof C.PrimitiveCollection||item instanceof C.Primitive);
            assert.equal(solids.length,1,'only one tunnel scene object, plus the shared polyline guide');
            if(transport==='road'){
                assert.ok(solids[0] instanceof C.PrimitiveCollection);
                assert.equal(solids[0].length,2,'road paint retains its independent opaque pass');
                assert.equal(solids[0].get(0).geometryInstances.length,4,
                    'no separate front-facade geometry instances');
            }else{
                assert.ok(solids[0] instanceof C.Primitive);
                assert.equal(solids[0].geometryInstances.length,4,
                    'rail tube has only the existing lining material groups');
            }
        }finally{service.dispose();}
        assert.equal(f.items.length,0,'guides and tunnel are released together');
    }
});

test('cropped/underground endpoints cannot acquire a floating orange portal',async()=>{
    const f=fixture(),source={...autoRoute(),portalEnds:[false,true]};
    const service=T.create(f.cesium,f.viewer,()=>{}, {sampleTerrain:async positions=>terrain(positions)});
    service.setAutomaticEnabled(true);
    try{
        const result=await service.setAutomaticRoutes([source],{longitude:lon,latitude:lat});
        assert.equal(result.count,1,JSON.stringify(service.diagnostics()));
        const guide=f.items.find(item=>Array.isArray(item.lines));
        assert.ok(guide);
        assert.equal(guide.lines.length,1,'only genuine source portal ends receive an orange border');
    }finally{service.dispose();}
});
