const test=require('node:test'),assert=require('node:assert/strict');
const {create,normalize,url,sources}=require('../../web/map_labels.js');
const bounds={west:7.9,east:8.1,south:46.9,north:47.1};
function payload(kind='place'){
 return {results:[{layerBodId:sources[kind],featureId:1,geometry:{type:'Point',coordinates:[8,47]},
  properties:kind==='place'?{name:'Teststadt',objektklasse:'TLM_SIEDLUNGSNAME',objektart:'Ort'}:{stn_label:'Teststrasse',str_status:'bestehend'}}]};
}
const tick=()=>new Promise(r=>setImmediate(r));
class Event{constructor(){this.listeners=new Set();}addEventListener(fn){this.listeners.add(fn);return()=>this.listeners.delete(fn);}fire(...args){for(const fn of this.listeners)fn(...args);}}
function setup(options={}){
 let online=true,time=1000;const calls=[],states=[],primitives=[],credits=new Set(),changed=new Event(),render=new Event(),terrain=new Event();
 class Labels{constructor(){this.items=[];}add(value){this.items.push(value);return value;}}
 const C={LabelCollection:Labels,Cartesian2:class{},Cartographic:class{static fromDegrees(lon,lat,z,out){Object.assign(out,{longitude:lon,latitude:lat});return out;}},
  Cartesian3:{fromDegrees:(lon,lat,height)=>({lon,lat,height})},Math:{toDegrees:r=>r*180/Math.PI},Color:{BLACK:{withAlpha:alpha=>({alpha})},fromCssColorString:value=>value},
  HeightReference:{CLAMP_TO_GROUND:2,RELATIVE_TO_GROUND:3},LabelStyle:{FILL_AND_OUTLINE:3},Credit:class{},SceneTransforms:{worldToWindowCoordinates:(_scene,p)=>({x:400+(p.lon-8)*1000,y:300+(p.lat-47)*1000})}};
 const viewer={canvas:{clientWidth:800,clientHeight:600},camera:{positionCartographic:{latitude:47*Math.PI/180,longitude:8*Math.PI/180,height:1000},changed},
  scene:{globe:{getHeight:()=>500,tileLoadProgressEvent:terrain},primitives:{add:p=>primitives.push(p),remove:p=>primitives.splice(primitives.indexOf(p),1)},preRender:render,requestRender(){}},
  cesiumWidget:{creditDisplay:{addStaticCredit:c=>credits.add(c),removeStaticCredit:c=>credits.delete(c)}}};
 const layer=create(C,viewer,(_type,state)=>states.push(state.state),{now:()=>time,online:()=>online,
  fetcher:async(address,args)=>{calls.push({address,args});const kind=address.includes(encodeURIComponent(sources.street))?'street':'place';return new Response(JSON.stringify(payload(kind)));},...options});
 return {layer,calls,states,primitives,viewer,credits,changed,render,terrain,online:v=>online=v,draw(){time+=100;render.fire();}};
}
test('official names are text-only, geographically bounded and deduplicated; incomplete categories stay explicit',()=>{
 const data=payload();data.results.push(data.results[0],{...data.results[0],featureId:2,geometry:{type:'Point',coordinates:[30,90]}});
 assert.equal(normalize(data,'place',bounds).records.length,1);
 assert.equal(normalize(payload('street'),'street',bounds).records[0].text,'Teststrasse');
 assert.equal(normalize({results:[{...payload().results[0],properties:{name:'<b>HTML</b>',objektklasse:'TLM_SIEDLUNGSNAME'}}]},'place',bounds).records.length,0);
 assert.throws(()=>normalize({results:new Array(651)},'place',bounds));
 const request=new URL(url('street',bounds));assert.equal(request.hostname,'api3.geo.admin.ch');assert.equal(request.searchParams.get('sr'),'4326');assert.equal(request.searchParams.has('searchText'),false);
});
test('visibility is independent of imagery, repeated requests use the bounded session cache and labels declutter',async()=>{
 const p=setup();assert.equal(p.calls.length,0);p.layer.set({visible:true});await tick();p.draw();
 assert.equal(p.calls.length,2);assert.equal(p.primitives.length,1);assert.equal(p.primitives[0].items.filter(l=>l.show).length,1,'Overlapping place/street names must declutter');
 assert.ok(p.states.includes('ready'));assert.equal(p.calls[0].args.credentials,'omit');
 p.layer.set({visible:true});await tick();assert.equal(p.calls.length,2);
 p.layer.set({visible:false});assert.equal(p.primitives[0].show,false);assert.equal(p.credits.size,0);
 p.layer.set({visible:true});await tick();p.draw();assert.equal(p.calls.length,2);assert.equal(p.credits.size,1);
 p.layer.dispose();assert.equal(p.changed.listeners.size,0);assert.equal(p.render.listeners.size,0);assert.equal(p.terrain.listeners.size,0);assert.equal(p.primitives.length,0);
});
test('cached-only and network-offline modes never fall back to remote label requests',async()=>{
 for(const cachedOnly of [true,false]){
  const p=setup({cachedOnly});if(!cachedOnly)p.online(false);p.layer.set({visible:true});await tick();
  assert.equal(p.calls.length,0);assert.equal(p.states.at(-1),'offline');assert.equal(p.primitives[0].show,false);p.layer.dispose();
 }
});
test('late responses after hide/dispose do not restore labels, and failed refreshes preserve the last valid names',async()=>{
 const resolves=[];const late=setup({fetcher:()=>new Promise(r=>resolves.push(r))});late.layer.set({visible:true});late.layer.set({visible:false});
 for(const resolve of resolves)resolve(new Response(JSON.stringify(payload('street'))));await tick();assert.equal(late.primitives[0].show,false);late.layer.dispose();
 let fail=false;const p=setup({fetcher:async address=>{if(fail)throw Error('offline');return new Response(JSON.stringify(payload(address.includes(encodeURIComponent(sources.street))?'street':'place')));}});
 p.layer.set({visible:true});await tick();p.draw();assert.equal(p.primitives[0].items[0].text,'Teststadt');
 fail=true;p.layer.set({visible:true,retry:true});await tick();p.draw();assert.equal(p.states.at(-1),'failed');assert.equal(p.primitives[0].items[0].text,'Teststadt');p.layer.dispose();
});
