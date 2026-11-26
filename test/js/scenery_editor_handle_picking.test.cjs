'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const {pickHandle}=require('../../web/features/scenery/scenery_editor.js');
const handle=(axis,x,y,extra={})=>({id:'fpv-edit-'+axis,position:{getValue:()=>({x,y})},show:true,...extra});
function fixture(entities,picked){let picks=0;return {entities,C:{SceneTransforms:{worldToWindowCoordinates:(_scene,p)=>p}},viewer:{clock:{currentTime:0},scene:{canvas:{clientWidth:390,clientHeight:844},pick(){picks++;return {id:picked};}}},get picks(){return picks;}};}
test('north endpoint wins over foreground bounds without a GPU read',()=>{
 const f=fixture([handle('east',250,300),handle('north',195,250),handle('up',195,190)],{id:'bound-line'});
 assert.equal(pickHandle(f.C,f.viewer,f.entities,{x:195,y:250},'touch'),'north');assert.equal(f.picks,0);
});
test('nearest endpoint distinguishes nearby rotation and translation controls',()=>{
 const f=fixture([handle('north',195,250),handle('heading',200,253)]);
 assert.equal(pickHandle(f.C,f.viewer,f.entities,{x:195,y:250},'touch'),'north');
 assert.equal(pickHandle(f.C,f.viewer,f.entities,{x:200,y:253},'mouse'),'heading');
});
test('touch tolerance is bounded and mouse precision is retained',()=>{
 const f=fixture([handle('north',100,100)]);
 assert.equal(pickHandle(f.C,f.viewer,f.entities,{x:113,y:100},'touch'),'north');
 assert.equal(pickHandle(f.C,f.viewer,f.entities,{x:113,y:100},'mouse'),null);
 assert.equal(pickHandle(f.C,f.viewer,f.entities,{x:115,y:100},'touch'),null);
});
test('arrow shafts and ring segments retain GPU picking away from endpoints',()=>{
 const north=handle('north',100,100),f=fixture([north],north);
 assert.equal(pickHandle(f.C,f.viewer,f.entities,{x:100,y:150},'mouse'),'north');assert.equal(f.picks,1);
 const foreign=fixture([north],{id:'fpv-edit-north'});
 assert.equal(pickHandle(foreign.C,foreign.viewer,foreign.entities,{x:100,y:150},'touch'),null,'a foreign same-name entity must not become an editor handle');
});
test('hidden, invalid, offscreen and unrelated markers do not capture touches',()=>{
 for(const e of [handle('north',100,100,{show:false}),handle('north',100,100,{isShowing:false}),handle('north',NaN,100),handle('north',-2,100),handle('north',400,100),handle('other',100,100)]){
  const f=fixture([e]);assert.equal(pickHandle(f.C,f.viewer,f.entities,{x:100,y:100},'touch'),null);
 }
});
