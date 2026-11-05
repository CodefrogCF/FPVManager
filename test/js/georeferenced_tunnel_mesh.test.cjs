'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fixture = require('../../docs/examples/tunnel_georeferenced_trimesh_v2_demo.json');
const T = require('../../web/scene_environment.js').FPVTunnelFlythrough;
const clone = x => JSON.parse(JSON.stringify(x));
const p = (lon=8.20005, latitude=46.8, height=502.5) => ({longitude:lon,latitude,height});
function cesiumMock(){
    const added=[],removed=[];
    class Geometry{constructor(opts){Object.assign(this,opts);}}
    class Primitive{constructor(opts){Object.assign(this,opts);}}
    const C={
        Cartesian3:{fromDegrees:(lon,lat,h=0)=>({x:lon*1000,y:lat*1000,z:h})},
        Geometry,GeometryAttribute:Geometry,Primitive,GeometryInstance:Geometry,
        ComponentDatatype:{DOUBLE:1},PrimitiveType:{TRIANGLES:4},
        BoundingSphere:{fromVertices:values=>({count:values.length})},
        Color:{fromBytes:(...a)=>a},ColorGeometryInstanceAttribute:{fromColor:x=>x},
        PerInstanceColorAppearance:Geometry,
        ClippingPolygon:Geometry,
        ClippingPolygonCollection:class{constructor(o){this.polygons=o.polygons;this.length=o.polygons.length}},
    };
    C.ClippingPolygonCollection.isSupported=()=>true;
    const old={length:0},globe={clippingPolygons:old};
    const viewer={scene:{globe,primitives:{add:item=>{added.push(item);return item;},
        remove:item=>{removed.push(item);added.splice(added.indexOf(item),1);}},requestRender(){}}};
    const events=[],service=T.create(C,viewer,(type,data)=>events.push({type,...data}));
    return {C,viewer,old,added,removed,events,service};
}
test('v2 import preserves real EPSG:4979 vertices and separate collision triangle indices',()=>{
    const model=T.importGeoreferencedMesh(clone(fixture));
    assert.equal(model.kind,'georeferenced-trimesh');
    assert.equal(model.quality,'external-mesh-unverified');
    assert.equal(model.clearanceVerified,false);
    assert.equal(model.portalsVerified,false);
    assert.equal(model.canFly,false);
    assert.deepEqual(model.visualMesh.vertices[0],fixture.visualMesh.vertices[0]);
    assert.equal(T.collisionMesh(model).triangleCount,fixture.collisionMesh.triangles.length);
    const {C}=cesiumMock(),geometry=T.geometry(C,model);
    assert.equal(geometry.indices.length,fixture.visualMesh.triangles.length*3);
    assert.equal(geometry.attributes.position.values.length,fixture.visualMesh.vertices.length*3);
});
test('continuous swept sphere collides with imported walls, floor and ceiling; open ends stay passable',()=>{
    const m=T.importGeoreferencedMesh(clone(fixture));
    assert.equal(T.collision(m,p(8.20005,46.8-5/111320),p()),true,'left wall');
    assert.equal(T.collision(m,p(8.20005,46.8+5/111320),p()),true,'right wall');
    assert.equal(T.collision(m,p(8.20005,46.8,508),p()),true,'roof');
    assert.equal(T.collision(m,p(8.20005,46.8,498),p()),true,'floor');
    assert.equal(T.collision(m,p(8.19998),p(8.20003)),false,'open entrance');
    assert.equal(T.collision(m,p(8.20007),p(8.20013)),false,'open exit');
    assert.equal(T.collision(m,p(9.1,46.8),p(9.10002,46.8)),false,'distant');
});
test('independently supplied colliders are actually used rather than visual triangles',()=>{
    const doc=clone(fixture);
    doc.collisionMesh.triangles=doc.collisionMesh.triangles.slice(0,2); // floor only
    const m=T.importGeoreferencedMesh(doc);
    assert.equal(T.collisionMesh(m).triangleCount,2);
    assert.equal(T.collision(m,p(8.20005,46.8,498),p()),true,'floor collider');
    assert.equal(T.collision(m,p(8.20005,46.8,508),p()),false,'roof visual-only');
});
test('rejects missing CRS/datum/provenance, unbounded, invalid or degenerate meshes',()=>{
    for(const [edit,re] of [
        [d=>delete d.coordinateReference,/EPSG:4979/],
        [d=>d.coordinateReference='EPSG:2056',/EPSG:4979/],
        [d=>d.elevationReference='LN02',/ellipsoid/],
        [d=>d.source='',/source/],
        [d=>delete d.collisionMesh,/Collision mesh/],
        [d=>d.visualMesh.vertices[1][0]=Number.NaN,/EPSG:4979/],
        [d=>d.visualMesh.vertices[1][0]=9,/extent/],
        [d=>d.visualMesh.triangles[0]=[0,0,2],/index/],
        [d=>d.visualMesh.triangles[0]=[0,1,2+1000],/index/],
        [d=>d.visualMesh.vertices[2]=d.visualMesh.vertices[1],/degenerate/],
    ]){
        const doc=clone(fixture);edit(doc);
        assert.throws(()=>T.importGeoreferencedMesh(doc),re);
    }
    const extra=clone(fixture);extra.collisionMesh.vertices=[];
    assert.throws(()=>T.importGeoreferencedMesh(extra),/Collision mesh/);
});
test('import/render lifecycle preserves existing terrain clipping when no clipping polygons are supplied',()=>{
    const f=cesiumMock();
    assert.deepEqual(f.service.importModel(clone(fixture)),{
        ready:true,quality:'external-mesh-unverified',modelLabel:'GEOREFERENCED MESH · SOURCE NOT VERIFIED',
        sections:0,visualTriangles:8,collisionTriangles:8,canFly:false,
        portalsVerified:false,clearanceVerified:false
    });
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
    assert.equal(f.added.length,1);
    assert.equal(f.service.intersects(p(8.20005,46.8-5/111320),p()),false,'opt-in off');
    f.service.setCollisionEnabled(true);
    assert.equal(f.service.intersects(p(8.20005,46.8-5/111320),p()),true);
    assert.throws(()=>f.service.activate(),/explicit pose/);
    assert.throws(()=>f.service.firstPose(),/explicit pose/);
    f.service.stop();
    assert.equal(f.added.length,0);
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
    f.service.dispose();
});
test('invalid mesh import does not delete a previously loaded tunnel mesh',()=>{
    const f=cesiumMock();f.service.importModel(clone(fixture));
    const bad=clone(fixture);bad.coordinateReference='EPSG:2056';
    assert.throws(()=>f.service.importModel(bad),/EPSG:4979/);
    assert.equal(f.service.model.identity,fixture.identity);
    assert.equal(f.added.length,1);
});
test('explicit 3D entry/profile/flight clip required before imported mesh can be flown',()=>{
    const doc=clone(fixture);
    doc.entryPose={longitude:8.20001,latitude:46.8,height:502.5,headingRadians:Math.PI/2};
    doc.flightProfile={profile:'rectangular',sections:[
        {longitude:8.2,latitude:46.8,floorMetersWgs84:500,widthMeters:6,heightMeters:5},
        {longitude:8.2001,latitude:46.8,floorMetersWgs84:500,widthMeters:6,heightMeters:5},
    ]};
    doc.terrainClipPolygons={preview:[],flight:[[
        [8.19999,46.79995],[8.20011,46.79995],[8.20011,46.80005],[8.19999,46.80005]
    ]]};
    const f=cesiumMock(),r=f.service.importModel(doc);
    assert.equal(r.canFly,true);
    assert.equal(f.service.firstPose().heading,Math.PI/2);
    assert.equal(f.service.floorAt(p()),null,'floor only during flight');
    f.service.activate();
    assert.equal(f.service.flight,true);
    assert.equal(f.service.floorAt(p()),500);
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,1);
    f.service.stop();
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
});
test('explicit preview terrain polygons are applied and restored without leaking the original owner',()=>{
    const f=cesiumMock(),doc=clone(fixture);
    doc.terrainClipPolygons={preview:[[
        [8.19999,46.79996],[8.20002,46.79996],
        [8.20002,46.80004],[8.19999,46.80004]
    ]]};
    f.service.importModel(doc);
    assert.equal(f.viewer.scene.globe.clippingPolygons.length,1);
    f.service.stop();
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
    const bad=clone(fixture);
    bad.terrainClipPolygons={preview:[[[8.2,46.8],[8.2,46.8],[8.2,46.8]]]};
    assert.throws(()=>T.importGeoreferencedMesh(bad),/degenerate clipping polygon/);
});
test('mesh with no requested terrain cut still loads on limited WebGL devices',()=>{
    const f=cesiumMock();f.C.ClippingPolygonCollection.isSupported=()=>false;
    assert.equal(f.service.importModel(clone(fixture)).ready,true);
    assert.equal(f.viewer.scene.globe.clippingPolygons,f.old);
    f.service.dispose();
});
