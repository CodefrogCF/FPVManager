const test=require('node:test');
const assert=require('node:assert/strict');
const {bindControls,axis,gamepadFrame}=require('../../web/navigation_controls.js');
const {createSimulator}=require('../../web/free_flight.js');
const Controller=require('../../web/controller_input.js');
class Target{
    constructor(rect={left:0,top:0,width:400,height:600}){this.listeners=new Map();this.style={};this.rect=rect;this.hidden=true;}
    addEventListener(type,fn){if(!this.listeners.has(type))this.listeners.set(type,new Set());this.listeners.get(type).add(fn);}
    removeEventListener(type,fn){this.listeners.get(type)?.delete(fn);}
    fire(type,values={}){for(const fn of this.listeners.get(type)??[])fn({button:0,pointerId:1,clientX:250,clientY:300,preventDefault(){},...values});}
    focus(){this.onFocus?.();}setPointerCapture(){}getBoundingClientRect(){return this.rect;}
}
function setup(mode='ground',flightAgent=null){
    let time=0,pads=[],active=true;const movements=[],looks=[],vertical=[],states=[];
    const canvas=new Target(),stick=new Target({left:0,top:450,width:100,height:100}),thumb=new Target(),look=new Target(),lookThumb=new Target();
    const panel=new Target(),host=new Target(),doc=new Target();
    doc.getElementById=id=>id==='look-stick'?look:lookThumb;doc.activeElement=canvas;doc.hasFocus=()=>true;doc.hidden=false;
    canvas.onFocus=()=>{doc.activeElement=canvas;canvas.fire('focus');};
    panel.querySelector=s=>s==='[data-stick]'?stick:thumb;
    host.navigator={getGamepads:()=>pads};host.performance={now:()=>time};
    const agent=flightAgent??{status:()=>({active,mode}),flightInput:frame=>movements.push(frame),stick:(...v)=>movements.push(v),look:(...v)=>looks.push(v),
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
test('Web gamepad, native controller and touch use Acro zero-centre throttle through the real flight model',async()=>{
    for(const source of ['web','native','touch']){
        const agent=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,isTerrainReady:()=>true,
            captureCamera:()=>({heading:0}),restoreCamera(){},applyPose(){},onState(){}});
        await agent.start({latitude:47,longitude:8,flightMode:'acro',agl:500,acroMotorTimeConstant:0},new AbortController().signal);
        const p=setup('acro',agent);
        const native={forward:0,right:0,yaw:0,pitch:0,vertical:0,reset:false,exit:false,connected:true};
        if(source==='web')p.pads([pad()]);
        else if(source==='native')p.binding.native(native);
        else p.stick.fire('pointerdown',{clientX:50,clientY:500});
        p.binding.tick(.1);
        for(const [value,command] of [[0,0],[1,1],[0,0],[-1,0]]){
            if(source==='web')p.pads([pad({y:-value})]);
            else if(source==='native')p.binding.native({...native,forward:value});
            else p.stick.fire('pointermove',{clientX:50,clientY:500-value*35});
            p.binding.tick(.1);agent.tick(1/60);
            assert.equal(agent.status().throttle,command,`${source} at ${value}`);
            assert.equal(agent.status().thrustAcceleration>0,command>0,`${source} motor at ${value}`);
        }
        p.binding();
    }
});

test('USB radio throttle uses selectable endpoints in Angle/Acro through Web and native inputs; unplug cuts Acro gas',async()=>{
    for(const mode of ['acro','angle'])for(const source of ['web','native'])for(const zero of ['bottom','center']){
        const agent=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,isTerrainReady:()=>true,
            captureCamera:()=>({heading:0}),restoreCamera(){},applyPose(){},onState(){}});
        await agent.start({latitude:47,longitude:8,flightMode:mode,agl:500,acroMotorTimeConstant:0,
            controller:{layout:'radio',throttleZero:zero}},new AbortController().signal);
        const p=setup(mode,agent),axes=[0,0,zero==='bottom'?-1:0,0];
        const frame={forward:0,right:0,yaw:0,pitch:0,vertical:0,reset:false,exit:false,connected:true,axes,generation:1};
        const update=()=>{if(source==='web')p.pads([{connected:true,mapping:'',axes,buttons:[{value:1},{value:1}]}]);else p.binding.native(frame);p.binding.tick(.01);agent.tick(.01);};
        update();assert.equal(agent.status().throttle,0);
        for(const raw of [-1,0,.5,1]){axes[2]=raw;update();assert.equal(agent.status().throttle,Controller.throttle(raw,zero),`${mode}/${source}/${zero}/${raw}`);}
        p.canvas.fire('keydown',{key:'q'});update();assert.equal(agent.status().throttle,0,'Keyboard gas cut takes priority over an external throttle');
        p.canvas.fire('keyup',{key:'q'});p.canvas.fire('keydown',{key:'e'});update();assert.equal(agent.status().throttle,1);
        p.canvas.fire('keyup',{key:'e'});
        const snapshot=agent.status();agent.controllerSettings({...agent.controller,throttleZero:zero==='bottom'?'center':'bottom'});
        assert.equal(agent.status().height,snapshot.height);assert.deepEqual(agent.status().attitude,snapshot.attitude);
        update();assert.equal(agent.status().throttle,mode==='acro'?0:.5,'Changed mapping must wait for a new idle');
        p.pads([]);p.binding.native({...frame,connected:false});p.binding.tick(.01);agent.tick(.01);
        if(mode==='acro')assert.equal(agent.status().throttle,0);
        await agent.reset();assert.equal(agent.controller.layout,'radio');
        assert.equal(agent.controller.throttleZero,zero==='bottom'?'center':'bottom');p.binding();
    }
});

test('bottom-throttle radio requires idle after focus loss and on replacement by another device',async()=>{
    const config=Controller.configuration({layout:'radio',throttleZero:'bottom'});
    const agentPad=(t,id='first')=>({connected:true,mapping:'',index:0,id,axes:[0,0,t,0],buttons:[]});
    // Supply the immutable settings without bypassing the real input gating.
    let input;
    const agent={status:()=>({active:true,mode:'acro',controller:config}),flightInput:v=>input=v,stick(){},look(){},key(){},clearKeys(){},pause(){},stop(){}};
    const q=setup('acro',agent);
    q.pads([agentPad(1)]);q.binding.tick(.1);assert.equal(input.throttle,0);
    q.pads([agentPad(-1)]);q.binding.tick(.1);q.pads([agentPad(1)]);q.binding.tick(.1);assert.equal(input.throttle,1);
    q.pads([agentPad(1,'second')]);q.binding.tick(.1);assert.equal(input.throttle,0);
    q.pads([agentPad(-1,'second')]);q.binding.tick(.1);q.pads([agentPad(1,'second')]);q.binding.tick(.1);assert.equal(input.throttle,1);
    q.host.fire('blur');q.doc.activeElement=null;q.binding.tick(.1);q.canvas.focus();q.binding.tick(.1);assert.equal(input.throttle,0);
    q.binding();
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
