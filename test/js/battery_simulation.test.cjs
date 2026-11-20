const test=require('node:test');
const assert=require('node:assert/strict');
const {create,normalize,levelPower,poweredFlightPower}=require('../../web/battery_simulation.js');
const {createSimulator,parameters}=require('../../web/free_flight.js');
const {create:makeHud}=require('../../web/flight_hud.js');
const profile={batteryId:1,chemistry:'LiPo',cellCount:6,capacityMah:4500,
    nominalVoltageVolts:22.2,chargePercent:100,hoverPowerWatts:180,
    cruisePowerWatts:290,cruiseSpeedMetersPerSecond:17,
    maxPowerWatts:1100,maxSpeedMetersPerSecond:45,takeoffWeightGrams:1320};
const spawn={latitude:46.7,longitude:8.4};
function simulator(){const poses=[];const sim=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,
    captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:p=>poses.push(p),
    isTerrainReady:()=>true,onState:()=>{}});return {sim,poses};}
async function start(sim,overrides={}){await sim.start({...spawn,agl:200,flightMode:'gps',showBatteryVoltage:true,
    batteryProfile:profile,...overrides},new AbortController().signal);}
function advance(sim,seconds=5){for(let i=0;i<seconds*60;i++)sim.tick(1/60);}

test('profile validation fails closed without battery or drone power metadata',()=>{
    assert.equal(create(null),null);
    assert.equal(create({...profile,hoverPowerWatts:null}),null);
    assert.equal(create({...profile,chargePercent:undefined}),null);
    assert.equal(create({...profile,cellCount:0}),null);
    assert.equal(create({...profile,chemistry:'unknown'}),null);
    assert.equal(create({...profile,capacityMah:NaN}),null);
    assert.equal(create({...profile,cruiseSpeedMetersPerSecond:0}),null);
    assert.equal(normalize(profile).capacityWh,99.9);
});

test('level-flight interpolation follows the route energy power curve endpoints',()=>{
    const p=normalize(profile);
    assert.equal(levelPower(p,0).watts,180);
    assert.equal(levelPower(p,17).watts,290);
    assert.equal(levelPower(p,8.5).watts,235);
    assert.equal(levelPower(p,45).watts,1100);
    assert.equal(levelPower(p,50).extrapolated,true);
});

test('energy depletion tracks power, charge, capacity, ascent and chemistry',()=>{
    const low=create(profile),high=create({...profile,hoverPowerWatts:500,cruisePowerWatts:900});
    const small=create({...profile,capacityMah:1000});
    const ascending=create(profile);
    for(let i=0;i<1200;i++){
        low.tick(.05,0,0);high.tick(.05,0,0);small.tick(.05,0,0);ascending.tick(.05,0,5);
    }
    assert.ok(low.consumedWh>0);
    assert.ok(high.consumedWh>low.consumedWh);
    assert.ok(ascending.consumedWh>low.consumedWh);
    assert.ok(high.snapshot().cellVoltageVolts<low.snapshot().cellVoltageVolts);
    assert.ok(small.snapshot().cellVoltageVolts<low.snapshot().cellVoltageVolts);
    assert.ok(create({...profile,chemistry:'LiHV'}).snapshot().packVoltageVolts>create(profile).snapshot().packVoltageVolts);
    assert.ok(create({...profile,chargePercent:35}).snapshot().packVoltageVolts<create(profile).snapshot().packVoltageVolts);
});

test('cell thresholds and optional sag respond without violating model voltage bounds',()=>{
    const regular=create({...profile,chargePercent:20});
    const sag=create({...profile,chargePercent:20},{resistanceOhmsPerCell:.02});
    regular.tick(.1,17,0);sag.tick(.1,17,0);
    assert.ok(sag.snapshot().cellVoltageVolts<regular.snapshot().cellVoltageVolts);
    assert.equal(regular.snapshot({lowVoltagePerCell:4,criticalVoltagePerCell:3.9}).level,'critical');
    assert.equal(regular.snapshot({lowVoltagePerCell:4,criticalVoltagePerCell:3.2}).level,'low');
    assert.equal(regular.snapshot({lowVoltagePerCell:3.0,criticalVoltagePerCell:2.9}).level,'normal');
    const exhausted=create({...profile,chargePercent:0});
    exhausted.tick(.1,10,10);
    assert.equal(exhausted.snapshot().consumedWh,0);
    assert.ok(exhausted.snapshot().cellVoltageVolts>=2.8);
    assert.equal(exhausted.snapshot().remainingEnergyWh,0);
});

test('simulator reset, pause and battery HUD toggle preserve or reset state correctly',async()=>{
    const {sim}=simulator();await start(sim);
    const initial=sim.status().battery;
    advance(sim,6);const consumed=sim.status().battery;
    assert.ok(consumed.consumedWh>initial.consumedWh);
    sim.batteryHud({enabled:false,showCell:true,low:3.6,critical:3.2});
    assert.equal(sim.status().battery,null);
    advance(sim,4);
    sim.batteryHud({enabled:true,showCell:true,low:3.6,critical:3.2});
    assert.ok(sim.status().battery.consumedWh>consumed.consumedWh);
    assert.equal(sim.status().showBatteryCellVoltage,true);
    sim.pause(true);const before=sim.status().battery.consumedWh;
    advance(sim,3);assert.equal(sim.status().battery.consumedWh,before);
    sim.pause(false);
    await sim.reset();assert.equal(sim.status().battery.consumedWh,0);
    assert.equal(sim.status().showBatteryVoltage,true);
    assert.equal(sim.status().lowBatteryCellVoltage,3.6);
    assert.throws(()=>sim.batteryHud({enabled:true,showCell:false,low:3.1,critical:3.3}));
    sim.stop();await start(sim,{batteryProfile:{...profile,capacityMah:900}});
    advance(sim,5);assert.ok(sim.status().battery.remainingPercent<consumed.remainingPercent);
});

test('replayed route time drains battery and a restart returns it to initial state',async()=>{
    const {sim}=simulator();await start(sim);
    const point={...spawn,height:1200,ground:1000,heading:0,pitch:0,speed:15,seconds:0};
    assert.equal(sim.playbackPose(point),true);
    sim.playbackPose({...point,seconds:.1});
    assert.ok(sim.status().battery.consumedWh>0);
    sim.playbackPose({...point,seconds:.2});const previous=sim.status().battery.consumedWh;
    sim.playbackPose({...point,seconds:0});assert.equal(sim.status().battery.consumedWh,0);
    sim.playbackPose({...point,seconds:.2});assert.ok(sim.status().battery.consumedWh>=previous);
});

test('missing battery data shows unavailable SIM estimate, no fabricated voltage',async()=>{
    const {sim}=simulator();await start(sim,{batteryProfile:{...profile,cruisePowerWatts:null}});
    assert.deepEqual(sim.status().battery,{available:false,estimated:true});
    const nodes=new Map();const doc={getElementById(id){if(!nodes.has(id))nodes.set(id,{hidden:false,
        textContent:'',style:{},setAttribute(key,value){this[key]=value;}});return nodes.get(id);}};
    const hud=makeHud(doc);hud.update(sim.status(),0);
    assert.equal(nodes.get('hud-battery-readout').hidden,false);
    assert.equal(nodes.get('hud-battery-voltage').textContent,'—');
    hud.update({...sim.status(),showBatteryVoltage:false},0);
    assert.equal(nodes.get('hud-battery-readout').hidden,true);
});

test('flight battery parameters reject invalid toggle, thresholds and resistance',()=>{
    assert.throws(()=>parameters({showBatteryVoltage:1}));
    assert.throws(()=>parameters({showBatteryCellVoltage:'true'}));
    assert.throws(()=>parameters({lowBatteryCellVoltage:3.1,criticalBatteryCellVoltage:3.2}));
    assert.throws(()=>parameters({batterySagResistanceOhmsPerCell:Infinity}));
});


test('battery HUD labels the independent ESC and motor proxy warnings as estimates',()=>{
    const nodes=new Map();const doc={getElementById(id){if(!nodes.has(id))nodes.set(id,{hidden:false,
        textContent:'',style:{},dataset:{},setAttribute(k,v){this[k]=v;}});return nodes.get(id);}};
    const hud=makeHud(doc);
    hud.update({mode:'gps',hudStyle:'goggles',showBatteryVoltage:true,
        battery:{available:true,packVoltageVolts:22.0,cellVoltageVolts:3.67,level:'normal',
            escPossiblyOverloaded:true,motorPossiblyOverloaded:false}},0);
    assert.ok(nodes.get('hud-battery-status').textContent.includes('ESC?'));
    assert.ok(!nodes.get('hud-battery-status').textContent.includes('MOTOR?'));
});


test('7-inch 6S 4500 mAh Acro battery draw is motor-load based, not free-fall speed based', async()=>{
    const battery={...profile,chemistry:'LiPo',capacityMah:4500,continuousDischargeC:120,
        resistanceOhmsPerCell:0,takeoffWeightGrams:1320};
    const p=normalize(battery);
    assert.equal(p.capacityWh,99.9);
    assert.ok(p.resistance>0,'an entered 0 mΩ is not a measured zero-resistance pack');
    assert.equal(poweredFlightPower(p,0,1).watts,p.hoverPowerWatts);
    assert.equal(poweredFlightPower(p,30,0).watts,p.hoverPowerWatts*.08,
        'zero motor thrust must use avionics/idle power, not 30 m/s windspeed');
    assert.ok(poweredFlightPower(p,17,1).watts < p.cruisePowerWatts,
        'initial calibration should not add arbitrary 10% to configured cruise watts');
    const falling=simulator(),powered=simulator();
    for(const f of [falling,powered])
        await start(f.sim,{flightMode:'acro',agl:850,batteryProfile:battery});
    powered.sim.flightInput({throttle:.5,yaw:0,pitch:0,roll:0});
    // Zero motor input: gravity accelerates the drone to high falling speed.
    advance(falling.sim,8);
    const free=falling.sim.status();
    assert.ok(free.verticalSpeed < -10,'the aircraft should actually free-fall');
    assert.ok(free.airspeedMetersPerSecond>10);
    assert.ok(free.battery.estimatedPowerWatts<=20,'unpowered flight should draw electronics-level power');
    assert.ok(free.battery.consumedWh<.05,'eight seconds of idle cannot use hover-flight energy');
    advance(powered.sim,8);
    assert.ok(powered.sim.status().battery.consumedWh>free.battery.consumedWh*10,
        'the same duration of powered hover must draw considerably more energy');
    falling.sim.stop();powered.sim.stop();
});

test('powered motor demand, not descent rate, controls consumption in Acro',()=>{
    const pack=normalize(profile);
    const idle=poweredFlightPower(pack,35,0).watts;
    const hover=poweredFlightPower(pack,0,1).watts;
    const ascent=poweredFlightPower(pack,0,2).watts;
    assert.ok(idle<hover && hover<ascent);
    const dive=create(profile),normal=create(profile);
    for(let i=0;i<600;i++){
        dive.tick(.05,35,-20,{thrustToWeight:0});
        normal.tick(.05,0,0,{thrustToWeight:1});
    }
    assert.ok(dive.consumedWh<normal.consumedWh*.1);
    assert.ok(dive.snapshot().remainingPercent>normal.snapshot().remainingPercent);
});
