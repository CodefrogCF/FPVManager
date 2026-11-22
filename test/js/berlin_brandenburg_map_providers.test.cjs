'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs');
const P=require('../../web/map_providers.js');
const bounds=P.regionalBounds;
const candidate={latitude:52.484197,longitude:13.789789};

test('Ruedersdorf lies within the documented official Berlin/Brandenburg WMS rectangle',()=>{
    assert.ok(candidate.longitude>=bounds[0]&&candidate.longitude<=bounds[2]);
    assert.ok(candidate.latitude>=bounds[1]&&candidate.latitude<=bounds[3]);
    assert.ok(bounds[1]>50&&bounds[3]<55,'regional coverage cannot become a global imagery replacement');
});

test('regional map styles use the documented WMS layers in EPSG:3857',()=>{
    const adapter=P.createAdapters(C);
    const expected={satellite:['dop20c','bebb_dop20c'],topographic:['basemapde-bebb_2025','basemapde_farbe_2025'],relief:['dgm','dgmshade']};
    for(const [style,[service,layer]] of Object.entries(expected)){
        const [image]=adapter.regionalImagery(style);
        assert.ok(image instanceof C.WebMapServiceImageryProvider);
        assert.equal(image.layers,layer);
        assert.match(image._resource.url,new RegExp('mapproxy/'+service+'/service/wms'));
        assert.match(image._resource.url,/crs=EPSG%3A3857/);
        assert.equal(image._resource.url.includes('transparent=true'),true);
        assert.equal(image.rectangle.west,C.Math.toRadians(bounds[0]));
        assert.equal(image.rectangle.north,C.Math.toRadians(bounds[3]));
        assert.match(image.credit.html,/GeoBasis-DE\/LGB/);
        assert.match(image.credit.html,/Geoportal Berlin/);
        assert.match(adapter.describeRegionalImagery(style).licenseUri,/dl-de\/by-2-0/);
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
