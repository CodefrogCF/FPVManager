'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs'),E=require('../../web/scene_environment.js'),T=E.FPVTunnelFlythrough;
for(const name of ['HTMLCanvasElement','HTMLImageElement','ImageBitmap','OffscreenCanvas','HTMLVideoElement'])globalThis[name]??=class {};
function event(){const listeners=new Set();return {addEventListener:f=>{listeners.add(f);return()=>listeners.delete(f);},fire:()=>{for(const f of listeners)f();}};}
const coordinates=i=>[[8.6+i*.002,46.7],[8.6002+i*.002,46.7]];
test('several visible portals remain open beyond the old 110 metre centre-ray limit',async()=>{
    const preUpdate=event(),primitives=[],viewer={camera:{positionCartographic:{longitude:8.6*Math.PI/180,
        latitude:46.7*Math.PI/180,height:1500}},scene:{context:{webgl2:true},preUpdate,
        globe:{getHeight:()=>500,clippingPolygons:{length:0},clippingPlanes:{length:0}},requestRender(){},
        primitives:{add:p=>{primitives.push(p);return p;},remove:p=>{const i=primitives.indexOf(p);if(i>=0)primitives.splice(i,1);}}}};
    let clock=1000;
    const service=T.create(C,viewer,()=>{}, {sampleTerrain:async points=>points.map(()=>500),now:()=>clock});
    service.setAutomaticEnabled(true);
    try{
        const routes=Array.from({length:3},(_,i)=>({id:`peripheral-${i}`,kind:'tunnel',transport:'road',coordinates:coordinates(i)}));
        const result=await service.setAutomaticRoutes(routes,{longitude:8.6,latitude:46.7045,height:500});
        assert.equal(result.count,3);
        assert.equal(service.apertureSpecs().length,6,'all six mouths are eligible despite foreground focus ~500 m away');
        assert.equal(service.diagnostics().clipped,6);
        assert.ok(viewer.scene.globe.material.uniforms.apertureBounds5);
        const copy=service.apertureSpecs();copy[0].forward.east=100;
        assert.notEqual(service.apertureSpecs()[0].forward.east,100);
        service.setPerformanceProfile('compatibility');await new Promise(resolve=>setImmediate(resolve));
        clock+=1000;preUpdate.fire();assert.equal(service.apertureSpecs().length,2);
    }finally{service.dispose();}
    assert.equal(viewer.scene.globe.material,undefined);
});
test('portal aperture follows the source road grade through the opening',()=>{
    const model={kind:'tunnel',profile:'vaulted',sections:[
        {longitude:8.6,latitude:46.7,floorMetersWgs84:500,widthMeters:6,heightMeters:5},
        {longitude:8.6,latitude:46.70018,floorMetersWgs84:504,widthMeters:6,heightMeters:5}]};
    const spec=T.boundedClipSpec(model,0),uniforms=T.apertureUniforms(C,spec);
    assert.ok(spec.grade>.19&&spec.grade<.21);
    assert.equal(uniforms.apertureRoof.w,spec.grade);
    const cut=T.clippingVolume(C,spec),local=new C.Cartesian3(0,20,spec.grade*20+2);
    for(let i=0;i<cut.length;i++)assert.ok(C.Cartesian3.dot(cut.get(i).normal,local)+cut.get(i).distance<0);
    cut.destroy();
});
test('3D model walls share the exact terrain aperture equations and unused masks stay inactive',()=>{
    const spec={longitude:8.6,latitude:46.7,floor:500,forward:{east:0,north:1},
        halfWidth:3.5,before:8,after:26,below:1,above:6,grade:.1,shape:'rectangular'};
    const options=E.modelPortalShaderOptions(C,[spec]),shader=new C.CustomShader(options);
    assert.match(shader.fragmentShaderText,/fsInput\.attributes\.positionEC/);
    assert.match(shader.fragmentShaderText,/fpvPortalClips\(positionEC, face\)/);
    assert.match(shader.fragmentShaderText,/0\.422618262/);
    assert.equal(shader.uniforms.fpvApertureRoof.value.w,.1);
    assert.equal(shader.uniforms.fpvApertureBounds1.value.x,0);
    shader.destroy();
});
