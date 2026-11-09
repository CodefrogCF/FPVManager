'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs');
const T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
for(const name of ['HTMLCanvasElement','HTMLImageElement','ImageBitmap','OffscreenCanvas','HTMLVideoElement'])
    globalThis[name]??=class {};
const route={id:'slope-road',kind:'tunnel',transport:'road',
    coordinates:[[8.2,46.8],[8.2001,46.8],[8.2002,46.8]]};
const model=()=>T.procedural(route,[500,520,500],{profile:'vaulted'});
function scene(){
    const entries=[];
    const previous={length:0};
    const viewer={scene:{globe:{clippingPolygons:previous,clippingPlanes:previous},
        context:{webgl2:true},primitives:{add:p=>{entries.push(p);return p;},
            remove:p=>{const i=entries.indexOf(p);if(i>=0)entries.splice(i,1);}},requestRender(){}}};
    return {viewer,previous};
}

test('real Cesium aperture retains transparent imagery and uses a precise local frame',()=>{
    const spec=T.boundedClipSpec(model(),0),material=T.slopeClipMaterial(C,spec);
    assert.ok(material instanceof C.Material);
    assert.match(material.shaderSource,/dFdx\(positionEC\)/);
    assert.match(material.shaderSource,/dFdy\(positionEC\)/);
    assert.match(material.shaderSource,/0\.422618262/,'65 degree geometric slope threshold');
    assert.match(material.shaderSource,/material\.alpha = 0\.0/,'existing globe imagery survives');
    const u=material.uniforms;
    const origin=C.Cartesian3.add(u.apertureOriginHigh,u.apertureOriginLow,new C.Cartesian3());
    assert.ok(C.Cartesian3.distance(origin,C.Cartesian3.fromDegrees(8.2,46.8,499.9))<.001);
    for(const axis of [u.apertureEast,u.apertureNorth,u.apertureUp])
        assert.ok(Math.abs(C.Cartesian3.magnitude(axis)-1)<1e-8);
    assert.ok(Math.abs(C.Cartesian3.dot(u.apertureUp,u.apertureNorth))<1e-8);
    assert.equal(u.apertureBounds.y,spec.before);
    assert.equal(u.apertureBounds.z,spec.after);
    assert.equal(u.apertureRoof.z,spec.roofRise);
    material.destroy();
});

test('Globe enables the aperture on terrain without encoded vertex normals',()=>{
    const spec=T.boundedClipSpec(model(),0);
    for(const view of [null,C.Matrix4.IDENTITY]){
        const material=T.slopeClipMaterial(C,spec,view);
        // Globe's material setup uses these exact substring checks, including
        // comments. Mentioning "ordinary slopes" silently disabled the whole
        // aperture on terrain providers that do not encode vertex normals.
        assert.doesNotMatch(material.shaderSource,/slope|normalEC/);
        material.destroy();
    }
});

test('CPU eye origins follow a moving camera without rebuilding aperture geometry',()=>{
    const spec=T.boundedClipSpec(model(),0),origin=C.Cartesian3.fromDegrees(
        spec.longitude,spec.latitude,spec.floor);
    const eye=C.Cartesian3.fromDegrees(spec.longitude-.001,spec.latitude-.001,spec.floor+20);
    const local=C.Transforms.eastNorthUpToFixedFrame(eye),view=C.Matrix4.inverse(local,new C.Matrix4());
    const material=T.slopeClipMaterial(C,spec,view);
    assert.doesNotMatch(material.shaderSource,/czm_translateRelativeToEye/);
    assert.ok(C.Cartesian3.distance(material.uniforms.apertureOriginHigh,
        C.Matrix4.multiplyByPoint(view,origin,new C.Cartesian3()))<1e-8);
    const moved=C.Matrix4.multiply(C.Matrix4.fromTranslation(new C.Cartesian3(2,-4,1)),view,new C.Matrix4());
    assert.equal(T.updateSlopeClipMaterial(C,material,moved),true);
    assert.ok(C.Cartesian3.distance(material.uniforms.apertureOriginHigh,
        C.Matrix4.multiplyByPoint(moved,origin,new C.Cartesian3()))<1e-8);
    assert.equal(C.Cartesian3.magnitude(material.uniforms.apertureOriginLow),0);
    material.destroy();
});

test('automatic aperture preserves another terrain material and never falls back to native clipping',async()=>{
    const {viewer,previous}=scene(),foreign=C.Material.fromType('Color');
    viewer.scene.globe.material=foreign;
    const service=T.create(C,viewer,()=>{}, {sampleTerrain:async points=>points.map(()=>500)});
    service.setAutomaticEnabled(true);
    await service.setAutomaticRoutes([{...route,coordinates:route.coordinates.slice(0,2)}],
        {longitude:8.2,latitude:46.8});
    assert.equal(service.status().autoCount,1);
    assert.equal(viewer.scene.globe.material,foreign);
    assert.equal(viewer.scene.globe.clippingPlanes,previous);
    assert.equal(viewer.scene.globe.clippingPolygons,previous);
    service.dispose();
    assert.equal(viewer.scene.globe.material,foreign);
    foreign.destroy();
});

test('unsupported slope clipping leaves all terrain intact while displaying the tunnel mesh',async()=>{
    const {viewer,previous}=scene();viewer.scene.context.webgl2=false;
    const service=T.create(C,viewer,()=>{}, {sampleTerrain:async points=>points.map(()=>500)});
    service.setAutomaticEnabled(true);
    await service.setAutomaticRoutes([{...route,coordinates:route.coordinates.slice(0,2)}],
        {longitude:8.2,latitude:46.8});
    assert.equal(service.status().autoCount,1);
    assert.equal(viewer.scene.globe.material,undefined);
    assert.equal(viewer.scene.globe.clippingPlanes,previous);
    assert.equal(viewer.scene.globe.clippingPolygons,previous);
    service.dispose();
});

test('imported cross-section tunnels use the same floor-preserving aperture lifecycle',()=>{
    const {viewer,previous}=scene();
    const service=T.create(C,viewer);
    service.importModel({version:1,source:'explicit test cross sections',
        elevationReference:'WGS84_ELLIPSOID',profile:'vaulted',sections:model().sections});
    assert.ok(viewer.scene.globe.material instanceof C.Material);
    service.activate();
    assert.equal(viewer.scene.globe.clippingPolygons,previous);
    assert.equal(viewer.scene.globe.clippingPlanes,previous);
    service.stop();
    assert.equal(viewer.scene.globe.material,undefined);
    service.dispose();
});

test('a covered gallery can activate without excavating terrain or requiring an aperture',async()=>{
    const {viewer,previous}=scene();viewer.scene.context.webgl2=false;
    const service=T.create(C,viewer,()=>{}, {sampleTerrain:async points=>points.map(()=>500)});
    await service.prepare({...route,kind:'underpass'});
    assert.equal(service.model.kind,'covered-way');
    service.activate();
    assert.equal(service.flight,true);
    assert.equal(viewer.scene.globe.material,undefined);
    assert.equal(viewer.scene.globe.clippingPlanes,previous);
    assert.equal(viewer.scene.globe.clippingPolygons,previous);
    service.dispose();
});
