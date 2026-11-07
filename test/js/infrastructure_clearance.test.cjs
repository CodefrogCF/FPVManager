'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const Environment = require('../../web/scene_environment.js');
const I = Environment.FPVInfrastructureClearance;
const T = Environment.FPVTunnelFlythrough;
const base = {
    version: 1, elevationReference: 'WGS84_ELLIPSOID',
    source: 'Local imported measured sections; independent verification pending',
    surfaces: [
        {id: 'bridge-01', kind: 'deck', name: 'Test viaduct', sourceId: 'CH-01', quality: 'surveyed',
            bottomMetersWgs84: 110, topMetersWgs84: 112, widthMeters: 6,
            centerline: [{latitude: 46.8, longitude: 8.2}, {latitude: 46.8, longitude: 8.20014}]},
        {id: 'pier-01', kind: 'support', name: 'Test pier', sourceId: 'CH-01-pier',
            bottomMetersWgs84: 95, topMetersWgs84: 112, radiusMeters: .8,
            center: {latitude: 46.8, longitude: 8.20008}}
    ]
};
const samples = (height, latitude = 46.8, start = 8.20006, end = 8.20010) => ({
    samples: [{latitude, longitude: start, height, segment: 0},
        {latitude, longitude: end, height, segment: 0}], radiusMeters: .25
});

test('surface import retains source but cannot self-verify a surveyed accuracy claim', () => {
    const input = I.validateDocument(base);
    assert.equal(input.surfaces.length, 2);
    assert.equal(input.surfaces[0].quality, 'external-unverified');
    assert.equal(input.surfaces[0].claimedQuality, 'surveyed');
    assert.equal(input.surfaces[0].source, base.source);
    assert.equal(input.surfaces[0].sourceId, 'CH-01');
    assert.throws(() => I.validateDocument({...base, elevationReference: 'LN02'}), /WGS84/);
    assert.throws(() => I.validateDocument({...base, surfaces: [...base.surfaces, base.surfaces[0]]}), /duplicated/);
    assert.throws(() => I.validateDocument({...base, surfaces: [{...base.surfaces[0], bottomMetersWgs84: null}]}), /heights/);
    assert.throws(() => I.validateDocument({...base, surfaces: Array.from({length: 49}, (_, i) => ({...base.surfaces[0], id: 'bridge-' + i}))}), /bounded/);
});

test('bridge underside, bridge top, side clearance and supports are assessed separately', () => {
    const bridge = I.validateDocument(base).surfaces;
    const below = I.analyse(samples(109.9), bridge);
    assert.ok(below.findings.some(h => h.id === 'bridge-01' && h.clearanceMeters < 0));
    assert.ok(below.findings.some(h => h.id === 'pier-01' && h.clearanceMeters < 0));
    assert.ok(I.analyse(samples(112.1), bridge).findings.some(h => h.id === 'bridge-01'));
    const clearUnder = I.analyse(samples(105, 46.8, 8.20001, 8.20003), [bridge[0]]);
    assert.equal(clearUnder.findings.length, 0);
    const aside = I.analyse(samples(110, 46.801), bridge);
    assert.equal(aside.findings.length, 0);
    assert.equal(aside.incomplete, true);
    assert.equal(aside.coverage, 'local-models-only');
});

test('unknown elevations, missing bridge meshes and out-of-range paths cannot produce a green result', () => {
    const noModel = I.analyse(samples(110), []);
    assert.equal(noModel.coverage, 'unassessed');
    assert.equal(noModel.incomplete, true);
    const missing = I.analyse(samples(null), I.validateDocument(base).surfaces);
    assert.equal(missing.findings.length, 0);
    assert.ok(missing.unknownHeightSamples > 0);
    assert.equal(missing.incomplete, true);
    const route = {samples: Array.from({length: 512}, (_, i) => ({latitude: 46.7, longitude: 8.1 + i * .0001,
        height: 100, segment: Math.floor(i / 20)})), radiusMeters: .25};
    assert.equal(I.analyse(route, []).processingLimited, true);
    assert.throws(() => I.analyse({...route, samples: [...route.samples, route.samples.at(-1)]}), /unbounded/);
});

test('tunnel side walls, floor and ceiling are advisory model boundaries, not surveyed clearance', () => {
    const model = T.importSections({version: 1, source: 'Local test model', identity: 'tunnel:1',
        elevationReference: 'WGS84_ELLIPSOID', sections: [
            {latitude: 46.8, longitude: 8.2, floorMetersWgs84: 100, heightMeters: 5, widthMeters: 6},
            {latitude: 46.8, longitude: 8.20007, floorMetersWgs84: 100, heightMeters: 5, widthMeters: 6}]});
    const center = I.analyse(samples(102.5, 46.8, 8.20002, 8.20004), [], model);
    assert.equal(center.findings.length, 0);
    const closeCeiling = I.analyse(samples(104.85, 46.8, 8.20002, 8.20004), [], model);
    assert.ok(closeCeiling.findings.some(h => h.kind === 'tunnel' && h.status === 'model-contact'));
    assert.equal(closeCeiling.findings[0].quality, 'external-unverified');
    const wall = I.analyse(samples(102.5, 46.800027, 8.20002, 8.20004), [], model);
    assert.ok(wall.findings.some(h => h.kind === 'tunnel' && h.status === 'model-contact'));
});

test('renderer owns and releases separate advisory entities; flying checks modeled bridges', () => {
    const entities = [], viewer = {scene: {requestRender() {}}, entities: {
        add(e) {entities.push(e); return e;}, remove(e) {const n = entities.indexOf(e);if (n >= 0) entities.splice(n, 1);}
    }};
    const C = {Color: {RED: 'red', ORANGE: 'orange'}, Cartesian3: {fromDegreesArrayHeights: v => v}};
    const first = I.create(C, viewer);
    assert.equal(first.replace(base).quality, 'external-unverified');
    first.setVisible(true);
    const report = first.assess(samples(109.9));
    assert.ok(report.findings.length > 0);
    assert.ok(entities.length > 0);
    assert.equal(first.collision({latitude: 46.8, longitude: 8.20006, height: 109.7},
        {latitude: 46.8, longitude: 8.20009, height: 110.1}), true);
    first.setVisible(false);
    assert.equal(entities.length, 0);
    first.dispose();
    const second = I.create(C, viewer);
    assert.equal(second.status().surfaceCount, 0);
    assert.equal(entities.length, 0);
    second.dispose();
});

test('retained tunnel model survives editor navigation for analysis but is erased on renderer reload', () => {
    const viewer = {scene: {requestRender() {}}, entities: {add: x => x, remove() {}}};
    const c = {Color: {RED: 'red', ORANGE: 'orange'}, Cartesian3: {fromDegreesArrayHeights: x => x}};
    const service = I.create(c, viewer);
    const m = T.importSections({version: 1, source: 'Local model', identity: 'candidate',
        elevationReference: 'WGS84_ELLIPSOID', sections: [
            {latitude: 46.8, longitude: 8.2, floorMetersWgs84: 100, heightMeters: 5, widthMeters: 6},
            {latitude: 46.8, longitude: 8.20007, floorMetersWgs84: 100, heightMeters: 5, widthMeters: 6}]});
    service.retainTunnel(m);
    assert.equal(service.hasUnverifiedTunnel(), true);
    const hits = service.assess(samples(104.9, 46.8, 8.20002, 8.20004));
    assert.equal(hits.findings.some(x => x.kind === 'tunnel'), true);
    service.forgetTunnel();
    assert.equal(service.hasUnverifiedTunnel(), false);
    assert.equal(service.assess(samples(104.9)).coverage, 'unassessed');
    service.dispose();
});

test('opt-in imported infrastructure collisions work independently of advisory visibility',()=>{
    const viewer={scene:{requestRender(){}},entities:{add:x=>x,remove(){}}};
    const C={Color:{RED:'red',ORANGE:'orange'},Cartesian3:{fromDegreesArrayHeights:x=>x}};
    const service=I.create(C,viewer);
    service.replace(base);
    const a={latitude:46.8,longitude:8.20006,height:110.5};
    const b={latitude:46.8,longitude:8.20009,height:110.5};
    assert.equal(service.collision(a,b),false,'hidden advisory models are not active by default');
    assert.throws(()=>service.setCollisionEnabled('true'),/Invalid/);
    service.setCollisionEnabled(true);
    assert.equal(service.collision(a,b),true,'explicit opt-in activates imported model collision');
    service.setCollisionEnabled(false);
    assert.equal(service.collision(a,b),false);
    service.dispose();
});

test('bridge volume blocks only deck and real supports, never the void below its underside',()=>{
    const v={scene:{requestRender(){}},entities:{add:x=>x,remove(){}}};
    const svc=I.create(null,v);
    svc.replace(base);svc.setCollisionEnabled(true);
    const path=(y,z)=>({latitude:46.8,longitude:y,height:z});
    assert.equal(svc.collision(path(8.20002,105),path(8.20005,105)),false,
        'free space beneath a deck is navigable');
    assert.equal(svc.collision(path(8.20006,111),path(8.20009,111)),true,
        'deck thickness is solid');
    assert.equal(svc.collision(path(8.20008,100),path(8.20008,105)),true,
        'a real pier remains solid');
    svc.dispose();
});
