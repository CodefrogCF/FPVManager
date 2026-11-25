'use strict';
const {createSimulator}=require('../../../web/features/flight/free_flight.js');
const profiles=require('./profiles.json');
const {createProvider}=require('../../../web/features/weather/environmental_wind.js');
const {performance}=require('node:perf_hooks');
const home={latitude:46.7,longitude:8.4};
const rc=q=>({controlLink:{quality:q,source:'estimatedModel'}});
const flight=(throttle=0,pitch=0,roll=0,yaw=0)=>m=>m.flightInput({throttle,pitch,roll,yaw});
const stick=(forward=0,right=0)=>m=>m.stick(forward,right);
const rescue={enabled:true,mode:'gpsRescue',activationDelaySeconds:.2,recoveryDelaySeconds:.3,rescueAltitudeMeters:5,returnSpeedMetersPerSecond:7};
const scenarios={
    hover:{mode:'gps',duration:10,events:[]},
    climb:{mode:'acro',duration:5,events:[[0,flight(.8)]]},
    cruise:{mode:'gps',duration:15,events:[[0,stick(1)]]},
    dive:{mode:'acro',duration:8,events:[[0,flight(.5,-.6)],[1,flight(0)],[5,flight(.8,.5)],[6,flight(.7)]]},
    braking:{mode:'gps',duration:12,events:[[0,stick(1)],[6,stick()]]},
    freefall:{mode:'acro',duration:5,events:[]},
    rotation:{mode:'acro',duration:6,events:[[0,flight(.5,0,1)],[1,flight(0,0,-1)],[2,flight(0)],[3,flight(.5,1,0,1)],[4,flight(.5)]]},
    lowPower:{mode:'acro',duration:5,lowPower:true,events:[[0,flight(1)]]},
    wind:{mode:'gps',duration:12,wind:true,events:[[0,stick(.5)],[6,stick()]]},
    landing:{mode:'acro',agl:1,duration:5,events:[[0,flight(0)],[3,flight(.85)]]},
    collision:{mode:'gps',duration:8,wall:true,events:[[0,stick(1,.3)]]},
    rescue:{mode:'gps',agl:10,duration:40,events:[[0,stick(1)],[4,m=>{m.stick(0,0);m.linkAssessment(rc(0));}]],failsafe:rescue},
    takeover:{mode:'acro',duration:8,events:[[0,flight(.5)],[1,m=>m.linkAssessment(rc(0))],[4,m=>m.linkAssessment(rc(.9))],[5,flight(.5,0,.3)],[6,flight(.5)]],failsafe:rescue}
};
function percentile(values,p){const a=[...values].sort((x,y)=>x-y);return a.length?a[Math.ceil(a.length*p)-1]:null;}
function timing(values){return {count:values.length,p50Ms:percentile(values,.5),p95Ms:percentile(values,.95),maxMs:values.length?values.reduce((max,v)=>Math.max(max,v),0):null};}
function sample(s,t,previous){const b=s.battery?.available?s.battery:null;
    const out={time_s:t,speed_mps:s.speed,horizontal_speed_mps:s.horizontalSpeed,vertical_speed_mps:s.verticalSpeed,airspeed_mps:s.airspeedMetersPerSecond,
        altitude_m:s.height-1000,altitude_change_m:null,roll_deg:s.roll*180/Math.PI,pitch_deg:s.pitch*180/Math.PI,yaw_deg:s.heading*180/Math.PI,
        qw:s.attitude.w,qx:s.attitude.x,qy:s.attitude.y,qz:s.attitude.z,
        voltage_v:b?.packVoltageVolts??null,current_a:b?.currentAmps??null,energy_wh:b?.consumedWh??null,power_w:b?.estimatedPowerWatts??null,
        thrust_accel_mps2:s.thrustAcceleration,distance_m:s.distance,phase:s.failsafe.phase,collision:s.lastCollision?.mode??null,
        terrain_state:s.terrainVerification.state,throttle:s.throttle, battery_remaining_wh:b?.remainingEnergyWh??null, battery_limited:b?.batteryCurrentLimited??null, esc_limited:b?.escCurrentLimited??null, motor_limited:b?.motorCurrentLimited??null};
    out.speed_change_mps2=previous?(out.speed_mps-previous.speed_mps)/(t-previous.time_s):null;
    out.vertical_accel_mps2=previous?(out.vertical_speed_mps-previous.vertical_speed_mps)/(t-previous.time_s):null;
    return out;}
async function run({profile='reference-7-inch',scenario='hover',fps=60,model='advanced',measure=false,stall=false}={}){
    if(!Object.hasOwn(profiles,profile)||!Object.hasOwn(scenarios,scenario)||![30,60,120].includes(fps)||!['legacy','advanced'].includes(model))throw Error('Unknown benchmark configuration');
    const p=profiles[profile],sc=scenarios[scenario],steps=[],frames=[],trace=[],phases=new Set(),collisions=new Set();
    let maxQueued=0,maxSubsteps=0,wallChecks=0,maxWallDistance=0;
    const env=sc.wind?createProvider({sampleLocal:()=>null}):null;
    if(env)env.configure(null,{fallbackSpeedMs:7,fallbackFromDegrees:230,gustSpeedMs:2,turbulenceIntensity:.4,seed:17});
    const sim=createSimulator({sampleHeight:async()=>1000,renderedHeight:()=>1000,isTerrainReady:()=>true,captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},onState:()=>{},
        ...(env?{sampleWind:env.sample}:{}),
        ...(sc.wall?{modeledCollision:(from,to)=>{wallChecks++;if(to.latitude>home.latitude+.00009)return 'wall';return false;}}:{}),
        ...(measure?{measurePhysicsStep:(integrate,dt)=>{const start=performance.now();integrate(dt);steps.push(performance.now()-start);}}:{})});
    await sim.start({...home,agl:sc.agl??200,physicsModel:model,physicsStepHz:120,flightMode:sc.mode,maxSpeed:12,climbSpeed:5,acceleration:9,deceleration:7,showBatteryVoltage:true,
        acroRollRate:360,acroPitchRate:360,acroYawRate:300,propulsionProfile:p.propulsionProfile,batteryProfile:{...p.batteryProfile,...(sc.lowPower?{chargePercent:12,continuousDischargeC:.2}: {})},...(sc.failsafe?{failsafe:sc.failsafe}:{})},new AbortController().signal);
    const time0=performance.now(),cpu0=process.cpuUsage(),mem0=process.memoryUsage();let peakHeap=mem0.heapUsed,peakRss=mem0.rss;
    trace.push(sample(sim.status(),0,null));trace[0].altitude_change_m=0;
    for(let i=0;i<sc.duration*fps;i++){
        for(const [t,action] of sc.events)if(i===t*fps)action(sim);
        const start=performance.now();sim.tick(stall&&i===fps?2:1/fps);if(measure)frames.push(performance.now()-start);
        const s=sim.status(),d=s.physicsDiagnostics;
        phases.add(s.failsafe.phase);if(s.lastCollision)collisions.add(s.lastCollision.mode);
        maxQueued=Math.max(maxQueued,d.queuedSeconds);maxSubsteps=Math.max(maxSubsteps,d.lastSubsteps);
        if(sc.wall)maxWallDistance=Math.max(maxWallDistance,s.position.latitude-home.latitude);
        if((i+1)%(fps/10)===0){const point=sample(s,(i+1)/fps,trace.at(-1));point.altitude_change_m=point.altitude_m-trace[0].altitude_m;trace.push(point);}
        if(measure&&(i+1)%fps===0){const m=process.memoryUsage();peakHeap=Math.max(peakHeap,m.heapUsed);peakRss=Math.max(peakRss,m.rss);}
    }
    const elapsedMs=performance.now()-time0,cpu=process.cpuUsage(cpu0),mem1=process.memoryUsage(),s=sim.status();sim.stop();
    // Only steady scenario tails; never claim a real full-pack endurance measurement.
    const tail=trace.filter(point=>point.time_s>=sc.duration-5),end=trace.at(-1),begin=tail[0];
    const meanPower=(end.energy_wh-begin.energy_wh)*3600/(end.time_s-begin.time_s);
    const enduranceEstimate=!stall&&['hover','cruise'].includes(scenario)&&meanPower>0&&Number.isFinite(end.battery_remaining_wh)?
        {steadyWindowSeconds:end.time_s-begin.time_s,meanPowerWatts:meanPower,remainingMinutesAtSameLoad:end.battery_remaining_wh/meanPower*60,source:'synthetic-constant-load-extrapolation'}:null;
    return {profile,scenario,model,fps,altitudeDatum:'synthetic-ground-relative',timeBasis:stall?'script-clock-with-injected-stall':'script-clock',durationSeconds:sc.duration,
        trace,enduranceEstimate,phases:[...phases],collisions:[...collisions],wallChecks,maxWallDistance,diagnostics:{...s.physicsDiagnostics,maxQueuedSeconds:maxQueued,maxSubsteps},
        ...(measure?{performance:{elapsedMs,cpuMs:(cpu.user+cpu.system)/1000,step:timing(steps),frameTick:timing(frames),heapStartBytes:mem0.heapUsed,heapEndBytes:mem1.heapUsed,heapSampledPeakBytes:Math.max(peakHeap,mem1.heapUsed),rssSampledPeakBytes:Math.max(peakRss,mem1.rss)}}:{})};
}
function maximumDifference(a,b){if(a.trace.length!==b.trace.length)throw Error('Trace lengths differ');const result={};for(let i=0;i<a.trace.length;i++)for(const k of Object.keys(a.trace[i])){
    const x=a.trace[i][k],y=b.trace[i][k];if(typeof x==='number'&&typeof y==='number')result[k]=Math.max(result[k]??0,Math.abs(x-y));else if(x!==y)throw Error(`Trace mismatch ${k} at ${i}`);
}return result;}
module.exports={profiles,scenarios,run,maximumDifference};
