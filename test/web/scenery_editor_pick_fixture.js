/* Test-only cooperative search for a real Cesium pick on the fixture model. */
(function(root){
 'use strict';
 async function findModelPixel(center,radius,makePixel,pick,model,yieldTask=()=>new Promise(resolve=>setTimeout(resolve,0))){
  // Retain every candidate of the original 2-pixel grid; try its center first.
  const offsets=[{x:0,y:0}];
  for(let x=-radius;x<=radius;x+=2)for(let y=-radius;y<=radius;y+=2){
   if(x||y)offsets.push({x,y});
  }
  offsets.sort((a,b)=>a.x*a.x+a.y*a.y-b.x*b.x-b.y*b.y);
  for(let i=0;i<offsets.length;i++){
   if(i&&i%4===0)await yieldTask();
   const {x,y}=offsets[i],pixel=makePixel(center.x+x,center.y+y);
   if(pick(pixel)?.primitive===model)return pixel;
  }
  return undefined;
 }
 if(typeof module==='object'&&module.exports)module.exports={findModelPixel};
 else root.FPVEditorPickFixture={findModelPixel};
})(globalThis);
