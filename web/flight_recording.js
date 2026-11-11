(function(root,factory){
    const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;else root.FPVFlightRecording=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    const maxSamples=4096,maxSeconds=1800;
    function create({emit,getState,clock=()=>performance.now()}){
        let id=null,phase='idle',count=0,segment=0,started=0,last=null,latest=null,gap=false;
        const listeners=new Set();
        function status(){return {id,phase,count};}
        function updateControls(){for(const fn of listeners)fn(status());}
        function publish(reason=null){emit('flight-recording-state',{...status(),reason});updateControls();}
        function valid(s){return s?.active&&s.position&&Number.isFinite(s.position.latitude)&&Math.abs(s.position.latitude)<89.9&&
            Number.isFinite(s.position.longitude)&&Math.abs(s.position.longitude)<=180&&Number.isFinite(s.height)&&Math.abs(s.height)<=100000;}
        function point(s){const p=latest??{};p.latitude=s.position.latitude;p.longitude=s.position.longitude;p.height=s.height;
            p.ground=Number.isFinite(s.agl)&&s.agl>=0&&s.agl<=100000?s.height-s.agl:null;
            p.speed=Number.isFinite(s.speed)&&s.speed>=0&&s.speed<=200?s.speed:null;
            p.time=Math.max(0,(clock()-started)/1000);return p;}
        function distance(a,b){const r=Math.PI/180,n=(a.latitude-b.latitude)*r*6371000,
            e=(a.longitude-b.longitude)*r*6371000*Math.cos((a.latitude+b.latitude)*r/2);return Math.hypot(n,e,a.height-b.height);}
        function append(p,force=false){
            if(p.time>maxSeconds){stop('30-minute recording limit reached');return;}
            const dt=last?p.time-last.time:Infinity;
            const dynamicChange=last&&(
                (p.speed===null)!==(last.speed===null)||
                (Number.isFinite(p.speed)&&Number.isFinite(last.speed)&&Math.abs(p.speed-last.speed)>.75)||
                (p.ground===null)!==(last.ground===null)||
                (Number.isFinite(p.ground)&&Number.isFinite(last.ground)&&
                    Math.abs((p.height-p.ground)-(last.height-last.ground))>1)
            );
            if(last&&(dt<=0||(!force&&(dt<.5||(distance(p,last)<1&&dt<2&&!dynamicChange)))))return;
            if(gap||last&&(dt>3||distance(p,last)>2000)){segment++;gap=false;}
            count++;last={...p};
            emit('flight-recording-sample',{id,sample:[count,segment,p.time,p.latitude,p.longitude,p.height,p.ground,p.speed]});
            updateControls();
            if(count>=maxSamples)stop('4096-sample recording limit reached');
        }
        function flush(){if(latest)append(latest,true);}
        function stop(reason=null){if(phase!=='recording'&&phase!=='paused')return;const was=phase;phase='stopped';if(was==='recording')flush();publish(reason);}
        function observe(s){
            if(phase!=='recording')return;
            if(!s.active){stop('Flight ended or restarted; recording retained');return;}
            if(!valid(s)){stop('Invalid position; recording retained');return;}
            if((clock()-started)/1000>maxSeconds){stop('30-minute recording limit reached');return;}
            if(s.paused){if(!gap){flush();gap=true;}return;}
            latest=point(s);append(latest);
        }
        function control(c){
            if(typeof c.id!=='string'||!c.id||c.id.length>100)throw Error('Invalid recording identity');
            if(c.action==='restore'){
                if(!Number.isInteger(c.count)||c.count<0||c.count>maxSamples)throw Error('Invalid recording count');
                id=c.id;count=c.count;phase=count?'stopped':'idle';last=latest=null;publish();return {};
            }
            if(c.action==='start'){
                if(count||phase==='recording'||phase==='paused')throw Error('Review or discard the existing recording first');
                const s=getState();if(!valid(s))throw Error('Start a simulated flight first');
                id=c.id;phase='recording';count=segment=0;started=clock();last=latest=null;gap=false;publish();observe(s);return {};
            }
            if(c.id!==id)throw Error('Recording changed');
            switch(c.action){
                case 'pause':if(phase==='recording'){flush();if(phase==='recording'){phase='paused';gap=true;publish();}}break;
                case 'resume':if(phase!=='paused'||!valid(getState()))throw Error('Recording cannot resume');phase='recording';gap=true;latest=null;publish();observe(getState());break;
                case 'stop':stop();break;
                case 'discard':phase='idle';count=0;last=latest=null;publish();break;
                default:throw Error('Unknown recording action');
            }
            return {};
        }
        return {observe,control,status,stop,
            bind(doc,language){
                const button=doc.getElementById('record-flight'),pause=doc.getElementById('pause-recording'),
                    review=doc.getElementById('review-recording'),label=doc.getElementById('flight-recording-status');
                const update=s=>{
                    const running=s.phase==='recording'||s.phase==='paused';
                    const action=running?'stop':s.count?'review':'start';
                    const title=action==='start'?'Record simulated flight':action==='stop'?'Stop flight recording':'Review flight recording';
                    button.title=language?.translate(title)??title;
                    button.setAttribute('aria-label',button.title);button.setAttribute('aria-pressed',String(running));
                    button.dataset.recording=s.phase;button.textContent=running?'■':s.count?'↗':'●';
                    const pauseLabel=s.phase==='paused'?'Resume recording':'Pause recording';
                    pause.hidden=!running;pause.textContent=language?.translate(pauseLabel)??pauseLabel;
                    const phaseLabel=s.phase==='recording'?'REC':s.phase==='paused'?'Paused':'Recorded';
                    review.hidden=!s.count;
                    label.textContent=s.count?(language?.translate('{0} · {1} samples · temporary',
                        language.translate(phaseLabel),s.count)??`${phaseLabel} · ${s.count} samples · temporary`):'';
                };
                // Recording while flying must not blur the canvas and brake the simulator.
                button.addEventListener('pointerdown',event=>event.preventDefault());
                button.addEventListener('click',()=>{const s=status();emit('flight-recording-action',{action:s.phase==='recording'||s.phase==='paused'?'stop':s.count?'review':'start'});});
                pause.addEventListener('click',()=>emit('flight-recording-action',{action:phase==='paused'?'resume':'pause'}));
                review.addEventListener('click',()=>emit('flight-recording-action',{action:'review'}));
                const removeLanguage=language?.onChange(()=>update(status()));
                listeners.add(update);update(status());
                return ()=>{removeLanguage?.();listeners.delete(update);};
            }};
    }
    return {create,maxSamples,maxSeconds};
});

// Virtual-only route playback. Kept in this registered Flutter asset so that
// existing Android/iOS/Windows asset manifests need no pubspec changes.
(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports.routePlayback=api;
    else root.FPVRoutePlayback=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const rad=Math.PI/180,R=6378137,MAX_SAMPLES=1000,MAX_DURATION=7200;
    const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
    const finite=n=>typeof n==='number'&&Number.isFinite(n);
    function coordinate(p){return p&&finite(p.latitude)&&finite(p.longitude)&&Math.abs(p.latitude)<89.9&&Math.abs(p.longitude)<=180;}
    function distance(a,b){const lat1=a.latitude*rad,lat2=b.latitude*rad,delta=(b.longitude-a.longitude)*rad;
        return 2*R*Math.asin(Math.sqrt(clamp(Math.sin((lat2-lat1)/2)**2+Math.cos(lat1)*Math.cos(lat2)*Math.sin(delta/2)**2,0,1)));}
    function bearing(a,b){const a1=a.latitude*rad,b1=b.latitude*rad,d=(b.longitude-a.longitude)*rad;
        return (Math.atan2(Math.sin(d)*Math.cos(b1),Math.cos(a1)*Math.sin(b1)-Math.sin(a1)*Math.cos(b1)*Math.cos(d))+2*Math.PI)%(2*Math.PI);}
    // Great-circle interpolation, including tracks that cross the antimeridian.
    function interpolate(a,b,f){
        const ll=p=>{const lat=p.latitude*rad,lon=p.longitude*rad;return [Math.cos(lat)*Math.cos(lon),Math.cos(lat)*Math.sin(lon),Math.sin(lat)];};
        const x=ll(a),y=ll(b),angle=Math.acos(clamp(x.reduce((s,v,i)=>s+v*y[i],0),-1,1));
        if(angle<1e-10)return {latitude:a.latitude+(b.latitude-a.latitude)*f,longitude:a.longitude};
        const k=Math.sin(angle),u=Math.sin((1-f)*angle)/k,v=Math.sin(f*angle)/k;
        const r=x.map((n,i)=>n*u+y[i]*v),lon=Math.atan2(r[1],r[0])/rad;
        return {latitude:Math.atan2(r[2],Math.hypot(r[0],r[1]))/rad,longitude:lon};
    }
    function validate(command){
        const points=command?.points;
        if(!Array.isArray(points)||points.length<2||points.length>MAX_SAMPLES)throw Error('Replay needs 2–1000 waypoints');
        for(const p of points){
            if(!coordinate(p)||!['absolute','agl','unspecified'].includes(p.heightMode))throw Error('Invalid replay waypoint');
            if(p.heightMode!=='unspecified'&&(!finite(p.heightMeters)||Math.abs(p.heightMeters)>100000||
                (p.heightMode==='agl'&&p.heightMeters<0)))throw Error('Invalid replay height');
            if(p.speedMetersPerSecond!=null&&(!finite(p.speedMetersPerSecond)||p.speedMetersPerSecond<0||p.speedMetersPerSecond>200))throw Error('Invalid planned speed');
        }
        if(!finite(command.defaultSpeedMetersPerSecond)||command.defaultSpeedMetersPerSecond<.5||command.defaultSpeedMetersPerSecond>100||
           !finite(command.defaultAglMeters)||command.defaultAglMeters<1||command.defaultAglMeters>1000)throw Error('Invalid replay fallback');
        if(command.recorded!=null){
            if(!Array.isArray(command.recorded)||command.recorded.length!==points.length)throw Error('Recorded track does not match route');
            let last=-1;
            for(const p of command.recorded){
                if(!finite(p.seconds)||p.seconds<=last||p.seconds<0||p.seconds>1800||
                    !finite(p.absoluteElevationMeters)||Math.abs(p.absoluteElevationMeters)>100000||
                    (p.terrainElevationMeters!=null&&(!finite(p.terrainElevationMeters)||p.terrainElevationMeters>p.absoluteElevationMeters))||
                    (p.groundSpeedMetersPerSecond!=null&&(!finite(p.groundSpeedMetersPerSecond)||p.groundSpeedMetersPerSecond<0||p.groundSpeedMetersPerSecond>200)))
                    throw Error('Invalid recorded replay samples');
                last=p.seconds;
            }
        }
        return points;
    }
    // sampleGround only for routes requiring terrain-based height resolution.
    // It is always called in <=64-point chunks and may be interrupted.
    async function prepare(command,sampleGround,signal){
        const points=validate(command),recorded=command.recorded;
        const heights=new Array(points.length).fill(null),requires=[];
        if(!recorded)for(let i=0;i<points.length;i++){
            if(points[i].heightMode!=='absolute')requires.push(i);
        }
        if(requires.length){
            for(let offset=0;offset<requires.length;offset+=64){
                signal?.throwIfAborted?.();
                const indices=requires.slice(offset,offset+64);
                const values=await sampleGround(indices.map(i=>points[i]),signal);
                signal?.throwIfAborted?.();
                if(!Array.isArray(values)||values.length!==indices.length||values.some(v=>!finite(v)))
                    throw Error('Terrain heights unavailable for route replay');
                indices.forEach((i,j)=>heights[i]=values[j]);
            }
        }
        const trajectory=[];let time=0;let assumedHeight=false,assumedSpeed=false;
        for(let i=0;i<points.length;i++){
            const p=points[i],r=recorded?.[i],ground=r?.terrainElevationMeters??heights[i];
            let height;
            if(r)height=r.absoluteElevationMeters;
            else if(p.heightMode==='absolute')height=p.heightMeters;
            else{height=ground+(p.heightMode==='agl'?p.heightMeters:command.defaultAglMeters);
                if(p.heightMode==='unspecified')assumedHeight=true;}
            if(!finite(height)||Math.abs(height)>100000)throw Error('Replay altitude is unavailable');
            const speed=r?.groundSpeedMetersPerSecond??p.speedMetersPerSecond??null;
            if((recorded&&!finite(speed))||(!recorded&&(!finite(speed)||speed<=0)))assumedSpeed=true;
            if(i>0){
                if(r){time=r.seconds-recorded[0].seconds;}
                else{const previous=trajectory[i-1],leg=Math.hypot(distance(previous,p),height-previous.height);
                    const legSpeed=points[i-1].speedMetersPerSecond;
                    time+=Math.max(.1,leg/((finite(legSpeed)&&legSpeed>0)?legSpeed:command.defaultSpeedMetersPerSecond));}
            }
            if(time>MAX_DURATION)throw Error('Route exceeds maximum replay duration (2 h)');
            trajectory.push({latitude:p.latitude,longitude:p.longitude,height,ground,seconds:time,
                speed:recorded?speed:(finite(speed)&&speed>0?speed:command.defaultSpeedMetersPerSecond),
                speedKnown:recorded?finite(speed):finite(speed)&&speed>0,
                heightMode:recorded?'recorded':p.heightMode,agl:recorded?null:(p.heightMode==='absolute'?null:(p.heightMode==='agl'?p.heightMeters:command.defaultAglMeters))});
        }
        if(trajectory.at(-1).seconds<=0)throw Error('Replay duration is zero');
        return {points:trajectory,duration:trajectory.at(-1).seconds,
            recorded:Boolean(recorded),assumedHeight,assumedSpeed};
    }
    function evaluate(trajectory,seconds){
        const arr=trajectory.points,t=clamp(seconds,0,trajectory.duration);
        let lo=0,hi=arr.length-1;
        while(hi-lo>1){const mid=(lo+hi)>>1;if(arr[mid].seconds<=t)lo=mid;else hi=mid;}
        const a=arr[lo],b=arr[hi],f=clamp((t-a.seconds)/(b.seconds-a.seconds),0,1);
        const pos=interpolate(a,b,f);
        const height=a.height+(b.height-a.height)*f;
        const speed=a.speedKnown&&b.speedKnown?a.speed+(b.speed-a.speed)*f:
            Math.hypot(distance(a,b),b.height-a.height)/(b.seconds-a.seconds);
        // Look slightly ahead/behind to soften changes of heading at corners.
        function pointAt(time){if(time<=arr[0].seconds)return arr[0];if(time>=trajectory.duration)return arr.at(-1);
            let i=0,j=arr.length-1;while(j-i>1){const mid=(i+j)>>1;if(arr[mid].seconds<=time)i=mid;else j=mid;}
            return interpolate(arr[i],arr[j],(time-arr[i].seconds)/(arr[j].seconds-arr[i].seconds));}
        const behind=pointAt(Math.max(0,t-.25)),ahead=pointAt(Math.min(trajectory.duration,t+.25));
        const heading=distance(behind,ahead)>1e-3?bearing(behind,ahead):bearing(a,b);
        const distanceMeters=distance(a,b);
        const pitch=Math.atan2(b.height-a.height,Math.max(distanceMeters,.001));
        return {...pos,height,heading,pitch,roll:0,ground:a.ground!=null&&b.ground!=null?
            a.ground+(b.ground-a.ground)*f:null,speed,seconds:t,progress:t/trajectory.duration,
            aglTarget:a.agl!=null&&b.agl!=null?a.agl+(b.agl-a.agl)*f:null};
    }
    function create({simulator,sampleGround,renderedGround=()=>null,emit=()=>{},display=()=>{}}){
        let flight=null,phase='idle',time=0,rate=1,operation=0,loading=false,lastEmit=-1,reason=null;
        let loadingAbort=null;
        const status=()=>({phase,active:phase==='playing'||phase==='paused',loading,
            duration:flight?.duration??0,seconds:time,progress:flight?time/flight.duration:0,
            speed:rate,recorded:flight?.recorded??false,reason,
            assumedSpeed:flight?.assumedSpeed??false,assumedHeight:flight?.assumedHeight??false});
        function publish(force=false){const s=status();display(s);if(force||Math.abs(time-lastEmit)>=.5||!s.active){lastEmit=time;emit('route-playback-state',s);} }
        function interrupt(message){++operation;loadingAbort?.abort();loadingAbort=null;flight=null;phase='idle';loading=false;time=0;reason=message??null;publish(true);}
        async function start(command,signal){
            interrupt();const token=operation;loading=true;phase='loading';publish(true);
            const pending=new AbortController();loadingAbort=pending;
            const cancel=()=>pending.abort();
            signal?.addEventListener('abort',cancel,{once:true});
            if(signal?.aborted)cancel();
            try{
                const next=await prepare(command,sampleGround,pending.signal);
                pending.signal.throwIfAborted();if(token!==operation)throw Error('Replay cancelled');
                const first=next.points[0],terrain=first.ground??(await sampleGround([first],pending.signal))[0];
                if(!finite(terrain))throw Error('Terrain unavailable at replay start');
                const agl=first.height-terrain;
                if(agl<1||agl>1000)throw Error('Replay start altitude must be 1–1000 m AGL');
                await simulator.start({...command.settings,latitude:first.latitude,longitude:first.longitude,agl,flightMode:'gps'},pending.signal);
                pending.signal.throwIfAborted();if(token!==operation)throw Error('Replay cancelled');
                flight=next;time=0;rate=1;phase='playing';loading=false;reason=null;
                simulator.playbackPose(evaluate(flight,0));publish(true);return status();
            }catch(error){
                const cancelled=token!==operation||pending.signal.aborted;
                if(token===operation){interrupt(cancelled?'Replay cancelled':error.message||'Replay unavailable');simulator.stop();}
                throw cancelled?Error('Replay cancelled'):error;
            }finally{signal?.removeEventListener('abort',cancel);if(loadingAbort===pending)loadingAbort=null;}
        }
        function control(command){
            if(command.action==='speed'){
                if(![.25,.5,1,2,4].includes(command.speed)||!flight)throw Error('Invalid replay speed');
                rate=command.speed;
            }else if(command.action==='stop'){if(!flight){interrupt('Replay cancelled');return status();}phase='stopped';simulator.playbackEnd();}
            else if(command.action==='restart'){if(!flight)throw Error('No route available');time=0;phase='playing';simulator.playbackPose(evaluate(flight,0));}
            else if(command.action==='pause'){if(phase!=='playing')throw Error('Replay is not running');phase='paused';}
            else if(command.action==='resume'){if(phase!=='paused')throw Error('Replay is not paused');phase='playing';}
            else throw Error('Unknown replay action');
            publish(true);return status();
        }
        function tick(dt){if(phase!=='playing'||!flight)return;
            if(!simulator.active){interrupt('Renderer or simulator stopped');return;}
            if(!finite(dt)||dt<=0)return;
            const nextTime=Math.min(flight.duration,time+Math.min(dt,.1)*rate);
            const frame=evaluate(flight,nextTime);
            if(frame.aglTarget!=null){
                const terrain=renderedGround(frame);
                if(!finite(terrain)){
                    phase='paused';reason='Terrain tiles unavailable: replay paused. Resume after they load.';
                    publish(true);return;
                }
                frame.ground=terrain;frame.height=terrain+frame.aglTarget;
            }
            time=nextTime;reason=null;
            if(simulator.playbackPose(frame)===false){
                phase='paused';reason='Simulated infrastructure collision detected; replay paused.';
                simulator.playbackEnd();publish(true);return;
            }
            if(time>=flight.duration){phase='finished';simulator.playbackEnd();}
            publish(time>=flight.duration);
        }
        return {start,control,tick,interrupt,status,get active(){return phase==='playing'||phase==='paused';},
            get loaded(){return Boolean(flight);}};
    }
    return {MAX_SAMPLES,prepare,evaluate,create,distance,bearing};
});
