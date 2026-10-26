const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/controller_input.js');
test('controller configuration rejects unknown layouts, duplicate/out-of-range channels and invalid reversals',()=>{
    for(const value of [null,[],{layout:'unknown'},{throttleZero:'low'},{rollAxis:16},{pitchAxis:0},{throttleAxis:1.5},{invertYaw:1}])
        assert.throws(()=>C.configuration(value));
    const config=C.configuration({layout:'radio',throttleZero:'bottom',invertThrottle:true});
    assert.equal(config.throttleZero,'bottom');assert.equal(Object.isFrozen(config),true);
});
test('unmapped USB radio channels map explicitly; directions can reverse and buttons cannot reset or exit',()=>{
    const config=C.configuration({layout:'radio',throttleZero:'bottom'});
    const pad={connected:true,mapping:'',axes:[.5,-.5,0,.2],buttons:[{value:1},{value:1}]};
    const f=C.gamepadFrame(pad,config);
    assert.equal(f.forward,0);assert.ok(f.right>0);assert.ok(f.yaw>0);assert.ok(f.pitch>0);
    assert.equal(f.reset,false);assert.equal(f.exit,false);
    const reversed=C.gamepadFrame(pad,C.configuration({...config,invertRoll:true,invertPitch:true,invertYaw:true}));
    assert.equal(reversed.right,-f.right);assert.equal(reversed.yaw,-f.yaw);assert.equal(reversed.pitch,-f.pitch);
    assert.equal(C.gamepadFrame({...pad,axes:[0,0]},config).unsupported,true);
    assert.equal(C.nativeFrame({axes:[0,0,NaN,0]},config).unsupported,true);
    assert.equal(C.gamepadFrame(pad).unsupported,true);
    assert.equal(C.gamepadFrame(pad,config,false).unsupported,true);
    assert.equal(C.nativeFrame({axes:[0,0,-1,0]},config,false).unsupported,true);
    assert.equal(C.gamepadFrame({connected:true,mapping:'standard',axes:[0,NaN,0,0]},C.configuration({throttleZero:'bottom'})).unsupported,true);
});
test('bottom zero uses the whole travel, centre zero only the upper half, and activation requires actual idle',()=>{
    for(const [raw,bottom,center] of [[-1,0,0],[0,.5,0],[.5,.75,.5],[1,1,1]]){
        assert.equal(C.throttle(raw,'bottom'),bottom);assert.equal(C.throttle(raw,'center'),center);
    }
    assert.equal(C.throttle(NaN,'bottom'),0);
    const idle={forward:-1,right:0,yaw:0,pitch:0,vertical:0,reset:false,exit:false};
    const cfg=C.configuration({throttleZero:'bottom'});
    assert.equal(C.neutral(idle,cfg,true),true);
    assert.equal(C.neutral({...idle,forward:0},cfg,true),false);
    assert.equal(C.neutral({...idle,forward:-.95},cfg,true),false);
    assert.equal(C.neutral({...idle,right:1},cfg,true),false);
    assert.equal(C.neutral({...idle,forward:0},C.defaults,true),true);
});
