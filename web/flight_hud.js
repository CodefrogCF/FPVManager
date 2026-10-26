(function(root,factory){
    const api=factory(typeof module==='object'&&module.exports?require('./free_flight.js'):root.FPVFreeFlight);
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVFlightHud=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(flight){
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
        const d=state.distance;
        const height=value=>number(value,Math.abs(value)>=1000?0:1);
        return {speed:number(Number.isFinite(state.horizontalSpeed)?state.horizontalSpeed*3.6:null,0),
            agl:height(state.agl),height:height(state.heightAboveHome),
            distance:Number.isFinite(d)?number(d>=1000?d/1000:d,d>=1000&&d<100000?1:0):'—',
            distanceUnit:d>=1000?'km':'m',
            vertical:number(state.verticalSpeed),throttle:number(Number.isFinite(state.throttle)?state.throttle*100:null,0),
            angle:homeDirection(state,viewHeading),atHome:Number.isFinite(d)&&d<1};
    }
    function create(doc){
        const hud=doc.getElementById('navigation-hud');
        const elements=Object.fromEntries(['speed','agl','height','distance','distance-unit','vertical','throttle','throttle-readout','mode','warning','home-arrow','home-marker']
            .map(key=>[key,doc.getElementById('hud-'+key)]));
        let style,reason=null,inputWarning='';
        function text(key,value){if(elements[key].textContent!==value)elements[key].textContent=value;}
        function warning(){text('warning',reason||inputWarning);elements.warning.hidden=!(reason||inputWarning);}
        function update(state,viewHeading){
            const t=telemetry(state,viewHeading),next=state.hudStyle==='betaflight'?'betaflight':'goggles';
            if(style!==next){style=next;hud.setAttribute('data-style',style);}
            for(const key of ['speed','agl','height','distance','vertical','throttle'])text(key,t[key]);
            text('distance-unit',t.distanceUnit);
            elements['throttle-readout'].hidden=state.mode==='gps';
            text('mode',`SIM · ${state.mode.toUpperCase()}${state.paused?' · PAUSED':''}`);
            reason=state.reason;warning();
            elements['home-arrow'].hidden=t.angle===null;
            elements['home-marker'].hidden=!t.atHome;
            if(t.angle!==null){
                const arrow=elements['home-arrow'];
                arrow.style.transform=`rotate(${t.angle}rad)`;
                arrow.setAttribute('aria-label',`Home direction ${number(t.angle*degrees,0)}° from view heading`);
            }
        }
        return {update,device(message){inputWarning=message==='Controller ready'?'':message;warning();}};
    }
    return {homeDirection,telemetry,create};
});
