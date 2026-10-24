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
  for(const id of ['heliports','wildfire'])await p.manager.set({id,visible:true,opacity:.4});
  assert.equal(p.wms[0].config.definition.layer,'ch.bazl.flugplaetze-heliports');
  assert.equal(p.wms[1].config.definition.layer,'ch.bafu.gefahren-waldbrand_warnung');
  assert.equal(p.events[1][1].id,'wildfire');assert.equal(p.wms[0].command.opacity,.4);
  p.manager.dispose();assert.equal(p.disposed.length,2);
});
test('a failed replacement retains the prior source and disposal retires an attachment that completes late',async()=>{
  const p=fixture();await p.manager.set({id:'traffic',visible:true,features:[feature()]});const old=p.sources[0];
  const add=p.viewer.dataSources.add;p.viewer.dataSources.add=async()=>{throw Error('fixture');};
  await assert.rejects(p.manager.set({id:'traffic',visible:true,features:[feature('next')]}));assert.equal(p.sources[0],old);
  let finish;p.viewer.dataSources.add=source=>new Promise(resolve=>{finish=()=>{add(source);resolve(source);};});
  const pending=p.manager.set({id:'traffic',visible:true,features:[feature('late')]});p.manager.dispose();finish();
  assert.deepEqual(await pending,{superseded:true});assert.equal(p.sources.length,0);assert.equal(p.credits.size,0);
});
