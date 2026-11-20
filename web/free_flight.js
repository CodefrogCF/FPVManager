(function(root,factory){
    const isNode=typeof module==='object'&&module.exports;
    const api=factory(isNode?require('./controller_input.js'):root.FPVControllerInput,
        isNode?require('./battery_simulation.js'):root.FPVBatterySimulation,
        isNode?require('./signal_hud.js'):root.FPVSignalHud,
        isNode?require('./simulated_failsafe.js'):root.FPVSimulatedFailsafe,
        isNode?require('./rescue_velocity.js'):root.FPVRescueVelocity,
        isNode?require('./flight_physics.js'):root.FPVFlightPhysics);
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVFreeFlight=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(controller,batterySimulation,signalHud,failsafeModule,rescueVelocity,flightPhysics){
    'use strict';
    const R=6378137,rad=Math.PI/180,g=9.80665;
    const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
    const valid=p=>p&&Number.isFinite(p.latitude)&&Number.isFinite(p.longitude)&&Math.abs(p.latitude)<89.9&&Math.abs(p.longitude)<=180;
    const wrap=a=>((a%(2*Math.PI))+2*Math.PI)%(2*Math.PI);
    const rateCommand=(stick,maximum,expo)=>maximum*stick*((1-expo)+expo*stick*stick);
    function move(p,north,east){return {latitude:p.latitude+north/R/rad,
        longitude:((p.longitude+east/(R*Math.cos(p.latitude*rad))/rad+540)%360)-180};}
    function distance(a,b){
        const x=(a.latitude-b.latitude)*rad,y=(a.longitude-b.longitude)*rad;
        const h=Math.sin(x/2)**2+Math.cos(a.latitude*rad)*Math.cos(b.latitude*rad)*Math.sin(y/2)**2;
        return 2*R*Math.asin(Math.sqrt(clamp(h,0,1)));
    }
    function bearing(a,b){
        const lat1=a.latitude*rad,lat2=b.latitude*rad,dl=(b.longitude-a.longitude)*rad;
        return wrap(Math.atan2(Math.sin(dl)*Math.cos(lat2),
            Math.cos(lat1)*Math.sin(lat2)-Math.sin(lat1)*Math.cos(lat2)*Math.cos(dl)));
    }
    function parameters(c){
        const p={agl:c.agl??20,maxSpeed:c.maxSpeed??15,climbSpeed:c.climbSpeed??5,
            acceleration:c.acceleration??6,deceleration:c.deceleration??4,flightMode:c.flightMode??'angle',cameraTiltDegrees:c.cameraTiltDegrees??0,cameraFovDegrees:c.cameraFovDegrees??90,graphicsProfile:c.graphicsProfile??'balanced',hudStyle:c.hudStyle??'goggles',physicsModel:c.physicsModel??'legacy',physicsStepHz:c.physicsStepHz??120,showCoordinates:c.showCoordinates??false,
            showBatteryVoltage:c.showBatteryVoltage??false,showBatteryCellVoltage:c.showBatteryCellVoltage??false,
            signalHud:signalHud.settings(c.signalHud??{}),failsafe:failsafeModule.configuration(c.failsafe??{}),
            lowBatteryCellVoltage:c.lowBatteryCellVoltage??3.5,criticalBatteryCellVoltage:c.criticalBatteryCellVoltage??3.3,
            batteryUseChemistryThresholds:c.batteryUseChemistryThresholds??true,
            batterySagResistanceOhmsPerCell:c.batterySagResistanceOhmsPerCell??0,batteryProfile:c.batteryProfile??null,
            acroThrustToWeight:c.acroThrustToWeight??4,acroThrustCurve:c.acroThrustCurve??1,
            acroMotorTimeConstant:c.acroMotorTimeConstant??.04,acroTerminalVelocity:c.acroTerminalVelocity??22.5,
            acroRollRate:c.acroRollRate??180,acroPitchRate:c.acroPitchRate??180,
            acroYawRate:c.acroYawRate??180,acroRateExpo:c.acroRateExpo??0,controller:controller.configuration(c.controller)};
        for(const [key,min,max] of [['agl',1,1000],['maxSpeed',.5,100],['climbSpeed',.2,30],
            ['acceleration',.2,50],['deceleration',.2,50],['cameraTiltDegrees',0,80],['cameraFovDegrees',50,140],['acroThrustToWeight',1.1,12],
            ['acroThrustCurve',0,1],['acroMotorTimeConstant',0,.5],['acroTerminalVelocity',5,120],
            ['acroRollRate',10,1500],['acroPitchRate',10,1500],['acroYawRate',10,1500],['acroRateExpo',0,1]]){
            if(!Number.isFinite(p[key])||p[key]<min||p[key]>max)throw new Error(`Invalid flight ${key}`);
        }
        if(!['gps','angle','acro'].includes(p.flightMode))throw new Error('Unknown flight mode');
        flightPhysics.configuration({mode:p.physicsModel,hz:p.physicsStepHz});
        if(!['quality','balanced','performance','compatibility'].includes(p.graphicsProfile))throw new Error('Unknown flight graphics profile');
        if(!['goggles','betaflight'].includes(p.hudStyle))throw new Error('Unknown flight HUD style');
        if(typeof p.showCoordinates!=='boolean')throw new Error('Invalid HUD coordinate visibility');
        if(typeof p.showBatteryVoltage!=='boolean'||typeof p.showBatteryCellVoltage!=='boolean')throw new Error('Invalid battery HUD visibility');
        if(!Number.isFinite(p.lowBatteryCellVoltage)||!Number.isFinite(p.criticalBatteryCellVoltage)||
            p.criticalBatteryCellVoltage<.5||p.criticalBatteryCellVoltage>4.4||p.lowBatteryCellVoltage<.6||p.lowBatteryCellVoltage>4.5||p.lowBatteryCellVoltage<=p.criticalBatteryCellVoltage)
            throw new Error('Invalid estimated battery voltage thresholds');
        if(typeof p.batteryUseChemistryThresholds!=='boolean')throw new Error('Invalid chemistry threshold mode');
        if(!Number.isFinite(p.batterySagResistanceOhmsPerCell)||p.batterySagResistanceOhmsPerCell<0||p.batterySagResistanceOhmsPerCell>.1)
            throw new Error('Invalid estimated battery sag');
        return p;
    }
    // Body forward/right/down -> local north/east/down, a right-handed frame.
    // Quaternions keep Acro attitude continuous through inverted flight/loops.
    const multiply=(a,b)=>({w:a.w*b.w-a.x*b.x-a.y*b.y-a.z*b.z,
        x:a.w*b.x+a.x*b.w+a.y*b.z-a.z*b.y,y:a.w*b.y-a.x*b.z+a.y*b.w+a.z*b.x,
        z:a.w*b.z+a.x*b.y-a.y*b.x+a.z*b.w});
    function normalized(q){const n=Math.hypot(q.w,q.x,q.y,q.z);return {w:q.w/n,x:q.x/n,y:q.y/n,z:q.z/n};}
    function rotate(q,v){const p=multiply(multiply(q,{w:0,...v}),{w:q.w,x:-q.x,y:-q.y,z:-q.z});return {x:p.x,y:p.y,z:p.z};}
    function euler(yaw,pitch,roll){
        const axis=(angle,x,y,z)=>({w:Math.cos(angle/2),x:x*Math.sin(angle/2),y:y*Math.sin(angle/2),z:z*Math.sin(angle/2)});
        return multiply(multiply(axis(yaw,0,0,1),axis(pitch,0,1,0)),axis(roll,1,0,0));
    }
    function createSimulator({sampleHeight,renderedHeight,terrainCollision,modeledCollision=()=>false,
        onSurfaceDiscontinuity=()=>false,captureCamera,restoreCamera,applyPose,applyGraphics,prepareGraphics,
        isTerrainReady,onState,sampleWind=()=>null}){
        let active=false,pending=false,paused=false,playback=false,operation=0,abort=null,saved=null,spawn=null,position=null;
        let height=0,heading=0,pitch=0,roll=0,ground=null,homeHeight=null,reason=null,config=parameters({}),q=euler(0,0,0);
        let velocity={north:0,east:0,up:0},rates={x:0,y:0,z:0},input={throttle:0,yaw:0,pitch:0,roll:0};
        let forward=0,right=0,vertical=0,throttle=0,motorThrust=0;
        let deferPose=false;
        let wind={north:0,east:0,up:0},windInfo=null;
        let battery=null,lastReplaySeconds=null,linkAssessment=null,wasFailsafeControlled=false;
        // A Cesium globe tile can be absent even when the terrain provider is ready.
        // Unknown heights must not be converted to a contact or a fabricated floor.
        let terrainVerification={state:'complete',samples:0,missingSamples:0,unverifiedDistanceMeters:0};
        const failsafe=failsafeModule.create();
        const keys=new Set();
        // Self-centring sticks: Acro uses only the upper half for motor command.
        function motorCommand(){return config.flightMode==='acro'?Math.max(0,throttle):(throttle+1)/2;}
        function clearKeys(){keys.clear();input.throttle=input.yaw=input.pitch=input.roll=0;forward=right=vertical=throttle=0;}
        function brake(){velocity={north:0,east:0,up:0};rates={x:0,y:0,z:0};}
        function orientation(attitude=q){
            const tilt=config.cameraTiltDegrees*rad,c=Math.cos(tilt),s=Math.sin(tilt);
            const f=rotate(attitude,{x:c,y:0,z:-s}),u=rotate(attitude,{x:-s,y:0,z:-c});
            return {direction:{north:f.x,east:f.y,up:-f.z},up:{north:u.x,east:u.y,up:-u.z}};
        }
        function status(){return {active,pending,paused,playback,flightId:operation,mode:config.flightMode,cameraTiltDegrees:config.cameraTiltDegrees,cameraFovDegrees:config.cameraFovDegrees,graphicsProfile:config.graphicsProfile,hudStyle:config.hudStyle,physicsModel:config.physicsModel,physicsStepHz:config.physicsStepHz,physicsDiagnostics:runtime?.diagnostics()??null,showCoordinates:config.showCoordinates,showBatteryVoltage:config.showBatteryVoltage,
            showBatteryCellVoltage:config.showBatteryCellVoltage,signalHud:{...config.signalHud},
            failsafeSettings:{...config.failsafe},failsafe:failsafe.status(),lowBatteryCellVoltage:config.lowBatteryCellVoltage,
            criticalBatteryCellVoltage:config.criticalBatteryCellVoltage,
            batteryUseChemistryThresholds:config.batteryUseChemistryThresholds,
            battery:config.showBatteryVoltage?(battery?.snapshot(config.batteryUseChemistryThresholds?{}:{lowVoltagePerCell:config.lowBatteryCellVoltage,criticalVoltagePerCell:config.criticalBatteryCellVoltage})??{available:false,estimated:true}):null,
            controller:config.controller,position:position&&{...position},height,heading,pitch,roll,
            throttle:motorCommand(),thrustAcceleration:motorThrust,verticalSpeed:velocity.up,wind:windInfo,
            attitude:{...q},agl:Number.isFinite(ground)?height-ground:null,
            terrainVerification:{...terrainVerification},
            speed:Math.hypot(velocity.north,velocity.east,velocity.up),horizontalSpeed:Math.hypot(velocity.north,velocity.east),
            // Simulator-modelled 3D air-relative speed. Never a measured sensor
            // reading; wind is the current simulated wind vector, not a forecast.
            airspeedMetersPerSecond:Math.hypot(velocity.north-wind.north,velocity.east-wind.east,velocity.up-wind.up),
            home:spawn&&{...spawn},heightAboveHome:Number.isFinite(homeHeight)?height-homeHeight:null,
            distance:spawn&&position?distance(spawn,position):0,reason};}
        function publish(){onState(status());}
        function pose(){if(!deferPose)applyPose({...position,...status(),...(config.flightMode==='gps'?{}:orientation())});}
        function physicsSnapshot(){return {position:position&&{...position},height,heading,pitch,roll,
            attitude:{...q},velocity:{...velocity},angularVelocity:{...rates},
            propulsionAcceleration:motorThrust,
            environment:{gravityAcceleration:{north:0,east:0,up:-g},
                windVelocity:{north:wind.north,east:wind.east,up:wind.up},
                // Collision queries are resolved by the shared swept-path layer.
                collisionSource:'terrain-and-supported-models'}};}
        function renderPhysics(previous,current,alpha){
            if(!active)return;
            if(!previous||!current||!previous.position||!current.position){pose();return;}
            const interpolated=flightPhysics.interpolateState(previous,current,alpha);
            const output={...status(),...interpolated};
            applyPose({...interpolated.position,...output,...(config.flightMode==='gps'?{}:orientation(interpolated.attitude))});
        }
        let runtime=null;
        function buildRuntime(){return flightPhysics.createRuntime({mode:config.physicsModel,hz:config.physicsStepHz,
            integrate:stepCore,snapshot:physicsSnapshot,present:renderPhysics,isActive:()=>active});}
        function stop(message=null){
            const running=active||pending;
            ++operation;abort?.abort();abort=null;clearKeys();brake();motorThrust=0;runtime?.reset();active=pending=paused=playback=false;reason=message;
            windInfo=null;wind={north:0,east:0,up:0};battery=null;lastReplaySeconds=null;failsafe.reset();linkAssessment=null;wasFailsafeControlled=false;
            terrainVerification={state:'complete',samples:0,missingSamples:0,unverifiedDistanceMeters:0};
            if(saved)restoreCamera(saved);saved=null;
            if(running)publish();
        }
        async function start(command,signal){
            if(!valid(command))throw new Error('Invalid simulation spawn position');
            const next=parameters(command);
            if(!isTerrainReady())throw new Error('Detailed terrain is required for simulated flight');
            stop();const token=++operation;abort=new AbortController();const request=abort;
            const cancel=()=>{if(token===operation)stop();};
            signal.addEventListener('abort',cancel,{once:true});pending=true;reason=null;publish();
            try{
                signal.throwIfAborted();const sampled=await sampleHeight(command,request.signal);
                signal.throwIfAborted();request.signal.throwIfAborted();
                if(token!==operation||!isTerrainReady())throw new Error('Simulation cancelled');
                if(!Number.isFinite(sampled))throw new Error('No terrain height at spawn');
                config=next;runtime=buildRuntime();failsafe.setConfiguration(next.failsafe);lastReplaySeconds=null;battery=batterySimulation.create(config.batteryProfile,
                    {resistanceOhmsPerCell:config.batterySagResistanceOhmsPerCell});saved=captureCamera();applyGraphics?.(config.graphicsProfile);spawn={latitude:command.latitude,longitude:command.longitude};
                position={...spawn};height=sampled+config.agl;ground=homeHeight=sampled;heading=saved.heading||0;pitch=roll=0;q=euler(heading,0,0);
                motorThrust=acroThrust(motorCommand());
                if(prepareGraphics){
                    pose();await prepareGraphics(request.signal);
                    signal.throwIfAborted();request.signal.throwIfAborted();
                    if(token!==operation||!isTerrainReady())throw new Error('Simulation cancelled');
                }
                active=true;pending=false;pose();publish();return {};
            }catch(error){if(token!==operation)return {cancelled:true};stop('Unable to start simulated flight');throw error;}
            finally{signal.removeEventListener('abort',cancel);}
        }
        function gpsStep(seconds){
            let f=forward+Number(keys.has('ArrowUp')||keys.has('w'))-Number(keys.has('ArrowDown')||keys.has('s'));
            let r=right+Number(keys.has('ArrowRight')||keys.has('d'))-Number(keys.has('ArrowLeft')||keys.has('a'));
            const length=Math.max(1,Math.hypot(f,r));f/=length;r/=length;
            const up=clamp(vertical+Number(keys.has('e'))-Number(keys.has('q')),-1,1);
            function response(v,target){
                const rate=(target===0?config.deceleration:config.acceleration)/Math.max(config.maxSpeed,config.climbSpeed);
                const decay=Math.exp(-rate*seconds);
                return {v:target+(v-target)*decay,d:target*seconds+(v-target)*(1-decay)/rate};
            }
            let airN=(Math.cos(heading)*f-Math.sin(heading)*r)*config.maxSpeed-wind.north;
            let airE=(Math.sin(heading)*f+Math.cos(heading)*r)*config.maxSpeed-wind.east;
            const norm=Math.max(1,Math.hypot(airN,airE)/config.maxSpeed);airN/=norm;airE/=norm;
            const n=response(velocity.north,airN+wind.north);
            const e=response(velocity.east,airE+wind.east);
            const z=response(velocity.up,up*config.climbSpeed);
            velocity={north:n.v,east:e.v,up:z.v};return {north:n.d,east:e.d,up:z.d};
        }
        // Approximate GPS-assisted autonomous velocity control. It passes through
        // the SAME segment collision and terrain sweep as manual flight.
        function automatedStep(seconds,state){
            const fs=config.failsafe;
            let targetNorth=0,targetEast=0,targetUp=0;
            if(['rescueHold','climb','turn','return','landing','landed'].includes(state.phase)&&position&&spawn&&Number.isFinite(homeHeight)){
                const meters=distance(position,spawn),altitude=state.targetAltitudeMeters??height;
                if(state.phase==='climb'){
                    targetUp=clamp((altitude-height)*.6,0,Math.min(fs.climbSpeedMetersPerSecond,config.climbSpeed));
                }else if(state.phase==='turn'){
                    const direction=bearing(position,spawn);
                    const angle=Math.atan2(Math.sin(direction-heading),Math.cos(direction-heading));
                    heading=wrap(heading+clamp(angle,-1.5*seconds,1.5*seconds));
                    targetUp=clamp((altitude-height)*.5,-config.climbSpeed,config.climbSpeed);
                }else if(state.phase==='return'&&meters>3){
                    const speed=rescueVelocity.approachSpeed(meters,
                        Math.min(fs.returnSpeedMetersPerSecond,config.maxSpeed),config.deceleration);
                    const direction=bearing(position,spawn);
                    targetNorth=Math.cos(direction)*speed;targetEast=Math.sin(direction)*speed;
                    // Return at the attained rescue altitude, without a continuous yaw turn.
                    targetUp=clamp((altitude-height)*.5,-config.climbSpeed,config.climbSpeed);
                }else if(state.phase==='landing'){
                    // Complete horizontal braking near home, then descend slowly.
                    if(meters>1){const direction=bearing(position,spawn);
                        const speed=Math.min(2,rescueVelocity.approachSpeed(meters,2,config.deceleration));
                        targetNorth=Math.cos(direction)*speed;targetEast=Math.sin(direction)*speed;}
                    if(meters<=3)targetUp=-Math.min(1.5,config.climbSpeed);
                }
            }else if(state.phase==='descend')targetUp=-Math.min(1,config.climbSpeed);
            // Use normal deceleration/acceleration and the current wind model,
            // with no unbounded jump when entering or leaving rescue.
            // Coupled vector controller reaches the feasible commanded speed without
            // applying the manual-stick smoothing twice. Braking distance limits
            // the approach speed; all travel still uses the normal collision sweep.
            const planar=rescueVelocity.advance(velocity,{north:targetNorth,east:targetEast},seconds,
                config.acceleration,config.deceleration,config.maxSpeed);
            velocity.north=planar.next.north;velocity.east=planar.next.east;
            const upChange=clamp(targetUp-velocity.up,-config.deceleration*seconds,config.acceleration*seconds);
            const nextUp=clamp(velocity.up+upChange,-config.climbSpeed,config.climbSpeed);
            const travel={...planar.travel,up:(velocity.up+nextUp)*.5*seconds};
            velocity.up=nextUp;
            pitch+=(0-pitch)*Math.min(1,seconds*4);roll+=(0-roll)*Math.min(1,seconds*4);
            q=euler(heading,pitch,roll);
            return travel;
        }
        function insufficientRescueBattery(){
            if(!battery||!config.batteryProfile)return false; // unknown is not proof of shortage
            const p=config.batteryProfile,s=battery.snapshot(),capacity=s.remainingEnergyWh;
            if(!Number.isFinite(capacity)||!Number.isFinite(s.remainingPercent))return false;
            const neededSeconds=(spawn&&position?distance(spawn,position)/Math.max(.5,Math.min(config.maxSpeed,config.failsafe.returnSpeedMetersPerSecond)):0)+
                config.failsafe.rescueAltitudeMeters/Math.max(.2,config.failsafe.climbSpeedMetersPerSecond);
            const watts=Math.max(p.hoverPowerWatts??0,p.cruisePowerWatts??0);
            return s.remainingPercent<=3||watts>0&&capacity < 1.3*watts*neededSeconds/3600;
        }
        // Angle: 50° tilt limit/self-level. Acro: configurable body rates, no leveling.
        // Angle retains its centred hover aid. Acro throttle is a motor command
        // over 0..1; its hover point depends on thrust/weight and the thrust curve.
        function acroThrust(command){
            const curve=config.acroThrustCurve;
            return g*config.acroThrustToWeight*((1-curve)*command+curve*command*command);
        }
        function acroTranslation(u,dt){
            const target=acroThrust(motorCommand()),tau=config.acroMotorTimeConstant;
            const decay=tau>0?Math.exp(-dt/tau):0,previous=motorThrust;
            motorThrust=target+(previous-target)*decay;
            const thrust=tau>0?target+(previous-target)*tau*(-Math.expm1(-dt/tau))/dt:target;
            const acceleration={north:u.x*thrust,east:u.y*thrust,up:-u.z*thrust-g};
            // Kick / exact quadratic-drag drift / kick (Strang splitting).
            // Drag opposes air-relative velocity; attitude does not rotate
            // momentum. No GPS-style speed clamp or altitude/braking controller.
            const middle={};
            for(const axis of ['north','east','up'])middle[axis]=velocity[axis]+acceleration[axis]*dt*.5-wind[axis];
            const speed=Math.hypot(middle.north,middle.east,middle.up);
            const drag=g/(config.acroTerminalVelocity*config.acroTerminalVelocity),loss=drag*speed*dt;
            const drift=loss>1e-10?Math.log1p(loss)/loss:1;
            const travel={};
            for(const axis of ['north','east','up']){
                travel[axis]=wind[axis]*dt+middle[axis]*dt*drift;
                velocity[axis]=wind[axis]+middle[axis]/(1+loss)+acceleration[axis]*dt*.5;
            }
            return travel;
        }
        function fpvStep(seconds){
            throttle=clamp(input.throttle+vertical+Number(keys.has('e'))-Number(keys.has('q')),-1,1);
            const yaw=clamp(input.yaw+Number(keys.has('d'))-Number(keys.has('a')),-1,1);
            const nose=clamp(input.pitch+Number(keys.has('w')||keys.has('ArrowUp')||keys.has('i'))-Number(keys.has('s')||keys.has('ArrowDown')||keys.has('k')),-1,1);
            const bank=clamp(input.roll+Number(keys.has('ArrowRight')||keys.has('l'))-Number(keys.has('ArrowLeft')||keys.has('j')),-1,1);
            const steps=Math.max(1,Math.ceil(seconds*240-1e-8)),dt=seconds/steps;
            let north=0,east=0,up=0;
            for(let i=0;i<steps;i++){
                const response=1-Math.exp(-8*dt);
                if(config.flightMode==='angle'){
                    pitch+=(-nose*50*rad-pitch)*response;roll+=(bank*50*rad-roll)*response;
                    heading=wrap(heading+yaw*1.8*dt);q=euler(heading,pitch,roll);
                }else{
                    // Cubic expo softens the centre, preserving both the sign
                    // and full-stick rate. The existing rate response stays intact.
                    rates.x+=(rateCommand(bank,config.acroRollRate,config.acroRateExpo)*rad-rates.x)*response;
                    rates.y+=(-rateCommand(nose,config.acroPitchRate,config.acroRateExpo)*rad-rates.y)*response;
                    rates.z+=(rateCommand(yaw,config.acroYawRate,config.acroRateExpo)*rad-rates.z)*response;
                    const speed=Math.hypot(rates.x,rates.y,rates.z),angle=speed*dt,scale=speed>1e-12?Math.sin(angle/2)/speed:0;
                    q=normalized(multiply(q,{w:Math.cos(angle/2),x:rates.x*scale,y:rates.y*scale,z:rates.z*scale}));
                    const f=rotate(q,{x:1,y:0,z:0}),r=rotate(q,{x:0,y:1,z:0});
                    heading=wrap(Math.atan2(f.y,f.x));pitch=Math.asin(clamp(-f.z,-1,1));roll=Math.atan2(r.z,1-2*(q.x*q.x+q.y*q.y));
                }
                const u=rotate(q,{x:0,y:0,z:-1});
                if(config.flightMode==='acro'){
                    const travel=acroTranslation(u,dt);north+=travel.north;east+=travel.east;up+=travel.up;continue;
                }
                const thrust=g+throttle*(throttle>=0?config.acceleration:g);
                const drag=config.deceleration/config.maxSpeed,decay=Math.exp(-drag*dt),old={...velocity};
                velocity.north=wind.north+(old.north-wind.north)*decay+u.x*thrust*(1-decay)/drag;
                velocity.east=wind.east+(old.east-wind.east)*decay+u.y*thrust*(1-decay)/drag;
                const airN=velocity.north-wind.north,airE=velocity.east-wind.east,speed=Math.hypot(airN,airE);
                // A new gust must not snap ground velocity to an airspeed cap.
                // Existing excess airspeed can decay naturally through drag.
                const limit=Math.max(config.maxSpeed,Math.hypot(old.north-wind.north,old.east-wind.east));
                if(speed>limit){velocity.north=wind.north+airN*limit/speed;velocity.east=wind.east+airE*limit/speed;}
                velocity.up=clamp(old.up+(-u.z*thrust-g)*dt,-config.climbSpeed,config.climbSpeed);
                north+=(old.north+velocity.north)*.5*dt;east+=(old.east+velocity.east)*.5*dt;up+=(old.up+velocity.up)*.5*dt;
            }
            return {north,east,up};
        }
        function playbackPose(point){
            runtime?.discardBacklog();
            if(!active||config.flightMode!=='gps'||!point||
               !valid(point)||!Number.isFinite(point.height)||
               !Number.isFinite(point.heading)||!Number.isFinite(point.pitch)||
               !Number.isFinite(point.speed))throw Error('Invalid replay pose');
            failsafe.reset();wasFailsafeControlled=false;
            if(playback && position && modeledCollision({...position,height},
                {latitude:point.latitude,longitude:point.longitude,height:point.height})) {
                clearKeys();brake();reason='Simulated infrastructure model contact; replay paused';
                pose();return false;
            }
            playback=true;clearKeys();
            position={latitude:point.latitude,longitude:point.longitude};
            height=point.height;heading=point.heading;pitch=point.pitch;roll=0;
            ground=Number.isFinite(point.ground)?point.ground:null;
            q=euler(heading,-pitch,0);
            velocity={north:Math.cos(heading)*point.speed*Math.cos(pitch),
                east:Math.sin(heading)*point.speed*Math.cos(pitch),up:Math.sin(pitch)*point.speed};
            if(Number.isFinite(point.seconds)&&point.seconds>=0){
                if(lastReplaySeconds!==null && point.seconds<lastReplaySeconds){
                    battery=batterySimulation.create(config.batteryProfile,
                        {resistanceOhmsPerCell:config.batterySagResistanceOhmsPerCell});
                }else if(battery && lastReplaySeconds!==null){
                    // Replay time (not wall time) makes 0.25×/4× and pauses equivalent.
                    // Replay speed is reconstructed ground speed: only a modelling proxy.
                    battery.tick(Math.min(.5,point.seconds-lastReplaySeconds),point.speed,velocity.up);
                }
                lastReplaySeconds=point.seconds;
            }
            reason=null;pose();return true;
        }
        function playbackEnd(){runtime?.discardBacklog();failsafe.reset();wasFailsafeControlled=false;playback=false;clearKeys();brake();reason=null;pose();}
        // An explicit user action enters validated SIMULATION-ONLY cross sections.
        // The caller verifies the generated model and owns terrain clipping.
        function enterTunnel(point){
            runtime?.discardBacklog();
            if(!active||pending||playback||!valid(point)||
                ![point.height,point.heading,point.ground].every(Number.isFinite))
                throw Error('Cannot enter unsupported simulated tunnel.');
            clearKeys();brake();position={latitude:point.latitude,longitude:point.longitude};
            height=point.height;ground=point.ground;heading=point.heading;pitch=roll=0;
            q=euler(heading,0,0);reason='SIMULATION ONLY – tunnel dimensions are not surveyed';
            pose();publish();
        }
        function stepCore(seconds){
            if(!active||playback)return;
            if(!isTerrainReady()){stop('Terrain unavailable; returned to globe view');return;}
            const previousGround=ground;
            const floor=renderedHeight({...position,height});
            // A missing synthetic segment can suddenly expose mountain terrain
            // hundreds of metres above the drone. Never teleport the drone to
            // that surface: retain its pose and wait for the next tunnel window.
            if(Number.isFinite(floor)&&height<floor+.5&&onSurfaceDiscontinuity({
                position:{...position},height,previousGround,nextGround:floor})){
                brake();reason='Tunnel continuation loading: movement paused';pose();return;
            }
            ground=Number.isFinite(floor)?floor:null;
            if(ground!=null&&height<ground+.5){height=ground+.5;brake();}
            windInfo=sampleWind({...position,agl:ground==null?NaN:height-ground});
            const validWind=windInfo?.available&&['north','east','up'].every(k=>Number.isFinite(windInfo[k])&&Math.abs(windInfo[k])<=100);
            wind=validWind?windInfo:{north:0,east:0,up:0};
            if(windInfo?.available&&!validWind)windInfo={enabled:true,available:false,reason:'invalid'};
            if(paused){pose();return;}
            if(!Number.isFinite(seconds)||seconds<=0)return;
            // Integration receives validated elapsed physics time from the selected adapter.
            const dt=seconds;
            const desiredHeading=spawn&&position?bearing(position,spawn):null;
            const fs=failsafe.step(dt,linkAssessment,{playback,position,home:spawn,height,homeHeight,
                headingErrorRadians:desiredHeading===null?null:Math.atan2(Math.sin(desiredHeading-heading),Math.cos(desiredHeading-heading)),
                distanceToHome:spawn&&position?distance(spawn,position):null,batteryInsufficient:insufficientRescueBattery()});
            if(fs.phase==='landed'){brake();reason='GPS Rescue: simulated landing complete';pose();return;}
            const controlled=fs.active;
            if(controlled&&!wasFailsafeControlled)clearKeys();wasFailsafeControlled=controlled;
            const travel=controlled?automatedStep(dt,fs):config.flightMode==='gps'?gpsStep(dt):fpvStep(dt);
            // Consume simulated energy only after collision/terrain checks below.
            const horizontal=Math.hypot(travel.north,travel.east);
            const endpoint=horizontal===0?position:move(position,travel.north,travel.east);
            const modeledContact=modeledCollision({...position,height},{...endpoint,height:height+travel.up});
            if(modeledContact){
                brake();reason=modeledContact==='bridge' ? 'Simulated bridge or support surface contact: movement stopped' :
                    modeledContact==='model' ? 'Approximate rendered 3D surface contact: movement stopped (not surveyed)' :
                    'Simulated tunnel surface contact: movement stopped';pose();return;
            }
            if(terrainCollision?.({...position,height},{...endpoint,height:height+travel.up})){
                brake();reason='Terrain contact: movement stopped';pose();return;
            }
            const steps=Math.max(1,Math.ceil(horizontal/.5));
            let next=null,nextHeight=height,nextGround=null,contact=false,waitingForTunnel=false;
            let missingSamples=Number(!Number.isFinite(floor)),unverifiedMeters=0;
            for(let i=1;i<=steps;i++){
                const fraction=i/steps,p=i===steps?endpoint:move(position,travel.north*fraction,travel.east*fraction);
                if(!valid(p)){brake();reason='Supported latitude limit reached';pose();return;}
                // A missing rendered tile is UNKNOWN, not a solid obstacle or
                // evidence of clear terrain. Keep the regular mesh/model ray
                // collisions, check every available terrain sample and expose
                // unverified travel to the pilot. No height is extrapolated.
                const z=height+travel.up*fraction;
                const h=p===position?floor:renderedHeight({...p,height:z});
                if(!Number.isFinite(h)){
                    missingSamples++;
                    unverifiedMeters+=horizontal/steps;
                    next=p;nextHeight=z;nextGround=null;
                    continue;
                }
                if(z<h+.5){
                    if(onSurfaceDiscontinuity({position:{...p},height:z,
                        previousGround:nextGround??floor,nextGround:h})){
                        waitingForTunnel=true;contact=true;break;
                    }
                    if(horizontal<.001){next=p;nextHeight=h+.5;nextGround=h;}
                    contact=true;break;
                }
                next=p;nextHeight=z;nextGround=h;
            }
            if(next){position=next;height=nextHeight;ground=nextGround;}
            terrainVerification={state:missingSamples===0?'complete':missingSamples===steps+1?'unavailable':'partial',
                samples:steps+1,missingSamples,
                unverifiedDistanceMeters:terrainVerification.unverifiedDistanceMeters+unverifiedMeters};
            if(battery){
                // Use horizontal air-relative speed for the speed/load proxy.
                // A zero-throttle dive must not drain the pack as if its falling
                // velocity were high powered forward flight. GPS Rescue uses
                // its own assisted controller and keeps the level-flight model.
                const horizontalAirSpeed=Math.hypot(velocity.north-wind.north,velocity.east-wind.east);
                const thrustG=controlled||config.flightMode==='gps'?null:
                    config.flightMode==='acro'?Math.max(0,motorThrust/g):
                    Math.max(0,1+throttle*(throttle>=0?config.acceleration/g:1));
                battery.tick(dt,horizontalAirSpeed,velocity.up,
                    thrustG===null?null:{thrustToWeight:thrustG});
            }
            if(contact){brake();reason=waitingForTunnel ?
                'Tunnel continuation loading: movement paused':
                'Terrain contact: movement stopped';}
            else reason=missingSamples?'Terrain collision unverified: tiles still loading':null;
            pose();
        }
        function tick(seconds){
            if(!active||playback)return;
            if(paused){runtime?.discardBacklog();stepCore(seconds);return;}
            if(!runtime){stepCore(seconds);return;}
            // Fixed substeps can update physics and collision multiple times,
            // but present only one interpolated camera pose per rendered frame.
            deferPose=config.physicsModel==='advanced';
            try{runtime.advance(seconds);}finally{deferPose=false;}
        }
        async function reset(signal){
            if(!active||!spawn)return {};
            return start({...spawn,...config},signal??new AbortController().signal);
        }
        return {start,stop,reset,tick,status,playbackPose,playbackEnd,enterTunnel,get active(){return active;},get flightMode(){return config.flightMode;},
            get controller(){return config.controller;},
            controllerSettings(value){
                config={...config,controller:controller.configuration(value)};clearKeys();
                if(active){pose();publish();}
            },
            hudStyle(style){
                if(!['goggles','betaflight'].includes(style))throw new Error('Unknown flight HUD style');
                config={...config,hudStyle:style};if(active){pose();publish();}
            },
            failsafeSettings(value){
                config={...config,failsafe:failsafeModule.configuration(value)};
                failsafe.setConfiguration(config.failsafe);clearKeys();if(active){pose();publish();}
            },
            linkAssessment(value){linkAssessment=value??null;},
            resumeAfterFailsafe(){if(failsafe.recover()){clearKeys();if(active){pose();publish();}return true;}return false;},
            signalHudSettings(value){
                config={...config,signalHud:signalHud.settings(value)};if(active){pose();publish();}
            },
            batteryHud({enabled,showCell,low,critical,useChemistryThresholds}){
                const next={...config,batteryUseChemistryThresholds:useChemistryThresholds??config.batteryUseChemistryThresholds,showBatteryVoltage:enabled,showBatteryCellVoltage:showCell,
                    lowBatteryCellVoltage:low,criticalBatteryCellVoltage:critical};
                parameters(next);config=next;if(active){pose();publish();}
            },
            showCoordinates(value){
                if(typeof value!=='boolean')throw new Error('Invalid HUD coordinate visibility');
                config={...config,showCoordinates:value};if(active){pose();publish();}
            },
            graphicsProfile(profile){
                if(!['quality','balanced','performance','compatibility'].includes(profile))throw new Error('Unknown flight graphics profile');
                if(active)applyGraphics?.(profile);
                config={...config,graphicsProfile:profile};if(active)publish();
            },
            cameraFov(degrees){
                if(!Number.isFinite(degrees)||degrees<50||degrees>140)throw new Error('Invalid camera FOV');
                config={...config,cameraFovDegrees:degrees};
                if(active){pose();publish();}
            },
            cameraTilt(degrees){
                if(!Number.isFinite(degrees)||degrees<0||degrees>80)throw new Error('Invalid camera tilt');
                config={...config,cameraTiltDegrees:degrees};
                if(active){pose();publish();}
            },
            reconfigure(command,signal){if(!active||!spawn)throw new Error('No active simulation');return start({...command,...spawn},signal);},
            look(dx,dy){if(active&&!playback&&!failsafe.status().active&&config.flightMode==='gps'&&Number.isFinite(dx)&&Number.isFinite(dy)){
                heading=wrap(heading+dx*.004);pitch=clamp(pitch-dy*.004,-85*rad,85*rad);}},
            key(key,down){if(playback)return;
                if(failsafe.status().active){if(down&&['w','a','s','d','ArrowUp','ArrowDown','ArrowLeft','ArrowRight','i','j','k','l','e','q'].includes(key)&&failsafe.recover()){
                    clearKeys();keys.add(key);pose();publish();}return;}
                if(down&&active)keys.add(key);else keys.delete(key);},
            stick(f,r){if(playback||!Number.isFinite(f)||!Number.isFinite(r))return;
                if(failsafe.status().active){if(Math.max(Math.abs(f),Math.abs(r))<.3||!failsafe.recover())return;clearKeys();}
                forward=clamp(f,-1,1);right=clamp(r,-1,1);},
            flightInput(frame){if(!active||playback||!frame||
                ![frame.throttle,frame.yaw,frame.pitch,frame.roll].every(Number.isFinite))return;
                if(failsafe.status().active){
                    // As in Betaflight, recover only after a sustained RC link AND
                    // deliberate yaw/pitch/roll movement, not an idle throttle.
                    if(Math.max(Math.abs(frame.yaw),Math.abs(frame.pitch),Math.abs(frame.roll))<.3||
                        !failsafe.recover())return;
                    clearKeys();
                }
                input.throttle=clamp(frame.throttle,-1,1);input.yaw=clamp(frame.yaw,-1,1);
                input.pitch=clamp(frame.pitch,-1,1);input.roll=clamp(frame.roll,-1,1);},
            vertical(v){if(playback||!Number.isFinite(v))return;
                if(failsafe.status().active){if(Math.abs(v)<.3||!failsafe.recover())return;clearKeys();}
                vertical=clamp(v,-1,1);},
            pause(value){if(!playback&&paused!==value&&active){runtime?.discardBacklog();paused=value;clearKeys();brake();reason=value?'Paused: tap the view to resume':null;pose();publish();}},
            clearKeys};
    }
    return {createSimulator,parameters,distance,bearing,rateCommand};
});
