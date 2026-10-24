const test=require('node:test');
const assert=require('node:assert/strict');
const {bindControls,axis,gamepadFrame}=require('../../web/navigation_controls.js');
class Target{
    constructor(rect={left:0,top:0,width:400,height:600}){this.listeners=new Map();this.style={};this.rect=rect;this.hidden=true;}
    addEventListener(type,fn){if(!this.listeners.has(type))this.listeners.set(type,new Set());this.listeners.get(type).add(fn);}
    removeEventListener(type,fn){this.listeners.get(type)?.delete(fn);}
    fire(type,values={}){for(const fn of this.listeners.get(type)??[])fn({button:0,pointerId:1,clientX:250,clientY:300,preventDefault(){},...values});}
    focus(){this.onFocus?.();}setPointerCapture(){}getBoundingClientRect(){return this.rect;}
}
function setup(mode='ground'){
    let time=0,pads=[],active=true;const movements=[],looks=[],vertical=[],states=[];
    const canvas=new Target(),stick=new Target({left:0,top:450,width:100,height:100}),thumb=new Target(),look=new Target(),lookThumb=new Target();
    const panel=new Target(),host=new Target(),doc=new Target();
    doc.getElementById=id=>id==='look-stick'?look:lookThumb;doc.activeElement=canvas;doc.hasFocus=()=>true;doc.hidden=false;
    canvas.onFocus=()=>{doc.activeElement=canvas;canvas.fire('focus');};
    panel.querySelector=s=>s==='[data-stick]'?stick:thumb;
    host.navigator={getGamepads:()=>pads};host.performance={now:()=>time};
    const agent={status:()=>({active,mode}),flightInput:frame=>movements.push(frame),stick:(...v)=>movements.push(v),look:(...v)=>looks.push(v),
        key(){},clearKeys(){},vertical:v=>vertical.push(v),stop:()=>active=false,reset:()=>states.push('reset'),pause:v=>states.push(v)};
    const binding=bindControls(agent,canvas,panel,host,doc,{onDevice:v=>states.push(v)});
    binding.tick(.1);
    return {binding,canvas,stick,thumb,look,lookThumb,host,doc,movements,looks,vertical,states,
        pads:v=>pads=v,time:v=>time=v,active:()=>active};
}
function pad({x=0,y=0,rx=0,ry=0,lt=0,rt=0,a=0,b=0}={}){return {connected:true,mapping:'standard',axes:[x,y,rx,ry],
    buttons:Array.from({length:16},(_,i)=>({value:({0:a,1:b,6:lt,7:rt})[i]??0}))};}
test('standard gamepad axes, triggers and deadzones have a deterministic mapping',()=>{
    assert.equal(axis(.1),0);assert.equal(axis(NaN),0);assert.equal(axis(1),1);
    const f=gamepadFrame(pad({x:1,y:-1,rx:.8,ry:-.8,rt:.7}));
    assert.equal(f.forward,1);assert.equal(f.right,1);assert.ok(f.yaw>0&&f.pitch<0);assert.equal(f.vertical,.7);
    assert.equal(gamepadFrame({connected:true,mapping:''}).unsupported,true);
});
test('Angle and Acro map left stick to throttle/yaw and right stick to pitch/roll; GPS retains translation',()=>{
    for(const mode of ['angle','acro']){
        const p=setup(mode);p.pads([pad()]);p.binding.tick(.1);
        p.pads([pad({x:1,y:-1,rx:-1,ry:-1})]);p.binding.tick(.1);
        assert.deepEqual(p.movements.at(-1),{throttle:1,yaw:1,pitch:1,roll:-1});
        assert.equal(p.looks.length,0);p.pads([]);p.host.fire('gamepaddisconnected');p.binding.tick(.1);
        assert.deepEqual(p.movements.at(-1),{throttle:0,yaw:0,pitch:0,roll:0});p.binding();
    }
    const gps=setup('gps');gps.pads([pad()]);gps.binding.tick(.1);gps.pads([pad({x:1,y:-1,rx:1})]);gps.binding.tick(.1);
    assert.deepEqual(gps.movements.at(-1),[1,1]);assert.ok(gps.looks.at(-1)[0]>0);gps.binding();
});
test('two touch fingers independently control FPV throttle/yaw and attitude; releasing one preserves the other',()=>{
    const p=setup('angle');
    p.stick.fire('pointerdown',{pointerId:1,clientX:85,clientY:500});p.binding.tick(.1);
    assert.deepEqual(p.movements.at(-1),{throttle:0,yaw:1,pitch:0,roll:0});
    p.canvas.fire('pointerdown',{pointerId:2,pointerType:'touch',clientX:300,clientY:300});
    p.canvas.fire('pointermove',{pointerId:2,pointerType:'touch',clientX:300,clientY:265});p.binding.tick(.1);
    assert.deepEqual(p.movements.at(-1),{throttle:0,yaw:1,pitch:1,roll:0});
    p.stick.fire('pointermove',{pointerId:1,clientX:50,clientY:465});p.binding.tick(.1);
    assert.deepEqual(p.movements.at(-1),{throttle:1,yaw:0,pitch:1,roll:0});
    p.canvas.fire('pointercancel',{pointerId:2});p.binding.tick(.1);
    assert.deepEqual(p.movements.at(-1),{throttle:1,yaw:0,pitch:0,roll:0});
    p.stick.fire('pointercancel',{pointerId:1});p.binding.tick(.1);
    assert.deepEqual(p.movements.at(-1),{throttle:0,yaw:0,pitch:0,roll:0});p.binding();
});
test('right touch stick floats at the touch and disappears on release without releasing the movement finger',()=>{
    const p=setup();p.stick.fire('pointerdown',{pointerId:1,clientX:50,clientY:450});
    p.canvas.fire('pointerdown',{pointerId:2,pointerType:'touch',clientX:300,clientY:300});
    assert.equal(p.look.hidden,false);
    p.canvas.fire('pointermove',{pointerId:2,pointerType:'touch',clientX:335,clientY:265});p.binding.tick(.1);
    assert.ok(p.looks.at(-1)[0]>0&&p.looks.at(-1)[1]<0);assert.ok(p.movements.at(-1)[0]>0);
    p.canvas.fire('pointerup',{pointerId:3});assert.equal(p.look.hidden,false);
    p.canvas.fire('pointercancel',{pointerId:2});assert.equal(p.look.hidden,true);
    p.binding.tick(.1);assert.ok(p.movements.at(-1)[0]>0);
    p.stick.fire('pointercancel',{pointerId:1});p.binding.tick(.1);assert.deepEqual(p.movements.at(-1),[0,0]);
    p.canvas.fire('pointerdown',{pointerType:'touch',clientX:100});assert.equal(p.look.hidden,true);
    p.binding();
});
test('controller activation and focus recovery require neutral sticks; no stale movement survives disconnection',()=>{
    const p=setup();p.pads([pad({y:-1})]);p.binding.tick(.1);assert.deepEqual(p.movements.at(-1),[0,0]);
    p.pads([pad()]);p.binding.tick(.1);p.pads([pad({y:-1,rx:1,rt:1})]);p.binding.tick(.1);
    assert.equal(p.movements.at(-1)[0],1);assert.ok(p.looks.at(-1)[0]>0);assert.equal(p.vertical.at(-1),1);
    p.host.fire('blur');p.doc.activeElement=null;p.binding.tick(.1);assert.deepEqual(p.movements.at(-1),[0,0]);
    p.canvas.focus();p.binding.tick(.1);assert.deepEqual(p.movements.at(-1),[0,0]);
    p.pads([pad()]);p.binding.tick(.1);p.pads([pad({y:-1})]);p.binding.tick(.1);assert.equal(p.movements.at(-1)[0],1);
    p.pads([]);p.host.fire('gamepaddisconnected');p.binding.tick(.1);assert.deepEqual(p.movements.at(-1),[0,0]);
    p.binding();
});
test('native inputs expire, reject nonfinite frames and edge-trigger reset and exit',()=>{
    const p=setup();const neutral={forward:0,right:0,yaw:0,pitch:0,vertical:0,reset:false,exit:false,connected:true};
    p.binding.native(neutral);p.binding.tick(.1);
    p.binding.native({...neutral,forward:1,reset:true});p.binding.tick(.1);p.binding.tick(.1);
    assert.equal(p.states.filter(s=>s==='reset').length,1);assert.equal(p.movements.at(-1)[0],1);
    p.time(300);p.binding.tick(.1);assert.deepEqual(p.movements.at(-1),[0,0]);
    p.binding.native({...neutral,forward:NaN});p.binding.tick(.1);assert.deepEqual(p.movements.at(-1),[0,0]);
    p.binding.native(neutral);p.binding.tick(.1);p.binding.native({...neutral,exit:true});p.binding.tick(.1);assert.equal(p.active(),false);
    p.binding();assert.equal(p.canvas.listeners.get('pointermove').size,0);
});
