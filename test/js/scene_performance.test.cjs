'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {create}=require('../../web/core/scene_performance.js');
class Event{
    constructor(){this.listeners=new Set();}
    addEventListener(listener){this.listeners.add(listener);return ()=>this.listeners.delete(listener);}
    fire(){for(const listener of this.listeners)listener();}
}
function fixture(capacity=16){
    const preRender=new Event(),postRender=new Event(),scene={preRender,postRender};
    let time=0;let resourceQueries=0;
    const profiler=create({scene},{capacity,now:()=>time,resources:()=>{
        resourceQueries++;
        return {resident:2,visible:1,pending:0,estimatedTilesetBytes:2048};
    }});
    function frame(interval=16,duration=4){
        time+=interval;preRender.fire();time+=duration;postRender.fire();
    }
    return {profiler,frame,scene,preRender,postRender,setTime:value=>time=value,resourceQueries:()=>resourceQueries};
}
test('scene timing is disabled by default and never polls resources per frame',()=>{
    const f=fixture();f.frame();
    assert.equal(f.preRender.listeners.size,0);
    assert.equal(f.postRender.listeners.size,0);
    assert.equal(f.profiler.snapshot().frames,0);
    f.profiler.start();f.frame();f.frame();
    assert.equal(f.profiler.snapshot().frames,2);
    assert.equal(f.resourceQueries(),2,'resources are read only on snapshot');
    assert.equal(f.profiler.snapshot().tilesets.estimatedBytes,2048);
    f.profiler.dispose();assert.equal(f.preRender.listeners.size,0);
    assert.equal(f.postRender.listeners.size,0);
    f.frame();assert.equal(f.profiler.snapshot().frames,0);
    assert.throws(()=>f.profiler.start(),/disposed/);
});
test('bounded samples report CPU callbacks and pacing without counting idle gaps as dropped frames',()=>{
    const f=fixture();f.profiler.start();
    for(let i=0;i<32;i++)f.frame(16,4);
    let s=f.profiler.snapshot();
    assert.equal(s.frames,32);
    assert.equal(s.renderSamples,16);
    assert.equal(s.intervalSamples,16);
    assert.equal(s.cpuRenderMs.p50,4);
    assert.equal(s.over33Ms,0);
    f.frame(1000,5);s=f.profiler.snapshot();
    assert.equal(s.frames,33);
    assert.equal(s.over33Ms,0,'idle gap excluded from continuous pacing');
    f.frame(50,6);s=f.profiler.snapshot();
    assert.equal(s.over33Ms,1);
    assert.ok(s.framePacingMs.p95>=20);
    assert.match(s.caveat,/not GPU time/);
    f.profiler.stop();f.frame();assert.equal(f.profiler.snapshot().frames,34);
    f.profiler.start();assert.equal(f.profiler.snapshot().frames,0);
    f.profiler.dispose();
});
test('stopping and restarting never accumulates Cesium listeners; invalid capacity is rejected',()=>{
    for(const cap of [0,15,601,NaN,2.5])assert.throws(()=>fixture(cap));
    const f=fixture();
    for(let i=0;i<10;i++){
        f.profiler.start();f.profiler.start();
        assert.equal(f.preRender.listeners.size,1);assert.equal(f.postRender.listeners.size,1);
        f.profiler.stop();f.profiler.stop();
        assert.equal(f.preRender.listeners.size,0);assert.equal(f.postRender.listeners.size,0);
    }
    f.profiler.dispose();
});

test('continuous flight reports long stutters while background time is excluded',()=>{
    const preRender=new Event(),postRender=new Event();
    let time=0,foreground=true,continuous=true;
    const profiler=create({scene:{preRender,postRender}}, {now:()=>time,
        isContinuous:()=>continuous,isForeground:()=>foreground});
    const frame=(gap,duration)=>{time+=gap;preRender.fire();time+=duration;postRender.fire();};
    profiler.start();frame(16,4);frame(500,320);
    let status=profiler.snapshot();
    assert.equal(status.framePacingMs.max,504,'500 ms in-flight hitch is not hidden as idle time');
    assert.equal(status.cpuRenderMs.max,320,'a slow actual render is always measured');
    assert.equal(status.over100Ms,1);
    foreground=false;frame(1000,4);foreground=true;frame(1000,4);
    assert.equal(profiler.snapshot().over100Ms,1,'background/resume does not look like a flight hitch');
    continuous=false;frame(2000,4);
    assert.equal(profiler.snapshot().over100Ms,1,'idle map time is still excluded');
    profiler.dispose();
});

test('opt-in integration timing is bounded, stops recording, and resets across sessions',()=>{
    const f=fixture();let calls=0;const integrate=dt=>{assert.equal(dt,1/120);calls++;f.setTime(calls*2);return 42;};
    assert.equal(f.profiler.measurePhysicsStep(integrate,1/120),42);
    assert.equal(f.profiler.snapshot().physicsStep.count,0);
    f.profiler.start();for(let i=0;i<40;i++)f.profiler.measurePhysicsStep(integrate,1/120);
    let s=f.profiler.snapshot().physicsStep;assert.equal(s.count,40);assert.equal(s.samples,16);assert.equal(s.totalMs,80);assert.equal(s.p95Ms,2);
    f.profiler.stop();f.profiler.measurePhysicsStep(integrate,1/120);assert.equal(f.profiler.snapshot().physicsStep.count,40);
    f.profiler.start();assert.equal(f.profiler.snapshot().physicsStep.count,0);f.profiler.dispose();
});


test('FPS uses actual frame intervals and reports idle age rather than inventing a rate',()=>{
    const f=fixture();f.profiler.start();
    assert.equal(f.profiler.snapshot().renderFps,null);
    f.frame(16,4);f.frame(16,4);f.frame(16,4);
    assert.equal(f.profiler.snapshot().renderFps,50);
    f.setTime(3000);
    assert.ok(f.profiler.snapshot().frameAgeMs>1500);
    f.profiler.stop();
    assert.equal(f.preRender.listeners.size,0);assert.equal(f.postRender.listeners.size,0);
});


test('extended diagnostics separate observed update, render and animation cadence, then release observers',()=>{
    let time=0,id=0,foreground=true;
    const callbacks=new Map(),preUpdate=new Event(),postUpdate=new Event(),preRender=new Event(),postRender=new Event();
    const gl={getExtension:n=>n==='WEBGL_debug_renderer_info'?{UNMASKED_VENDOR_WEBGL:1,UNMASKED_RENDERER_WEBGL:2}:null,
        getParameter:n=>({1:'Test GPU vendor',2:'Test GPU renderer',3:'WebGL 2.0'})[n],VERSION:3,drawingBufferWidth:1920,drawingBufferHeight:1080};
    const scene={preUpdate,postUpdate,preRender,postRender,canvas:{width:1920,height:1080,clientWidth:960,clientHeight:540}};
    const viewer={scene,resolutionScale:1};
    const p=create(viewer,{capacity:16,now:()=>time,gpuContext:()=>gl,isForeground:()=>foreground,
        requestFrame:cb=>{callbacks.set(++id,cb);return id;},cancelFrame:key=>callbacks.delete(key),
        resources:()=>({terrainProvider:'BKG DGM5'})});
    const frame=stamp=>{const [key,cb]=callbacks.entries().next().value;callbacks.delete(key);cb(stamp);};
    p.start();p.recordTerrainProgress(3);time=5;p.recordTerrainProgress(7);
    preUpdate.fire();time+=6;postUpdate.fire();time+=2;preRender.fire();time+=4;postRender.fire();
    time=30;p.recordTerrainProgress(0);
    for(let i=0;i<20;i++)frame(i*16.6667);
    const s=p.snapshot();
    assert.equal(s.cpuUpdateMs.p95,6);assert.equal(s.cpuRenderMs.p95,4);assert.equal(s.cpuSceneMs.p95,12);
    assert.equal(s.canvas.bufferWidth,1920);assert.equal(s.canvas.cssWidth,960);assert.equal(s.renderer.renderer,'Test GPU renderer');assert.equal(s.renderer.unmasked,true);
    assert.ok(Math.abs(s.animationCadence.medianHz-60)<.1);assert.equal(s.animationCadence.samples,16);
    assert.equal(s.terrainProvider,'BKG DGM5');assert.deepEqual(s.terrainStreaming,{pending:0,peak:7,activeMs:null,lastBatchMs:30,batches:1});
    foreground=false;frame(10000);foreground=true;frame(11000);assert.ok(Math.abs(p.snapshot().animationCadence.medianHz-60)<.1);
    p.stop();assert.equal(callbacks.size,0);assert.equal(preUpdate.listeners.size,0);assert.equal(postUpdate.listeners.size,0);
    p.start();assert.equal(p.snapshot().cpuSceneMs.samples,0);assert.equal(p.snapshot().terrainStreaming.batches,0);p.dispose();assert.equal(callbacks.size,0);
});

test('long-task metrics are opt-in, session bounded and distinguish unsupported engines',()=>{
    const scene={preRender:new Event(),postRender:new Event(),frameState:{commandList:[1,2,3]}};
    let observer;
    class Observer{
        static supportedEntryTypes=['longtask'];
        constructor(cb){this.cb=cb;observer=this;this.records=[];}
        observe(options){assert.deepEqual(options,{type:'longtask',buffered:false});}
        takeRecords(){return this.records.splice(0);}
        disconnect(){this.disconnected=true;}
    }
    const profiler=create({scene},{now:()=>100,Observer});
    assert.equal(profiler.snapshot().mainThreadLongTasks.supported,false);
    profiler.start();observer.records.push({startTime:90,duration:80},{startTime:110,duration:55},{startTime:180,duration:75});
    assert.deepEqual(profiler.snapshot().mainThreadLongTasks,{supported:true,count:2,totalMs:130,maxMs:75});
    assert.equal(profiler.snapshot().sceneCommands.count,3);
    profiler.stop();assert.equal(observer.disconnected,true);
    profiler.start();assert.equal(profiler.snapshot().mainThreadLongTasks.count,0);profiler.dispose();
});


test('benchmark can omit GPU queries while retaining CPU frame timing; next normal session restores GPU timing',()=>{
    const preRender=new Event(),postRender=new Event();let time=0,queries=0;
    const gl={getExtension(name){if(name==='EXT_disjoint_timer_query_webgl2')queries++;return null;}};
    const p=create({scene:{preRender,postRender}},{now:()=>time,gpuContext:()=>gl});
    assert.throws(()=>p.start({gpuTiming:'false'}),/Invalid GPU timing/);assert.equal(p.running,false);
    p.start({gpuTiming:false});for(let i=0;i<3;i++){time+=16;preRender.fire();time+=4;postRender.fire();}
    const snapshot=p.snapshot();assert.equal(queries,0);assert.equal(snapshot.gpuRenderMs.enabled,false);assert.equal(snapshot.gpuRenderMs.samples,0);
    assert.equal(snapshot.cpuRenderMs.p50,4);assert.equal(snapshot.renderFps,50);
    p.stop();p.start();assert.equal(queries,1);assert.equal(p.snapshot().gpuRenderMs.enabled,true);p.dispose();
});
