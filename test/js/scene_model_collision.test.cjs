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

test('loaded 3D tile side-wall raycast detects a horizontal impact below its roof',()=>{
    function Cartesian3(x,y,z){this.x=x;this.y=y;this.z=z;}
    Cartesian3.fromDegrees=(longitude,latitude,height)=>new Cartesian3(longitude*100000,latitude*100000,height);
    const C={Cartesian3,Ray:class{constructor(origin,direction){this.origin=origin;this.direction=direction;}},
        Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},
        SceneMode:{SCENE3D:3}};
    let picks=0;
    const scene={mode:3,globe:{getHeight:()=>100},sampleHeightSupported:true,sampleHeight:()=>140,
        pickFromRay:ray=>{picks++;return {object:{content:{tileset:{}}},
            position:new Cartesian3(ray.origin.x+ray.direction.x,ray.origin.y+ray.direction.y,ray.origin.z+ray.direction.z)};}};
    const model=FPVSceneModelCollision.create(C,{scene},{hasVisibleModels:()=>true});
    model.setEnabled(true);
    const a={longitude:8.2,latitude:46.8,height:113},b={longitude:8.20002,latitude:46.8,height:113};
    assert.equal(model.collision(a,b),'model','side walls work even when below the model roof');
    assert.ok(picks>=1&&picks<=3,'raycast budget');
    scene.pickFromRay=ray=>({object:{name:'unidentified-terrain'},position:ray.origin});
    assert.equal(model.collision(a,b),false,'unidentified terrain is not a building wall');
    scene.pickFromRay=ray=>({object:{content:{tileset:{}}},position:new Cartesian3(ray.origin.x+1000,ray.origin.y,ray.origin.z)});
    assert.equal(model.collision(a,b),false,'out-of-segment hit must not block flight');
    model.dispose();
});
