'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs');
const {createTerrainMeshPicker}=require('../../web/flight_rendering.js');
const projection=new C.GeographicProjection();
const originalPick=C.TerrainMesh.prototype.pick;
const originalSceneMode=C.TerrainMesh.prototype.updateSceneMode;
function baseline(mesh,r,cull){
    originalSceneMode.call(mesh,C.SceneMode.SCENE3D);
    return originalPick.call(mesh,r,cull,C.SceneMode.SCENE3D,projection);
}

function mesh(size=25){
    const vertices=[],indices=[];
    let decodes=0;
    for(let y=0;y<size;y++)for(let x=0;x<size;x++){
        const point=C.Cartesian3.fromDegrees(8.39+x/(size-1)*.02,46.69+y/(size-1)*.02,
            1000+120*Math.sin(x/(size-1)*4)+90*Math.cos(y/(size-1)*5));
        vertices.push(point.x,point.y,point.z);
    }
    for(let y=0;y<size-1;y++)for(let x=0;x<size-1;x++){
        const a=y*size+x,b=a+1,c=a+size,d=c+1;
        indices.push(a,b,d,a,d,c);
    }
    // Real terrain meshes also contain vertical skirts, all of which must be
    // included in the accelerated picker even though they are not road faces.
    const skirtStart=vertices.length/3;
    for(let x=0;x<size;x++){
        const top=C.Cartesian3.fromArray(vertices,x*3),cart=C.Cartographic.fromCartesian(top);
        const bottom=C.Cartesian3.fromRadians(cart.longitude,cart.latitude,cart.height-80);
        vertices.push(bottom.x,bottom.y,bottom.z);
        if(x){indices.push(x-1,skirtStart+x-1,skirtStart+x,x-1,skirtStart+x,x);}
    }
    const encoding={exaggeration:1,exaggerationRelativeHeight:0,
        getExaggeratedPosition(buffer,index,result){decodes++;return C.Cartesian3.fromArray(buffer,index*3,result);}};
    const rectangle=C.Rectangle.fromDegrees(8.39,46.69,8.41,46.71);
    const result=new C.TerrainMesh(C.Cartesian3.ZERO,new Float64Array(vertices),new Uint32Array(indices),
        (size-1)**2*6,size*size,700,1300,rectangle,C.BoundingSphere.fromVertices(vertices),undefined,3,
        C.OrientedBoundingBox.fromRectangle(rectangle,700,1300),encoding,[],[],[],[]);
    return {mesh:result,decodes:()=>decodes,count:vertices.length/3};
}
function ray(lon,lat,height,targetHeight){
    const a=C.Cartesian3.fromDegrees(lon,lat,height),b=C.Cartesian3.fromDegrees(lon,lat,targetHeight);
    return new C.Ray(a,C.Cartesian3.normalize(C.Cartesian3.subtract(b,a,new C.Cartesian3()),new C.Cartesian3()));
}
function equalPoint(actual,expected,label){
    if(!expected){assert.equal(actual,undefined,label);return;}
    assert.ok(actual&&C.Cartesian3.distance(actual,expected)<1e-6,label);
}

test('cached terrain picks retain exact Cesium contacts, misses, back faces and skirts',()=>{
    // Defer Cesium's worker partitioning in Node. The baseline still runs its
    // actual mesh transform, triangle decoder and intersection implementation.
    const schedule=C.TaskProcessor.prototype.scheduleTask;
    C.TaskProcessor.prototype.scheduleTask=()=>undefined;
    const picker=createTerrainMeshPicker(C),f=mesh();
    let seed=9,hits=0,misses=0;
    const random=()=>{seed=(1664525*seed+1013904223)>>>0;return seed/2**32;};
    try{
        picker.start();
        for(let i=0;i<250;i++){
            const lon=8.388+random()*.024,lat=46.688+random()*.024;
            for(const [height,target] of [[1600,500],[500,1600]])for(const cull of [false,true]){
                const r=ray(lon,lat,height,target);
                const expected=baseline(f.mesh,r,cull);
                const actual=f.mesh.pick(r,cull,C.SceneMode.SCENE3D,projection);
                equalPoint(actual,expected,`ray ${i} cull=${cull} height=${height}`);
                expected?hits++:misses++;
            }
        }
        for(let x=1;x<24;x++){
            const top=C.Cartesian3.fromArray(f.mesh.vertices,x*3),cart=C.Cartographic.fromCartesian(top);
            const a=C.Cartesian3.fromRadians(cart.longitude,cart.latitude-.000001,cart.height-30),
                b=C.Cartesian3.fromRadians(cart.longitude,cart.latitude+.000001,cart.height-30),
                r=new C.Ray(a,C.Cartesian3.normalize(C.Cartesian3.subtract(b,a,new C.Cartesian3()),new C.Cartesian3()));
            const expected=baseline(f.mesh,r,false);
            assert.ok(expected,'the skirt ray has a contact');
            equalPoint(f.mesh.pick(r,false,C.SceneMode.SCENE3D,projection),expected,'skirt');
        }
        assert.ok(hits>100&&misses>100);
        assert.equal(picker.status().builds,1);
    }finally{picker.stop();C.TaskProcessor.prototype.scheduleTask=schedule;}
    assert.equal(C.TerrainMesh.prototype.pick,originalPick);
});

test('shared vertices are decoded once and repeated height queries reuse bounded batches',()=>{
    const picker=createTerrainMeshPicker(C),f=mesh(65),r=ray(8.4,46.7,1600,0);
    try{
        picker.start();const before=picker.status();
        for(let i=0;i<100;i++)assert.ok(f.mesh.pick(r,false,C.SceneMode.SCENE3D,projection));
        const after=picker.status();
        assert.equal(f.decodes(),f.count);
        assert.equal(after.builds-before.builds,1);
        assert.ok((after.triangleTests-before.triangleTests)/100<f.mesh.indices.length/30,
            'each query tests less than a tenth of the complete terrain mesh');
        assert.ok(after.bytes<=16*1024*1024&&after.meshes<=64);
    }finally{picker.stop();}
    assert.equal(picker.status().bytes,0);
});

test('mesh replacement, exaggeration and scene transitions invalidate decoded terrain',()=>{
    const picker=createTerrainMeshPicker(C),f=mesh(),r=ray(8.4,46.7,1600,0);
    try{
        picker.start();const before=picker.status().builds;
        f.mesh.pick(r,false,C.SceneMode.SCENE3D,projection);
        f.mesh.vertices=new Float64Array(f.mesh.vertices);
        f.mesh.pick(r,false,C.SceneMode.SCENE3D,projection);
        f.mesh.encoding.exaggeration=2;
        f.mesh.pick(r,false,C.SceneMode.SCENE3D,projection);
        f.mesh.updateExaggeration(2,0);
        f.mesh.pick(r,false,C.SceneMode.SCENE3D,projection);
        f.mesh.updateSceneMode(C.SceneMode.SCENE2D);
        f.mesh.pick(r,false,C.SceneMode.SCENE3D,projection);
        assert.equal(picker.status().builds-before,5);
    }finally{picker.stop();}
});

test('flight owners share one picker and restore Cesium only after the last flight ends',()=>{
    const a=createTerrainMeshPicker(C),b=createTerrainMeshPicker(C),f=mesh(),r=ray(8.4,46.7,1600,0);
    try{
        a.start();a.start();const activePick=C.TerrainMesh.prototype.pick;
        b.start();assert.equal(C.TerrainMesh.prototype.pick,activePick);
        a.stop();a.stop();assert.equal(C.TerrainMesh.prototype.pick,activePick);
        assert.ok(f.mesh.pick(r,false,C.SceneMode.SCENE3D,projection));
        assert.ok(b.status().bytes>0);
    }finally{a.stop();b.stop();}
    assert.equal(C.TerrainMesh.prototype.pick,originalPick);
    assert.equal(b.status().bytes,0);
});

test('cache eviction keeps memory bounded when flight crosses many terrain tiles',()=>{
    const picker=createTerrainMeshPicker(C),r=ray(8.4,46.7,1600,0);
    try{
        picker.start();const before=picker.status().evictions;
        for(let i=0;i<80;i++){
            const f=mesh(65);assert.ok(f.mesh.pick(r,false,C.SceneMode.SCENE3D,projection));
            assert.ok(picker.status().bytes<=16*1024*1024);
            assert.ok(picker.status().meshes<=64);
        }
        assert.ok(picker.status().evictions>before);
    }finally{picker.stop();}
});

test('an unsupported mesh or scene mode retains the original picker and an explicit memory limit is enforced',()=>{
    let originalCalls=0;
    class Mesh{pick(){originalCalls++;return 'original';}}
    const picker=createTerrainMeshPicker({...C,TerrainMesh:Mesh},{maxBytes:22000,maxMeshes:2});
    const r=ray(8.4,46.7,1600,0);
    try{
        picker.start();
        const unsupported=new Mesh();assert.equal(unsupported.pick(r,false,C.SceneMode.SCENE3D,projection),'original');
        const small=mesh().mesh;Object.setPrototypeOf(small,Mesh.prototype);
        assert.ok(small.pick(r,false,C.SceneMode.SCENE3D,projection));
        assert.equal(small.pick(r,false,C.SceneMode.SCENE2D,projection),'original');
        const second=mesh().mesh;Object.setPrototypeOf(second,Mesh.prototype);
        assert.ok(second.pick(r,false,C.SceneMode.SCENE3D,projection));
        assert.ok(picker.status().bytes<=22000);assert.equal(picker.status().meshes,1);
        assert.equal(picker.status().evictions,1);
        const large=mesh(65).mesh;Object.setPrototypeOf(large,Mesh.prototype);
        assert.equal(large.pick(r,false,C.SceneMode.SCENE3D,projection),'original');
        assert.equal(originalCalls,3);
    }finally{picker.stop();}
});
