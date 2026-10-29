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
            p.ground=Number.isFinite(s.agl)?s.height-s.agl:null;p.time=Math.max(0,(clock()-started)/1000);return p;}
        function distance(a,b){const r=Math.PI/180,n=(a.latitude-b.latitude)*r*6371000,
            e=(a.longitude-b.longitude)*r*6371000*Math.cos((a.latitude+b.latitude)*r/2);return Math.hypot(n,e,a.height-b.height);}
        function append(p,force=false){
            if(p.time>maxSeconds){stop('30-minute recording limit reached');return;}
            const dt=last?p.time-last.time:Infinity;
            if(last&&(!force&&(dt<.5||distance(p,last)<1&&dt<2)||dt<=0))return;
            if(gap||last&&(dt>3||distance(p,last)>2000)){segment++;gap=false;}
            count++;last={...p};
            emit('flight-recording-sample',{id,sample:[count,segment,p.time,p.latitude,p.longitude,p.height,p.ground]});
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
            bind(doc){
                const button=doc.getElementById('record-flight'),pause=doc.getElementById('pause-recording'),
                    review=doc.getElementById('review-recording'),label=doc.getElementById('flight-recording-status');
                const update=s=>{
                    const running=s.phase==='recording'||s.phase==='paused';
                    const action=running?'stop':s.count?'review':'start';
                    button.title=action==='start'?'Record simulated flight':action==='stop'?'Stop flight recording':'Review flight recording';
                    button.setAttribute('aria-label',button.title);button.setAttribute('aria-pressed',String(running));
                    button.dataset.recording=s.phase;button.textContent=running?'■':s.count?'↗':'●';
                    pause.hidden=!running;pause.textContent=s.phase==='paused'?'Resume recording':'Pause recording';
                    review.hidden=!s.count;label.textContent=s.count?`${s.phase==='recording'?'REC':s.phase==='paused'?'Paused':'Recorded'} · ${s.count} samples · temporary`:'';
                };
                // Recording while flying must not blur the canvas and brake the simulator.
                button.addEventListener('pointerdown',event=>event.preventDefault());
                button.addEventListener('click',()=>{const s=status();emit('flight-recording-action',{action:s.phase==='recording'||s.phase==='paused'?'stop':s.count?'review':'start'});});
                pause.addEventListener('click',()=>emit('flight-recording-action',{action:phase==='paused'?'resume':'pause'}));
                review.addEventListener('click',()=>emit('flight-recording-action',{action:'review'}));
                listeners.add(update);update(status());return ()=>listeners.delete(update);
            }};
    }
    return {create,maxSamples,maxSeconds};
});
