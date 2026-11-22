'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const M=require('../../web/scenery_manager.js');
const catalog=require('../../web/assets/scenery/catalog.json');

// The normal release must align the local plant with the active terrain too,
// not only in the opt-in BKG 3D beta test build.
test('Ruedersdorf: default release aligns the scenery against its terrain provider',()=>{
    const source=fs.readFileSync(path.join(__dirname,'../../web/globe.js'),'utf8');
    assert.match(source,/terrainKey:\(\)=>!regionalTerrainChanging&&terrainManager\.status\(\)\.state==='ready'\?terrainManager\.provider:null/);
    assert.doesNotMatch(source,/terrainKey:\(\)=>regionalTerrain&&/);
    const item=M.validate(catalog)[0];
    const localGround=item.groundReferenceLocalUp;
    assert.equal(typeof localGround,'number');
    const referenceHeight=82;
    const alignment=M.terrainAligned(item,referenceHeight);
    assert.ok(Math.abs(alignment.ellipsoidHeightM+localGround*item.alignment.scale-referenceHeight)<1e-8);
    assert.equal(alignment.longitude,item.alignment.longitude);
    assert.equal(alignment.latitude,item.alignment.latitude);
});

test('BKG beta LoD2 remains explicitly opt-in in Flutter release configuration',()=>{
    const source=fs.readFileSync(path.join(__dirname,'../../lib/features/globe/globe_page_path.dart'),'utf8');
    assert.match(source,/const bool\.fromEnvironment\('FPV_REGIONAL_3D_TEST'\)/);
    const build=fs.readFileSync(path.join(__dirname,'../../tool/build_android_ruedersdorf_test.ps1'),'utf8');
    assert.match(build,/flutter build apk --release --dart-define=FPV_REGIONAL_3D_TEST=true/);
    assert.match(build,/check_release_artifacts\.py --apk/);
});

test('a changed real terrain provider recalibrates placement without moving the site horizontally',async()=>{
    class Matrix4{}
    Matrix4.fromRotationTranslation=x=>x;
    Matrix4.multiply=(a,b)=>({a,b});
    const C={Cartesian3:{fromDegrees:(...v)=>v},Transforms:{eastNorthUpToFixedFrame:x=>x},
        Matrix3:{fromRotationZ:x=>x},Matrix4,Math:{toRadians:x=>x*Math.PI/180},
        Color:class{},Credit:class{}};
    const models=[];
    const viewer={scene:{primitives:{add:x=>models.push(x),remove:x=>{const at=models.indexOf(x);if(at>=0)models.splice(at,1);}},
        preUpdate:{addEventListener:()=>()=>{}},requestRender(){}},cesiumWidget:{creditDisplay:{addStaticCredit(){},removeStaticCredit(){}}}};
    let provider={id:'standard'};const samples=[];
    const model={ready:true,destroy(){}};
    const mgr=M.create(C,viewer,{
        fetchCatalog:async()=>catalog,position:()=>({...catalog.sceneries[0].alignment,height:100}),
        modelFactory:async()=>model,collisionFactory:async()=>{throw Error('Collision not needed');},
        terrainKey:()=>provider,
        sampleGround:async()=>{const h=provider.id==='standard'?78:84;samples.push([provider.id,h]);return h;},
    });
    const flush=()=>new Promise(resolve=>setImmediate(resolve));
    try{
        await mgr.initialize();await flush();mgr.tick(true);await flush();
        const standard=mgr.snapshot()[0];
        assert.equal(standard.heightState,'adjusted');
        assert.equal(standard.groundHeightM,78);
        assert.equal(standard.effectiveAlignment.longitude,standard.alignment.longitude);
        assert.equal(standard.effectiveAlignment.latitude,standard.alignment.latitude);
        provider={id:'bkg'};
        mgr.tick(true);await flush();
        const beta=mgr.snapshot()[0];
        assert.equal(beta.heightState,'adjusted');
        assert.equal(beta.groundHeightM,84);
        assert.ok(Math.abs(beta.effectiveAlignment.ellipsoidHeightM-standard.effectiveAlignment.ellipsoidHeightM-6)<1e-7);
        assert.deepEqual(samples,[['standard',78],['bkg',84]]);
    }finally{mgr.dispose();}
});
