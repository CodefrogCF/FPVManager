const test=require('node:test'),assert=require('node:assert/strict');
const {create,validate}=require('../../web/road_navigation.js');
function fixture(){
    const listeners=new Set(),entities=new Set();let height,look=null,restored=null;
    const C={Cartesian3:{clone:p=>({...p}),fromDegrees:(longitude,latitude,height=0)=>({longitude,latitude,height})},
        Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},HeadingPitchRange:class{constructor(heading,pitch,range){Object.assign(this,{heading,pitch,range});}},
        Math:{toRadians:v=>v*Math.PI/180},Matrix4:{IDENTITY:{}},Color:{fromCssColorString:v=>v,WHITE:'white'},HeightReference:{CLAMP_TO_GROUND:1}};
    const viewer={entities:{add:p=>{entities.add(p);return p;},remove:p=>entities.delete(p)},
        scene:{requestRender(){},postRender:{addEventListener:f=>{listeners.add(f);return()=>listeners.delete(f);}},screenSpaceCameraController:{enableInputs:true},globe:{tilesLoaded:true,getHeight:()=>height,
            tileLoadProgressEvent:{addEventListener:f=>{listeners.add(f);return()=>listeners.delete(f);}}}},
        camera:{positionWC:{x:1},directionWC:{x:2},upWC:{x:3},lookAt:(target,offset)=>look={target,offset},lookAtTransform(){},setView:p=>restored=p}};
    return {viewer,manager:create(C,viewer),entities,listeners,get look(){return look;},get restored(){return restored;},refine:value=>{height=value;for(const f of listeners)f(0);}};
}
const command={active:true,follow:true,position:{latitude:47,longitude:8,heading:90}};
test('road navigation updates one ground marker, follows terrain refinement and restores camera controls',()=>{
    const p=fixture();p.manager.set(command);assert.equal(p.entities.size,1);assert.equal(p.look.target.height,0);assert.equal(p.look.offset.range,12000);
    assert.equal(p.viewer.scene.screenSpaceCameraController.enableInputs,false);
    p.refine(650);p.refine(650);assert.equal(p.look.target.height,650);
    p.manager.set({...command,position:{...command.position,latitude:47.1}});assert.equal(p.entities.size,1);
    p.manager.set({...command,follow:false});assert.equal(p.viewer.scene.screenSpaceCameraController.enableInputs,true);
    p.manager.set({...command,position:null});assert.equal([...p.entities][0].show,false);
    p.manager.set({active:false,follow:true});assert.equal(p.entities.size,0);assert.deepEqual(p.restored.destination,{x:1});
    p.manager.dispose();p.manager.dispose();assert.equal(p.listeners.size,0);
    assert.throws(()=>p.manager.set(command));
});
test('invalid road navigation packets do not alter the existing marker or follow state',()=>{
    const p=fixture();p.manager.set(command);
    for(const position of [{latitude:91,longitude:8,heading:0},{latitude:47,longitude:8,heading:360},{latitude:NaN,longitude:8,heading:0}]){
        assert.throws(()=>p.manager.set({...command,position}));assert.equal(p.entities.size,1);
    }
    assert.throws(()=>validate({...command,follow:'true'}));p.manager.dispose();
});
test('finite fill-mesh heights cannot lower the initial camera until the new view has rendered and loaded',()=>{
    const p=fixture();p.viewer.scene.globe.tilesLoaded=false;p.refine(.17);p.manager.set(command);
    p.refine(.17);p.refine(.17);assert.equal(p.look.offset.range,12000);
    p.viewer.scene.globe.tilesLoaded=true;p.refine(1000);assert.equal(p.look.target.height,1000);assert.equal(p.look.offset.range,550);
    p.manager.set({...command,position:null});p.manager.set(command);assert.equal(p.look.offset.range,12000);
    p.manager.dispose();
});
test('zoom changes follow distance without resetting terrain readiness; compass follow toggles preserve zoom',()=>{
    const p=fixture();p.manager.set(command);p.refine(650);p.refine(650);
    p.manager.set({...command,cameraDistanceMeters:60});assert.equal(p.look.offset.range,60);
    p.manager.toggleFollow();assert.equal(p.manager.following,false);
    p.manager.toggleFollow();p.refine(650);p.refine(650);assert.equal(p.look.offset.range,60);
    for(const cameraDistanceMeters of [59,1801,NaN,Infinity,'100'])assert.throws(()=>p.manager.set({...command,cameraDistanceMeters}));
    assert.equal(p.look.offset.range,60);p.manager.dispose();
});
