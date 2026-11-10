/* Synthetic scheduling microbenchmark. Does not measure hardware FPS/GPU. */
'use strict';
const {performance}=require('node:perf_hooks');
const {create}=require('../web/scene_environment.js');
class Event{
    constructor(){this.listeners=new Set();}
    addEventListener(listener){this.listeners.add(listener);return ()=>this.listeners.delete(listener);}
    fire(){for(const f of this.listeners)f();}
}
async function main(){
    const frames=Number(process.argv[2]??10000);
    if(!Number.isSafeInteger(frames)||frames<100||frames>1000000)throw Error('Frame count must be 100..1000000');
    const counts={showWrites:0,budgetWrites:0,requests:0,loads:0,removes:0};
    const C={JulianDate:{clone:d=>({...d}),fromIso8601:s=>({s})},ClockStep:{SYSTEM_CLOCK:2},SunLight:class{},
        Credit:class{},ShadowMode:{DISABLED:0},Cesium3DTileset:{fromUrl:async(_,options)=>{
            counts.loads++;
            const tile={...options,show:false,tileFailed:new Event(),loadProgress:new Event(),
                isDestroyed:()=>false,destroy(){}};
            for(const key of ['show','maximumScreenSpaceError','cacheBytes','maximumCacheOverflowBytes']){
                let current=tile[key];
                Object.defineProperty(tile,key,{get:()=>current,set(value){
                    counts[key==='show'?'showWrites':'budgetWrites']++;current=value;
                }});
            }
            return tile;
        }}};
    const preUpdate=new Event();
    const viewer={clock:{currentTime:{s:'now'},clockStep:1,shouldAnimate:false},camera:{positionCartographic:{height:1000}},
        cesiumWidget:{creditDisplay:{addStaticCredit(){},removeStaticCredit(){}}},
        scene:{globe:{enableLighting:false},preUpdate,requestRender(){counts.requests++;},
            primitives:{add(){},remove(tile){counts.removes++;tile.destroy();}}}};
    const manager=create(C,viewer);
    const preference={buildings:true,vegetation:true,structures:true,lighting:false};
    manager.set(preference);
    await new Promise(resolve=>setImmediate(resolve));
    const startCounts={...counts};
    const start=performance.now();
    for(let i=0;i<frames;i++)preUpdate.fire();
    for(let i=0;i<100;i++)manager.set(preference);
    const elapsedMs=+(performance.now()-start).toFixed(2);
    const delta=Object.fromEntries(Object.keys(counts).map(key=>[key,counts[key]-startCounts[key]]));
    viewer.camera.positionCartographic.height=30000;preUpdate.fire();
    viewer.camera.positionCartographic.height=1000;preUpdate.fire();
    const crossings=counts.showWrites-startCounts.showWrites;
    const resources=manager.resourceStats();manager.dispose();
    console.log(JSON.stringify({fixture:'synthetic',frames,repeatCommands:100,elapsedMs,
        stablePhase:delta,heightCrossingShowWrites:crossings,resources,
        note:'Property-write microbenchmark only. Actual GPU/FPS must be measured with scene-performance on a device.'},null,2));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
