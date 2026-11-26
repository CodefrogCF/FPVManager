'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const probe=require('../../tool/scenery/reference/bkg_rf_probe.js');
const input={source:'Synthetic test, not measured data',controls:[0,1,2].map((i)=>({longitude:13.7+i*.001,latitude:52.4,dhhn2016M:40+i,ellipsoidM:82+i}))};
test('BKG reference diagnostic differentiates two vertical hypotheses but never authorizes RF',()=>{
    for(const [values,hypothesis] of [[[82,83,84],'matches-ellipsoid-locally'],[[40,41,42],'matches-normal-locally'],[[61,62,63],'inconclusive'],[[82,83,100],'inconclusive']]){
        const result=probe.compare(input,values);assert.equal(result.hypothesis,hypothesis);assert.equal(result.rfAuthorized,false);
    }
    assert.throws(()=>probe.compare(input,[82,83,NaN]),/Incomplete/);
    assert.throws(()=>probe.validate({...input,controls:[input.controls[0],input.controls[0],input.controls[1]]}),/Duplicate/);
});
test('diagnostic uses production cache with distinct cold/warm samples and native comparison',async()=>{
    const provider={availability:{computeMaximumLevelAtPosition:()=>15}};
    const C={Cartographic:{fromDegrees:(longitude,latitude)=>({longitude,latitude})},sampleTerrainMostDetailed:async(p,pts)=>{assert.equal(p,provider);return pts.map((v,i)=>({...v,height:82+i}));}};
    let calls=0,reset=false;
    const cacheModule={create:()=>({setStation:p=>assert.equal(p,input.controls[0]),sample:async(p,pts,signal)=>{assert.equal(p,provider);assert.equal(signal.aborted,false);calls++;return pts.map((v,i)=>({...v,height:82+i}));},diagnostics:()=>({tileRequests:calls}),reset:()=>{reset=true;}})};
    const regional={terrain:async()=>provider,inCountry:()=>true,terrainUrl:'https://example.invalid/'};
    const result=await probe.run(input,{C,regional,cacheModule});assert.equal(calls,2);assert.equal(reset,true);assert.equal(result.coldVsNativeMaxM,0);assert.equal(result.warmVsNativeMaxM,0);assert.deepEqual(result.levels,[15,15,15]);assert.equal(result.rfAuthorized,false);
});
