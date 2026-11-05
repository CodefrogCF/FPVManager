'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {create}=require('../../web/scene_performance.js');
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
