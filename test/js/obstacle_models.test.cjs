const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const C=require('../../web/cesium/index.cjs');
const Models=require('../../web/obstacle_models.js');

test('all local models contain actual finite unit-height geometry without external dependencies',()=>{
    const names=['power-pylon','utility-pole','antenna-mast','lattice-tower','tower-crane','chimney','wind-turbine','cableway-support'];
    for(const name of names){
        const file=fs.readFileSync(path.join(__dirname,'../../web/models/obstacles',name+'.glb'));
        assert.equal(file.readUInt32LE(0),0x46546c67);
        assert.equal(file.readUInt32LE(4),2);
        assert.equal(file.readUInt32LE(8),file.length);
        const jsonLength=file.readUInt32LE(12);
        assert.equal(file.readUInt32LE(16),0x4e4f534a);
        const gltf=JSON.parse(file.toString('utf8',20,20+jsonLength));
        assert.equal(gltf.buffers.length,1);
        assert.equal(gltf.buffers[0].uri,undefined);
        assert.equal(gltf.images,undefined);
        assert.equal(gltf.nodes[0].scale,undefined);
        const binary=28+jsonLength;
        const accessor=gltf.accessors[0],view=gltf.bufferViews[accessor.bufferView];
        let bottom=Infinity,top=-Infinity;
        for(let i=0;i<accessor.count;i++){
            const p=[0,1,2].map(k=>file.readFloatLE(binary+view.byteOffset+i*12+k*4));
            assert.ok(p.every(Number.isFinite));bottom=Math.min(bottom,p[1]);top=Math.max(top,p[1]);
        }
        assert.equal(bottom,0,name);assert.equal(top,1,name);
        const normals=gltf.accessors[1],nv=gltf.bufferViews[normals.bufferView];
        assert.equal(normals.count,accessor.count);
        for(let i=0;i<normals.count;i++){
            const n=[0,1,2].map(k=>file.readFloatLE(binary+nv.byteOffset+i*12+k*4));
            assert.ok(n.every(Number.isFinite));assert.ok(Math.abs(Math.hypot(...n)-1)<1e-6);
        }
        const indices=gltf.accessors[2],iv=gltf.bufferViews[indices.bufferView];
        assert.equal(indices.count%3,0);
        assert.ok(indices.count/3<1500,'bounded low-poly mesh');
        for(let i=0;i<indices.count;i++)assert.ok(file.readUInt16LE(binary+iv.byteOffset+i*2)<accessor.count);
        // Cesium's glTF Y-up -> Z-up correction, then entity ENU placement.
        const base=C.Cartesian3.fromDegrees(8.4,46.7,500);
        const enu=C.Transforms.eastNorthUpToFixedFrame(base);
        const axis=C.Matrix3.fromRotationX(Math.PI/2);
        const localTop=C.Matrix3.multiplyByVector(axis,new C.Cartesian3(0,10,0),new C.Cartesian3());
        const worldTop=C.Matrix4.multiplyByPoint(enu,localTop,new C.Cartesian3());
        assert.ok(Math.abs(C.Cartesian3.distance(base,worldTop)-10)<1e-8);
        assert.ok(Math.abs(C.Cartographic.fromCartesian(worldTop).height-510)<1e-6);
    }
});

test('actual Cesium ModelGraphics retains metric scale and separate constant terrain positioning',()=>{
    const primitives=new C.PrimitiveCollection();
    const source=new C.CustomDataSource('test');
    const viewer={scene:{primitives,requestRender(){}}};
    const models=Models.create(C,viewer),base=C.Cartesian3.fromDegrees(8.4,46.7,500);
    const marker=source.entities.add({position:C.Cartesian3.fromDegrees(8.4,46.7,510),point:{pixelSize:7}});
    const stem=source.entities.add({polyline:{positions:[base,marker.position.getValue(C.JulianDate.now())]}});
    const entity=models.add('TRANSMISSION_LINE',10,base,source,marker,stem);
    const time=C.JulianDate.now();
    assert.equal(entity.model.scale.getValue(time),10);
    assert.equal(entity.model.minimumPixelSize.getValue(time),0);
    assert.equal(entity.model.heightReference.getValue(time),C.HeightReference.NONE);
    assert.equal(entity.model.enableVerticalExaggeration.getValue(time),false);
    assert.equal(entity.position.isConstant,true);
    const primitive={id:entity,ready:true,readyEvent:new C.Event(),errorEvent:new C.Event()};
    primitives.add(primitive);
    assert.equal(marker.point.distanceDisplayCondition.getValue(time).near,6000);
    primitive.errorEvent.raiseEvent(new Error('GPU resource unavailable'));
    assert.equal(marker.point.distanceDisplayCondition.getValue(time).near,0);
    assert.equal(entity.model.show.getValue(time),false);
    models.dispose();
    assert.equal(primitives.primitiveAdded.numberOfListeners,0);
    assert.equal(primitive.readyEvent.numberOfListeners,0);
    assert.equal(primitive.errorEvent.numberOfListeners,0);
});

test('source classification uses a fixed local asset catalog and unknown types have no assumed model',()=>{
    const mapping={TRANSMISSION_LINE:'power-pylon',POLE:'utility-pole',MAST:'antenna-mast',
        TOWER:'lattice-tower',CRANE:'tower-crane',STACK:'chimney',WINDMILL:'wind-turbine',
        CABLE_CAR:'cableway-support',CATENARY:'cableway-support'};
    for(const [type,name] of Object.entries(mapping)) assert.equal(Models.uri(type),`models/obstacles/${name}.glb`);
    for(const type of [undefined,'BUILDING','VEGETATION','OTHER','../remote','__proto__','constructor']) assert.equal(Models.uri(type),null);
});

test('removed or replaced GPU primitives restore symbols and ignore obsolete model readiness',()=>{
 const primitives=new C.PrimitiveCollection({destroyPrimitives:false}),source=new C.CustomDataSource();
 const models=Models.create(C,{scene:{primitives,requestRender(){}}});
 const base=C.Cartesian3.fromDegrees(8.4,46.7,500),time=C.JulianDate.now();
 const marker=source.entities.add({position:base,point:{pixelSize:7}}),stem=source.entities.add({polyline:{positions:[base,base]}});
 const entity=models.add('POLE',10,base,source,marker,stem);
 const primitive=()=>({id:entity,ready:false,readyEvent:new C.Event(),errorEvent:new C.Event()});
 const first=primitives.add(primitive());first.readyEvent.raiseEvent();
 assert.equal(marker.point.distanceDisplayCondition.getValue(time).near,6000);
 primitives.remove(first);
 assert.equal(marker.point.distanceDisplayCondition.getValue(time).near,0);
 assert.equal(entity.model.show.getValue(time),true,'A renderer replacement can load again');
 const second=primitives.add(primitive());first.readyEvent.raiseEvent();
 assert.equal(marker.point.distanceDisplayCondition.getValue(time).near,0);
 second.readyEvent.raiseEvent();assert.equal(marker.point.distanceDisplayCondition.getValue(time).near,6000);
 models.remove(entity);assert.equal(second.readyEvent.numberOfListeners,0);
 assert.equal(primitives.primitiveRemoved.numberOfListeners,0);models.dispose();
});
