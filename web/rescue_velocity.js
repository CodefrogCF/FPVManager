// Legacy GPS Rescue velocity tracking and shared safe-approach speed guidance.
// Advanced Rescue uses approachSpeed only: actual motion is force-driven.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVRescueVelocity=api;})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
    function advance(velocity,goal,dt,acceleration,deceleration,limit){
        if(![velocity.north,velocity.east,goal.north,goal.east,dt,acceleration,deceleration,limit].every(Number.isFinite)||
            dt<0||acceleration<=0||deceleration<=0||limit<=0)throw Error('Invalid autonomous velocity');
        const speed=Math.hypot(goal.north,goal.east),scale=speed>limit?limit/speed:1;
        const desired={north:goal.north*scale,east:goal.east*scale};
        const difference={north:desired.north-velocity.north,east:desired.east-velocity.east};
        const magnitude=Math.hypot(difference.north,difference.east);
        const braking=desired.north*velocity.north+desired.east*velocity.east < 0 || speed<Math.hypot(velocity.north,velocity.east);
        const step=Math.min(magnitude,(braking?deceleration:acceleration)*dt);
        const ratio=magnitude>0?step/magnitude:0;
        const next={north:velocity.north+difference.north*ratio,east:velocity.east+difference.east*ratio};
        return {next,travel:{north:(velocity.north+next.north)*.5*dt,east:(velocity.east+next.east)*.5*dt}};
    }
    function approachSpeed(distance,desiredSpeed,deceleration){
        return Math.min(desiredSpeed,Math.sqrt(Math.max(0,2*deceleration*Math.max(0,distance-2))));
    }
    return {advance,approachSpeed};
});
