'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs');
for(const name of ['HTMLCanvasElement','HTMLImageElement','ImageBitmap','OffscreenCanvas','HTMLVideoElement'])
    globalThis[name]??=class {};
const T=require('../../web/scene_environment.js').FPVTunnelFlythrough;
const scale=111319.49079327358,lon=8.6,lat=46.7;
const at=metres=>[lon,lat+metres/scale];
const route={id:'falling-bore',kind:'tunnel',transport:'road',
    coordinates:[0,20,40,60,80,100].map(at),
    roadApproaches:[[-4,-8,-12,-16,-20].map(at),[104,108,112,116,120].map(at)],
    roadApproachKinds:['bridge','road'],bridgeDeckSampled:[true,false]};

test('flat bridge and road retain their measured grade before a descending bore at both portals',()=>{
    const model=T.procedural(route,[502,530,540,540,530,492],{profile:'vaulted',
        portalApproachHeights:[500,500,500,500,500,490,490,490,490,490]});
    const start=T.boundedClipSpec(model,0),end=T.boundedClipSpec(model,1);
    assert.ok(Math.abs(start.grade+.1)<1e-9);
    assert.ok(Math.abs(end.grade-.1)<1e-9);
    assert.equal(start.approachGrade,0);
    assert.equal(end.approachGrade,0);
    assert.ok(Math.abs(model.portalApproachProfiles[0].floor-499.9)<1e-9);
    assert.equal(model.portalApproachProfiles[0].samples.length,5);
    const u=T.apertureUniforms(C,start);
    assert.equal(u.apertureBounds.w,0,'outside road grade uses the spare bounded-aperture component');
    assert.ok(Math.abs(u.apertureRoof.w+.1)<1e-9,'inside bore grade remains independent');
    const p={longitude:lon,latitude:at(-15)[1],height:500.5};
    assert.ok(Math.abs(T.portalApproachFloor(model,p,0,{...start,before:24})-499.9)<1e-7,
        'a drone half a metre above the bridge is not below an invented upward ramp');
});

test('connected approach fit retains its direction and outlier rejection instead of inheriting tunnel grade',()=>{
    const road={...route,roadApproachKinds:['road','road']};
    const model=T.procedural(road,[510,530,540,540,530,492],{profile:'vaulted',
        portalApproachHeights:[499.6,499.2,520,498.4,498,490,490,490,490,490]});
    const start=T.boundedClipSpec(model,0);
    assert.ok(Math.abs(start.approachGrade-.1)<1e-8,'falling outward road rises inward');
    assert.notEqual(start.approachGrade,start.grade);
    assert.equal(model.portalApproachProfiles[0].samples.length,4);
    const p={longitude:lon,latitude:at(-16)[1],height:498.9};
    assert.ok(Math.abs(T.portalApproachFloor(model,p,0,{...start,before:24})-498.3)<1e-7);
});

test('piecewise grade uses the same bounded mask for Globe and loaded model walls',()=>{
    const spec={longitude:lon,latitude:lat,floor:500,forward:{east:0,north:1},halfWidth:3,
        before:24,after:26,below:1.1,above:5.75,shape:'vaulted',roofRise:2.25,
        grade:-.1,approachGrade:0};
    const material=T.slopeClipMaterial(C,spec),modelShader=require('../../web/scene_environment.js')
        .modelPortalShaderOptions(C,[spec]);
    assert.equal(material.uniforms.apertureBounds.w,0);
    assert.equal(modelShader.uniforms.fpvApertureBounds.value.w,0);
    assert.equal(material.uniforms.apertureRoof.w,-.1);
    assert.match(T.portalClipShaderSource(),/along < 0\.0 \? bounds\.w : apertureRoof\.w/);
    assert.equal(T.apertureUniforms(C,{...spec,approachGrade:.6}),null,
        'implausible road grades never authorize an aperture');
    const legacy=T.apertureUniforms(C,{...spec,approachGrade:undefined});
    assert.equal(legacy.apertureBounds.w,-.1,'explicit/legacy models preserve their existing grade');
});

test('moving flight masks cannot replace a measured road approach with the bore grade',()=>{
    const model=T.procedural(route,[502,530,540,540,530,492],{profile:'vaulted',
        portalApproachHeights:[500,500,500,500,500,490,490,490,490,490]});
    const pose=(along,height=500.5)=>({longitude:lon,latitude:at(along)[1],height});
    assert.equal(T.flightClipSpec(model,pose(-4)),null,
        'before the real entrance, the measured portal cut owns the opening');
    assert.equal(T.flightClipSpec(model,pose(104,490.5)),null,
        'the far real exit keeps its independent road approach too');
    const interior=T.flightClipSpec(model,pose(.01));
    assert.equal(interior.interior,true);
    assert.equal(T.portalApproachFloor(model,pose(-3),0,interior),null,
        'an almost coincident interior origin cannot shadow the real portal floor');
    assert.ok(T.flightClipSpec({...model,portalEnds:[false,true]},pose(-4)),
        'artificial window boundaries retain their overlapping interior mask');
});
