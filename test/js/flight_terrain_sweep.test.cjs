'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs');
const {create,terrainSegmentIntersects}=require('../../web/flight_rendering.js');

function fixture(tiles=[]){
    const state={picks:0,publicPicks:0};
    const scene={mode:C.SceneMode.SCENE3D,mapProjection:new C.GeographicProjection(),
        globe:{ellipsoid:C.Ellipsoid.WGS84,_surface:{_tilesToRender:tiles},pick(ray,scene,result){
            state.publicPicks++;
            let best=null,distance=Infinity;
            for(const tile of tiles){
                const hit=tile.data?.pick?.(ray,scene.mode,scene.mapProjection,true);
                if(hit){const gap=C.Cartesian3.distance(ray.origin,hit);if(gap<distance){best=hit;distance=gap;}}
            }
            return best&&C.Cartesian3.clone(best,result);
        }}};
    return {viewer:{scene,camera:{}},state};
}
function ray(from,to){
    const a=C.Cartesian3.fromDegrees(from.longitude,from.latitude,from.height),
        b=C.Cartesian3.fromDegrees(to.longitude,to.latitude,to.height),
        direction=C.Cartesian3.subtract(b,a,new C.Cartesian3());
    const length=C.Cartesian3.magnitude(direction);
    return {ray:new C.Ray(a,C.Cartesian3.normalize(direction,direction)),length};
}
function contactTile(rectangle,hitAt,calls){
    return {rectangle,data:{pick(r,mode,projection,cull,result){
        assert.equal(mode,C.SceneMode.SCENE3D);assert.equal(cull,true);calls.count++;
        return hitAt==null?undefined:C.Ray.getPoint(r,hitAt,result);
    }}};
}

test('short sweeps never initialize the terrain pickers of distant visible tiles',()=>{
    const near={count:0},far={count:0};
    const tiles=[contactTile(C.Rectangle.fromDegrees(8.39,46.69,8.41,46.71),null,near)];
    for(let i=0;i<200;i++)tiles.push(contactTile(C.Rectangle.fromDegrees(8.5+i*.01,46.7,8.51+i*.01,46.71),1000,far));
    const f=fixture(tiles),from={longitude:8.4,latitude:46.7,height:1500},to={...from,height:1500.5};
    const adapter=create(C,f.viewer);
    for(let i=0;i<100;i++)assert.equal(adapter.terrainCollision(from,to),false);
    assert.equal(near.count,100);assert.equal(far.count,0);
    assert.equal(f.state.publicPicks,0);
});

test('bounded sweeps retain triangle contacts, segment limits and adjacent tile boundaries',()=>{
    const from={longitude:8.4,latitude:46.7,height:1500},to={...from,height:1501};
    const probe=ray(from,to),a={count:0},b={count:0};
    const first=contactTile(C.Rectangle.fromDegrees(8.39,46.69,8.4,46.71),null,a),
        second=contactTile(C.Rectangle.fromDegrees(8.4,46.69,8.41,46.71),.5,b);
    const f=fixture([first,second]);
    assert.equal(terrainSegmentIntersects(C,f.viewer,probe.ray,from,probe.length,new C.Cartesian3()),true);
    assert.equal(a.count,1);assert.equal(b.count,1);
    second.data=contactTile(second.rectangle,2,b).data;
    assert.equal(terrainSegmentIntersects(C,f.viewer,probe.ray,from,probe.length,new C.Cartesian3()),false);
});

test('dateline, high-latitude and underground sweeps preserve neighboring tile contacts',()=>{
    for(const [from,to,rect] of [
        [{longitude:179.999999,latitude:0,height:50},{longitude:-179.999999,latitude:0,height:50},C.Rectangle.fromDegrees(-180,-.01,-179.99,.01)],
        [{longitude:-179.999999,latitude:0,height:50},{longitude:179.999999,latitude:0,height:50},C.Rectangle.fromDegrees(179.99,-.01,180,.01)],
        [{longitude:8.4,latitude:85,height:100},{longitude:8.40001,latitude:85,height:100},C.Rectangle.fromDegrees(8.400002,84.99,8.5,85.01)],
        [{longitude:8.4,latitude:46.7,height:-100},{longitude:8.4,latitude:46.7,height:-99},C.Rectangle.fromDegrees(8.39,46.69,8.41,46.71)],
    ]){
        const probe=ray(from,to),calls={count:0},tile=contactTile(rect,probe.length/2,calls),f=fixture([tile]);
        assert.equal(terrainSegmentIntersects(C,f.viewer,probe.ray,from,probe.length,new C.Cartesian3()),true);
        assert.equal(calls.count,1);
    }
});

test('pinned Cesium triangle math agrees with the full public ray for random short sweeps',()=>{
    let seed=7;
    const random=()=>{seed=(1664525*seed+1013904223)>>>0;return seed/2**32;};
    const tiles=[];
    for(let x=0;x<12;x++)for(let y=0;y<12;y++){
        const west=8.397+x*.0005,south=46.697+y*.0005,east=west+.0005,north=south+.0005;
        const points=[[west,south],[east,south],[east,north],[west,north]].map(([lon,lat])=>
            C.Cartesian3.fromDegrees(lon,lat,1000+(lon-8.4)*12000+(lat-46.7)*18000));
        const triangles=[[0,1,2],[0,2,3]];
        tiles.push({rectangle:C.Rectangle.fromDegrees(west,south,east,north),data:{pick(r,_mode,_projection,cull,result){
            let best=Infinity;
            for(const [a,b,c] of triangles){const hit=C.IntersectionTests.rayTriangleParametric(r,points[a],points[b],points[c],cull);
                if(hit!==undefined&&hit>=0)best=Math.min(best,hit);}
            return best<Infinity?C.Ray.getPoint(r,best,result):undefined;
        }}});
    }
    const f=fixture(tiles);
    let contacts=0;
    for(let i=0;i<500;i++){
        const from={longitude:8.3975+random()*.005,latitude:46.6975+random()*.005,height:960+random()*80},
            to={longitude:from.longitude+(random()-.5)*.0002,latitude:from.latitude+(random()-.5)*.0002,height:from.height+(random()-.5)*12};
        const probe=ray(from,to),hit=f.viewer.scene.globe.pick(probe.ray,f.viewer.scene),
            expected=!!hit&&C.Cartesian3.distance(probe.ray.origin,hit)<=probe.length+.001;
        if(expected)contacts++;
        assert.equal(terrainSegmentIntersects(C,f.viewer,probe.ray,from,probe.length,new C.Cartesian3()),expected,`sweep ${i}`);
    }
    assert.ok(contacts>0,'the comparison includes real terrain contacts');
});

test('unsupported terrain internals and non-3D scenes retain the public Cesium pick',()=>{
    for(const unsupported of [f=>delete f.viewer.scene.globe._surface,f=>{f.viewer.scene.mode=C.SceneMode.SCENE2D;},
        f=>{f.viewer.scene.globe._surface._tilesToRender=[{rectangle:null}];}]){
        const f=fixture([]);unsupported(f);
        f.viewer.scene.globe.pick=(r,_scene,result)=>{f.state.publicPicks++;return C.Ray.getPoint(r,.5,result);};
        const from={longitude:8.4,latitude:46.7,height:1000},to={...from,height:1001},probe=ray(from,to);
        assert.equal(terrainSegmentIntersects(C,f.viewer,probe.ray,from,probe.length,new C.Cartesian3()),true);
        assert.equal(f.state.publicPicks,1);
    }
});
