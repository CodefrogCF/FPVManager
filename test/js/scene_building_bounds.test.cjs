const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs');
const {partition,create,encloseRegion,encloseTileAncestors}=require('../../web/scene_tile_loading.js');
const {perspectiveFov}=require('../../web/flight_rendering.js');
// Published region headers from the official swisstopo hall tile near the
// reported point. No building geometry or imagery is bundled in this test.
const cell=[.14376106001478595,.8293753759569198,.14379968900662826,.8293922831941433,345.3171000000002,369.8355999998748];
const content=[.1437598771569566,.8293690718152033,.1438054013591323,.8294009300094617,345.3171000000002,369.8355999998748];
const bounds=region=>({region:[...region]});
const source=()=>({asset:{version:'1.0'},geometricError:100,root:{boundingVolume:bounds(cell),geometricError:100,
    children:[{boundingVolume:bounds(cell),geometricError:0,
        content:{uri:'hall.b3dm',boundingVolume:bounds(content)}}]}});
function construct(json){
    const tileset=new C.Cesium3DTileset({}),resource=new C.Resource('https://example.test/tileset.json');
    tileset._root=tileset.loadTileset(resource,json);return tileset;
}
function view(fov,aspect,heading,pitch,height){
    const eye=C.Cartesian3.fromDegrees(8.239163,47.521022,height),matrix=C.Transforms.eastNorthUpToFixedFrame(eye);
    const h=heading*Math.PI/180,p=pitch*Math.PI/180;
    const direction=C.Matrix4.multiplyByPointAsVector(matrix,new C.Cartesian3(Math.sin(h)*Math.cos(p),Math.cos(h)*Math.cos(p),Math.sin(p)),new C.Cartesian3());
    const up=C.Matrix4.multiplyByPointAsVector(matrix,new C.Cartesian3(-Math.sin(h)*Math.sin(p),-Math.cos(h)*Math.sin(p),Math.cos(p)),new C.Cartesian3());
    return new C.PerspectiveFrustum({aspectRatio:aspect,fov:perspectiveFov(fov,aspect),near:.1,far:5000}).computeCullingVolume(eye,direction,up);
}

test('small explicit trees enclose overhanging content and children without changing source headers or payloads',async()=>{
    const original=source(),unchanged=JSON.stringify(original);let expanded=0;
    const result=await partition(original,'https://example.test/tileset.json',{
        makeUrl(){throw Error('Small repaired trees do not need external fragments');},onBoundsExpanded:n=>expanded+=n});
    assert.deepEqual(result.root.boundingVolume.region,content);
    assert.deepEqual(result.root.children[0].boundingVolume.region,content);
    assert.equal(result.root.children[0].content.uri,'https://example.test/hall.b3dm');
    assert.deepEqual(result.root.children[0].content.boundingVolume.region,content);
    assert.equal(expanded,2);assert.equal(JSON.stringify(original),unchanged);
    const wide=source();wide.root.children=Array.from({length:80},()=>source().root.children[0]);
    const fragments=new Map(),sliced=await partition(wide,'https://example.test/tileset.json',{maxNodes:4,
        makeUrl:json=>{const url='blob:bounds/'+fragments.size;fragments.set(url,json);return url;}});
    assert.ok(fragments.size>0);assert.deepEqual(sliced.root.boundingVolume.region,content);
    for(const fragment of fragments.values())assert.deepEqual(fragment.root.boundingVolume.region,content);
});

test('actual Cesium culling retains a hall whose grid cell is outside the 105-degree flight view',async()=>{
    const original=construct(source()),corrected=construct(await partition(source(),'https://example.test/tileset.json',{makeUrl(){}}));
    let formerlyCulled=0,outside=0;
    try{
        for(const aspect of [16/9,9/16])for(const fov of [90,105,120])for(const pitch of [-20,0,10])
            for(const height of [360,375])for(let heading=-180;heading<180;heading+=2){
                const volume=view(fov,aspect,heading,pitch,height),tile=original.root.children[0];
                const visible=volume.computeVisibility(tile.contentBoundingVolume)!==C.Intersect.OUTSIDE;
                if(visible){
                    if(volume.computeVisibility(tile.boundingVolume)===C.Intersect.OUTSIDE)formerlyCulled++;
                    assert.notEqual(volume.computeVisibility(corrected.root.boundingVolume),C.Intersect.OUTSIDE);
                    assert.notEqual(volume.computeVisibility(corrected.root.children[0].boundingVolume),C.Intersect.OUTSIDE);
                }else if(volume.computeVisibility(corrected.root.boundingVolume)===C.Intersect.OUTSIDE)outside++;
            }
        for(let heading=-180;heading<180;heading++)if(view(105,16/9,heading,75,1000)
            .computeVisibility(corrected.root.boundingVolume)===C.Intersect.OUTSIDE)outside++;
        assert.ok(formerlyCulled>100,'The original headers reproduce premature edge culling');
        assert.ok(outside>100,'Ordinary offscreen culling remains active');
    }finally{original.destroy();corrected.destroy();}
});

test('late external content refreshes cached ancestor volumes even through an unchanged intermediate header',()=>{
    const json=source();json.root.children[0].boundingVolume=bounds(content);
    const unchanged=JSON.stringify(json),tileset=construct(json),parent=tileset.root,proxy=parent.children[0];
    const oldRadius=parent.boundingSphere.radius;
    try{
        assert.equal(encloseTileAncestors(proxy,content),1,'Already-correct proxy still repairs its too-small parent');
        assert.deepEqual(parent._header.boundingVolume.region,content);
        assert.ok(parent.boundingSphere.radius>oldRadius);
        const radius=parent.boundingSphere.radius;parent.updateTransform(C.Matrix4.IDENTITY);
        assert.equal(parent.boundingSphere.radius,radius,'Cached volume stays corrected without a transform change');
        assert.equal(parent._updatedVisibilityFrame,-1);
        assert.equal(encloseTileAncestors(proxy,content),0,'Repeated external updates do not rebuild unchanged bounds');
        assert.equal(JSON.stringify(json),unchanged,'Source header objects remain immutable');
    }finally{tileset.destroy();}
});

test('region repair only grows valid global extents and preserves unsupported volumes',()=>{
    const outer=[.1,.8,.2,.9,0,100],inner=[.11,.81,.19,.89,1,99];
    assert.equal(encloseRegion(outer,inner),outer);
    assert.deepEqual(encloseRegion(outer,[.09,.79,.21,.91,-5,110]),[.09,.79,.21,.91,-5,110]);
    for(const other of [undefined,[],[NaN,.8,.2,.9,0,100],[.2,.8,.1,.9,0,100],[-4,.8,.2,.9,0,100]])
        assert.equal(encloseRegion(outer,other),outer);
    assert.equal(encloseRegion(undefined,inner),undefined);
});

test('halls retain corrected culling bounds when local header fragments reach their memory cap',async()=>{
    const factory={externalTileset:(_tileset,_tile,_resource,json)=>({json})};
    const runtime={Resource:C.Resource,RequestState:C.RequestState,Cesium3DTileContentFactory:factory,Cesium3DTileset:{
        async fromUrl(){return {destroy(){},isDestroyed:()=>false};}}};
    const loader=create(runtime,{headerBudgetBytes:1}),owner=await loader.load('https://example.test/tileset.json',{});
    const original=source();original.root.children=Array.from({length:80},()=>source().root.children[0]);
    try{
        const result=await factory.externalTileset(owner,{},new C.Resource('https://example.test/tileset.json'),original);
        assert.equal(result.json.root.children.length,80);
        assert.deepEqual(result.json.root.boundingVolume.region,content);
        assert.deepEqual(result.json.root.children[0].boundingVolume.region,content);
        assert.equal(loader.status().liveFragments,0);assert.equal(loader.status().liveBytes,0);
        assert.equal(original.root.boundingVolume.region[0],cell[0]);
    }finally{owner.destroy();loader.dispose();}
});
