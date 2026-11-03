const test=require('node:test');const assert=require('node:assert/strict');
const {create,validate}=require('../../web/situational_layers.js');
const time=Date.parse('2026-10-24T12:00:00Z');
function feature(id='one'){return {id,name:'<img src=x onerror=alert(1)>',detail:'source <script>bad</script>',timestampUtc:'2026-10-24T11:59:59Z',geometry:{type:'Point',coordinates:[8,47]}};}
function fixture(options={}){
  const sources=[],credits=new Set(),events=[],wms=[],disposed=[],intervals=new Set();let at=time;
  const C={CustomDataSource:class{constructor(){this.entities={values:[],add(e){this.values.push(e);return e;}};}},
    Credit:class{constructor(html){this.html=html;}},Color:{BLACK:'black',fromCssColorString:value=>value},
    Cartesian3:{fromDegrees:(...v)=>v,fromDegreesArray:v=>v},Cartographic:{fromDegrees:(...v)=>v},
    HeightReference:{CLAMP_TO_GROUND:1},Rectangle:{contains:(_,p)=>p[0]<10}};
  if(options.avalanche){
    C.Color.fromCssColorString=color=>({withAlpha:alpha=>({color,alpha})});
    C.PolygonHierarchy=class{constructor(positions,holes=[]){this.positions=positions;this.holes=holes;}};
    C.ClassificationType={TERRAIN:2};
  }
  const viewer={dataSources:{add:async source=>{sources.push(source);return source;},remove:source=>{const i=sources.indexOf(source);if(i>=0)sources.splice(i,1);}},
    camera:{computeViewRectangle:()=>({}),moveEnd:{addEventListener:()=>()=>{}}},scene:{globe:{},requestRender(){}},
    cesiumWidget:{creditDisplay:{addStaticCredit:c=>credits.add(c),removeStaticCredit:c=>credits.delete(c)}}};
  const factory=(_C,_viewer,emit,config)=>({set:command=>{wms.push({command,config});emit('',{state:'ready'});},dispose:()=>disposed.push(config)});
  const manager=create(C,viewer,(...v)=>events.push(v),factory,{now:()=>at,timers:{setInterval:f=>{intervals.add(f);return f;},clearInterval:f=>intervals.delete(f)},...options});
  return {manager,viewer,sources,credits,events,wms,disposed,intervals,time:v=>{at=v;for(const f of intervals)f();}};
}
test('awareness validation bounds geometries, IDs, coordinates and source text',()=>{
  validate({id:'aircraft',visible:true,features:[feature()]});
  for(const command of [{id:'other',visible:false},{id:'wildfire',visible:true,opacity:2},
    {id:'aircraft',visible:true,features:[feature(),feature()]},
    {id:'aircraft',visible:true,features:[{...feature(),geometry:{type:'Point',coordinates:[8,NaN]}}]}])assert.throws(()=>validate(command));
});
test('traffic categories remain distinct; future events and old/unknown counter measurements stay hidden',async()=>{
  const p=fixture();
  await p.manager.set({id:'traffic',visible:true,features:[
    {...feature('closed'),category:'closure'},
    {...feature('works'),category:'roadworks'},
    {...feature('planned'),category:'congestion',validFromUtc:new Date(time+60000).toISOString()}
  ]});
  const events=p.sources[0].entities.values;
  assert.equal(events[0].point.color,'#e75c54');assert.equal(events[1].point.color,'#d6b74f');assert.equal(events[2].show,false);
  p.time(time+61000);assert.equal(events[2].show,true);
  assert.throws(()=>validate({id:'traffic',visible:true,features:[{...feature(),category:'made-up'}]}));
  p.time(time);await p.manager.set({id:'traffic-counters',visible:true,features:[feature('counter'),{...feature('unknown'),timestampUtc:null}]});
  const counters=p.sources[1].entities.values;
  assert.equal(counters[0].show,true);assert.equal(counters[1].show,false);
  p.time(time+181000);assert.equal(counters[0].show,false);
  await p.manager.set({id:'traffic-counters',visible:false});assert.equal(p.sources.length,1);p.manager.dispose();
});
test('independent sources retain credits, escape untrusted details and hide stale/expired/outside positions',async()=>{
  const p=fixture();await p.manager.set({id:'aircraft',visible:true,features:[feature()]});
  const entity=p.sources[0].entities.values[0];assert.ok(entity.show);assert.ok(entity.description.includes('&lt;script&gt;'));
  assert.equal(entity.description.includes('<script>'),false);assert.equal(p.credits.size,1);
  assert.ok(p.manager.pick(entity));assert.equal(p.events.at(-1)[0],'situational-selected');
  p.time(time+45000);assert.equal(entity.point.color,'#e6b64d');p.time(time+301000);assert.equal(entity.show,false);
  await p.manager.set({id:'traffic',visible:true,features:[{...feature(),id:'traffic',validUntilUtc:'2026-10-24T11:00:00Z'}]});
  assert.equal(p.sources[1].entities.values[0].show,false);
  await p.manager.set({id:'aircraft',visible:false});assert.equal(p.sources.length,1);assert.equal(p.credits.size,1);
  p.manager.dispose();assert.equal(p.sources.length,0);assert.equal(p.credits.size,0);assert.equal(p.intervals.size,0);
});
test('official WMS definitions stay independent and retain visibility, opacity and status routing',async()=>{
  const p=fixture();assert.equal(p.wms.length,0);
  for(const id of ['heliports','wildfire','roads'])await p.manager.set({id,visible:true,opacity:.4});
  assert.equal(p.wms[0].config.definition.layer,'ch.bazl.flugplaetze-heliports');
  assert.equal(p.wms[1].config.definition.layer,'ch.bafu.gefahren-waldbrand_warnung');
  assert.equal(p.events[1][1].id,'wildfire');assert.equal(p.wms[0].command.opacity,.4);
  assert.equal(p.wms[2].config.definition.layer,'ch.swisstopo.swisstlm3d-strassen');
  assert.deepEqual(p.wms[2].config.definition.bounds,[3.329595,44.074747,14.278255,49.200438]);
  assert.equal(p.wms[2].config.attribution,'© swisstopo · geo.admin.ch');
  await p.manager.set({id:'roads',visible:false,opacity:.4});
  assert.equal(p.wms.at(-1).command.visible,false);
  p.manager.dispose();assert.equal(p.disposed.length,3);
});
test('a failed replacement retains the prior source and disposal retires an attachment that completes late',async()=>{
  const p=fixture();await p.manager.set({id:'traffic',visible:true,features:[feature()]});const old=p.sources[0];
  const add=p.viewer.dataSources.add;p.viewer.dataSources.add=async()=>{throw Error('fixture');};
  await assert.rejects(p.manager.set({id:'traffic',visible:true,features:[feature('next')]}));assert.equal(p.sources[0],old);
  let finish;p.viewer.dataSources.add=source=>new Promise(resolve=>{finish=()=>{add(source);resolve(source);};});
  const pending=p.manager.set({id:'traffic',visible:true,features:[feature('late')]});p.manager.dispose();finish();
  assert.deepEqual(await pending,{superseded:true});assert.equal(p.sources.length,0);assert.equal(p.credits.size,0);
});

function avalanche(){return {id:'warning',name:'Regional warning',detail:'Full source text <script>unsafe</script>\n'+'x'.repeat(2000),level:3,
  timestampUtc:'2026-10-24T11:00:00Z',validFromUtc:'2026-10-24T11:30:00Z',validUntilUtc:'2026-10-24T14:00:00Z',
  geometry:{type:'MultiPolygon',coordinates:[
    [[[8,47],[8.2,47],[8.2,47.2],[8,47.2],[8,47]],[[8.05,47.05],[8.05,47.1],[8.1,47.1],[8.1,47.05],[8.05,47.05]]],
    [[[8.3,47],[8.4,47],[8.4,47.1],[8.3,47.1],[8.3,47]]]
  ]}};}
test('avalanche renders each part once, retains holes, opacity and full escaped details, expires and cleans up',async()=>{
  const p=fixture({avalanche:true}),f=avalanche();
  await p.manager.set({id:'avalanche',visible:true,opacity:.4,features:[f]});
  const entities=p.sources[0].entities.values;
  assert.equal(entities.length,2);assert.equal(entities[0].polygon.hierarchy.holes.length,1);
  assert.deepEqual(entities[0].polygon.material,{color:'#ff9900',alpha:.4});
  assert.equal(entities[0].polygon.classificationType,2);
  assert.ok(entities[0].description.includes('&lt;script&gt;'));assert.ok(entities[0].description.length>2000);
  assert.equal(p.manager.pick(entities[1]),f);assert.equal(p.events.at(-1)[1].detail,f.detail);
  assert.equal(entities[0].show,true);p.time(Date.parse(f.validUntilUtc));assert.equal(entities[0].show,false);
  p.time(Date.parse(f.validFromUtc)-1);assert.equal(entities[1].show,false);
  await assert.rejects(p.manager.set({id:'avalanche',visible:true,opacity:.4,features:[{...f,level:6}]}));
  assert.equal(p.sources.length,1);
  p.manager.dispose();assert.equal(p.sources.length,0);assert.equal(p.credits.size,0);assert.equal(p.intervals.size,0);
});
test('avalanche rejects open rings, foreign coordinates, invalid validity and excessive geometry',()=>{
  for(const mutate of [f=>f.geometry.coordinates[0][0].pop(),f=>f.geometry.coordinates[0][0][0]=[180,47],
    f=>f.validUntilUtc='invalid',f=>f.geometry.coordinates=Array(257).fill(f.geometry.coordinates[0])]){
    const f=avalanche();mutate(f);assert.throws(()=>validate({id:'avalanche',visible:true,opacity:.5,features:[f]}));
  }
});

test('OSM POI rendering uses bounded markers, retains ODbL credit and escapes names/tags',async()=>{
  const p=fixture();
  const item={...feature('node/123'),name:'Water <b>unsafe</b>',detail:'access: <script>unsafe</script>\nRetrieved: 2026-11-03'};
  await p.manager.set({id:'osm-poi',visible:true,features:[item]});
  assert.equal(p.sources.length,1);
  const entity=p.sources[0].entities.values[0];
  assert.equal(entity.point.color,'#86ca70');
  assert.ok(entity.description.includes('&lt;script&gt;'));
  assert.ok([...p.credits][0].html.includes('OpenStreetMap contributors'));
  assert.ok([...p.credits][0].html.includes('ODbL'));
  assert.throws(()=>validate({id:'osm-poi',visible:true,features:Array.from({length:301},(_,i)=>feature(String(i)))}));
  assert.throws(()=>validate({id:'osm-poi',visible:true,features:[{...item,geometry:{type:'LineString',coordinates:[[8,47],[8.1,47.1]]}}]}));
  p.manager.dispose();assert.equal(p.credits.size,0);
});
