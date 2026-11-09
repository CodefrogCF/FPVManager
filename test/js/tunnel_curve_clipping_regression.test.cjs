'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs'),T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
for(const name of ['HTMLCanvasElement','HTMLImageElement','ImageBitmap','OffscreenCanvas','HTMLVideoElement'])globalThis[name]??=class {};
const scale=111319.49079327358,lat=46.7,lon=8.6;
const point=(x,y,z=502)=>({longitude:lon+x/(scale*Math.cos(lat*Math.PI/180)),latitude:lat+y/scale,height:z});
const document={version:1,elevationReference:'WGS84_ELLIPSOID',source:'bounded right-angle bore',profile:'rectangular',
    sections:[[0,-20],[0,0],[0,12],[12,12],[28,12]].map(([x,y])=>({...point(x,y),
        floorMetersWgs84:500,widthMeters:6,heightMeters:5}))};
function contains(spec,p){
    const x=(p.longitude-spec.longitude)*scale*Math.cos(spec.latitude*Math.PI/180),y=(p.latitude-spec.latitude)*scale,
        along=x*spec.forward.east+y*spec.forward.north,across=-x*spec.forward.north+y*spec.forward.east,
        up=p.height-spec.floor-(along<0?spec.approachGrade??spec.grade??0:spec.grade??0)*along;
    return Math.abs(across)<spec.halfWidth&&along>-spec.before&&along<spec.after&&up> -spec.below&&up<spec.above;
}
test('local flight apertures follow a bend missed by the old single tangent box',()=>{
    const model=T.importSections(document),p={...point(0,4),heading:0},target=point(10,12);
    assert.equal(contains(T.flightClipSpec(model,p),target),false);
    const masks=T.flightClipSpecs(model,p);
    assert.ok(masks.length>=2);
    assert.ok(masks.some(spec=>contains(spec,target)),'next section of the physical bore is cut too');
    assert.ok(!masks.some(spec=>contains(spec,point(10,30))),'rock outside the bend stays intact');
    for(let y=-3;y<=12;y+=.5)assert.ok(masks.some(spec=>contains(spec,point(0,y))),`continuous approach to bend at ${y}`);
    for(let x=0;x<=20;x+=.5)assert.ok(masks.some(spec=>contains(spec,point(x,12))),`continuous outgoing bore at ${x}`);
});
test('two-slot profile keeps the portal and upcoming bend connected without replacing the material',()=>{
    let clock=1000,frame=()=>{},material=null,assignments=0;
    const globe={clippingPlanes:{length:0},clippingPolygons:{length:0}};
    Object.defineProperty(globe,'material',{get:()=>material,set:v=>{assignments++;material=v;}});
    const viewer={camera:{positionCartographic:null,heading:0,viewMatrix:C.Matrix4.IDENTITY},scene:{globe,context:{webgl2:true},
        preUpdate:{addEventListener:f=>{frame=f;return()=>{};}},primitives:{add:p=>p,remove:()=>true},requestRender(){}}};
    const service=T.create(C,viewer,()=>{},{now:()=>clock,isSimulating:()=>true});
    const move=(x,y,heading=0)=>{const p=point(x,y);viewer.camera.heading=heading;
        viewer.camera.positionCartographic={longitude:p.longitude*Math.PI/180,latitude:p.latitude*Math.PI/180,height:p.height};
        clock+=500;frame();};
    move(0,4);service.setPerformanceProfile('compatibility');service.importModel(document);service.activate();
    try{
        const original=material,bounds=material.uniforms.apertureBounds;
        const masks=service.apertureSpecs();assert.equal(masks.length,2);
        for(let y=-18;y<=12;y+=.5)assert.ok(masks.some(spec=>contains(spec,point(0,y))),`no gap before bend at ${y}`);
        assert.ok(masks.some(spec=>contains(spec,point(10,12))));
        const before=service.apertureRevision(),writes=assignments;
        for(const p of [[0,6],[0,9],[0,11],[3,12],[9,12],[15,12]])move(...p,p[0]?Math.PI/2:0);
        assert.equal(material,original);
        assert.equal(material.uniforms.apertureBounds,bounds);
        assert.equal(assignments,writes,'ordinary movement never reassigns Globe.material');
        assert.ok(service.apertureRevision()>before,'native model masks can observe changed uniform positions');
    }finally{service.dispose();}
});
