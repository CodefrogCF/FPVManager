const test=require('node:test'),assert=require('node:assert/strict');
const {create,time}=require('../../web/scene_environment.js');
class Event{
    constructor(){this.listeners=new Set();}
    addEventListener(f){this.listeners.add(f);return ()=>this.listeners.delete(f);}
    fire(...v){for(const f of this.listeners)f(...v);}
}
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(loader){
    const requests=[],states=[],primitives=[],credits=new Set(),timers=new Map();let nextTimer=0;
    const C={JulianDate:{clone:x=>({...x}),fromIso8601:value=>({value})},ClockStep:{SYSTEM_CLOCK:2},SunLight:class{},Credit:class{},ShadowMode:{DISABLED:0},
        Cesium3DTileset:{fromUrl:(url,options)=>{requests.push({url,options});return loader?.(url,options)??Promise.resolve(tile(options));}}};
    const viewer={clock:{currentTime:{value:'2026-01-01T12:00:00.000Z'},clockStep:1,shouldAnimate:false},camera:{positionCartographic:{height:1000}},
        cesiumWidget:{creditDisplay:{addStaticCredit:c=>credits.add(c),removeStaticCredit:c=>credits.delete(c)}},
        scene:{light:{original:true},globe:{enableLighting:false,dynamicAtmosphereLightingFromSun:false},preUpdate:new Event(),requestRender(){},
            primitives:{add:p=>primitives.push(p),remove:p=>{primitives.splice(primitives.indexOf(p),1);p.destroy();}}}};
    function tile(options){let destroyed=false;return {...options,tileFailed:new Event(),loadProgress:new Event(),destroy(){destroyed=true;},isDestroyed:()=>destroyed};}
    const manager=create(C,viewer,(type,event)=>states.push({type,...event}),{setTimer:f=>{timers.set(++nextTimer,f);return nextTimer;},clearTimer:id=>timers.delete(id)});
    const set=(options={})=>manager.set({buildings:false,vegetation:false,lighting:false,...options});
    return {manager,set,C,viewer,requests,states,primitives,credits,timers,tile};
}
test('3D sources are opt-in and toggling retains loaded tiles without new imports or credits',async()=>{
    const p=fixture();p.set();await flush();assert.equal(p.requests.length,0);
    p.set({buildings:true});p.set({buildings:true});await flush();
    assert.equal(p.requests.length,1);const model=p.primitives[0];assert.ok(model.show);assert.equal(p.credits.size,1);
    p.set();assert.equal(model.show,false);assert.equal(model.isDestroyed(),false);assert.equal(p.credits.size,0);
    p.set({buildings:true});assert.equal(p.requests.length,1);assert.equal(model.show,true);
    p.viewer.camera.positionCartographic.height=30000;p.viewer.scene.preUpdate.fire();assert.equal(model.show,false);
    p.viewer.camera.positionCartographic.height=1000;p.viewer.scene.preUpdate.fire();assert.equal(model.show,true);
    p.manager.dispose();assert.ok(model.isDestroyed());assert.equal(p.credits.size,0);assert.equal(p.timers.size,0);
});
test('metadata failure, timeout and late completion stay local to the layer and allow retry',async()=>{
    let resolve;const p=fixture(()=>new Promise(r=>resolve=r));p.set({vegetation:true});await flush();
    const late=p.tile({});[...p.timers.values()][0]();resolve(late);await flush();
    assert.ok(late.isDestroyed());assert.equal(p.primitives.length,0);assert.equal(p.states.at(-1).state,'failed');
    p.set({vegetation:true,retry:'vegetation'});await flush();const replacement=p.tile({});resolve(replacement);await flush();
    assert.equal(p.primitives[0],replacement);assert.equal(p.states.at(-1).state,'ready');
    replacement.tileFailed.fire();assert.equal(p.states.at(-1).state,'partial');assert.ok(replacement.show);
    replacement.loadProgress.fire(0,0);assert.equal(p.states.at(-1).state,'partial');
    p.manager.dispose();assert.equal(replacement.tileFailed.listeners.size,0);
    const q=fixture(()=>Promise.reject(Error('offline')));q.set({buildings:true});await flush();
    assert.equal(q.states.at(-1).state,'failed');assert.ok(q.states.every(e=>e.type==='scene-layer-status'));q.manager.dispose();
});
test('disposal rejects late results and loading uses the current flight budget',async()=>{
    let resolve;const p=fixture(()=>new Promise(r=>resolve=r));p.set({buildings:true});await flush();
    p.manager.performance('performance');const model=p.tile({});resolve(model);await flush();
    assert.equal(model.maximumScreenSpaceError,40);assert.ok(model.cacheBytes+model.maximumCacheOverflowBytes<=32*1024*1024);
    assert.equal(model.shadows,0);assert.equal(model.preloadWhenHidden,false);
    p.manager.performance('quality');assert.equal(model.maximumScreenSpaceError,12);assert.ok(model.cacheBytes<=48*1024*1024);p.manager.dispose();
    const q=fixture(()=>new Promise(r=>resolve=r));q.set({buildings:true});await flush();q.manager.dispose();const late=q.tile({});resolve(late);await flush();
    assert.ok(late.isDestroyed());assert.equal(q.primitives.length,0);assert.equal(q.timers.size,0);
});
test('fixed route and flight times have scoped priority and restore current map lighting',()=>{
    const p=fixture();const initial=p.viewer.clock.currentTime;p.set({lighting:true});assert.equal(p.viewer.clock.clockStep,2);
    p.manager.setTime({scope:'route',enabled:true,timeUtc:'2026-06-21T12:00:00Z'});assert.equal(p.viewer.clock.currentTime.value,'2026-06-21T12:00:00.000Z');assert.equal(p.viewer.clock.shouldAnimate,false);
    p.manager.setTime({scope:'flight',enabled:true,timeUtc:'2026-12-21T17:00:00Z'});assert.equal(p.viewer.clock.currentTime.value,'2026-12-21T17:00:00.000Z');
    p.manager.setTime({scope:'flight',enabled:false});assert.equal(p.viewer.clock.currentTime.value,'2026-06-21T12:00:00.000Z');
    p.manager.setTime({scope:'route',enabled:false});assert.equal(p.viewer.clock.clockStep,2);
    p.set();assert.deepEqual(p.viewer.clock.currentTime,initial);assert.equal(p.viewer.scene.globe.enableLighting,false);
    p.manager.setTime({scope:'route',enabled:true});assert.equal(p.viewer.scene.globe.enableLighting,true);p.manager.dispose();
});
test('calendar times reject malformed, out-of-range and timezone-ambiguous values',()=>{
    for(const value of ['yesterday','2026-02-31T12:00:00Z','1800-01-01T12:00:00Z','2026-06-01T12:00:00','2026-06-01T12:00:00+02:00'])assert.throws(()=>time(value));
    assert.equal(time('2026-06-01T12:00:00.123456Z'),'2026-06-01T12:00:00.123Z');assert.equal(time(null),null);
});

test('sun lighting remains active close to ground for satellite and relief imagery and restores defaults',()=>{
 const p=fixture(),g=p.viewer.scene.globe;
 Object.assign(g,{lightingFadeInDistance:20000000,lightingFadeOutDistance:10000000,
  nightFadeInDistance:50000000,nightFadeOutDistance:10000000,vertexShadowDarkness:.3});
 // Capture a fresh manager after configuring the source defaults.
 p.manager.dispose();const manager=create(p.C,p.viewer);
 manager.set({buildings:false,vegetation:false,lighting:true});
 assert.equal(g.lightingFadeOutDistance,0);assert.equal(g.lightingFadeInDistance,1);
 assert.equal(g.nightFadeOutDistance,0);assert.equal(g.nightFadeInDistance,1);
 assert.equal(g.vertexShadowDarkness,.06);
 manager.set({buildings:false,vegetation:false,lighting:false});
 assert.equal(g.lightingFadeOutDistance,10000000);assert.equal(g.lightingFadeInDistance,20000000);
 assert.equal(g.nightFadeOutDistance,10000000);assert.equal(g.nightFadeInDistance,50000000);
 assert.equal(g.vertexShadowDarkness,.3);manager.dispose();
});
