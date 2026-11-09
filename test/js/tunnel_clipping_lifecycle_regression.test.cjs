'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs'),T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
for(const name of ['HTMLCanvasElement','HTMLImageElement','ImageBitmap','OffscreenCanvas','HTMLVideoElement'])globalThis[name]??=class {};
const scale=6378137*Math.PI/180,longitude=8.6,latitude=46.7;
const point=(east,north,height=502)=>({longitude:longitude+east/(scale*Math.cos(latitude*Math.PI/180)),latitude:latitude+north/scale,height});
const section=(east,north,floor=500)=>({...point(east,north),floorMetersWgs84:floor,widthMeters:8,heightMeters:6});
const bent={kind:'tunnel',profile:'rectangular',portalEnds:[false,false],
    sections:[section(0,-100),section(0,-60),section(0,-20),section(0,0),section(20,0),section(60,0)]};
function contains(spec,p){
    const east=(p.longitude-spec.longitude)*scale*Math.cos(spec.latitude*Math.PI/180),north=(p.latitude-spec.latitude)*scale;
    const along=east*spec.forward.east+north*spec.forward.north,side=-east*spec.forward.north+north*spec.forward.east;
    const up=p.height-spec.floor-(along<0?spec.approachGrade??spec.grade:spec.grade)*along;
    return Math.abs(side)<spec.halfWidth&&along>-spec.before&&along<spec.after&&up>-spec.below&&up<spec.above;
}
function setup(){
    const listeners=new Set(),primitives=[];let clock=1000,material,assignments=0;
    const globe={clippingPlanes:{length:0},clippingPolygons:{length:0}};
    Object.defineProperty(globe,'material',{get:()=>material,set:value=>{material=value;assignments++;}});
    const viewer={camera:{viewMatrix:C.Matrix4.IDENTITY,heading:0},scene:{context:{webgl2:true},globe,
        preUpdate:{addEventListener:fn=>{listeners.add(fn);return()=>listeners.delete(fn);}},requestRender(){},
        primitives:{add:p=>{primitives.push(p);return p;},remove:p=>{const i=primitives.indexOf(p);if(i>=0)primitives.splice(i,1);}}}};
    const move=(east,north,elapsed=500)=>{
        const p=point(east,north);viewer.camera.positionCartographic={longitude:p.longitude*Math.PI/180,latitude:p.latitude*Math.PI/180,height:p.height};
        clock+=elapsed;for(const listener of listeners)listener();
    };
    move(0,-10,0);
    const service=T.create(C,viewer,()=>{},{isSimulating:()=>true,now:()=>clock});
    service.importModel({version:1,elevationReference:'WGS84_ELLIPSOID',source:'Clipping lifecycle fixture',profile:bent.profile,sections:bent.sections});
    service.model.portalEnds=[false,false];service.activate();
    return {viewer,service,move,assignments:()=>assignments};
}

test('flight cuts follow a sharp bore bend and keep unrelated rock outside their bounded frames',()=>{
    const p=point(0,-10),old=T.flightClipSpec(bent,p),specs=T.flightClipSpecs(bent,p);
    assert.ok(!contains(old,point(12,0)),'one tangent box misses the outgoing bore');
    assert.equal(specs.length,2,'nearly straight samples merge into one frame on either side of the bend');
    for(const p of [point(0,-18),point(0,-3),point(3,0),point(12,0),point(25,0)])
        assert.ok(specs.some(spec=>contains(spec,p)),JSON.stringify(p));
    assert.ok(specs.every(spec=>!contains(spec,point(12,12))),'diagonal rock outside the actual bores is retained');
    assert.ok(specs.every(spec=>spec.interior&&T.clippingVolume(C,spec)),'all curve frames remain bounded valid masks');
});

test('moving flight cuts keep one owned Material and existing vector uniforms across bends and active-count changes',()=>{
    const f=setup();
    try{
        const material=f.viewer.scene.globe.material,source=material.shaderSource,
            bounds=material.uniforms.apertureBounds,origin=material.uniforms.apertureOriginHigh;
        const assignments=f.assignments();let revision=f.service.apertureRevision();
        for(const [east,north] of [[0,-9],[0,-2],[4,0],[18,0],[38,0],[50,0],[0,-35]]){
            f.move(east,north);
            assert.equal(f.viewer.scene.globe.material,material);
            assert.equal(material.shaderSource,source);
            assert.equal(material.uniforms.apertureBounds,bounds);
            assert.equal(material.uniforms.apertureOriginHigh,origin);
            assert.ok(f.service.apertureRevision()>revision);revision=f.service.apertureRevision();
            for(let index=f.service.apertureSpecs().length;index<T.PORTAL_APERTURE_BUDGETS.balanced;index++)
                assert.equal(material.uniforms[`apertureBounds${index||''}`].x,0,'unused slots are disabled');
        }
        assert.equal(f.assignments(),assignments,'movement never reassigns Globe.material or dirties its shader set');
        f.move(0,-35,50);assert.equal(f.service.apertureRevision(),revision,'eye-only updates do not change the aperture revision');
        f.move(0,-35,500);assert.equal(f.service.apertureRevision(),revision,'an unchanged selection does not publish a false revision');
        assert.equal(material.isDestroyed(),false);
    }finally{f.service.dispose();}
});

test('in-place uniform updates validate without native clipping collections and never mutate foreign materials',()=>{
    const spec=T.flightClipSpecs(bent,point(0,-10))[0];
    const numeric={...C,ClippingPlaneCollection:class {constructor(){throw Error('Unexpected native clipping allocation');}}};
    const material=T.slopeClipMaterial(numeric,[spec],C.Matrix4.IDENTITY,{capacity:3});
    assert.ok(material);
    const vectors=Object.values(material.uniforms);
    assert.equal(T.updateSlopeClipSpecs(numeric,material,[spec,{...spec,floor:501}],C.Matrix4.IDENTITY),true);
    assert.ok(Object.values(material.uniforms).every((value,index)=>value===vectors[index]));
    const before=material.uniforms.apertureBounds.x;
    assert.equal(T.updateSlopeClipSpecs(numeric,material,[{...spec,halfWidth:100}],C.Matrix4.IDENTITY),false);
    assert.equal(material.uniforms.apertureBounds.x,before,'invalid updates leave the active material intact');
    const foreign=C.Material.fromType('Color');
    assert.equal(T.updateSlopeClipSpecs(C,foreign,[spec],C.Matrix4.IDENTITY),false);
    material.destroy();foreign.destroy();
});

test('a nearby true portal and upcoming bend both remain selected on the compatibility budget',()=>{
    const f=setup();
    try{
        // Move the true source mouth to 20 m before the bend.
        f.service.model.sections=f.service.model.sections.slice(2);
        f.service.model.portalEnds=[true,false];
        f.service.setPerformanceProfile('compatibility');f.move(0,-10);
        const specs=f.service.apertureSpecs();
        assert.equal(specs.length,2);
        assert.ok(specs.some(spec=>!spec.interior),'the measured physical entry corridor keeps its portal mask');
        assert.ok(specs.some(spec=>contains(spec,point(12,0))),'the remaining slot opens the outgoing bore');
    }finally{f.service.dispose();}
});
