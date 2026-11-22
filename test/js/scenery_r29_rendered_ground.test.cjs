'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const M=require('../../web/scenery_manager.js');

class Cartesian3{}
Cartesian3.fromRadians=(lon,lat,height)=>({longitude:lon,latitude:lat,height});
Cartesian3.negate=()=>({x:0,y:0,z:-1});
class Ray{constructor(origin,direction){this.origin=origin;this.direction=direction;}}
const C={Cartesian3,Ray,Ellipsoid:{WGS84:{geodeticSurfaceNormal:()=>({x:0,y:0,z:1})}},
  Cartographic:{fromCartesian:hit=>hit}};

test('R29 BKG calibration samples the currently rendered Globe surface, not the model or raw provider',()=>{
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

test('R29 cannot invent a BKG height from unavailable rendered terrain',()=>{
  const heights=M.pickRenderedGroundHeights(C,{scene:{globe:{pick:()=>undefined}}},[{longitude:13.8,latitude:52.4}]);
  assert.ok(Number.isNaN(heights[0]));
  assert.throws(()=>M.fitGroundReference([[0,0,-2.02575]],heights,-2.02575,16.023268178),/Insufficient/);
});

test('R29 beta alignment uses five real terrain hits and never mixes raw BKG heights',()=>{
  const source=fs.readFileSync('web/globe.js','utf8');
  assert.match(source,/const displayed=FPVSceneryManager\.pickRenderedGroundHeights\(Cesium,viewer,positions\)/);
  assert.match(source,/if\(regionalTerrain\)\{\s*if\(displayed\.filter\(Number\.isFinite\)\.length<5\)/);
  assert.match(source,/heights=displayed;/);
  assert.doesNotMatch(source,/RUEDERSDORF_BKG_VISUAL_OFFSET_M/);
});


test('R31 does not use the historical GCG2016 separation as an extra visual offset',()=>{
  const item=require('../../web/assets/scenery/catalog.json').sceneries[0];
  const offset=38.871142784910;
  const expected=40.949489589+offset;
  assert.ok(Math.abs(expected-79.82063237391)<1e-9);
  assert.equal(item.alignment.longitude,13.789853720999993);
  assert.equal(item.alignment.ellipsoidHeightM,34.25);
  assert.equal(item.heightAlignmentMode,'fixed');
});
