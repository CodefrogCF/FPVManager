'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {run,profiles,scenarios,maximumDifference}=require('../../tool/benchmarks/physics_validation/scenarios.cjs');
const {parseCsv,compare}=require('../../tool/benchmarks/physics_validation/telemetry.cjs');
const last=r=>r.trace.at(-1);
let all;
async function benchmarks(){return all??=Promise.all(Object.keys(profiles).map(async profile=>[profile,Object.fromEntries(await Promise.all(Object.keys(scenarios).map(async scenario=>[scenario,await run({profile,scenario})])))] )).then(Object.fromEntries);}
test('two documented benchmark profiles, all scripted scenarios and finite normalized states',async()=>{
    const results=await benchmarks();assert.equal(profiles['reference-7-inch'].propulsionProfile.takeoffWeightGrams,1320);
    for(const scenarios of Object.values(results))for(const r of Object.values(scenarios)){
        assert.equal(r.trace.length,r.durationSeconds*10+1);
        assert.ok(Math.abs(r.diagnostics.simulatedSeconds-r.durationSeconds)<1e-7);assert.equal(r.diagnostics.droppedSeconds,0);
        for(const s of r.trace){for(const v of Object.values(s))if(typeof v==='number')assert.ok(Number.isFinite(v));
            assert.ok(Math.abs(Math.hypot(s.qw,s.qx,s.qy,s.qz)-1)<1e-8);assert.ok(s.energy_wh>=0&&s.current_a>=0&&s.voltage_v>0);
            assert.ok(Math.abs(s.power_w-s.voltage_v*s.current_a)<1e-5);
        }
    }
});
test('all synthetic advanced traces are deterministic at 30, 60 and 120 render FPS',async()=>{
    const results=await benchmarks();for(const [profile,rs] of Object.entries(results))for(const [scenario,r] of Object.entries(rs))for(const fps of [30,120]){
        const other=await run({profile,scenario,fps});assert.equal(other.diagnostics.droppedSeconds,0);
        for(const [k,v] of Object.entries(maximumDifference(r,other)))assert.ok(v<1e-7,`${profile} ${scenario} ${fps} ${k} ${v}`);
    }
});
test('reference hover, climb, cruise, brake, freefall and low-power limits remain plausible',async()=>{
    const r=(await benchmarks())['reference-7-inch'];
    assert.ok(Math.abs(last(r.hover).altitude_change_m)<1);
    assert.ok(last(r.climb).altitude_change_m>20);assert.ok(last(r.cruise).horizontal_speed_mps>10);
    assert.ok(r.hover.enduranceEstimate.remainingMinutesAtSameLoad>0);assert.equal(r.freefall.enduranceEstimate,null);
    assert.ok(last(r.braking).speed_mps<.2);assert.ok(last(r.freefall).vertical_speed_mps<-10);
    assert.equal(last(r.freefall).thrust_accel_mps2,0);assert.ok(last(r.freefall).energy_wh<.05);
    assert.ok(last(r.lowPower).thrust_accel_mps2<9.80665);assert.ok(last(r.lowPower).altitude_change_m<0);
    assert.ok(last(r.lowPower).battery_limited);assert.ok(last(r.climb).energy_wh>last(r.freefall).energy_wh);
    assert.ok(last(r.dive).altitude_change_m<0);assert.ok(last(r.wind).speed_mps<1);
    const five=(await benchmarks())['synthetic-5-inch'];assert.ok(Math.abs(last(five.climb).altitude_change_m-last(r.climb).altitude_change_m)>5);
    assert.ok(last(five.hover).energy_wh<last(r.hover).energy_wh);
});
test('landing, collision barrier, rescue phases and manual takeover run through real simulator logic',async()=>{
    const r=(await benchmarks())['reference-7-inch'];assert.ok(r.landing.collisions.includes('rest'));
    assert.ok(r.landing.trace.find(p=>p.time_s===2).speed_mps<.01);assert.ok(last(r.landing).altitude_m>2);
    assert.ok(r.collision.wallChecks>0&&r.collision.maxWallDistance<=.00009);assert.ok(r.collision.collisions.includes('hard-stop'));
    for(const phase of ['rescueHold','climb','turn','return','landing','landed'])assert.ok(r.rescue.phases.includes(phase));
    assert.equal(last(r.rescue).thrust_accel_mps2,0);assert.equal(last(r.takeover).phase,'normal');
});
test('injected render stall reports bounded catch-up, and legacy stays available',async()=>{
    const r=await run({scenario:'cruise',measure:true,stall:true});assert.ok(r.diagnostics.droppedSeconds>=1.49);
    assert.ok(r.diagnostics.maxQueuedSeconds<=.5);assert.ok(r.diagnostics.maxSubsteps<=24);assert.ok(r.performance.step.count>0);
    const legacy=await run({model:'legacy',scenario:'hover',measure:true});assert.equal(legacy.model,'legacy');assert.ok(legacy.performance.step.count>0);
});
test('normalized telemetry compares only overlapping channels, handles angular wrap and quaternion sign',()=>{
    const rows=parseCsv('time_s,speed_mps,yaw_deg,qw,qx,qy,qz,voltage_v\n0,2,359,-1,0,0,0,\n0.1,4,1,1,0,0,0,21\n0.2,8,4,1,0,0,0,20');
    const trace=[{time_s:0,speed_mps:3,yaw_deg:1,qw:1,qx:0,qy:0,qz:0,voltage_v:22},{time_s:.1,speed_mps:4,yaw_deg:359,qw:-1,qx:0,qy:0,qz:0,voltage_v:22}];
    const r=compare({timeBasis:'script-clock',trace},rows);assert.equal(r.matchedRows,2);assert.equal(r.skippedRows,1);
    assert.equal(r.metrics.speed_mps.mae,.5);assert.equal(r.metrics.yaw_deg.mae,2);assert.equal(r.metrics.orientation_error_deg.mae,0);
    assert.equal(r.metrics.voltage_v.samples,1);assert.equal(r.validated,false);assert.equal(r.metrics.current_a,undefined);
    assert.equal(compare({timeBasis:'script-clock',trace},rows,{offsetSeconds:5}).matchedRows,0);
});
test('telemetry rejects ambiguous timestamps, units and invalid numbers without guessing',()=>{
    for(const csv of ['time_ms,speed_mps\n0,1\n1,2','time_s,speed_mps\n0,1\n0,2','time_s,speed_mps\n0,Infinity\n1,2','time_s,speed_mps\n0,-1\n1,2','time_s,qw\n0,1\n1,1','time_s,speed_mps,qw,qx,qy,qz\n0,-1,,,,\n1,2,1,0,0,0'])assert.throws(()=>parseCsv(csv));
});
