'use strict';
const fs=require('node:fs'),path=require('node:path'),test=require('node:test'),assert=require('node:assert/strict');
const C=require(process.env.FPV_COLLISION_RUNTIME||'../../web/scenery_collision.js');
const b=fs.readFileSync(process.env.FPV_R5_FPC||path.resolve(__dirname,'../../web/assets/scenery/local_reference.fpc'));
const m=C.parse(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)),R=.25/16.023268178233355;
const sections=[['high',-5.06,-1.49,14,[[-1.76,-1.52],[-1.40,-1.16],[-1.01,-.77],[-.53,-.32],[-.29,-.13]]],['low',-1.49,3.44,19,[[-1.76,-1.56],[-1.46,-1.25],[-.98,-.77]]]];
for(const [name,x0,x1,n,bands] of sections)for(const side of [-2.304,-.88])for(let i=0;i<n;i++)for(let j=0;j<bands.length;j++){
 let [s,e]=bands[j],doors=name==='high'?(side===-.88?[4]:[1,9]):(side===-.88?[9]:[2,15]);
 const door=j===0&&doors.includes(i);if(door){s=-1.92;e=Math.max(e,s+.23)}
 const closed=name==='low'&&side===-.88&&((j===1&&![2,9,15].includes(i))||(j===2&&i>=16)||(j===0&&!doors.includes(i)&&[0,1,5,6,13,17,18].includes(i)));
 test(`R5 ${name} side ${side} bay ${i} band ${j}: ${door?'entry':closed?'solid infill':'at least one clear local approach'}`,()=>{
  let w=(x1-x0)/n,x=x0+w*i,paths=0;for(let u of [.21,.30,.40,.50,.60,.70,.79])for(let v of [.20,.32,.44,.56,.68,.80]){
   const X=x+w*u,Z=s+(e-s)*v,sign=side===-.88?1:-1;
   if(!C.sweep(m,[X,side+sign*.075,Z],[X,side-sign*.075,Z],R))paths++;
  }
  if(closed)assert.equal(paths,0);else assert.ok(paths>0);
 });
}
const cases=[['aisle alongside spine',[-4.9,-1.90,-1.25],[3.1,-1.90,-1.25],false],['central support',[-1.75,-1.592,-1.3],[-1.2,-1.592,-1.3],true],['over tanks',[-3.2,-1.43,-1.55],[-2.1,-1.43,-1.55],false],['shared foundation',[-2.65,-1.84,-1.70],[-2.65,-1.84,-1.96],true],['adjacent raised platform',[-2.7,-2.1,-1.42],[-2.7,-2.1,-1.65],true],['roof',[-3.3,-1.59,.4],[-3.3,-1.59,-.6],true],['roof gap',[-2.60,-1.59,.2],[-2.60,-1.59,-.32],false]];
for(let y of [-1.761,-1.543,-1.325,-1.107])cases.push(['longitudinal tank '+y,[-3.15,y,-1.762],[-2.65,y,-1.762],true]);
for(let [name,a,z,expected] of cases)test(name,()=>assert.equal(!!C.sweep(m,a,z,R),expected));
