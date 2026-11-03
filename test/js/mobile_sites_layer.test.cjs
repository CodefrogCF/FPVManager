const test=require('node:test');
const assert=require('node:assert/strict');
const {create,validate}=require('../../web/situational_layers.js');
function station(id){return {id,name:'Station <script>demo()</script>',
 detail:'BAKOM / official <script>demo()</script> \n LV95 2600000,1200000',
 geometry:{type:'Point',coordinates:[7.44,46.95]}};}
function harness(){
 const sources=[],credits=new Set(),sent=[];
 const C={CustomDataSource:class{constructor(){this.entities={values:[],add(v){this.values.push(v);return v;}};}},
 Credit:class{constructor(html){this.html=html;}},
 Color:{BLACK:'black',fromCssColorString:v=>v},
 Cartesian3:{fromDegrees:(...v)=>v},Cartographic:{fromDegrees:(...v)=>v},
 Rectangle:{contains:()=>true}, HeightReference:{CLAMP_TO_GROUND:1}};
 const viewer={dataSources:{add:async s=>{sources.push(s);return s;},
 remove:s=>{const i=sources.indexOf(s);if(i>=0)sources.splice(i,1);}},
 camera:{computeViewRectangle:()=>({}),moveEnd:{addEventListener:()=>()=>{}}},
 scene:{globe:{},requestRender(){}},
 cesiumWidget:{creditDisplay:{addStaticCredit:c=>credits.add(c),removeStaticCredit:c=>credits.delete(c)}}};
 const timer={setInterval:()=>1,clearInterval:()=>{}};
 const layer=create(C,viewer,(...e)=>sent.push(e),()=>({dispose(){},set(){}}),{timers:timer});
 return {layer,sources,credits,sent};
}
test('BAKOM markers are point-only, source attributed and strictly capped',async()=>{
 const p=harness();
 const command={id:'mobile-sites',visible:true,features:[station('1')]};
 validate(command);
 await p.layer.set(command);
 assert.equal(p.sources[0].entities.values[0].point.color,'#b0a5ea');
 assert.ok([...p.credits][0].html.includes('BAKOM'));
 assert.ok(p.sources[0].entities.values[0].description.includes('&lt;script&gt;'));
 assert.equal(p.sources[0].entities.values[0].description.includes('<script>'),false);
 assert.ok(p.layer.pick(p.sources[0].entities.values[0]));
 assert.equal(p.sent.at(-1)[0],'situational-selected');
 assert.throws(()=>validate({id:'mobile-sites',visible:true,features:Array.from({length:181},(_,i)=>station(String(i)))}));
 assert.throws(()=>validate({id:'mobile-sites',visible:true,features:[{
 ...station('x'),geometry:{type:'LineString',coordinates:[[7.44,46.95],[7.45,46.95]]}}]}));
 p.layer.dispose();assert.equal(p.credits.size,0);
});
test('BAKOM renderer replacement, reload and hiding clean up sources and credits',async()=>{
 const p=harness();
 await p.layer.set({id:'mobile-sites',visible:true,features:[station('before')]});
 const old=p.sources[0];
 await p.layer.set({id:'mobile-sites',visible:true,features:[station('after')]});
 assert.equal(p.sources.length,1);
 assert.notEqual(p.sources[0],old);
 assert.equal(p.credits.size,1);
 assert.equal(p.sources[0].entities.values[0].properties.situationalFeature,'after');
 await p.layer.set({id:'mobile-sites',visible:false});
 assert.equal(p.sources.length,0);assert.equal(p.credits.size,0);
 await p.layer.set({id:'mobile-sites',visible:true,features:[station('reload')]});
 assert.equal(p.sources.length,1);
 p.layer.dispose();assert.equal(p.sources.length,0);assert.equal(p.credits.size,0);
});
