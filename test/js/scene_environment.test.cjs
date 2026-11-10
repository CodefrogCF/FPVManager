const test=require('node:test'),assert=require('node:assert/strict');
const {create,time}=require('../../web/scene_environment.js');
class Event{
    constructor(){this.listeners=new Set();}
    addEventListener(f){this.listeners.add(f);return ()=>this.listeners.delete(f);}
    fire(...v){for(const f of this.listeners)f(...v);}
}
const flush=()=>new Promise(resolve=>setImmediate(resolve));

test('bridge supports follow infrastructure visibility, opacity, graphics profile and disposal',async()=>{
    const values={enabled:false,opacity:1,profile:'balanced',refresh:0,disposed:false};
    const bridgeSupports={setEnabled:v=>{values.enabled=v;},setOpacity:v=>{values.opacity=v;},
        performance:v=>{values.profile=v;},refresh:()=>{values.refresh++;},dispose:()=>{values.disposed=true;}};
    const f=fixture(null,{bridgeSupports});
    f.set({structures:true,structuresOpacity:.6});await flush();
    assert.equal(values.enabled,true);
    assert.equal(values.opacity,.6);
    assert.equal(values.refresh,1);
    assert.equal(f.manager.structuresTileset(),f.primitives[0]);
    f.viewer.camera.positionCartographic.height=30000;f.viewer.scene.preUpdate.fire();
    assert.equal(values.enabled,false);
    f.viewer.camera.positionCartographic.height=1000;f.viewer.scene.preUpdate.fire();
    assert.equal(values.enabled,true);
    f.manager.performance('performance');assert.equal(values.profile,'performance');
    f.manager.navigationActive(true);assert.equal(values.profile,'navigation');
    f.manager.navigationActive(false);assert.equal(values.profile,'performance');
    f.set({structures:false});assert.equal(values.enabled,false);
    f.manager.dispose();assert.equal(values.disposed,true);
});
function fixture(loader,options={}){
    const requests=[],states=[],primitives=[],credits=new Set(),timers=new Map();let nextTimer=0;
    const C={JulianDate:{clone:x=>({...x}),fromIso8601:value=>({value})},ClockStep:{SYSTEM_CLOCK:2},SunLight:class{},Credit:class{},ShadowMode:{DISABLED:0},
        Cesium3DTileset:{fromUrl:(url,options)=>{requests.push({url,options});return loader?.(url,options)??Promise.resolve(tile(options));}}};
    const viewer={clock:{currentTime:{value:'2026-01-01T12:00:00.000Z'},clockStep:1,shouldAnimate:false},camera:{positionCartographic:{height:1000}},
        cesiumWidget:{creditDisplay:{addStaticCredit:c=>credits.add(c),removeStaticCredit:c=>credits.delete(c)}},
        scene:{light:{original:true},globe:{enableLighting:false,dynamicAtmosphereLightingFromSun:false},preUpdate:new Event(),requestRender(){},
            primitives:{add:p=>primitives.push(p),remove:p=>{primitives.splice(primitives.indexOf(p),1);p.destroy();}}}};
    function tile(options){let destroyed=false;return {...options,tileFailed:new Event(),loadProgress:new Event(),destroy(){destroyed=true;},isDestroyed:()=>destroyed};}
    const manager=create(C,viewer,(type,event)=>states.push({type,...event}),{setTimer:f=>{timers.set(++nextTimer,f);return nextTimer;},clearTimer:id=>timers.delete(id),...options});
    const set=(options={})=>manager.set({buildings:false,vegetation:false,lighting:false,...options});
    return {manager,set,C,viewer,requests,states,primitives,credits,timers,tile};
}
test('flight preparation primes shared model lighting only for requested 3D layers and reuses its texture',()=>{
    const f=fixture();let updates=0;
    const generator={colorTexture:undefined,update(state){
        assert.equal(state,f.viewer.scene.frameState);updates++;this.colorTexture={resident:true};
    }};
    f.viewer.scene.frameState={brdfLutGenerator:generator};
    f.manager.prepareGraphics();assert.equal(updates,0);
    f.set({structures:true});f.manager.prepareGraphics();assert.equal(updates,1);
    f.manager.prepareGraphics();assert.equal(updates,1,'A later flight retains the context-owned lookup');
    generator.colorTexture=undefined;
    generator.update=()=>{throw Error('unsupported lookup generator');};
    assert.doesNotThrow(()=>f.manager.prepareGraphics(),'Optional preparation must retain ordinary model loading');
    f.manager.dispose();generator.update=()=>{updates++;};
    f.manager.prepareGraphics();assert.equal(updates,1);
});

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

test('navigation inherits or overrides each model layer independently and restores map budgets without reimports',async()=>{
    const p=fixture();p.set({buildings:true});await flush();const building=p.primitives[0];
    p.manager.navigation({buildings:false,vegetation:true});assert.equal(building.show,true,'inactive navigation cannot change map');
    p.manager.navigationActive(true);await flush();assert.equal(building.show,false);assert.equal(p.primitives.length,2);
    const trees=p.primitives[1];assert.equal(trees.show,true);assert.equal(trees.cacheBytes,12*1024*1024);
    assert.equal(building.cacheBytes,24*1024*1024);assert.equal(trees.maximumScreenSpaceError,56);
    p.manager.performance('quality');assert.equal(building.maximumScreenSpaceError,32,'navigation retains its own budget');
    p.set({buildings:true,vegetation:false});assert.equal(trees.show,true,'map updates cannot overwrite enabled navigation');
    p.manager.navigation({buildings:null,vegetation:null});assert.equal(building.show,true);assert.equal(trees.show,false);
    p.manager.navigation({buildings:true,vegetation:true});p.manager.navigationActive(false);
    assert.equal(building.show,true);assert.equal(trees.show,false);assert.equal(building.maximumScreenSpaceError,12);
    assert.equal(p.requests.length,2);assert.throws(()=>p.manager.navigation({buildings:'enabled',vegetation:null}));
    assert.equal(trees.show,false);p.manager.dispose();
});

test('offline navigation model failure remains local and a late request cannot replace restored map settings',async()=>{
    let resolve;const p=fixture(()=>new Promise(r=>resolve=r));
    p.manager.navigation({buildings:true,vegetation:false});p.manager.navigationActive(true);await flush();
    p.manager.navigationActive(false);const model=p.tile({});resolve(model);await flush();
    assert.equal(model.show,false);assert.equal(model.cacheBytes,32*1024*1024);p.manager.dispose();
    const q=fixture(()=>Promise.reject(Error('offline')));
    q.manager.navigation({buildings:false,vegetation:true});q.manager.navigationActive(true);await flush();
    assert.equal(q.states.at(-1).state,'failed');assert.ok(q.states.every(s=>s.type==='scene-layer-status'));
    q.manager.navigationActive(false);assert.equal(q.states.at(-1).state,'hidden');q.manager.dispose();
});

test('navigation overrides precede inherited map imports; cached-only and offline sources recover without inventing models',async()=>{
    const p=fixture();p.manager.navigation({active:true,buildings:false,vegetation:false});
    p.set({buildings:true,vegetation:true});await flush();assert.equal(p.requests.length,0);
    p.manager.navigationActive(false);await flush();assert.equal(p.requests.length,2);p.manager.dispose();
    const q=fixture(undefined,{cachedOnly:true});q.manager.navigation({active:true,buildings:true,vegetation:true});await flush();
    assert.equal(q.requests.length,0);assert.equal(q.primitives.length,0);assert.equal(q.states.at(-1).state,'offline');q.manager.dispose();
    let online=false;const r=fixture(undefined,{isOnline:()=>online});r.set({buildings:true});
    assert.equal(r.requests.length,0);online=true;r.manager.networkChanged();await flush();
    assert.equal(r.requests.length,1);assert.equal(r.primitives.length,1);const model=r.primitives[0];
    online=false;r.manager.networkChanged();assert.equal(r.states.at(-1).state,'offline');assert.equal(model.show,true);
    online=true;r.manager.networkChanged();assert.equal(r.requests.length,1);assert.equal(r.states.at(-1).state,'ready');r.manager.dispose();
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

test('official swisstopo infrastructure tileset loads independently, is selectable and releases resources',async()=>{
    const p=fixture();p.set({buildings:false,vegetation:false,structures:true});await flush();
    assert.equal(p.requests.length,1);
    assert.match(p.requests[0].url,/ch\.swisstopo\.swisstlm3d\.3d\/v1\/tileset\.json/);
    const tile=p.primitives[0];assert.equal(tile.show,true);
    assert.ok(tile.cacheBytes<=16*1024*1024);
    assert.equal(p.credits.size,1);
    const selected=[];
    // The tile selection preserves only metadata actually published by the service.
    const pick={content:{tileset:tile},getPropertyIds:()=>['sourceId','name'],
        getProperty:key=>key==='sourceId'?'swiss-5':'Bridge'};
    const status=p.manager.pick(pick);
    assert.equal(status,true);
    assert.equal(p.states.at(-1).type,'infrastructure-selected');
    assert.equal(p.states.at(-1).datasetSource,'ch.swisstopo.swisstlm3d.3d');
    assert.equal(p.states.at(-1).attributes.sourceId,'swiss-5');
    assert.equal(p.manager.pick({}),false);
    p.set({structures:false});
    assert.equal(p.primitives.length,0);
    assert.equal(tile.isDestroyed(),true);
    assert.equal(p.credits.size,0);
    p.set({structures:true});await flush();assert.equal(p.requests.length,2);
    assert.equal(p.primitives.length,1);
    p.manager.dispose();assert.equal(p.primitives.length,0);
});
test('offline, tile errors and renderer disposal keep infrastructure incomplete without inventing geometry',async()=>{
    const p=fixture(undefined,{cachedOnly:true});p.set({structures:true});await flush();
    assert.equal(p.primitives.length,0);
    assert.equal(p.states.at(-1).state,'offline');
    p.manager.dispose();
    const q=fixture();q.set({structures:true});await flush();
    const tile=q.primitives[0];tile.tileFailed.fire();
    assert.equal(q.states.at(-1).state,'partial');
    q.manager.dispose();
    assert.equal(tile.isDestroyed(),true);
});


test('structure transparency is independently configurable and rejects invalid ranges',async()=>{
 const p=fixture();
 p.C.Cesium3DTileStyle=class{constructor(style){this.color=style.color}};
 p.set({structures:true,structuresOpacity:.5});await flush();
 assert.equal(p.primitives[0].style.color,"color('white', 0.5)");
 p.set({buildings:true,structures:true,structuresOpacity:.8});await flush();
 assert.equal(p.primitives[0].style.color,"color('white', 0.8)");
 assert.throws(()=>p.set({structures:true,structuresOpacity:1.5}));
 p.manager.dispose();
});

test('camera preUpdate and repeated scene commands avoid redundant 3D setters and render requests',async()=>{
    const p=fixture();let draws=0;
    p.viewer.scene.requestRender=()=>{draws++;};
    p.set({buildings:true,structures:true});await flush();
    const buildings=p.primitives[0],structures=p.primitives[1];
    const originalBuildingShow=buildings.show,originalStructuresShow=structures.show;
    // Proxy the Cesium property setters to catch redundant assignments.
    const counters=new Map();
    for(const tileset of [buildings,structures]){
        let value=tileset.show,showWrites=0,detail=tileset.maximumScreenSpaceError,detailWrites=0;
        Object.defineProperty(tileset,'show',{configurable:true,get:()=>value,set:newValue=>{showWrites++;value=newValue;}});
        Object.defineProperty(tileset,'maximumScreenSpaceError',{configurable:true,get:()=>detail,set:newValue=>{detailWrites++;detail=newValue;}});
        counters.set(tileset,()=>({showWrites,detailWrites}));
    }
    const before=draws;
    for(let n=0;n<1000;n++)p.viewer.scene.preUpdate.fire();
    for(let n=0;n<50;n++)p.set({buildings:true,structures:true});
    assert.equal(draws,before,'unchanged settings do not schedule new frames');
    for(const tile of [buildings,structures])assert.deepEqual(counters.get(tile)(),{showWrites:0,detailWrites:0});
    p.viewer.camera.positionCartographic.height=30000;
    p.viewer.scene.preUpdate.fire();p.viewer.scene.preUpdate.fire();
    for(const tile of [buildings,structures])assert.equal(counters.get(tile)().showWrites,1);
    p.viewer.camera.positionCartographic.height=1000;
    p.viewer.scene.preUpdate.fire();
    for(const tile of [buildings,structures])assert.equal(counters.get(tile)().showWrites,2);
    assert.equal(buildings.show,originalBuildingShow);
    assert.equal(structures.show,originalStructuresShow);
    p.manager.performance('quality');p.manager.performance('quality');
    assert.equal(counters.get(buildings)().detailWrites,1);
    assert.equal(counters.get(structures)().detailWrites,0,'structure precision is unchanged between these profiles');
    assert.equal(p.manager.resourceStats().resident,2);
    assert.equal(p.manager.resourceStats().visible,2);
    p.manager.dispose();assert.equal(p.manager.resourceStats().resident,0);
});

test('structure alpha style is changed only when explicitly needed and selection remains intact',async()=>{
    const p=fixture();let styles=0;
    p.C.Cesium3DTileStyle=class{constructor(options){styles++;this.options=options;}};
    p.set({structures:true,structuresOpacity:.6});await flush();
    const model=p.primitives[0];
    assert.equal(styles,1);
    for(let n=0;n<20;n++)p.set({structures:true,structuresOpacity:.6});
    assert.equal(styles,1);
    p.manager.performance('quality');assert.equal(styles,1);
    p.set({structures:true,structuresOpacity:.8});assert.equal(styles,2);
    assert.equal(model.style.options.color,"color('white', 0.8)");
    const result=p.manager.pick({content:{tileset:model},getPropertyIds:()=>['identifier'],getProperty:()=>123});
    assert.equal(result,true);
    assert.equal(p.states.at(-1).datasetSource,'ch.swisstopo.swisstlm3d.3d');
    p.manager.dispose();assert.equal(styles,2);
});

test('building roofs and facades use an optional Cesium surface shader only on detailed profiles',async()=>{
    const actual=require('../../web/cesium/index.cjs');
    const p=fixture();
    p.C.CustomShader=actual.CustomShader;
    p.C.VaryingType=actual.VaryingType;
    p.C.UniformType=actual.UniformType;
    p.set({buildings:true});await flush();
    const building=p.primitives[0];
    const detailed=building.customShader;
    assert.ok(detailed instanceof actual.CustomShader,'Cesium 3D building tiles receive an optional CustomShader');
    assert.match(detailed.fragmentShaderText,/roofDetail/);
    assert.match(detailed.fragmentShaderText,/wallDetail/);
    assert.equal(detailed.uniforms.u_fpv_detail.value,.50);
    p.manager.performance('quality');
    assert.equal(building.customShader,detailed,'detail level changes without reloading 3D Tiles');
    assert.equal(detailed.uniforms.u_fpv_detail.value,.85);
    p.manager.performance('compatibility');
    assert.equal(building.customShader,undefined,'compatibility leaves the source materials untouched');
    p.manager.performance('performance');
    assert.equal(building.customShader,undefined);
    p.manager.performance('balanced');
    assert.ok(building.customShader instanceof actual.CustomShader);
    p.manager.dispose();
});

test('loaded structures and building walls follow shared tunnel apertures and release masks independently of detail',async()=>{
    const actual=require('../../web/cesium/index.cjs');let specs=[],clock=0;
    const p=fixture(null,{getTunnelApertures:()=>specs,now:()=>clock});
    for(const name of ['CustomShader','UniformType','VaryingType','Cartesian3','Cartesian4','Matrix4','EncodedCartesian3',
        'ClippingPlane','ClippingPlaneCollection','Transforms'])p.C[name]=actual[name];
    p.set({buildings:true,structures:true});await flush();
    p.viewer.camera.viewMatrix=actual.Matrix4.clone(actual.Matrix4.IDENTITY);
    const buildings=p.primitives[0],structures=p.primitives[1];
    assert.equal(structures.customShader,undefined);
    specs=[{longitude:8.6,latitude:46.7,floor:500,forward:{east:0,north:1},halfWidth:3.5,
        before:8,after:26,below:1,above:6,shape:'rectangular',grade:.1}];
    clock=500;p.viewer.scene.preUpdate.fire();
    assert.ok(structures.customShader instanceof actual.CustomShader);
    assert.match(buildings.customShader.fragmentShaderText,/fpvBuildingDetail/);
    assert.match(buildings.customShader.fragmentShaderText,/fpvPortalClips/);
    const shader=structures.customShader;
    specs=[{...specs[0],grade:.15}];clock=1000;p.viewer.scene.preUpdate.fire();
    assert.equal(structures.customShader,shader,'only uniforms change while the mask layout is stable');
    assert.equal(shader.uniforms.fpvApertureRoof.value.w,.15);
    const before=actual.Cartesian3.clone(shader.uniforms.fpvApertureOriginHigh.value);
    p.viewer.camera.viewMatrix=actual.Matrix4.fromTranslation(new actual.Cartesian3(-100,0,0));
    p.viewer.scene.preUpdate.fire();
    assert.ok(Math.abs(shader.uniforms.fpvApertureOriginHigh.value.x-(before.x-100))<1e-6,
        'model aperture eye coordinates track camera changes without rebuilding geometry');
    p.manager.performance('compatibility');
    assert.ok(buildings.customShader instanceof actual.CustomShader,'floor-preserving clipping survives lightweight graphics');
    specs=[];clock=1500;p.viewer.scene.preUpdate.fire();
    assert.equal(structures.customShader,undefined);assert.equal(buildings.customShader,undefined);
    p.manager.dispose();
});

test('a changed tunnel aperture reaches native model walls on the next frame rather than one throttle period late',async()=>{
    const actual=require('../../web/cesium/index.cjs');let specs=[],revision=0,reads=0;
    const p=fixture(null,{getTunnelApertures:()=>{reads++;return specs;},getTunnelApertureRevision:()=>revision,
        now:()=>1000});
    for(const name of ['CustomShader','UniformType','VaryingType','Cartesian3','Cartesian4','Matrix4','EncodedCartesian3',
        'ClippingPlane','ClippingPlaneCollection','Transforms'])p.C[name]=actual[name];
    p.viewer.camera.viewMatrix=actual.Matrix4.clone(actual.Matrix4.IDENTITY);
    p.set({structures:true});await flush();p.viewer.scene.preUpdate.fire();
    specs=[{longitude:8.6,latitude:46.7,floor:500,forward:{east:0,north:1},halfWidth:3.5,
        before:8,after:26,below:1,above:6,shape:'rectangular',grade:0}];
    revision++;p.viewer.scene.preUpdate.fire();
    const shader=p.primitives[0].customShader;
    assert.ok(shader instanceof actual.CustomShader);
    const count=reads;
    for(let i=0;i<120;i++)p.viewer.scene.preUpdate.fire();
    assert.equal(reads,count,'unchanged apertures do not clone or stringify specifications per frame');
    specs=[{...specs[0],floor:501}];revision++;p.viewer.scene.preUpdate.fire();
    assert.equal(p.primitives[0].customShader,shader,'movement keeps the existing GPU shader');
    const position=actual.Cartesian3.fromDegrees(8.6,46.7,501);
    assert.ok(actual.Cartesian3.equalsEpsilon(shader.uniforms.fpvApertureOriginHigh.value,position,1e-9),
        'a same-time revision updates geometry without waiting another 400 ms');
    specs=[];revision++;p.viewer.scene.preUpdate.fire();
    assert.equal(p.primitives[0].customShader,undefined);
    p.manager.dispose();
});
