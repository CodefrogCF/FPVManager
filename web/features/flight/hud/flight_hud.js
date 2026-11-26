(function(root,factory){
    const isNode=typeof module==='object'&&module.exports;
    const api=factory(isNode?require('../free_flight.js'):root.FPVFreeFlight,
        isNode?require('./signal_hud.js'):root.FPVSignalHud);
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVFlightHud=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(flight,signalHud){
    'use strict';
    const degrees=180/Math.PI;
    const number=(value,digits=1)=>Number.isFinite(value)
        ? (Math.abs(value)<.5*10**-digits?0:value).toFixed(digits):'—';
    // A heading-relative compass cue, not a projected 3D waypoint or course arrow.
    function homeDirection(state,viewHeading){
        if(!state.home||!state.position||!Number.isFinite(state.distance)||state.distance<1||!Number.isFinite(viewHeading))return null;
        const angle=flight.bearing(state.position,state.home)-viewHeading;
        return Number.isFinite(angle)?Math.atan2(Math.sin(angle),Math.cos(angle)):null;
    }
    function telemetry(state,viewHeading){
        const d=state.distance,p=state.position;
        const coordinates=p&&Number.isFinite(p.latitude)&&Math.abs(p.latitude)<=90&&Number.isFinite(p.longitude)&&Math.abs(p.longitude)<=180
            ? `${number(p.latitude,5)}, ${number(p.longitude,5)}`:'—';
        const height=value=>number(value,Math.abs(value)>=1000?0:1);
        return {speed:number(Number.isFinite(state.horizontalSpeed)?state.horizontalSpeed*3.6:null,0),
            agl:height(state.agl),height:height(state.heightAboveHome),
            distance:Number.isFinite(d)?number(d>=1000?d/1000:d,d>=1000&&d<100000?1:0):'—',
            distanceUnit:d>=1000?'km':'m',
            vertical:number(state.verticalSpeed),throttle:number(Number.isFinite(state.throttle)?state.throttle*100:null,0),
            coordinates,angle:homeDirection(state,viewHeading),atHome:Number.isFinite(d)&&d<1};
    }
    function create(doc,language,{diagnostics=()=>null,diagnosticsEnabled=()=>true,clock=()=>performance.now()}={}){
        const hud=doc.getElementById('navigation-hud');
        const elements=Object.fromEntries(['speed','agl','height','distance','distance-unit','vertical','throttle','throttle-readout','mode','warning','home-arrow','home-marker','coordinates']
            .map(key=>[key,doc.getElementById('hud-'+key)]));
        let style,reason=null,inputWarning='',lastState,lastHeading,lastAssessment,lastFlightId=null;
        const translate=language?.translate??((message,...values)=>
            message.replace(/\{(\d+)\}/g,(match,index)=>index<values.length?String(values[index]):match));
        const signalDisplay=signalHud.create(doc,{translate});
        const wind=doc.getElementById('hud-wind'),windReadout=doc.getElementById('hud-wind-readout');
        const battery=doc.getElementById('hud-battery-readout'),batteryCell=doc.getElementById('hud-battery-cell-readout');
        const batteryVoltage=doc.getElementById('hud-battery-voltage'),batteryCellVoltage=doc.getElementById('hud-battery-cell-voltage');
        const batteryStatus=doc.getElementById('hud-battery-status');
        const failsafeStatus=doc.getElementById('hud-failsafe');
        let diagnosticPanel=null,lastDiagnosticAt=-Infinity;
        function updateDiagnostics(state){
            if(!diagnosticsEnabled()){
                if(diagnosticPanel)diagnosticPanel.hidden=true;
                lastDiagnosticAt=-Infinity;return;
            }
            if(clock()-lastDiagnosticAt<1000)return;
            const data=diagnostics();
            if(!data||data.enabled===false){if(diagnosticPanel)diagnosticPanel.hidden=true;return;}
            lastDiagnosticAt=clock();
            if(!diagnosticPanel){
                diagnosticPanel=doc.createElement('pre');diagnosticPanel.className='hud-terrain-diagnostics';
                diagnosticPanel.setAttribute('aria-label','Terrain diagnostics');hud.appendChild(diagnosticPanel);
            }
            const value=(key,fallback='—')=>data[key]??fallback;
            const metric=(value,unit)=>`${number(value,0)}${unit}`;
            const fs=state.failsafe??{};
            const content=[
                `LoS: ${value('los')} | ${value('quality',value('observationQuality'))}`,
                `Age: ${metric(data.ageMs??data.lastValidAgeMs,' ms')} | Calc: ${metric(data.durationMs??data.lastDurationMs,' ms')}`,
                `P50: ${metric(data.p50Ms,' ms')} | P95: ${metric(data.p95Ms,' ms')}`,
                `Requests: ${value('active',0)} active / ${value('queued',0)} queued | Failures: ${value('failures',0)}`,
                `Error: ${value('error',value('errorCategory'))} | ID: ${value('requestId')}/${value('generation')}`,
                ...(typeof data.errorDetail==='string'&&data.errorDetail.trim()
                    ?[`Detail: ${data.errorDetail.replace(/\s+/g,' ').trim().slice(0,160)}`]:[]),
                `Path: ${metric(data.distanceMeters,' m')} | Samples: ${value('samples',value('sampleCount'))}`,
                `Terrain: ${value('provider')} | Moved: ${metric(data.movementMeters,' m')}`,
                ...(data.scenery ? ['control','video'].map(k=>{const r=data.scenery[k];return `SIM scenery ${k}: ${r.obstructions} hits | ${number(r.lossDb,1)} dB | ${r.complete?'complete':'partial'} | ${(r.materials??[]).join(', ')} | ${metric(r.durationMs,' ms')}`;}) : []),
                `RC: ${number(fs.rcQuality,2)} | Failsafe: ${fs.phase??'normal'}`,
            ].join('\n');
            diagnosticPanel.hidden=false;
            if(diagnosticPanel.textContent!==content)diagnosticPanel.textContent=content;
        }
        function text(key,value){if(elements[key].textContent!==value)elements[key].textContent=value;}
        function warning(){text('warning',translate(reason||inputWarning));elements.warning.hidden=!(reason||inputWarning);}
        function update(state,viewHeading,assessment){
            if(lastFlightId!==state.flightId){signalDisplay.reset();lastFlightId=state.flightId;}
            lastState=state;lastHeading=viewHeading;lastAssessment=assessment;
            signalDisplay.update(state,assessment);
            updateDiagnostics(state);
            if(failsafeStatus){const fs=state.failsafe??{phase:'normal'};
                const observation=assessment?.observation;
                const uncertain=fs.uncertain===true||observation?.enabled===true&&observation.quality!=='valid';
                const noticeOnly=uncertain&&!fs.active;
                const analysisReason=typeof observation?.reason==='string'
                    ?observation.reason.replace(/\s+/g,' ').trim().slice(0,160):'';
                const labels={pending:'SIM RC · LOSS PENDING',hold:'SIM FAILSAFE · HOLD',
                    descend:'SIM FAILSAFE · DESCEND',rescueHold:'SIM GPS RESCUE · HOLD',climb:'SIM GPS RESCUE · CLIMB',turn:'SIM GPS RESCUE · TURN',
                    return:'SIM GPS RESCUE · RETURN',landing:'SIM GPS RESCUE · LANDING',landed:'SIM GPS RESCUE · LANDED',
                    unavailable:'SIM RESCUE UNAVAILABLE',awaitingManual:'SIM RC RESTORED · TAKE CONTROL'};
                failsafeStatus.hidden=!noticeOnly&&(!fs.enabled||!labels[fs.phase]);
                if(failsafeStatus.dataset)failsafeStatus.dataset.phase=noticeOnly?'uncertain':fs.recovering?'recovering':fs.phase;
                if(!failsafeStatus.hidden)failsafeStatus.textContent=noticeOnly?
                    'SIM RF · ANALYSIS UNCERTAIN'+(analysisReason?` · ${analysisReason}`:''):
                    labels[fs.phase]+(fs.recoveryReady?' · STICK TO TAKE OVER':fs.recovering?' · RC RECOVERING':'')+
                    (uncertain?' · ANALYSIS UNCERTAIN':'')+(fs.reason?` · ${fs.reason}`:'');
            }
            const t=telemetry(state,viewHeading),next=state.hudStyle==='betaflight'?'betaflight':'goggles';
            if(style!==next){style=next;hud.setAttribute('data-style',style);}
            for(const key of ['speed','agl','height','distance','vertical','throttle'])text(key,t[key]);
            text('distance-unit',t.distanceUnit);
            text('coordinates',t.coordinates);
            elements.coordinates.hidden=state.showCoordinates!==true;
            if(battery){
                battery.hidden=state.showBatteryVoltage!==true;
                if(!battery.hidden){
                    const reading=state.battery,available=reading?.available===true;
                    const set=(node,value)=>{if(node&&node.textContent!==value)node.textContent=value;};
                    set(batteryVoltage,available?number(reading.packVoltageVolts,1):'—');
                    set(batteryCellVoltage,available?number(reading.cellVoltageVolts,2):'—');
                    battery.setAttribute('data-level',available?reading.level:'unavailable');
                    // ESC/motor comparisons are only DC equal-share proxies;
                    // the '?' avoids presenting them as measured phase-current alarms.
                    const drive=available?(reading.batteryCurrentLimited===true?' · BAT DC LIMIT?':'')+
                        (reading.escCurrentLimited===true?' · ESC DC LIMIT?':reading.escPossiblyOverloaded===true?' · ESC?':'')+
                        (reading.motorCurrentLimited===true?' · MOTOR DC LIMIT?':reading.motorPossiblyOverloaded===true?' · MOTOR?':''):'';
                    set(batteryStatus,'SIM BAT'+(available&&reading.level==='critical'?' !':available&&reading.level==='low'?' ↓':'')+drive);
                    if(batteryCell)batteryCell.hidden=state.showBatteryCellVoltage!==true;
                    battery.title=translate(available
                        ?'SIM · Spannung aus Flugprofil geschätzt, keine echte Telemetrie.'
                        :'SIM · Keine Schätzung möglich: Akku- und Drohnenleistungsdaten prüfen.');
                }
            }
            elements['throttle-readout'].hidden=state.mode==='gps';
            if(wind&&windReadout){windReadout.hidden=!state.wind?.enabled;wind.textContent=state.wind?.available?`${number(state.wind.speedMs)} m/s`:'—';
                windReadout.title=translate(state.wind?.available?(state.wind.extrapolated?'Nächste Modellschicht konstant fortgesetzt':'Interpolierter Modellwind'):'Wind fehlt, ist abgelaufen oder liegt außerhalb des geladenen Ausschnitts. Physik ohne Wind.');}
            text('mode',`SIM · ${state.mode.toUpperCase()}${state.paused?' · '+translate('PAUSED'):''}`);
            reason=state.reason;warning();
            elements['home-arrow'].hidden=t.angle===null;
            elements['home-marker'].hidden=!t.atHome;
            if(t.angle!==null){
                const arrow=elements['home-arrow'];
                arrow.style.transform=`rotate(${t.angle}rad)`;
                arrow.setAttribute('aria-label',translate('Home direction {0}° from view heading',number(t.angle*degrees,0)));
            }
        }
        language?.onChange(()=>{if(lastState)update(lastState,lastHeading,lastAssessment);else warning();});
        return {update,device(message){inputWarning=message==='Controller ready'?'':message;warning();}};
    }
    return {homeDirection,telemetry,create};
});
