const test = require('node:test');
const assert = require('node:assert/strict');
const catalog = require('../../web/battery_chemistries.generated.js');
const {create, normalize, chemistry, openCircuitCellVoltage, estimateLoad} = require('../../web/battery_simulation.js');
const base = {batteryId: 17, chemistry:'LiPo', cellCount:6, capacityMah:4500,
    nominalVoltageVolts:22.2, chargePercent:100, hoverPowerWatts:150,
    cruisePowerWatts:300, cruiseSpeedMetersPerSecond:18};

const ids = ['LiPo', 'LiHV', 'LiIon', 'LiFePO4', 'NiMH', 'NiCd'];
test('all chemistry definitions share the same generated schema and valid voltage curves',()=>{
    assert.deepEqual(Object.keys(catalog),ids);
    for(const id of ids){
        const c=chemistry(id);assert.equal(c.id,id);
        assert.equal(chemistry(c.aliases[0]).id,id);
        assert.ok(c.curve[0][1]<c.curve.at(-1)[1]);
        for(let i=0;i<100;i++)assert.ok(openCircuitCellVoltage(i/100,c)<=openCircuitCellVoltage((i+1)/100,c));
        const p=normalize({...base,chemistry:id,nominalVoltageVolts:null});
        assert.equal(p.nominal,p.cellCount*c.nominalVolts);
        assert.ok(create({...base,chemistry:id}).snapshot().packVoltageVolts>0);
    }
    assert.equal(chemistry('Li-ion').id,'LiIon');
    assert.equal(chemistry('LiFePO4').id,'LiFePO4');
    assert.equal(create({...base,chemistry:'custom legacy pack'}),null);
});

test('chemistry presets vary voltage and sag for equivalent packs',()=>{
    const initial=ids.map(id=>create({...base,chemistry:id,nominalVoltageVolts:null}).snapshot());
    assert.ok(initial[1].cellVoltageVolts>initial[0].cellVoltageVolts);
    assert.ok(initial[3].cellVoltageVolts<initial[2].cellVoltageVolts);
    assert.ok(initial[4].cellVoltageVolts<initial[3].cellVoltageVolts);
    const lipo=create(base), liion=create({...base,chemistry:'LiIon'});
    for(let i=0;i<100;i++){lipo.tick(.1,18,0);liion.tick(.1,18,0);}
    assert.ok(liion.snapshot().currentAmps>lipo.snapshot().currentAmps);
    assert.ok(liion.snapshot().cellVoltageVolts<lipo.snapshot().cellVoltageVolts);
    assert.equal(liion.snapshot().thresholdSource,'chemistry');
});

test('reference current capability is flagged and battery overrides take precedence',()=>{
    const pack=normalize({...base,chemistry:'LiIon'});
    assert.ok(pack.resistance>0);
    const natural=estimateLoad(pack,0.5,800,pack.resistance);
    assert.ok(natural.currentLimitAmps>0);
    assert.ok(natural.exceedsReferenceCurrent);
    const tuned=normalize({...base,chemistry:'LiIon',continuousDischargeC:80,resistanceOhmsPerCell:.001});
    assert.equal(tuned.dischargeC,80);
    assert.equal(tuned.resistance,.001);
    assert.ok(!estimateLoad(tuned,0.5,800,tuned.resistance).exceedsReferenceCurrent);
    assert.ok(tuned.cell.referenceContinuousC!==tuned.dischargeC);
    const exhausted=create({...base,chargePercent:0});
    assert.equal(exhausted.snapshot().remainingEnergyWh,0);
});

test('chemistry thresholds are automatic unless user explicitly opts out',async()=>{
    const {createSimulator}=require('../../web/free_flight.js');
    const sim=createSimulator({sampleHeight:async()=>100,renderedHeight:()=>100,captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},isTerrainReady:()=>true,onState:()=>{}});
    await sim.start({latitude:46,longitude:8,agl:10,flightMode:'gps',showBatteryVoltage:true,
        batteryProfile:{...base,chemistry:'LiFePO4'},batteryUseChemistryThresholds:true},new AbortController().signal);
    assert.equal(sim.status().battery.thresholdSource,'chemistry');
    sim.batteryHud({enabled:true,showCell:true,low:3.5,critical:3.3,useChemistryThresholds:false});
    assert.equal(sim.status().battery.thresholdSource,'custom');
    sim.batteryHud({enabled:true,showCell:true,low:3.5,critical:3.3,useChemistryThresholds:true});
    assert.equal(sim.status().battery.thresholdSource,'chemistry');
    sim.stop();
});

test('custom internal resistance overrides HUD override and battery type capacity',()=>{
    const configured = {...base, continuousDischargeC:10, resistanceOhmsPerCell:.003};
    const model=create(configured,{resistanceOhmsPerCell:.08});
    const expected=estimateLoad(normalize(configured),1,0,.003);
    assert.ok(model.snapshot().packVoltageVolts>0);
    model.tick(.2,18,0);
    assert.ok(model.snapshot().cellVoltageVolts>2);
    assert.equal(normalize(configured).specificResistance,true);
    assert.ok(expected.currentLimitAmps===45);
    const overridden=create({...configured,resistanceOhmsPerCell:null},{resistanceOhmsPerCell:.08});
    overridden.tick(.2,18,0);
    assert.ok(model.snapshot().cellVoltageVolts>overridden.snapshot().cellVoltageVolts);
});

test('burst ratings are time-bounded and do not bypass continuous limits forever',()=>{
    const p=normalize({...base,continuousDischargeC:1,burstDischargeC:40,burstDurationSeconds:1});
    assert.equal(p.dischargeC,1);
    assert.equal(p.burstC,40);
    const during=estimateLoad(p,.8,500,p.resistance,.5);
    assert.ok(during.currentAmps>during.currentLimitAmps);
    assert.equal(during.exceedsReferenceCurrent,false);
    const after=estimateLoad(p,.8,500,p.resistance,2);
    assert.equal(after.exceedsReferenceCurrent,true);
    const simulated=create({...base,continuousDischargeC:1,burstDischargeC:40,burstDurationSeconds:.25});
    let state;
    for(let i=0;i<5;i++)state=simulated.tick(.2,18,0);
    assert.equal(state.exceedsReferenceCurrent,true);
    assert.equal(state.burstRemainingSeconds,0);
});


test('charging references distinguish lithium CV limits from nickel peak detection',()=>{
    const chemistries=require('../../web/battery_chemistries.generated.js');
    assert.equal(chemistries.LiPo.maxChargeVoltsPerCell,4.2);
    assert.equal(chemistries.LiHV.maxChargeVoltsPerCell,4.35);
    assert.equal(chemistries.LiFePO4.maxChargeVoltsPerCell,3.65);
    assert.equal(chemistries.NiMH.maxChargeVoltsPerCell,null);
    assert.equal(chemistries.NiCd.chargeMethod,'delta_peak_temperature');
});

test('ESC and motor current warnings are independent per-unit DC proxies',()=>{
    const p={...base,motorCount:4,escContinuousCurrentAmpsPerChannel:1,
        motorContinuousCurrentAmpsPerMotor:50};
    const model=create(p);
    model.tick(.2,18,0);
    const s=model.snapshot();
    assert.ok(s.estimatedInputCurrentPerMotorAmps>1);
    assert.equal(s.escPossiblyOverloaded,true);
    assert.equal(s.motorPossiblyOverloaded,false);
    const reverse=create({...p,escContinuousCurrentAmpsPerChannel:100,
        motorContinuousCurrentAmpsPerMotor:1});
    reverse.tick(.2,18,0);
    assert.equal(reverse.snapshot().escPossiblyOverloaded,false);
    assert.equal(reverse.snapshot().motorPossiblyOverloaded,true);
    const unknown=create({...p,motorCount:null});
    unknown.tick(.2,18,0);
    assert.equal(unknown.snapshot().escPossiblyOverloaded,null);
});
