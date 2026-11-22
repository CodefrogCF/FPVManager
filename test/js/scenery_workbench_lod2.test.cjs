'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const R=require('../../web/regional_3d.js');
const root=path.join(__dirname,'../..');
test('editor and terrain globe use distinct official height variants',()=>{
    assert.match(R.buildingsUrl,/lod2_4326_dgm5\.json$/);
    assert.match(R.buildingsFlatUrl,/lod2_4326_null\.json$/);
    const src=fs.readFileSync(path.join(root,'tool/scenery/cesium_georeference_workbench.js'),'utf8');
    assert.match(src,/const url=R\.buildingsFlatUrl/);
    assert.match(src,/tileFailed\?\.addEventListener/);
});
test('HTTP status and source URL survive diagnostics',()=>{
    const m=R.describeRequestError({statusCode:503,message:'Request has failed'},R.buildingsFlatUrl);
    assert.match(m,/HTTP 503/);
    assert.ok(m.includes(R.buildingsFlatUrl));
});
test('unknown HTTP status is not falsely reported as CORS',()=>{
    const m=R.describeRequestError({message:'Request has failed'},R.buildingsFlatUrl);
    assert.match(m,/HTTP-Status unbekannt/);
    assert.match(m,/Netzwerk\/CORS.*prüfen/);
});
test('R32 catalog uses physical terrain root while Workbench keeps flat ellipsoid preview at 34.25 m',()=>{
    const read=n=>JSON.parse(fs.readFileSync(path.join(root,'web/assets/scenery',n),'utf8'));
    const a=read('catalog.json').sceneries[0].alignment;
    const b=read('reference_alignment.json');
    for(const key of Object.keys(a))if(key!=='ellipsoidHeightM')assert.equal(a[key],b[key]);
    assert.equal(a.opacity,1);
    assert.equal(a.scale,16.023268178233355);
    assert.equal(b.ellipsoidHeightM,34.25);
    assert.ok(Math.abs(a.ellipsoidHeightM-112.279767885956)<1e-8);
    const editor=fs.readFileSync(path.join(root,'tool/scenery/cesium_georeference_workbench.js'),'utf8');
    assert.match(editor,/fetch\('\.\.\/\.\.\/web\/assets\/scenery\/reference_alignment\.json'/);
    assert.match(editor,/terrainProvider:new C\.EllipsoidTerrainProvider\(\)/);
});

test('reference edit enables only building replacement and prepares a disabled certified terrain region',()=>{
    const catalog=JSON.parse(fs.readFileSync(path.join(root,'web/assets/scenery/catalog.json'),'utf8'));
    const item=catalog.sceneries[0];
    assert.equal(item.replaceBuildings,true);
    assert.equal(item.clipTerrain,false);
    assert.equal(item.buildingRegions.length,1);
    assert.equal(item.buildingRegions[0].length,28);
    const M=require('../../web/scenery_manager.js');
    const validated=M.validate(catalog)[0];
    assert.deepEqual(item.terrainRegions.slice(0,item.terrainCertificates.length),validated.terrainCertificates.map(c=>c.polygon));
    assert.deepEqual(item.terrainRegions.at(-1),validated.terrainUnderlay.certificate.polygon);
    assert.equal(item.terrainRegions.length,item.terrainCertificates.length+1);
    assert.match(item.terrainCertificate.collisionSha256,/^[0-9a-f]{64}$/);
    assert.equal(item.heightOffsetM,0);
});
test('relay remains opt-in and runs on the local origin',()=>{
    const src=fs.readFileSync(path.join(root,'tool/scenery/cesium_georeference_workbench.js'),'utf8');
    assert.match(src,/get\('lod2'\)==='relay'/);
    assert.ok(src.includes("new URL('/__bkg_lod2__/lod2_4326_null.json',window.location.origin)"));
    assert.ok(src.includes('fromUrl(requestUrl,'));
});
