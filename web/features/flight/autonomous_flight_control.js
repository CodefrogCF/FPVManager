// Simulation-only guidance and attitude/thrust control for Advanced GPS and
// GPS Rescue. Body axes: forward/right/down; world: north/east/up.
// No position, velocity, altitude or heading state is mutated here.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVAutonomousFlightControl=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const g=9.80665,rad=Math.PI/180;
    const clamp=(v,lo,hi)=>Math.max(lo,Math.min(hi,v));
    const wrapAngle=a=>Math.atan2(Math.sin(a),Math.cos(a));
    const normalize=v=>{const n=Math.hypot(v.x,v.y,v.z);return {x:v.x/n,y:v.y/n,z:v.z/n};};
    const conj=q=>({w:q.w,x:-q.x,y:-q.y,z:-q.z});
    const multiply=(a,b)=>({w:a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,
        x:a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,y:a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,
        z:a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w});
    function rotate(q,v){const r=multiply(multiply(q,{w:0,...v}),conj(q));return {x:r.x,y:r.y,z:r.z};}
    function euler(yaw,pitch,roll){
        const axis=(a,x,y,z)=>({w:Math.cos(a/2),x:x*Math.sin(a/2),y:y*Math.sin(a/2),z:z*Math.sin(a/2)});
        return multiply(multiply(axis(yaw,0,0,1),axis(pitch,0,1,0)),axis(roll,1,0,0));
    }
    // Reuse the existing rescue approach/braking calculation; the velocity is
    // a GUIDANCE target, never assigned to the actual aircraft state.
    function rescueTargets(phase,position,home,distanceToHome,bearingToHome,height,targetAltitude,heading,config,approachSpeed){
        const target={north:0,east:0,up:0,heading};
        if(phase==='climb'){
            target.up=clamp((targetAltitude-height)*.6,0,
                Math.min(config.failsafe.climbSpeedMetersPerSecond,config.climbSpeed));
        }else if(phase==='turn'){
            target.heading=bearingToHome;
            target.up=clamp((targetAltitude-height)*.5,-config.climbSpeed,config.climbSpeed);
        }else if(phase==='return'){
            if(distanceToHome>3){
                const speed=approachSpeed(distanceToHome,
                    Math.min(config.failsafe.returnSpeedMetersPerSecond,config.maxSpeed),config.deceleration);
                target.north=Math.cos(bearingToHome)*speed;
                target.east=Math.sin(bearingToHome)*speed;
            }
            target.up=clamp((targetAltitude-height)*.5,-config.climbSpeed,config.climbSpeed);
            // Remain forward-facing on the return leg.
            target.heading=bearingToHome;
        }else if(phase==='landing'){
            if(distanceToHome>1){
                const speed=Math.min(2,approachSpeed(distanceToHome,2,config.deceleration));
                target.north=Math.cos(bearingToHome)*speed;
                target.east=Math.sin(bearingToHome)*speed;
            }
            if(distanceToHome<=3)target.up=-Math.min(1.5,config.climbSpeed);
        }else if(phase==='descend')target.up=-Math.min(1,config.climbSpeed);
        // 'hold', 'rescueHold', 'unavailable' and 'landed' request a stop.
        return target;
    }
    function manualTargets(forward,right,up,heading,config){
        const length=Math.max(1,Math.hypot(forward,right));
        const f=forward/length,r=right/length;
        return {north:(Math.cos(heading)*f-Math.sin(heading)*r)*config.maxSpeed,
            east:(Math.sin(heading)*f+Math.cos(heading)*r)*config.maxSpeed,
            up:clamp(up,-1,1)*config.climbSpeed,heading};
    }
    function accelerationRequest(current,target,config){
        const difference={north:target.north-current.north,east:target.east-current.east};
        const length=Math.hypot(difference.north,difference.east);
        const reducing=target.north*current.north+target.east*current.east<0||
            Math.hypot(target.north,target.east)<Math.hypot(current.north,current.east);
        const limit=reducing?config.deceleration:config.acceleration;
        const scaled=length>1e-12?Math.min(limit,3*length)/length:0;
        return {north:difference.north*scaled,east:difference.east*scaled,
            up:clamp(3*(target.up-current.up),-config.deceleration,config.acceleration)};
    }
    function dragAcceleration(velocity,wind,attitude,aerodynamics,dragModel,motorCommand){
        const body=dragModel.bodyAirVelocity(velocity,wind,attitude);
        const coeff=dragModel.dragCoefficients(aerodynamics,body,motorCommand);
        const drag=rotate(attitude,{x:-coeff.x*body.x*Math.abs(body.x),
            y:-coeff.y*body.y*Math.abs(body.y),z:-coeff.z*body.z*Math.abs(body.z)});
        return {north:drag.x,east:drag.y,up:-drag.z};
    }
    // Desired world-space acceleration -> thrust vector -> attitude. Vertical
    // force always includes gravity, and all demands are bounded by maximum
    // deliverable thrust, configured acceleration and 45-degree tilt.
    function command(current,target,attitude,wind,config,aerodynamics,dragModel,maxThrustAcceleration,motorCommand){
        const request=accelerationRequest(current,target,config);
        const drag=dragAcceleration(current,wind,attitude,aerodynamics,dragModel,motorCommand);
        let north=request.north-drag.north,east=request.east-drag.east;
        let up=clamp(g+request.up-drag.up,0,Math.max(0,maxThrustAcceleration));
        const horizontal=Math.hypot(north,east);
        const tiltLimit=Math.tan(45*rad)*Math.max(0,up);
        if(horizontal>tiltLimit&&horizontal>0){const scale=tiltLimit/horizontal;north*=scale;east*=scale;}
        let magnitude=Math.hypot(north,east,up);
        if(magnitude>maxThrustAcceleration&&magnitude>0){
            const ratio=maxThrustAcceleration/magnitude;north*=ratio;east*=ratio;up*=ratio;magnitude=maxThrustAcceleration;
        }
        // In north/east/down coordinates desired body thrust is (N,E,-up).
        // Find a right-handed attitude whose body-up axis aligns with thrust.
        const yaw=Number.isFinite(target.heading)?target.heading:0;
        const forward=Math.cos(yaw)*north+Math.sin(yaw)*east;
        const right=-Math.sin(yaw)*north+Math.cos(yaw)*east;
        const pitch=-Math.atan2(forward,Math.max(1e-12,up));
        const roll=Math.atan2(right,Math.hypot(up,forward));
        const desired=euler(yaw,pitch,roll);
        let error=multiply(conj(attitude),desired);
        if(error.w<0)error={w:-error.w,x:-error.x,y:-error.y,z:-error.z};
        const magnitudeError=Math.hypot(error.x,error.y,error.z);
        const theta=2*Math.atan2(magnitudeError,Math.max(0,error.w));
        const scale=magnitudeError>1e-12?theta/magnitudeError:2;
        const rates={x:clamp(error.x*scale*8,-config.acroRollRate*rad,config.acroRollRate*rad),
            y:clamp(error.y*scale*8,-config.acroPitchRate*rad,config.acroPitchRate*rad),
            z:clamp(error.z*scale*5,-config.acroYawRate*rad,config.acroYawRate*rad)};
        return {rates,thrustAcceleration:magnitude,desiredAttitude:desired,
            targetVelocity:{...target},requestedAcceleration:request,
            actualThrustTarget:{north,east,up},targetTiltRadians:Math.atan2(Math.hypot(north,east),up)};
    }
    return {rescueTargets,manualTargets,accelerationRequest,dragAcceleration,command};
});
