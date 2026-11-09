'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {FPVSceneModelCollision}=require('../../web/scene_environment.js');
function fixture({top=130,ground=100,models=true,supported=true,cost=0,postRender=true}={}){
    let calls=0,time=1000,job=0,lastPoint=null;
    const timers=new Map(),listeners=new Set();
    const C={Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},SceneMode:{SCENE3D:3}};
    const viewer={scene:{mode:3,sampleHeightSupported:supported,
        sampleHeight:point=>{calls++;time+=cost;lastPoint=point;return top;},globe:{getHeight:()=>ground}}};
    if(postRender)viewer.scene.postRender={addEventListener:fn=>{listeners.add(fn);return ()=>listeners.delete(fn);}};
    const probe=FPVSceneModelCollision.create(C,viewer,{hasVisibleModels:()=>models,now:()=>time,
        setTimer:fn=>{timers.set(++job,fn);return job;},clearTimer:id=>timers.delete(id)});
    const a={latitude:46.8,longitude:8.2,height:130},b={...a,longitude:8.200001};
    const render=()=>{for(const listener of listeners)listener();};
    const flush=()=>{render();for(const [id,fn] of [...timers]){timers.delete(id);fn();}};
    return {probe,a,b,viewer,render,flush,timers,listeners,attempts:()=>calls,
        lastPoint:()=>lastPoint,advance:ms=>{time+=ms}};
}

test('rendered model collision only consumes cached depth and coalesces sweeps after the visible frame',()=>{
    const f=fixture();assert.equal(f.probe.collision(f.a,f.b),false);f.flush();assert.equal(f.attempts(),0);
    assert.throws(()=>f.probe.setEnabled('true'),/Invalid/);f.probe.setEnabled(true);
    for(let i=0;i<1000;i++)assert.equal(f.probe.collision(f.a,f.b),false);
    assert.equal(f.attempts(),0,'no GPU readback inside the simulation');
    assert.equal(f.timers.size,0,'waits until the visible frame finishes');
    f.render();assert.equal(f.attempts(),0);assert.equal(f.timers.size,1);
    f.flush();assert.equal(f.attempts(),1);assert.equal(f.probe.collision(f.a,f.b),'model');
    assert.equal(f.probe.collision(f.a,{...f.b,height:130.1}),false,
        'one uncertain contact per probe cannot repeatedly brake every escape step');
    assert.equal(f.probe.collision({...f.a,height:145},{...f.b,height:145}),false);
    assert.equal(f.probe.collision(f.a,{...f.b,longitude:8.22}),false,'large jumps cannot borrow a cached roof');
    f.probe.dispose();assert.equal(f.listeners.size,0);assert.equal(f.probe.collision(f.a,f.b),false);
});

test('unsupported depth, unloaded layers, terrain-only positions and 2D mode fail open',()=>{
    for(const options of [{supported:false},{models:false},{top:100}]){
        const f=fixture(options);f.probe.setEnabled(true);f.probe.collision(f.a,f.b);f.flush();
        assert.equal(f.probe.collision(f.a,f.b),false);f.probe.dispose();
    }
    const f=fixture();f.probe.setEnabled(true);f.viewer.scene.mode=2;
    assert.equal(f.probe.collision(f.a,f.b),false);f.flush();assert.equal(f.attempts(),0);
    f.viewer.scene.mode=3;f.viewer.scene.sampleHeight=()=>{throw Error('depth unavailable');};
    f.probe.collision(f.a,f.b);assert.doesNotThrow(f.flush);assert.equal(f.probe.collision(f.a,f.b),false);
    f.probe.dispose();
});

test('cached deck top stays collidable and the space beneath a bridge stays clear',()=>{
    const f=fixture({top:140,ground:100});f.probe.setEnabled(true);
    let rays=0;f.viewer.scene.pickFromRay=()=>{rays++;throw Error('must not raycast during flight');};
    const from={...f.a,height:113},to={...f.b,height:113};
    f.probe.collision(from,to);f.flush();
    for(let i=0;i<1000;i++)assert.equal(f.probe.collision(from,to),false);
    assert.equal(f.probe.collision({...from,height:139.5},{...to,height:139.5}),'model');
    assert.equal(rays,0);assert.equal(f.attempts(),1);
    f.advance(351);f.probe.collision(from,to);assert.equal(f.attempts(),1);f.flush();assert.equal(f.attempts(),2);
    assert.equal(f.probe.status().approximate,true);f.probe.dispose();
});

test('slow GPU probe preserves adaptive cooldown and cannot supply stale or distant roof heights',()=>{
    const f=fixture({top:140,cost:75});f.probe.setEnabled(true);
    const a={...f.a,height:139.5},below={...a,height:113};
    f.probe.collision(below,below);f.flush();assert.equal(f.probe.collision(below,below),false);
    f.advance(400);f.probe.collision(below,below);f.flush();assert.equal(f.attempts(),1,'75 ms query imposes 900 ms cooldown');
    assert.equal(f.probe.collision(a,{...a,longitude:a.longitude+.00003}),false,'cannot spread a roof two metres sideways');
    f.advance(200);assert.equal(f.probe.collision(a,a),false,'cached result expires after 500 ms');
    f.flush();assert.equal(f.attempts(),1);
    f.advance(400);assert.equal(f.probe.collision(a,a),false);f.flush();assert.equal(f.attempts(),2);
    assert.equal(f.probe.collision(a,a),'model');assert.equal(f.probe.status().lastSampleMs,75);f.probe.dispose();
});

test('latest pending position wins; disabling or disposing cancels deferred probes',()=>{
    const f=fixture();f.probe.setEnabled(true);f.probe.collision(f.a,f.b);f.render();
    const latest={...f.b,longitude:8.20002};f.probe.collision(latest,latest);f.flush();
    assert.deepEqual(f.lastPoint(),{latitude:latest.latitude,longitude:latest.longitude});
    assert.equal(f.probe.collision(f.a,f.a),false);assert.equal(f.probe.collision(latest,latest),'model');
    f.advance(400);f.probe.collision(latest,latest);f.render();f.probe.setEnabled(false);f.flush();
    assert.equal(f.attempts(),1);assert.equal(f.probe.collision(latest,latest),false);
    f.probe.setEnabled(true);f.probe.collision(latest,latest);f.render();f.probe.dispose();f.flush();assert.equal(f.attempts(),1);
});

test('minimal scenes also defer depth queries instead of falling back to synchronous sampling',()=>{
    const f=fixture({postRender:false});f.probe.setEnabled(true);
    f.probe.collision(f.a,f.b);assert.equal(f.attempts(),0);assert.equal(f.timers.size,1);
    f.flush();assert.equal(f.attempts(),1);assert.equal(f.probe.collision(f.a,f.b),'model');f.probe.dispose();
});
