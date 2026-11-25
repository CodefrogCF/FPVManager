const test=require('node:test'),assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const {createViewportTracker}=require('../../web/features/infrastructure/obstacle_layers.js');
const Models=require('../../web/features/infrastructure/obstacle_models.js');
const rad=Math.PI/180;
function fixture(){
    let ground=2500,rect={west:5*rad,south:44*rad,east:12*rad,north:49*rad},rectCalls=0;
    const viewer={terrainProvider:{},camera:{positionCartographic:{longitude:9.342444*rad,latitude:47.249464*rad,height:3000},
        computeViewRectangle(){rectCalls++;return rect;}},scene:{globe:{getHeight(){return ground;},ellipsoid:{}}}};
    return {viewer,track:createViewportTracker(viewer),setGround:v=>ground=v,setRect:v=>rect=v,
        get rectCalls(){return rectCalls;}};
}
const local=b=>b.west<=b.east&&b.east-b.west<=.6&&b.north-b.south<=.6;
const contains=(b,lon,lat)=>b.west<=lon&&b.east>=lon&&b.south<=lat&&b.north>=lat;

test('Säntis stays in a local camera region even when the horizon rectangle spans Switzerland',()=>{
    const p=fixture(),bounds=p.track();
    assert.equal(local(bounds),true);assert.equal(contains(bounds,9.342444,47.249464),true);
    assert.equal(p.rectCalls,0,'A nearby camera must not use the orientation-dependent horizon rectangle');
    assert.equal(Models.maximumRange,Models.rangeFor(123.5));
});

test('looking away, tile eviction and small camera translations retain the same bounded region',()=>{
    const p=fixture();p.viewer.camera.positionCartographic.height=16000;
    const first=p.track();
    p.setGround(undefined);p.setRect(null);
    for(let i=0;i<100;i++){
        p.viewer.camera.positionCartographic.longitude=(9.342444+(i%2)*.005)*rad;
        assert.deepEqual(p.track(),first);
    }
    assert.equal(local(first),true);assert.equal(p.rectCalls,0);
});

test('the padded window recenters after departure while covering the full model range',()=>{
    const p=fixture(),first=p.track();
    p.viewer.camera.positionCartographic.latitude+=5000/6378137;
    const second=p.track();assert.notDeepEqual(second,first);
    const camera=p.viewer.camera.positionCartographic;
    assert.ok(contains(second,camera.longitude/rad,(camera.latitude-Models.maximumRange/6378137)/rad));
    assert.ok(contains(second,camera.longitude/rad,(camera.latitude+Models.maximumRange/6378137)/rad));
});

test('zooming far away releases the nearby region and returning rebuilds it',()=>{
    const p=fixture(),first=p.track();p.viewer.camera.positionCartographic.height=90000;
    assert.equal(local(p.track()),false);
    p.setRect(null);assert.deepEqual(p.track(),{west:-180,south:-90,east:180,north:90});
    p.viewer.camera.positionCartographic.height=3000;assert.deepEqual(p.track(),first);
});

test('terrain-ground retention is provider-aware and does not reuse another source',()=>{
    const p=fixture();p.viewer.camera.positionCartographic.height=16000;
    assert.equal(local(p.track()),true);p.setGround(undefined);
    assert.equal(local(p.track()),true);
    p.viewer.terrainProvider={};assert.equal(local(p.track()),false);
    p.setGround(2600);assert.equal(local(p.track()),true);
});

test('navigation keeps bounded nearby data and invalid camera poses cannot generate queries',()=>{
    const p=fixture();p.viewer.camera.positionCartographic.height=90000;
    assert.equal(local(p.track(true)),true);
    p.viewer.camera.positionCartographic.latitude=NaN;assert.equal(p.track(),null);
});

test('the production viewport bridge uses the shared nearby tracker',()=>{
    const globe=readFileSync(require.resolve('../../web/globe.js'),'utf8');
    assert.ok(globe.includes('FPVObstacles.createViewportTracker(viewer)'));
    const publish=globe.slice(globe.indexOf('    function publishObstacleViewport('));
    assert.match(publish,/obstacleViewportTracker\?\.\(navigationActive\(\)\)/);
    assert.match(publish,/sendToFlutter\('obstacle-viewport',bounds\)/);
    assert.doesNotMatch(publish,/computeViewRectangle/);
});
