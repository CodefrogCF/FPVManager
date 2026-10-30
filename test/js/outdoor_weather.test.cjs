const test=require('node:test');
const assert=require('node:assert/strict');
require('../../web/weather_overlay.js');
const weather=globalThis.FPVWeatherOverlay;
const situational=require('../../web/situational_layers.js');

function weatherFixture(){
 const sources=[];let time=Date.parse('2026-10-30T12:00:00Z');const ticks=new Set();
 const C={CustomDataSource:class{constructor(){this.show=false;this.entities={values:[],removeAll(){this.values=[];},add(e){this.values.push(e);return e;}};}},Color:{fromBytes:(...v)=>v},Cartesian3:{fromDegreesArray:v=>v},ClassificationType:{TERRAIN:1},HeightReference:{CLAMP_TO_GROUND:1}};
 const viewer={dataSources:{async add(s){sources.push(s);return s;},remove(s){const i=sources.indexOf(s);if(i>=0)sources.splice(i,1);}},scene:{requestRender(){}}};
 const manager=weather.create(C,()=>viewer,{now:()=>time,timers:{setInterval:f=>{ticks.add(f);return f;},clearInterval:f=>ticks.delete(f)}});
 const command=(kind,value=4)=>({kind,source:'Open-Meteo forecast samples',sourceType:'forecast',units:weather.definitions[kind].units,timestampUtc:'2026-10-30T14:00:00Z',expiresAtUtc:'2026-10-30T12:10:00Z',gridSpacingMeters:1000,opacity:.5,cells:[{west:8,south:47,east:8.01,north:47.01,value}]});
 return {manager,sources,command,advance(ms){time+=ms;for(const tick of ticks)tick();},ticks};
}

test('cloud percentages, negative temperatures and source units are validated independently',()=>{
 const f=weatherFixture();
 assert.doesNotThrow(()=>weather.validate(f.command('temperature',-12)));
 assert.doesNotThrow(()=>weather.validate(f.command('cloudCover',100)));
 assert.throws(()=>weather.validate(f.command('cloudCover',101)));
 assert.throws(()=>weather.validate({...f.command('snowfall'),units:'mm/h'}));
 assert.throws(()=>weather.validate({...f.command('rain'),sourceType:'observation'}));
 assert.notDeepEqual(weather.rgb('temperature',-10),weather.rgb('temperature',30));
 f.manager.dispose();
});

test('forecast variables coexist with independent opacity and visibility; stale data is hidden and reload-safe',async()=>{
 const f=weatherFixture();
 await f.manager.replace(f.command('wind'));
 await f.manager.replace(f.command('temperature',-12));
 assert.deepEqual(f.manager.activeKinds,['wind','temperature']);assert.equal(f.sources.length,2);
 assert.equal(f.sources[1].entities.values[0].properties.units,'°C');
 assert.equal(f.sources[1].entities.values[0].polygon.material[3],128);
 assert.throws(()=>weather.validate({...f.command('temperature'),opacity:2}));
 await assert.rejects(f.manager.replace({...f.command('cloudCover'),timestampUtc:'2026-10-30T15:00:00Z'}),/common forecast time/);
 f.manager.clear('wind');assert.deepEqual(f.manager.activeKinds,['temperature']);assert.equal(f.sources[0].show,false);assert.equal(f.sources[1].show,true);
 f.advance(11*60000);assert.equal(f.sources[1].show,false);assert.equal(f.sources[1].entities.values.length,1);
 f.manager.dispose();assert.equal(f.sources.length,0);assert.equal(f.ticks.size,0);
});

test('all outdoor networks and closure rasters retain their own WMS lifecycle and source attribution',async()=>{
 const requested=[],disposed=[],events=[];
 const manager=situational.create({}, {camera:{},scene:{globe:{},requestRender(){}}},(...e)=>events.push(e),(_C,_viewer,emit,config)=>({set(command){requested.push({command,config});emit('status',{state:'ready'});},dispose(){disposed.push(config);}}),{timers:{setInterval:()=>1,clearInterval(){}}});
 const ids=Object.keys(situational.definitions).filter(id=>id.startsWith('outdoor-'));
 assert.equal(ids.length,10);
 for(const id of ids){await manager.set({id,visible:true,opacity:.6});await manager.set({id,visible:false,opacity:.6});}
 assert.equal(requested.length,20);
 for(const item of requested){assert.equal(item.config.definition.url,'https://wms.geo.admin.ch/');assert.ok(item.config.attribution.length>5);assert.match(item.config.definition.layer,/^ch\.(astra|bafu|swisstopo)/);}
 assert.ok(events.every(e=>e[0]==='situational-status'));
 manager.dispose();assert.equal(disposed.length,10);
});

test('station and planned-ground-route commands remain bounded and distinct from driving and flight routes',()=>{
 const marker={id:'station-1',name:'Station',detail:'Measured · old snapshot',geometry:{type:'Point',coordinates:[8,47]}};
 situational.validate({id:'meteo-stations',visible:true,features:[marker]});
 situational.validate({id:'hydro-stations',visible:true,features:[marker]});
 situational.validate({id:'ground-route',visible:true,features:[{...marker,geometry:{type:'LineString',coordinates:[[8,47],[8.1,47.1]]}}]});
 assert.throws(()=>situational.validate({id:'ground-route',visible:true,features:Array(1001).fill(marker)}));
});
