'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const M=require('../../web/features/scenery/scenery_manager.js');

class Cartesian3{}
Cartesian3.fromRadians=(lon,lat,height)=>({longitude:lon,latitude:lat,height});
Cartesian3.negate=()=>({x:0,y:0,z:-1});
class Ray{constructor(origin,direction){this.origin=origin;this.direction=direction;}}
const C={Cartesian3,Ray,Ellipsoid:{WGS84:{geodeticSurfaceNormal:()=>({x:0,y:0,z:1})}},
  Cartographic:{fromCartesian:hit=>hit}};

test('BKG calibration samples the currently rendered Globe surface, not the model or raw provider',()=>{
  const observed=[];
  const viewer={scene:{globe:{pick:(ray,scene)=>{
    observed.push(ray.origin.longitude);
    return ray.origin.longitude===3 ? undefined : {height:42+ray.origin.longitude};
  }}}};
  const controls=Array.from({length:8},(_,i)=>({longitude:i,latitude:.1}));
  const result=M.pickRenderedGroundHeights(C,viewer,controls);
  assert.equal(result.length,8);
  assert.equal(result.filter(Number.isFinite).length,7);
  assert.equal(result[0],42);
  assert.ok(Number.isNaN(result[3]));
  assert.deepEqual(observed,[0,1,2,3,4,5,6,7]);
});

test('Rendered-terrain calibration cannot invent a BKG height from unavailable rendered terrain',()=>{
  const heights=M.pickRenderedGroundHeights(C,{scene:{globe:{pick:()=>undefined}}},[{longitude:13.8,latitude:52.4}]);
  assert.ok(Number.isNaN(heights[0]));
  assert.throws(()=>M.fitGroundReference([[0,0,-2.02575]],heights,-2.02575,16.023268178),/Insufficient/);
});

test('Beta alignment uses five real terrain hits and never mixes raw BKG heights',()=>{
  const source=fs.readFileSync('web/globe.js','utf8');
  assert.match(source,/const displayed=FPVSceneryManager\.pickRenderedGroundHeights\(Cesium,viewer,positions\)/);
  assert.match(source,/if\(regionalTerrain\)\{[\s\S]*const valid=displayed\.map/);
  assert.match(source,/heights=valid;/);
  assert.doesNotMatch(source,/RUEDERSDORF_BKG_VISUAL_OFFSET_M/);
});


test('GCG2016 is used only for the certified DGM1 model-root reference, not as a second runtime offset',()=>{
  const item=require('../../web/assets/scenery/catalog.json').sceneries[0];
  const offset=38.871142784910;
  const expected=40.949489589+offset;
  assert.ok(Math.abs(expected-79.82063237391)<1e-9);
  assert.equal(item.alignment.longitude,13.789853720999993);
  assert.ok(Math.abs(item.alignment.ellipsoidHeightM-112.279767885956)<1e-8);
  assert.equal(item.heightAlignmentMode,'terrain');
  assert.equal(item.requireGroundCalibration,true);
  const workbench=require('../../web/assets/scenery/reference_alignment.json');
  assert.equal(workbench.ellipsoidHeightM,34.25);
});


test('resident terrain mesh can calibrate a site outside the current globe pick list without provider I/O',()=>{
  const point={longitude:.2,latitude:.3};let calls=0;
  const globe={pick:()=>undefined,getHeight:p=>{assert.equal(p,point);calls++;return 42;}};
  assert.deepEqual(M.pickRenderedGroundHeights(C,{scene:{globe}},[point]),[42]);assert.equal(calls,1);
  globe.pick=()=>({height:45});
  assert.deepEqual(M.pickRenderedGroundHeights(C,{scene:{globe}},[point]),[45]);assert.equal(calls,1);
  globe.pick=()=>undefined;globe.getHeight=()=>undefined;
  assert.ok(Number.isNaN(M.pickRenderedGroundHeights(C,{scene:{globe}},[point])[0]));
});
