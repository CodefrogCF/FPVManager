'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {FPVSceneModelCollision}=require('../../web/scene_environment.js');
function fixture({top=130,ground=100,models=true,supported=true}={}){
    let calls=0,time=1000;
    const C={Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},SceneMode:{SCENE3D:3}};
    const viewer={scene:{mode:3,sampleHeightSupported:supported,
        sampleHeight:()=>{calls++;return top;},globe:{getHeight:()=>ground}}};
    const probe=FPVSceneModelCollision.create(C,viewer,{hasVisibleModels:()=>models,now:()=>time});
    const a={latitude:46.8,longitude:8.2,height:130};
    const b={latitude:46.8,longitude:8.20001,height:130};
    return {probe,a,b,viewer,attempts:()=>calls,advance:ms=>{time+=ms}};
}
test('rendered 3D model contact is explicitly opt-in, bounded and never a clearance claim',()=>{
    const f=fixture();
    assert.equal(f.probe.collision(f.a,f.b),false);
    assert.equal(f.attempts(),0);
    assert.throws(()=>f.probe.setEnabled('true'),/Invalid/);
    f.probe.setEnabled(true);
    assert.equal(f.probe.collision(f.a,f.b),'model');
    assert.equal(f.attempts(),1,'one bounded height probe, no multi-ray sampling');
    f.advance(500);
    assert.equal(f.probe.collision({...f.a,height:145},{...f.b,height:145}),false);
    assert.equal(f.probe.collision({...f.a,height:130},{...f.b,longitude:8.22,height:130}),false,'too large for synchronous bounded sampling');
    f.probe.dispose();assert.equal(f.probe.collision(f.a,f.b),false);
});
test('unsupported depth, unloaded layers, terrain-only positions and 2D mode fail open',()=>{
    for(const options of [{supported:false},{models:false},{top:100}]){
        const f=fixture(options);f.probe.setEnabled(true);assert.equal(f.probe.collision(f.a,f.b),false);f.probe.dispose();
    }
    const f=fixture();f.probe.setEnabled(true);
    f.viewer.scene.mode=2;assert.equal(f.probe.collision(f.a,f.b),false);
    f.viewer.scene.mode=3;
    f.viewer.scene.sampleHeight=()=>{throw Error('depth unavailable')};
    assert.equal(f.probe.collision(f.a,f.b),false);
    f.probe.dispose();
});

test('does not treat the empty volume beneath a bridge deck as solid',()=>{
    const f=fixture({top:140,ground:100});
    let rayCalls=0;
    f.viewer.scene.pickFromRay=()=>{rayCalls++;throw Error('must not raycast during flight');};
    f.probe.setEnabled(true);
    const from={...f.a,height:113},to={...f.b,height:113};
    assert.equal(f.probe.collision(from,to),false,'open underside is not a solid volume');
    for(let i=0;i<1000;i++)f.probe.collision(from,to);
    assert.equal(rayCalls,0);
    assert.equal(f.attempts(),1,'depth sample throttled across 1000 simulation frames');
    f.advance(351);
    f.probe.collision(from,to);
    assert.equal(f.attempts(),2);
    assert.equal(f.probe.status().approximate,true);
    f.probe.dispose();
});
test('slow GPU samples trigger an adaptive cooldown rather than repeated frame stalls',()=>{
    let time=1000,calls=0;
    const C={Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},SceneMode:{SCENE3D:3}};
    const viewer={scene:{mode:3,sampleHeightSupported:true,globe:{getHeight:()=>100},
        sampleHeight:()=>{calls++;time+=75;return 140;}}};
    const probe=FPVSceneModelCollision.create(C,viewer,{hasVisibleModels:()=>true,now:()=>time});
    probe.setEnabled(true);
    const a={latitude:46.8,longitude:8.2,height:139.5};
    assert.equal(probe.collision(a,a),'model');
    time+=400;assert.equal(probe.collision(a,a),false);
    assert.equal(calls,1,'slow sample imposes 900ms cooldown');
    time+=600;assert.equal(probe.collision(a,a),'model');
    assert.equal(calls,2);
    probe.dispose();
});

test('the rendered deck top remains collidable while the space below stays clear',()=>{
    const f=fixture({top:110,ground:95});
    f.probe.setEnabled(true);
    assert.equal(f.probe.collision({...f.a,height:100},{...f.b,height:100}),false);
    f.advance(400);
    assert.equal(f.probe.collision({...f.a,height:109.5},{...f.b,height:109.5}),'model');
    f.probe.dispose();
});
