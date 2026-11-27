'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs');
const P=require('../../web/features/map/map_providers.js');
const bounds=P.regionalBounds;
const candidate={latitude:52.484197,longitude:13.789789};

test('Ruedersdorf lies within the documented official Berlin/Brandenburg WMS rectangle',()=>{
    assert.ok(candidate.longitude>=bounds[0]&&candidate.longitude<=bounds[2]);
    assert.ok(candidate.latitude>=bounds[1]&&candidate.latitude<=bounds[3]);
    assert.ok(bounds[1]>50&&bounds[3]<55,'regional coverage cannot become a global imagery replacement');
});

test('country-wide CC BY basemap.de WMS plus detailed Brandenburg sources',()=>{
    const adapter=P.createAdapters(C);
    const nationwide={satellite:'de_basemapde_web_raster_farbe',topographic:'de_basemapde_web_raster_farbe',relief:'de_basemapde_web_raster_combshade'};
    for(const [style,layer] of Object.entries(nationwide)){
        const providers=adapter.regionalImagery(style);
        const national=providers[0];
        assert.ok(national instanceof C.WebMapServiceImageryProvider);
        assert.equal(national.layers,layer);
        assert.equal(national.rectangle.west,C.Math.toRadians(P.germanyBounds[0]));
        assert.equal(national.rectangle.north,C.Math.toRadians(P.germanyBounds[3]));
        assert.match(national.credit.html,/CC BY 4\.0/);
        assert.match(national.credit.html,/bkg\.bund\.de/);
        assert.match(national.credit.html,/verändert/);
        assert.equal(national.credit.showOnScreen,true);
        assert.match(national.credit.html,/creativecommons.org\/licenses\/by\/4.0/);
        assert.equal(adapter.describeRegionalImagery(style).licenseName,'CC BY 4.0');
        if(style==='topographic')assert.equal(providers.length,1);
        else{
            assert.equal(providers.length,2);
            const local=providers[1];
            assert.equal(local.layers,style==='satellite'?'bebb_dop20c':'dgmshade');
            assert.equal(local.rectangle.west,C.Math.toRadians(bounds[0]));
            assert.equal(local.rectangle.north,C.Math.toRadians(bounds[3]));
            assert.match(local.credit.html,/GeoBasis-DE\/LGB/);
            assert.match(local.credit.html,/Geoportal Berlin/);
            assert.equal(local.credit.showOnScreen,false);
            assert.match(local.credit.html,/govdata.de\/dl-de\/by-2-0/);
            assert.match(adapter.describeLocalRegionalImagery(style).licenseUri,/dl-de\/by-2-0/);
        }
    }
    assert.throws(()=>adapter.regionalImagery('other'),/Unknown regional map style/);
});

test('regional WMS is remote-only and never uses Swiss offline cache data',()=>{
    assert.deepEqual(P.createAdapters(C,{cacheOnly:true}).regionalImagery('satellite'),[]);
    assert.deepEqual(P.createAdapters(C).regionalImagery('satellite',true),[]);
    assert.deepEqual(P.createAdapters(C,{regionalImagery:false}).regionalImagery('satellite'),[]);
    assert.deepEqual(P.createAdapters(C,{imagery:{}}).regionalImagery('satellite'),[]);
    const offline={cacheRoot:'https://example.invalid/offline/',prepared:{packageId:'a'.repeat(64)}};
    assert.deepEqual(P.createAdapters(C,offline).regionalImagery('satellite'),[]);
});

test('Cesium 1.145 supports a WGS84 georeferenced model matrix at the Ruedersdorf anchor',()=>{
    const pose=C.Cartesian3.fromDegrees(candidate.longitude,candidate.latitude,0);
    const matrix=C.Transforms.eastNorthUpToFixedFrame(pose);
    const inverse=C.Matrix4.inverseTransformation(matrix,new C.Matrix4());
    const local=C.Matrix4.multiplyByPoint(inverse,pose,new C.Cartesian3());
    assert.ok(C.Cartesian3.magnitude(local)<1e-5);
    assert.equal(typeof C.Model.fromGltfAsync,'function');
    // Geometry/rendering of the actual 44.2 MB Ruedersdorf GLB is NOT tested.
});
