const test=require('node:test'),assert=require('node:assert/strict');
const {create,validate}=require('../../web/road_navigation.js');
class Event{
    listeners=new Set();
    addEventListener(f){this.listeners.add(f);return()=>this.listeners.delete(f);}
    fire(...args){for(const f of this.listeners)f(...args);}
}
function fixture(options={}){
    const frames=new Event(),tiles=new Event(),entities=new Set(),active=[];let height,look=null,restored=null,at=0;
    class Cartesian3{
        static clone(p){return {...p};}
        static fromDegrees(longitude,latitude,height=0,ellipsoid,result=new Cartesian3()){
            return Object.assign(result,{longitude,latitude,height,x:longitude*100000,y:latitude*100000,z:height});
        }
        static lerp(a,b,t,result){for(const key of ['x','y','z'])result[key]=a[key]+(b[key]-a[key])*t;return result;}
    }
    class Cartographic{static fromDegrees(longitude,latitude,height=0,result=new Cartographic()){return Object.assign(result,{longitude,latitude,height});}}
    const C={Cartesian3,Cartographic,HeadingPitchRange:class{},ConstantPositionProperty:class{setValue(p){this.value={...p};}},
        Math:{toRadians:v=>v*Math.PI/180},Matrix4:{IDENTITY:{}},Color:{fromCssColorString:v=>v,WHITE:'white'},HeightReference:{CLAMP_TO_GROUND:1}};
    const viewer={resolutionScale:1,entities:{add:p=>{entities.add(p);return p;},remove:p=>entities.delete(p)},
        scene:{msaaSamples:4,requestRender(){},preUpdate:frames,screenSpaceCameraController:{enableInputs:true},globe:{tileCacheSize:100,tilesLoaded:true,getHeight:()=>height,tileLoadProgressEvent:tiles}},
        camera:{positionWC:{x:1,y:2,z:3},directionWC:{x:2},upWC:{x:3},heading:0,pitch:-1,roll:0,
            lookAt(target,offset){look={target:{...target},offset:{...offset}};
                this.positionWC={...target,z:target.z+offset.range};this.heading=offset.heading;this.pitch=offset.pitch;},
            cancelFlight(){},lookAtTransform(){},setView(p){restored={destination:{...p.destination}};
                this.positionWC={...p.destination};Object.assign(this,p.orientation);}}};
    const manager=create(C,viewer,()=>{},{now:()=>at,onActive:value=>active.push(value),...options});
    function advance(ms){const end=at+ms;while(at<end){at=Math.min(end,at+1000/60);frames.fire();}}
    return {viewer,manager,entities,active,frames,tiles,advance,get at(){return at;},jumpClock(ms){at+=ms;frames.fire();},
        get look(){return look;},get restored(){return restored;},refine(value){height=value;tiles.fire(0);}};
}
const command={active:true,follow:true,position:{latitude:47,longitude:8,heading:90}};
const close=(actual,expected,epsilon=.001)=>assert.ok(Math.abs(actual-expected)<epsilon,actual+' != '+expected);
test('one marker, bounded terrain refinement, scoped graphics and cleanup restore the map',()=>{
    const p=fixture();p.manager.set(command);assert.equal(p.entities.size,1);assert.equal(p.look.target.height,0);assert.equal(p.look.offset.range,12000);
    assert.equal(p.viewer.resolutionScale,.9);assert.equal(p.viewer.scene.msaaSamples,2);assert.equal(p.viewer.scene.globe.tileCacheSize,256);
    p.refine(650);p.advance(3000);close(p.look.target.height,650);close(p.look.offset.range,550);
    assert.equal(p.viewer.scene.screenSpaceCameraController.enableInputs,false);
    p.manager.set({...command,position:{...command.position,latitude:47.1}});assert.equal(p.entities.size,1);
    assert.equal(p.look.offset.range,12000,'large jump must not reuse unrelated terrain');
    p.manager.set({...command,position:null});assert.equal([...p.entities][0].show,false);
    p.manager.set({active:false,follow:true});assert.equal(p.entities.size,0);assert.deepEqual(p.restored.destination,{x:1,y:2,z:3});
    assert.equal(p.viewer.resolutionScale,1);assert.equal(p.viewer.scene.msaaSamples,4);assert.equal(p.viewer.scene.globe.tileCacheSize,100);
    assert.deepEqual(p.active,[true,false]);p.manager.dispose();p.manager.dispose();
    assert.equal(p.frames.listeners.size+p.tiles.listeners.size,0);assert.throws(()=>p.manager.set(command));
});
test('invalid packets leave marker and camera untouched',()=>{
    const p=fixture();p.manager.set(command);const before=p.look;
    for(const position of [{latitude:91,longitude:8,heading:0},{latitude:47,longitude:8,heading:360},{latitude:NaN,longitude:8,heading:0}]){
        assert.throws(()=>p.manager.set({...command,position}));assert.equal(p.entities.size,1);assert.deepEqual(p.look,before);
    }
    assert.throws(()=>validate({...command,follow:'true'}));
    for(const cameraDistanceMeters of [59,1801,NaN,Infinity,'100'])assert.throws(()=>p.manager.set({...command,cameraDistanceMeters}));
    p.manager.dispose();
});
test('fill meshes cannot lower the initial overview while terrain is loading',()=>{
    const p=fixture();p.viewer.scene.globe.tilesLoaded=false;p.refine(.17);p.manager.set(command);
    p.advance(2000);assert.equal(p.look.offset.range,12000);assert.equal(p.manager.metrics.terrainQueries,0);
    p.viewer.scene.globe.tilesLoaded=true;p.refine(1000);p.advance(3000);close(p.look.target.height,1000);close(p.look.offset.range,550);
    p.manager.set({...command,position:null});p.manager.set(command);assert.equal(p.look.offset.range,12000);p.manager.dispose();
});
test('camera and marker interpolate fixes and shortest heading arc, without extrapolation or command mutation',()=>{
    const p=fixture(),initial={...command,position:{latitude:47,longitude:8,heading:359}};
    p.manager.set(initial);p.refine(650);p.advance(3000);
    const next={...command,position:{latitude:47.0001,longitude:8,heading:1}},copy=structuredClone(next);
    p.manager.set(next);close(p.look.target.latitude,47);p.advance(500);
    close(p.look.target.latitude,47.00005,.000001);
    assert.ok(p.look.offset.heading<.01||p.look.offset.heading>Math.PI*2-.01);
    close([...p.entities][0].position.value.latitude,p.look.target.latitude,.000001);
    p.advance(1000);close(p.look.target.latitude,next.position.latitude,.000001);
    const pose=structuredClone(p.look),queries=p.manager.metrics.terrainQueries;p.advance(5000);
    assert.deepEqual(p.look,pose);assert.deepEqual(next,copy);assert.ok(p.manager.metrics.terrainQueries-queries<3);
    p.manager.dispose();
});
test('manual camera is retained during fixes; follow return and zoom interpolate without restarting terrain',()=>{
    const p=fixture();p.manager.set(command);p.refine(650);p.advance(3000);
    p.manager.set({...command,cameraDistanceMeters:60});assert.ok(p.look.offset.range>60);p.advance(3000);close(p.look.offset.range,60);
    p.manager.toggleFollow();assert.equal(p.manager.following,false);
    p.viewer.camera.positionWC={x:4,y:5,z:6};p.viewer.camera.heading=0;
    const count=p.manager.metrics.cameraUpdates;
    p.manager.set({...command,follow:false,cameraDistanceMeters:60,position:{...command.position,latitude:47.0001}});
    p.advance(1000);assert.equal(p.manager.metrics.cameraUpdates,count);assert.deepEqual(p.viewer.camera.positionWC,{x:4,y:5,z:6});
    p.manager.toggleFollow();assert.equal(p.manager.following,true);
    assert.deepEqual(p.viewer.camera.positionWC,{x:4,y:5,z:6},'recenter must start at the actual free camera');
    p.advance(1000);close(p.look.offset.range,60);close(p.look.target.height,650);
    p.manager.dispose();
});
test('missing GPS and suspended loops stop animation; resume has no queued catch-up motion',()=>{
    const p=fixture();p.manager.set(command);p.refine(650);p.advance(3000);
    p.manager.set({...command,position:{...command.position,latitude:47.0001}});p.advance(200);p.jumpClock(10000);
    close(p.look.target.latitude,47.0001,.000001);
    p.manager.set({...command,position:null});const count=p.manager.metrics.cameraUpdates;
    p.advance(3000);assert.equal(p.manager.metrics.cameraUpdates,count);assert.equal([...p.entities][0].show,false);
    p.manager.set({active:false,follow:false});p.advance(1000);assert.equal(p.manager.metrics.cameraUpdates,count);
    p.manager.set(command);assert.equal(p.entities.size,1);assert.equal(p.look.offset.range,12000);p.manager.dispose();
});
test('terrain completion storms are throttled and renderer work stays local to bounded scratch state',()=>{
    const p=fixture();p.manager.set(command);p.refine(650);
    for(let i=0;i<240;i++){p.refine(650+i/100);p.advance(1000/60);}
    assert.ok(p.manager.metrics.terrainQueries<=21,JSON.stringify(p.manager.metrics));
    assert.equal(p.entities.size,1);p.manager.dispose();
});
test('antimeridian motion uses the short path and retains a lower pre-existing graphics budget',()=>{
    const p=fixture();p.viewer.resolutionScale=.7;p.viewer.scene.msaaSamples=1;
    p.manager.set({...command,position:{latitude:47,longitude:179.9999,heading:90}});p.advance(1000);
    p.manager.set({...command,position:{latitude:47,longitude:-179.9999,heading:90}});p.advance(500);
    assert.ok(Math.abs(p.look.target.longitude)>179.9998);assert.equal(p.viewer.resolutionScale,.7);
    assert.equal(p.viewer.scene.msaaSamples,1);p.manager.dispose();
});

test('terrain outages do not accept fallback ellipsoid heights or flatten the follow camera',()=>{
    let ready=false;const p=fixture({isTerrainReady:()=>ready});p.manager.set(command);p.refine(0);p.advance(2000);
    assert.equal(p.manager.metrics.terrainQueries,0);assert.equal(p.look.offset.range,12000);
    ready=true;p.refine(650);p.advance(3000);close(p.look.target.height,650);
    ready=false;p.refine(0);p.advance(3000);close(p.look.target.height,650);
    ready=true;p.refine(700);p.advance(3000);close(p.look.target.height,700);p.manager.dispose();
});
