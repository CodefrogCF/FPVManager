'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs');
const {partition,create}=require('../../web/scene_tile_loading.js');
const base='https://3d.geo.admin.ch/test/root.json?token=fixture&v=old';
function tree(depth=4,width=4){
    let index=0;
    function node(level){
        const id=index++,position=new C.Cartesian3(id%7,level,1);
        return {boundingVolume:{box:[0,0,0,40,0,0,0,40,0,0,0,40]},geometricError:128/(level+1),
            transform:C.Matrix4.pack(C.Matrix4.fromRotationTranslation(C.Matrix3.fromRotationZ(id*.07),position),[]),
            refine:level%2?'ADD':'REPLACE',extras:{id},
            ...(level===depth||id%3===0?{content:{uri:`../models/${id}.b3dm?local=${id}`,metadata:{class:'test',properties:{id}}}}:{}),
            ...(level<depth?{children:Array.from({length:width},()=>node(level+1))}:{})};
    }
    return {asset:{version:'1.0',tilesetVersion:'fixture-version',copyright:'Test source'},properties:{id:{minimum:0,maximum:100000}},root:node(0)};
}
function nodes(root){return 1+(root.children||[]).reduce((sum,child)=>sum+nodes(child),0);}
function uri(value){const u=new URL(value);u.searchParams.sort();return u.href;}
function collect(json,fragments=new Map(),resource=base){
    const list=[];const r=new C.Resource(resource);
    if(json.asset.tilesetVersion!==undefined)r.setQueryParameters({v:json.asset.tilesetVersion});
    function visit(header,parent=C.Matrix4.IDENTITY,inherited='REPLACE'){
        const transform=C.Matrix4.multiply(parent,header.transform?C.Matrix4.unpack(header.transform):C.Matrix4.IDENTITY,new C.Matrix4());
        const refine=header.refine||inherited;
        const contents=header.contents||(header.content?[header.content]:[]);
        for(const content of contents){
            const fragment=fragments.get(content.uri);
            if(fragment){visit(fragment.root,transform,refine);continue;}
            list.push({uri:uri(r.getDerivedResource({url:content.uri||content.url}).url),
                transform:C.Matrix4.pack(transform,[]),refine,error:header.geometricError,bounds:header.boundingVolume,
                extras:header.extras,metadata:content.metadata});
        }
        for(const child of header.children||[])visit(child,transform,refine);
    }
    visit(json.root);return list.sort((a,b)=>a.uri.localeCompare(b.uri));
}

test('lazy external headers retain every LOD geometry URI, query, transform and metadata field',async()=>{
    const source=tree(),unchanged=JSON.stringify(source),fragments=new Map();let yields=0,ticks=0;
    const result=await partition(source,base,{maxNodes:32,now:()=>++ticks,pause:async()=>yields++,
        makeUrl:value=>{const url='blob:fixture/'+fragments.size;fragments.set(url,value);return url;}});
    assert.notEqual(result,source);assert.ok(fragments.size>0);assert.ok(yields>0);
    assert.ok(nodes(result.root)<=32);
    for(const fragment of fragments.values()){
        assert.ok(nodes(fragment.root)<=32);assert.equal(fragment.asset.copyright,source.asset.copyright);
        assert.equal(fragment.asset.tilesetVersion,undefined,'A local fragment does not reapply the provider version');
    }
    assert.deepEqual(collect(result,fragments),collect(source));
    assert.equal(JSON.stringify(source),unchanged,'Source JSON is never mutated');
});

test('wide, deep and multiple-content trees keep bounded fragments and exact transforms',async()=>{
    for(const source of [tree(1,600),tree(80,1),tree(3,5)]){
        source.root.contents=[{uri:'first.glb'},{uri:'second.glb'},{uri:'data:application/octet-stream;base64,AAE='}];delete source.root.content;
        const fragments=new Map(),result=await partition(source,base,{maxNodes:16,
            makeUrl:value=>{const url='blob:fixture/'+fragments.size;fragments.set(url,value);return url;}});
        assert.ok(nodes(result.root)<=16);
        for(const fragment of fragments.values())assert.ok(nodes(fragment.root)<=16);
        assert.deepEqual(collect(result,fragments),collect(source));
    }
});

test('small, implicit and unsupported trees preserve ordinary Cesium loading; cancellation yields promptly',async()=>{
    for(const source of [tree(1,2),{...tree(),root:{implicitTiling:{},boundingVolume:{region:[0,0,1,1,0,1]}}}]){
        assert.equal(await partition(source,base,{makeUrl(){throw Error('must not be used');}}),source);
    }
    const controller=new AbortController();let ticks=0;
    await assert.rejects(partition(tree(),base,{now:()=>++ticks,signal:controller.signal,
        pause:async()=>controller.abort(),makeUrl:()=>''}),{name:'AbortError'});
});

test('actual pinned Cesium tile construction retains content bounds, resource versions and world matrices',async()=>{
    const source=tree(3,4),fragments=new Map();
    source.root.transform=C.Matrix4.pack(C.Transforms.eastNorthUpToFixedFrame(C.Cartesian3.fromDegrees(8.4,46.7,1000)),[]);
    const result=await partition(source,base,{maxNodes:16,makeUrl:data=>{
        const url='blob:fixture/'+fragments.size;fragments.set(url,data);return url;}});
    function construct(json,parts){
        const tileset=new C.Cesium3DTileset({});tileset._basePath=base;
        const resource=new C.Resource(base),root=tileset.loadTileset(resource,json),values=[];
        tileset._root=root;
        function visit(tile,currentResource){
            const content=tile._header.content,fragment=content&&parts.get(content.uri);
            if(fragment){
                const next=currentResource.getDerivedResource({url:content.uri});
                const child=tileset.loadTileset(next,fragment,tile);visit(child,next);return;
            }
            if(content){const sphere=tile.contentBoundingVolume.boundingSphere;
                values.push({uri:uri(tile._contentResource.url),matrix:C.Matrix4.pack(tile.computedTransform,[]),
                    center:C.Cartesian3.pack(sphere.center,[]),radius:sphere.radius,refine:tile.refine,error:tile.geometricError});}
            for(const child of tile.children)visit(child,currentResource);
        }
        try{visit(root,resource);return values.sort((a,b)=>a.uri.localeCompare(b.uri));}finally{tileset.destroy();}
    }
    assert.deepEqual(construct(result,fragments),construct(source,new Map()));
});

function fixture(){
    const calls=[];
    const factory={externalTileset:(tileset,tile,resource,json)=>{calls.push(json);return {json};}};
    const original=factory.externalTileset;
    const runtime={Resource:C.Resource,RequestState:C.RequestState,Cesium3DTileContentFactory:factory,Cesium3DTileset:{
        async fromUrl(){return {destroyed:false,destroy(){this.destroyed=true;},isDestroyed(){return this.destroyed;}};}}};
    return {runtime,factory,original,calls};
}

test('only owned scene layers use local headers; versioned fragments and cleanup work with actual Cesium resources',async()=>{
    const f=fixture(),getUrl=C.Resource.prototype.getUrlComponent,fetchBuffer=C.Resource.prototype.fetchArrayBuffer;
    const loader=create(f.runtime),tile=await loader.load(base,{});
    try{
        const source=tree(),content=await f.factory.externalTileset(tile,{},new C.Resource(base),source);
        assert.ok(nodes(content.json.root)<=64);assert.ok(loader.status().prepared>0);
        let proxy=content.json.root;while(!proxy.content?.uri?.startsWith('fpv-scene-fragment:'))proxy=proxy.children[0];
        const resource=new C.Resource(base).getDerivedResource({url:proxy.content.uri});
        assert.equal(resource.url,proxy.content.uri,'Provider query parameters do not corrupt local fragment URLs');
        const fragment=JSON.parse(new TextDecoder().decode(await resource.clone().fetchArrayBuffer()));
        assert.ok(fragment.root);
        assert.equal((await f.factory.externalTileset(tile,{},resource,fragment)).json,fragment);
        tile.destroy();
        await assert.rejects(resource.fetchArrayBuffer(),/released/);
        const plain={asset:{version:'1.0'},root:{boundingVolume:{sphere:[0,0,0,1]},geometricError:0}};
        const unowned=await f.factory.externalTileset({}, {},new C.Resource(base),plain);
        assert.equal(unowned.json,plain);
    }finally{if(!tile.isDestroyed())tile.destroy();loader.dispose();}
    assert.equal(loader.status().liveFragments,0);assert.equal(f.factory.externalTileset,f.original);
    assert.equal(C.Resource.prototype.getUrlComponent,getUrl);
    assert.equal(C.Resource.prototype.fetchArrayBuffer,fetchBuffer);
});

test('concurrent scene owners restore hooks only after disposal and abort unfinished header preparation',async()=>{
    const f=fixture(),a=create(f.runtime),b=create(f.runtime),tile=await b.load(base,{});
    a.dispose();assert.notEqual(f.factory.externalTileset,f.original);
    const promise=f.factory.externalTileset(tile,{},new C.Resource(base),tree(6,4));
    b.dispose();await assert.rejects(promise,{name:'AbortError'});
    assert.equal(b.status().liveFragments,0);assert.equal(f.factory.externalTileset,f.original);
    tile.destroy();
});
