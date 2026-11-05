'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {FPVSceneModelCollision}=require('../../web/scene_environment.js');
function fixture({top=130,ground=100,models=true,supported=true}={}){
    let calls=0;
    const C={Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},SceneMode:{SCENE3D:3}};
    const viewer={scene:{mode:3,sampleHeightSupported:supported,
        sampleHeight:()=>{calls++;return top;},globe:{getHeight:()=>ground}}};
    const probe=FPVSceneModelCollision.create(C,viewer,{hasVisibleModels:()=>models});
    const a={latitude:46.8,longitude:8.2,height:130};
    const b={latitude:46.8,longitude:8.20001,height:130};
    return {probe,a,b,viewer,attempts:()=>calls};
}
test('rendered 3D model contact is explicitly opt-in, bounded and never a clearance claim',()=>{
    const f=fixture();
    assert.equal(f.probe.collision(f.a,f.b),false);
    assert.equal(f.attempts(),0);
    assert.throws(()=>f.probe.setEnabled('true'),/Invalid/);
    f.probe.setEnabled(true);
    assert.equal(f.probe.collision(f.a,f.b),'model');
    assert.ok(f.attempts()<=9);
    assert.equal(f.probe.collision({...f.a,height:125},{...f.b,height:125}),false);
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
