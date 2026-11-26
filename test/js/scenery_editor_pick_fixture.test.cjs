'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {findModelPixel}=require('../web/scenery_editor_pick_fixture.js');
const makePixel=(x,y)=>({x,y}),center={x:100,y:150},model={};
test('editor fixture tries center first and requires the actual model primitive',async()=>{
 let calls=0;
 const result=await findModelPixel(center,30,makePixel,p=>{calls++;return {primitive:model};},model);
 assert.deepEqual(result,center);assert.equal(calls,1);
});
test('editor fixture retains the original search grid and yields between bounded batches',async()=>{
 for(const radius of [25,30]){
  const visited=new Set();let batch=0,yields=0;
  const result=await findModelPixel(center,radius,makePixel,p=>{
   assert.ok(++batch<=4);visited.add(`${p.x-center.x},${p.y-center.y}`);return {primitive:{}};
  },model,async()=>{batch=0;yields++;});
  assert.equal(result,undefined);assert.ok(yields>0);
  for(let x=-radius;x<=radius;x+=2)for(let y=-radius;y<=radius;y+=2)assert.ok(visited.has(`${x},${y}`));
  assert.equal(visited.size,(radius+1)**2+(radius%2));
 }
});
test('editor fixture stops after finding a model off center, not another primitive',async()=>{
 let count=0;
 const result=await findModelPixel(center,25,makePixel,p=>{count++;return {primitive:p.x===101&&p.y===149?model:{}};},model,async()=>{});
 assert.deepEqual(result,{x:101,y:149});assert.ok(count<=5);
});
