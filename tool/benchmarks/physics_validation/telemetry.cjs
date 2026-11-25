'use strict';
const fs=require('node:fs');
const MAX_BYTES=20*1024*1024,MAX_ROWS=100000;
const fields=['speed_mps','horizontal_speed_mps','vertical_speed_mps','airspeed_mps','altitude_change_m','speed_change_mps2','vertical_accel_mps2','roll_deg','pitch_deg','yaw_deg','qw','qx','qy','qz','voltage_v','current_a','energy_wh','power_w'];
const quaternion=['qw','qx','qy','qz'];
const circular=new Set(['roll_deg','pitch_deg','yaw_deg']);
const delta=(a,b)=>((a-b+180)%360+360)%360-180;
function readCsv(path){
    if(fs.statSync(path).size>MAX_BYTES)throw Error('Telemetry exceeds 20 MiB');
    return parseCsv(fs.readFileSync(path,'utf8'));
}
// Intentionally narrow normalized numeric CSV; no opaque Blackbox decoding,
// guessed units, location, personal identifiers, or interpolated missing values.
function parseCsv(text){
    if(Buffer.byteLength(text)>MAX_BYTES)throw Error('Telemetry exceeds 20 MiB');
    const lines=text.replace(/^\uFEFF/,'').trim().split(/\r?\n/);
    if(lines.length<3||lines.length>MAX_ROWS+1)throw Error('Expected 2–100000 telemetry samples');
    const keys=lines.shift().split(',').map(x=>x.trim());
    if(keys[0]!=='time_s'||new Set(keys).size!==keys.length||keys.length<2||keys.some(k=>k!=='time_s'&&!fields.includes(k)))throw Error('Invalid normalized telemetry headers');
    const qCount=quaternion.filter(k=>keys.includes(k)).length;
    if(qCount!==0&&qCount!==4)throw Error('Supply all four quaternion components or none');
    let last=-Infinity;
    const rows=lines.map((line,i)=>{
        const parts=line.split(',').map(v=>v.trim());if(parts.length!==keys.length)throw Error(`Wrong column count at row ${i+2}`);
        const row={};for(let j=0;j<keys.length;j++){
            const v=parts[j];if(v===''){row[keys[j]]=null;continue;}
            if(!/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$/i.test(v)||!Number.isFinite(Number(v)))throw Error(`Invalid numeric field at row ${i+2}`);
            row[keys[j]]=Number(v);
        }
        if(!Number.isFinite(row.time_s)||row.time_s<0||row.time_s<=last)throw Error('Timestamps must be nonnegative and strictly increasing');last=row.time_s;
        if(qCount){const q=quaternion.map(k=>row[k]);if(!q.every(v=>v===null)&&(!q.every(Number.isFinite)||Math.abs(Math.hypot(...q)-1)>.02))throw Error('Invalid quaternion');}
        for(const k of ['speed_mps','horizontal_speed_mps','airspeed_mps','voltage_v','current_a','energy_wh','power_w'])if(row[k]!=null&&row[k]<0)throw Error(`Negative ${k}`);
        return row;
    });
    return rows;
}
function interpolate(a,b,key,t){const x=a[key],y=b[key];if(!Number.isFinite(x))return null;if(t===0)return x;if(!Number.isFinite(y))return null;return circular.has(key)?x+delta(y,x)*t:x+(y-x)*t;}
function orientationError(a,b,row,t){
    const qa=quaternion.map(k=>a[k]),qb=quaternion.map(k=>b[k]),qr=quaternion.map(k=>row[k]);
    if(![...qa,...qb,...qr].every(Number.isFinite))return null;
    const dot=qa.reduce((s,v,i)=>s+v*qb[i],0),sign=dot<0?-1:1;
    const q=qa.map((v,i)=>v+(sign*qb[i]-v)*t);
    const cos=Math.abs(q.reduce((s,v,i)=>s+v*qr[i],0)/(Math.hypot(...q)*Math.hypot(...qr)));
    return 2*Math.acos(Math.min(1,cos))*180/Math.PI;
}
function summarize(errors){const n=errors.length;return n?{samples:n,bias:errors.reduce((s,x)=>s+x,0)/n,mae:errors.reduce((s,x)=>s+Math.abs(x),0)/n,rmse:Math.sqrt(errors.reduce((s,x)=>s+x*x,0)/n),maxAbsolute:errors.reduce((m,x)=>Math.max(m,Math.abs(x)),0)}:null;}
function compare(sim,rows,{offsetSeconds=0,maxGapSeconds=.25}={}){
    if(!Number.isFinite(offsetSeconds)||!Number.isFinite(maxGapSeconds)||maxGapSeconds<=0)throw Error('Invalid alignment settings');
    if(sim.timeBasis!=='script-clock'||!Array.isArray(sim.trace)||sim.trace.length<2)throw Error('Expected ordinary benchmark trace');
    const trace=sim.trace,errors=Object.fromEntries(fields.filter(k=>!quaternion.includes(k)).map(k=>[k,[]]));errors.orientation_error_deg=[];
    let j=0,matched=0,skipped=0;
    for(const row of rows){const t=row.time_s+offsetSeconds;if(t<trace[0].time_s||t>trace.at(-1).time_s){skipped++;continue;}
        while(j+1<trace.length-1&&trace[j+1].time_s<=t)j++;
        const a=trace[j],b=trace[j+1],gap=b.time_s-a.time_s;
        if(gap>maxGapSeconds||gap<=0){skipped++;continue;}const u=(t-a.time_s)/gap;matched++;
        for(const k of Object.keys(errors)){
            if(k==='orientation_error_deg'){const e=orientationError(a,b,row,u);if(e!==null)errors[k].push(e);continue;}
            const x=u===1?b[k]:interpolate(a,b,k,u),y=row[k];if(Number.isFinite(x)&&Number.isFinite(y))errors[k].push(circular.has(k)?delta(x,y):x-y);
        }
    }
    const metrics=Object.fromEntries(Object.entries(errors).map(([k,v])=>[k,summarize(v)]).filter(([,v])=>v!==null));
    return {source:'user-supplied-normalized-telemetry-unverified',profile:sim.profile,scenario:sim.scenario,model:sim.model,offsetSeconds,maxGapSeconds,matchedRows:matched,skippedRows:skipped,metrics,validated:false,
        note:'Errors are simulation minus recording (orientation error is unsigned). No automatic calibration, flight certification or device validation.'};
}
module.exports={parseCsv,readCsv,compare};
