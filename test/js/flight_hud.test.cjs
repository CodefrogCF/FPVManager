const test=require('node:test'),assert=require('node:assert/strict');
const {homeDirection,telemetry,create}=require('../../web/flight_hud.js');
const rad=Math.PI/180;
const state={mode:'acro',hudStyle:'goggles',horizontalSpeed:10,verticalSpeed:-3.5,throttle:.62,
    agl:17.5,heightAboveHome:25,distance:111,position:{latitude:0,longitude:0},home:{latitude:0,longitude:1}};

test('wind HUD distinguishes model wind, unavailable forcing and disabled wind',()=>{
    const nodes=new Map(),doc={getElementById:id=>{if(!nodes.has(id))nodes.set(id,{style:{},setAttribute(k,v){this[k]=v;}});return nodes.get(id);}};
    const hud=create(doc);hud.update({...state,wind:{enabled:true,available:true,speedMs:8}},0);
    assert.equal(nodes.get('hud-wind').textContent,'8.0 m/s');assert.equal(nodes.get('hud-wind-readout').hidden,false);
    hud.update({...state,wind:{enabled:true,available:false,reason:'expired'}},0);assert.equal(nodes.get('hud-wind').textContent,'—');assert.equal(nodes.get('hud-wind-readout').hidden,false);
    hud.update(state,0);assert.equal(nodes.get('hud-wind-readout').hidden,true);
});

test('home cue uses view heading rather than velocity and handles cardinal directions and heading wrap',()=>{
    for(const [home,heading,expected] of [
        [{latitude:1,longitude:0},0,0], [{latitude:0,longitude:1},0,90],
        [{latitude:0,longitude:-1},0,-90], [{latitude:-1,longitude:0},0,180],
        [{latitude:0,longitude:1},90,0], [{latitude:0,longitude:1},180,-90],
        [{latitude:1,longitude:0},359,1]
    ])assert.ok(Math.abs(homeDirection({...state,home},heading*rad)-expected*rad)<1e-10);
    const across={...state,position:{latitude:0,longitude:179.9},home:{latitude:0,longitude:-179.9}};
    assert.ok(Math.abs(homeDirection(across,0)-Math.PI/2)<1e-10);
    assert.equal(homeDirection({...state,distance:0},0),null);
    assert.equal(homeDirection({...state,distance:.5},0),null);
    assert.equal(homeDirection({...state,home:null},0),null);
    assert.equal(homeDirection(state,NaN),null);
});

test('HUD distinguishes AGL and launch-ground height; missing heights stay unknown and descent remains signed',()=>{
    const values=telemetry(state,0);
    assert.equal(values.speed,'36');assert.equal(values.agl,'17.5');assert.equal(values.height,'25.0');
    assert.equal(values.distance,'111');assert.equal(values.distanceUnit,'m');assert.equal(values.vertical,'-3.5');assert.equal(values.throttle,'62');
    assert.equal(telemetry({...state,heightAboveHome:-4.6},0).height,'-4.6');
    assert.equal(telemetry({...state,agl:null,heightAboveHome:undefined},0).agl,'—');
    assert.equal(telemetry({...state,heightAboveHome:NaN},0).height,'—');
    assert.equal(telemetry({...state,agl:-.001},0).agl,'0.0');
    assert.equal(telemetry({...state,distance:12400},0).distance,'12.4');
    assert.equal(telemetry({...state,distance:12400},0).distanceUnit,'km');
    assert.equal(telemetry({...state,agl:9876.5},0).agl,'9877');
    assert.equal(telemetry({...state,distance:0},0).atHome,true);
});

test('both HUD styles retain telemetry, home arrow and warnings with plain-text source values',()=>{
    const elements=new Map();
    const doc={getElementById(id){if(!elements.has(id))elements.set(id,{textContent:'',hidden:false,style:{},
        setAttribute(key,value){this[key]=value;}});return elements.get(id);}};
    const hud=create(doc),get=id=>elements.get(id);
    hud.update(state,0);
    assert.equal(get('navigation-hud')['data-style'],'goggles');
    assert.equal(get('hud-speed').textContent,'36');assert.equal(get('hud-home-arrow').hidden,false);
    assert.equal(get('hud-warning').hidden,true);
    hud.device('Controller disconnected');assert.equal(get('hud-warning').hidden,false);
    hud.update({...state,hudStyle:'betaflight',reason:'Paused: tap the view to resume',paused:true},Math.PI/2);
    assert.equal(get('navigation-hud')['data-style'],'betaflight');
    assert.equal(get('hud-warning').textContent,'Paused: tap the view to resume');
    assert.equal(get('hud-mode').textContent,'SIM · ACRO · PAUSED');
    assert.equal(get('hud-home-arrow').style.transform,'rotate(0rad)');
    hud.device('Controller ready');hud.update({...state,distance:0},0);
    assert.equal(get('hud-warning').hidden,true);assert.equal(get('hud-home-arrow').hidden,true);
    assert.equal(get('hud-home-marker').hidden,false);
    hud.update({...state,mode:'gps'},0);assert.equal(get('hud-throttle-readout').hidden,true);
});
