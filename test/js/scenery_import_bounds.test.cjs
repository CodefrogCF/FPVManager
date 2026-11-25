'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const A=require('../../web/features/scenery/scenery_alignment.js');
const scope={console,setTimeout,clearTimeout,URL,TextDecoder,TextEncoder,atob,btoa,TransformStream,ReadableStream,WritableStream,AbortController,Blob};scope.global=scope;
const C=vm.runInNewContext(fs.readFileSync(require.resolve('../../web/cesium/Cesium.js'),'utf8')+';Cesium',scope);
const fixture=require('../fixtures/scenery/bounds_reference.json');
for(const [index,entry]of fixture.cases.entries())test('imported bounds reference agrees with pinned Cesium transform '+index,()=>{
 const matrix=A.modelMatrix(C,entry.pose),minimum=[Infinity,Infinity,Infinity],maximum=[-Infinity,-Infinity,-Infinity];
 for(let mask=0;mask<8;mask++){
  const xyz=[0,1,2].map(j=>entry.localBounds[j+((mask&(1<<j))?3:0)]*entry.pose.scale);
  const p=C.Matrix4.multiplyByPoint(matrix,new C.Cartesian3(...xyz),new C.Cartesian3());
  for(const [j,key]of ['x','y','z'].entries()){minimum[j]=Math.min(minimum[j],p[key]);maximum[j]=Math.max(maximum[j],p[key]);}
 }
 for(let j=0;j<3;j++){assert.ok(Math.abs(minimum[j]-entry.minimum[j])<1e-7);assert.ok(Math.abs(maximum[j]-entry.maximum[j])<1e-7);}
});
