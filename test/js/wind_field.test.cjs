const test=require('node:test'),assert=require('node:assert/strict');
const {field,sample,create}=require('../../web/wind_field.js');
function snapshot({speed=10,from=270}={}){
    const lat=46.7,lon=8.4,radius=1500,dy=radius/111320,dx=radius/(111320*Math.cos(lat*Math.PI/180));
    return {mode:'current',source:'Open-Meteo',validAtUtc:'2026-10-28T10:00:00Z',retrievedUtc:'2026-10-28T10:00:00Z',expiresUtc:'2026-10-28T10:30:00Z',
        centerLatitude:lat,centerLongitude:lon,radiusMeters:radius,nodes:Array.from({length:9},(_,i)=>({latitude:lat+(Math.floor(i/3)-1)*dy,longitude:lon+(i%3-1)*dx,
            levels:[10,80,120,180].map(agl=>({agl,speedMs:speed,fromDegrees:from}))}))};
}
test('meteorological wind-from becomes world airflow; height interpolation handles direction wrap',()=>{
    const west=field(snapshot()),flow=sample(west,46.7,8.4,40);assert.ok(Math.abs(flow.north)<1e-10);assert.ok(Math.abs(flow.east-10)<1e-9);
    const raw=snapshot({from:350});for(const node of raw.nodes){node.levels=[{agl:10,speedMs:10,fromDegrees:350},{agl:80,speedMs:10,fromDegrees:10}];}
    const v=sample(field(raw),46.7,8.4,45);assert.ok(v.north< -9.8);assert.ok(Math.abs(v.east)<1e-10);
    assert.equal(sample(west,46.7,8.4,1000).extrapolated,true);assert.equal(sample(west,46.7,8.4,10).extrapolated,false);
});
test('bilinear interpolation preserves holes, exact grid nodes and outside coverage',()=>{
    const raw=snapshot();raw.nodes[0].levels=[];const data=field(raw);
    assert.ok(sample(data,46.7,8.4,80));assert.equal(sample(data,46.7-data.dy*.5,8.4-data.dx*.5,80),null);
    assert.equal(sample(data,46.7+data.dy*2,8.4,80),null);assert.equal(sample(data,46.7,8.4,NaN),null);
    raw.nodes[4].levels[0].speedMs=Infinity;assert.throws(()=>field(raw));
    const bad=snapshot();bad.nodes[4].latitude+=1;assert.throws(()=>field(bad));
});
class Event{constructor(){this.listeners=new Set();}addEventListener(fn){this.listeners.add(fn);return()=>this.listeners.delete(fn);}fire(...args){for(const fn of this.listeners)fn(...args);}}
function renderer(){
    let clock=0,now=Date.parse('2026-10-28T10:05:00Z'),queries=0,ready=true;const states=[],primitives=[],credits=new Set();
    class V{constructor(x=0,y=0,z=0){Object.assign(this,{x,y,z});}static fromDegrees(x,y,z){return new V(x,y,z);}}
    class Lines{constructor(){this.lines=[];}add(line){this.lines.push(line);return line;}removeAll(){this.lines=[];}}
    const tiles=new Event(),update=new Event();
    const C={Cartesian3:V,Cartographic:class{static fromDegrees(lon,lat,z,out){Object.assign(out,{lon,lat,z});return out;}},
        PolylineCollection:Lines,Transforms:{eastNorthUpToFixedFrame:p=>p},Matrix4:{multiplyByPoint:(p,v,out)=>Object.assign(out,{x:p.x+v.x,y:p.y+v.y,z:p.z+v.z})},
        Material:{fromType:(type,uniforms)=>({type,uniforms})},Color:{fromCssColorString:color=>({withAlpha:alpha=>({color,alpha})})},Credit:class{}};
    const viewer={scene:{preUpdate:update,primitives:{add:p=>primitives.push(p),remove:p=>primitives.splice(primitives.indexOf(p),1)},requestRender(){},
        globe:{tileLoadProgressEvent:tiles,getHeight:()=>{queries++;return 1000;}}},cesiumWidget:{creditDisplay:{addStaticCredit:c=>credits.add(c),removeStaticCredit:c=>credits.delete(c)}}};
    const layer=create(C,viewer,(type,state)=>states.push({type,...state}),{now:()=>now,elapsed:()=>clock,isTerrainReady:()=>ready});
    return {layer,states,credits,lines:()=>primitives[0],queries:()=>queries,frame(ms=50){clock+=ms;update.fire();},now:v=>now=v,ready:v=>ready=v,update,tiles};
}
test('animated 3D glyphs reuse ground heights, keep bounded densities and are independent of celestial time',()=>{
    const p=renderer();p.layer.set({visible:true,affectFlight:true,field:snapshot()});p.frame();
    assert.equal(p.lines().lines.length,75);const first={...p.lines().lines[20].positions[0]},queries=p.queries();
    for(let i=0;i<40;i++)p.frame();assert.equal(p.queries(),queries);assert.notEqual(p.lines().lines[20].positions[0].x,first.x);
    p.layer.performance('performance');p.frame();assert.equal(p.lines().lines.length,18);
    assert.ok(p.queries()<=queries);assert.ok(p.layer.sample({latitude:46.7,longitude:8.4,agl:30}).east>9.9);
    p.layer.navigation({latitude:46.7,longitude:8.4,agl:500});p.frame();assert.ok(p.layer.sample({latitude:46.7,longitude:8.4,agl:500}).extrapolated);
    p.layer.dispose();assert.equal(p.update.listeners.size,0);assert.equal(p.tiles.listeners.size,0);assert.equal(p.credits.size,0);
});
test('expiry, unknown coverage and terrain failure suspend display/forces without a false calm snapshot',()=>{
    const p=renderer();p.layer.set({visible:true,affectFlight:true,field:snapshot()});p.frame();
    p.ready(false);p.frame();assert.equal(p.lines().show,false);assert.equal(p.states.at(-1).state,'terrainPending');
    assert.equal(p.layer.sample({latitude:48,longitude:8,agl:50}).available,false);
    p.now(Date.parse('2026-10-28T10:31:00Z'));p.frame();assert.equal(p.states.at(-1).state,'expired');assert.equal(p.lines().show,false);
    assert.equal(p.layer.sample({latitude:46.7,longitude:8.4,agl:50}).reason,'expired');
    p.layer.set({visible:false,affectFlight:false,field:null});assert.equal(p.layer.sample({latitude:46.7,longitude:8.4,agl:50}),null);p.layer.dispose();
});
