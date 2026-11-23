'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const M=require('../../web/features/scenery/scenery_manager.js');
const catalog=require('../../web/assets/scenery/catalog.json');

// R32 preserves the flat Workbench preview independently from the physical
// DGM/GCG reference, and aligns Rüdersdorf to the rendered terrain at runtime.
test('R32: Ruedersdorf requires terrain alignment with official DGM1/GCG2016 root reference',()=>{
    const source=fs.readFileSync(path.join(__dirname,'../../web/globe.js'),'utf8');
    assert.match(source,/terrainKey:\(\)=>!regionalTerrainChanging&&terrainManager\.status\(\)\.state==='ready'\?terrainManager\.provider:null/);
    assert.doesNotMatch(source,/terrainKey:\(\)=>regionalTerrain&&/);
    const item=M.validate(catalog)[0];
    assert.equal(item.heightAlignmentMode,'terrain');
    assert.equal(item.requireGroundCalibration,true);
    assert.equal(item.heightCalibration.revision,'R32');
    assert.ok(Math.abs(item.alignment.ellipsoidHeightM-112.279767885956)<1e-8);
    assert.ok(Math.abs(item.alignment.ellipsoidHeightM+item.groundReferenceLocalUp*item.alignment.scale-79.8206323739)<1e-8);
    const flat=require('../../web/assets/scenery/reference_alignment.json');
    assert.equal(flat.ellipsoidHeightM,34.25);
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
    const autoCatalog=structuredClone(catalog);
    autoCatalog.sceneries[0].heightAlignmentMode='terrain';
    delete autoCatalog.sceneries[0].heightCalibration;
    const mgr=M.create(C,viewer,{
        fetchCatalog:async()=>autoCatalog,position:()=>({...catalog.sceneries[0].alignment,height:100}),
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

test('R32: scenery stays invisible until an active rendered-ground sample is applied, then follows provider',async()=>{
    class Matrix4{};
    Matrix4.fromRotationTranslation=x=>x;
    Matrix4.multiply=(a,b)=>({a,b});
    const C={Cartesian3:{fromDegrees:(...v)=>v},Transforms:{eastNorthUpToFixedFrame:x=>x},
        Matrix3:{fromRotationZ:x=>x},Matrix4,Math:{toRadians:x=>x*Math.PI/180},
        Color:class{},Credit:class{}};
    const viewer={scene:{primitives:{add(){},remove(){}},
        preUpdate:{addEventListener:()=>()=>{}},requestRender(){}},
        cesiumWidget:{creditDisplay:{addStaticCredit(){},removeStaticCredit(){}}}};
    let provider={id:'dgm5'},sampleCount=0,resume;
    const model={ready:true,destroy(){},show:true};
    const mgr=M.create(C,viewer,{
        fetchCatalog:async()=>catalog,position:()=>({...catalog.sceneries[0].alignment,height:100}),
        modelFactory:async()=>model,collisionFactory:async()=>{throw Error('Collider not required');},
        terrainKey:()=>provider,
        sampleGround:()=>{sampleCount++;return new Promise(resolve=>{resume=resolve;});},
    });
    const flush=()=>new Promise(resolve=>setImmediate(resolve));
    try{
        await mgr.initialize();await flush();mgr.tick(true);await flush();
        assert.equal(model.show,false,'DGM1 root must not be drawn against uncalibrated active BKG terrain');
        assert.equal(mgr.snapshot()[0].heightState,'pending');
        resume(41.5);await flush();
        assert.equal(model.show,true);
        assert.equal(mgr.snapshot()[0].heightState,'adjusted');
        assert.ok(Math.abs(mgr.snapshot()[0].effectiveAlignment.ellipsoidHeightM-73.959135512)<1e-7);
        provider={id:'ellipsoid'};mgr.tick(true);await flush();
        assert.equal(model.show,false,'Hide during provider switch: never expose stale altitude');
        resume(0);await flush();
        assert.equal(model.show,true);
        assert.ok(Math.abs(mgr.snapshot()[0].effectiveAlignment.ellipsoidHeightM-32.459135512)<1e-7);
        assert.equal(sampleCount,2);
    }finally{mgr.dispose();}
});

test('R32: unavailable provider sample never exposes a falsely-grounded model',async()=>{
    class Matrix4{};Matrix4.fromRotationTranslation=x=>x;Matrix4.multiply=(a,b)=>({a,b});
    const C={Cartesian3:{fromDegrees:(...v)=>v},Transforms:{eastNorthUpToFixedFrame:x=>x},
        Matrix3:{fromRotationZ:x=>x},Matrix4,Math:{toRadians:x=>x*Math.PI/180},Color:class{},Credit:class{}};
    const viewer={scene:{primitives:{add(){},remove(){}},preUpdate:{addEventListener:()=>()=>{}},requestRender(){}},
        cesiumWidget:{creditDisplay:{addStaticCredit(){},removeStaticCredit(){}}}};
    const model={ready:true,show:true,destroy(){}};
    const provider={id:'bkg'};
    const mgr=M.create(C,viewer,{fetchCatalog:async()=>catalog,
        position:()=>({...catalog.sceneries[0].alignment,height:100}),
        modelFactory:async()=>model,terrainKey:()=>provider,
        sampleGround:async()=>{throw Error('BKG terrain not resident');}});
    const flush=()=>new Promise(resolve=>setImmediate(resolve));
    try{await mgr.initialize();await flush();mgr.tick(true);await flush();
        assert.equal(model.show,false);assert.equal(mgr.snapshot()[0].heightState,'unavailable');
        assert.match(mgr.snapshot()[0].heightError,/BKG terrain not resident/);
    }finally{mgr.dispose();}
});

test('R32 migration upgrades legacy flat anchors without overriding an intentional edit',async()=>{
    class Matrix4{}
    Matrix4.fromRotationTranslation=x=>x;
    Matrix4.multiply=(a,b)=>({a,b});
    const C={Cartesian3:{fromDegrees:(...v)=>v},Transforms:{eastNorthUpToFixedFrame:x=>x},
        Matrix3:{fromRotationZ:x=>x},Matrix4,Math:{toRadians:x=>x*Math.PI/180},
        Color:class{},Credit:class{}};
    const viewer={scene:{primitives:{add(){},remove(){}},
        preUpdate:{addEventListener:()=>()=>{}},requestRender(){}},
        cesiumWidget:{creditDisplay:{addStaticCredit(){},removeStaticCredit(){}}}};
    const model={ready:true,destroy(){}};
    const mgr=M.create(C,viewer,{
        fetchCatalog:async()=>catalog,position:()=>({...catalog.sceneries[0].alignment,height:100}),
        modelFactory:async()=>model,
    });
    const item=catalog.sceneries[0];
    const flush=()=>new Promise(resolve=>setImmediate(resolve));
    try{
        await mgr.initialize();await flush();mgr.tick(true);
        for(const oldHeight of [32.25,33,34.25]){
            mgr.restoreEdits({[item.id]:{alignment:{...item.alignment,ellipsoidHeightM:oldHeight},heightOffsetM:0}});
            assert.equal(mgr.snapshot()[0].effectiveAlignment.ellipsoidHeightM,item.alignment.ellipsoidHeightM);
        }
        const intentional={...item.alignment,ellipsoidHeightM:35.5};
        mgr.restoreEdits({[item.id]:{alignment:intentional,heightOffsetM:0}});
        assert.equal(mgr.snapshot()[0].effectiveAlignment.ellipsoidHeightM,35.5);
    }finally{mgr.dispose();}
});
