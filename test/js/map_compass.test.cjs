const test=require('node:test'),assert=require('node:assert/strict');
const {create,north}=require('../../web/map_compass.js');
function fixture(){
    const listeners=new Set(),needle={style:{}},attrs={};let click,look,view,cancels=0,picked={x:0,y:0,z:0};
    const C={Cartesian2:class{constructor(x,y){Object.assign(this,{x,y});}},Cartesian3:{distance:()=>300},
        HeadingPitchRange:class{constructor(heading,pitch,range){Object.assign(this,{heading,pitch,range});}},Matrix4:{IDENTITY:{}}};
    const viewer={camera:{heading:Math.PI/2,pitch:-1,positionWC:{},cancelFlight:()=>cancels++,getPickRay:p=>p,
        lookAt:(target,offset)=>look={target,offset},lookAtTransform(){},setView:v=>view=v},
        scene:{canvas:{clientWidth:800,clientHeight:600},globe:{pick:()=>picked},requestRender(){},
            postRender:{addEventListener:f=>{listeners.add(f);return()=>listeners.delete(f);}}}};
    const button={querySelector:()=>needle,setAttribute:(k,v)=>attrs[k]=v,
        addEventListener:(type,f)=>click=f,removeEventListener:()=>click=null};
    return {C,viewer,button,attrs,needle,listeners,click:()=>click(),get look(){return look;},get view(){return view;},get cancels(){return cancels;},noTarget:()=>picked=null};
}
test('compass needle tracks camera heading; north keeps the viewed point, pitch and distance',()=>{
    const f=fixture(),compass=create(f.C,f.viewer,f.button);
    assert.equal(f.needle.style.transform,`rotate(${-Math.PI/2}rad)`);
    f.click();assert.equal(f.look.offset.heading,0);assert.equal(f.look.offset.range,300);assert.equal(f.look.offset.pitch,-1);
    assert.equal(f.cancels,1);
    f.viewer.camera.heading=.7;for(const update of f.listeners)update();assert.equal(f.needle.style.transform,'rotate(-0.7rad)');
    f.noTarget();north(f.C,f.viewer);assert.deepEqual(f.view.orientation,{heading:0,pitch:-1,roll:0});
    compass.dispose();assert.equal(f.listeners.size,0);
});
test('navigation compass alternates north/free and following; unavailable flight controls hide it',()=>{
    const f=fixture();let enabled=true;
    const navigation={active:true,following:true,toggleFollow(){this.following=!this.following;}};
    const compass=create(f.C,f.viewer,f.button,{navigation,isEnabled:()=>enabled});
    f.click();assert.equal(navigation.following,false);assert.equal(f.look.offset.heading,0);
    assert.equal(f.attrs['aria-label'],'Standort verfolgen');
    f.click();assert.equal(navigation.following,true);assert.equal(f.cancels,1);
    navigation.following=false;for(const update of f.listeners)update();
    f.click();assert.equal(navigation.following,false);assert.equal(f.cancels,2);
    f.click();assert.equal(navigation.following,true);
    enabled=false;for(const update of f.listeners)update();assert.equal(f.button.hidden,true);
    f.click();assert.equal(navigation.following,true);compass.dispose();
});
