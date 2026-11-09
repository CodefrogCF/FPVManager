'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const Actual=require('../../web/cesium/index.cjs');
const T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
for(const name of ['HTMLCanvasElement','HTMLImageElement','ImageBitmap','OffscreenCanvas','HTMLVideoElement'])
    globalThis[name]??=class {};
const route={id:'geometry-budget',kind:'underpass',transport:'road',source:'CPU fixture',
    coordinates:Array.from({length:96},(_,i)=>[8.2+Math.sin(i*.16)*.0001,46.8+i*18/111319.49079327358])};
function measuredCesium(){
    const counts={fromDegrees:0,geometries:0,instances:0};
    class Cartesian3 extends Actual.Cartesian3{
        static fromDegrees(...args){counts.fromDegrees++;return Actual.Cartesian3.fromDegrees(...args);}
    }
    class Geometry extends Actual.Geometry{constructor(options){super(options);counts.geometries++;}}
    class GeometryInstance extends Actual.GeometryInstance{constructor(options){super(options);counts.instances++;}}
    return {C:{...Actual,Cartesian3,Geometry,GeometryInstance},counts};
}
function createViewer(){
    const items=[];
    return {items,viewer:{scene:{globe:{getHeight:()=>500,clippingPolygons:{length:0}},
        primitives:{add:p=>{items.push(p);return p;},remove:p=>{
            const i=items.indexOf(p);if(i>=0)items.splice(i,1);p.destroy?.();return i>=0;}},requestRender(){}}}};
}
function values(geometry){return Array.from(geometry.attributes.position.values);}
test('a full 96-section detailed window builds its source surfaces once and retains two exact opaque passes',async()=>{
    const model=T.procedural(route,Array(96).fill(500),{profile:'vaulted'});
    const reference=measuredCesium();
    const surfaces=T.texturedSurfaceGeometries(reference.C,model);
    const paint=surfaces.filter(surface=>surface.kind==='marking');
    assert.equal(paint.length,1);assert.ok(paint[0].geometry.indices.length>500,'the fixture includes many lane dashes');
    for(const profile of ['balanced','quality']){
        const {C,counts}=measuredCesium(),f=createViewer();
        const service=T.create(C,f.viewer,()=>{},{sampleTerrain:async points=>points.map(()=>500)});
        service.setPerformanceProfile(profile);service.setAutomaticEnabled(true);
        try{
            assert.equal((await service.setAutomaticRoutes([route],{longitude:8.2,
                latitude:46.8+855/111319.49079327358})).count,1);
            assert.equal(service.diagnostics().entries[0].sections,96);
            const collection=f.items.find(p=>p instanceof Actual.PrimitiveCollection);
            assert.ok(collection);assert.equal(collection.length,2);
            const lining=collection.get(0),markings=collection.get(1);
            assert.equal(lining.appearance.isTranslucent(),false);
            assert.equal(markings.appearance.isTranslucent(),false);
            assert.equal(lining.appearance.getRenderState().depthMask,true);
            assert.equal(markings.appearance.getRenderState().depthMask,true);
            assert.deepEqual(values(markings.geometryInstances[0].geometry),values(paint[0].geometry));
            assert.deepEqual(Array.from(markings.geometryInstances[0].geometry.indices),Array.from(paint[0].geometry.indices));
            assert.ok(counts.geometries<=reference.counts.geometries,
                'painting must not rebuild a second copy of every wall and roof');
            assert.equal(counts.instances,surfaces.length,'every allocated instance belongs to an actual draw pass');
            assert.ok(counts.fromDegrees<=reference.counts.fromDegrees+64,
                'drawing and portal guides retain one full source-to-ECEF surface conversion');
        }finally{service.dispose();}
    }
});
test('performance mode also avoids rebuilding its already prepared solid-colour surfaces',async()=>{
    const model=T.procedural(route,Array(96).fill(500),{profile:'vaulted'}),reference=measuredCesium();
    const surfaces=T.surfaceGeometries(reference.C,model),{C,counts}=measuredCesium(),f=createViewer();
    const service=T.create(C,f.viewer,()=>{},{sampleTerrain:async points=>points.map(()=>500)});
    service.setPerformanceProfile('performance');service.setAutomaticEnabled(true);
    try{
        assert.equal((await service.setAutomaticRoutes([route],{longitude:8.2,
            latitude:46.8+855/111319.49079327358})).count,1);
        const primitive=f.items.find(p=>p instanceof Actual.Primitive);
        assert.ok(primitive);assert.equal(primitive.geometryInstances.length,surfaces.length);
        assert.equal(counts.geometries,reference.counts.geometries);
        assert.equal(counts.instances,surfaces.length);
        assert.ok(counts.fromDegrees<=reference.counts.fromDegrees+64);
        assert.equal(primitive.appearance.isTranslucent(),false);
    }finally{service.dispose();}
});
