const test = require('node:test');
const assert = require('node:assert/strict');
const { createWalker } = require('../../web/ground_navigation.js');

function setup({ sampleHeight = async () => 1000 } = {}) {
    let terrain = true, ground = 1000;
    const poses = [], restored = [], states = [];
    const walker = createWalker({ sampleHeight, renderedHeight: () => ground,
        captureCamera: () => ({ heading: 0, marker: 'original camera' }),
        applyPose: pose => poses.push(pose), restoreCamera: saved => restored.push(saved),
        isTerrainReady: () => terrain, onState: state => states.push(state) });
    return { walker, poses, restored, states,
        terrain(value) { terrain = value; }, ground(value) { ground = value; } };
}
const point = { latitude: 46.7, longitude: 8.4 };

test('walking follows changing terrain two metres above ground and permits looking upward', async () => {
    const page = setup();
    await page.walker.start(point, new AbortController().signal);
    assert.equal(page.poses.at(-1).height, 1002);
    page.walker.key('ArrowUp', true);
    page.walker.tick(0.1);
    assert.ok(page.poses.at(-1).latitude > point.latitude);
    page.ground(1025); page.walker.tick(0.1);
    assert.equal(page.poses.at(-1).height, 1027);
    page.walker.look(100, -200); page.walker.tick(0.1);
    assert.ok(page.poses.at(-1).pitch > 0);
    const before = page.walker.status().position;
    page.ground(undefined); page.walker.tick(0.1);
    assert.deepEqual(page.walker.status().position, before, 'unloaded terrain must stop translation');
    page.walker.clearKeys(); page.ground(1025); page.walker.tick(0.1);
    assert.deepEqual(page.walker.status().position, before, 'losing focus clears movement');
    page.walker.stop();
    assert.equal(page.restored.length, 1);
    assert.equal(page.restored[0].marker, 'original camera');
});

test('late terrain sampling cannot respawn after exit, cancellation or terrain failure', async () => {
    let resolve;
    const page = setup({sampleHeight: () => new Promise(done => { resolve = done; })});
    const start = page.walker.start(point, new AbortController().signal);
    page.walker.stop(); resolve(2000);
    assert.deepEqual(await start, {cancelled:true});
    assert.equal(page.walker.status().active, false);
    assert.equal(page.poses.length, 0);
    const next = setup();
    await next.walker.start(point, new AbortController().signal);
    next.terrain(false); next.walker.tick(0.1);
    assert.equal(next.walker.status().active, false);
    assert.equal(next.restored.length, 1);
    await assert.rejects(next.walker.start(point, new AbortController().signal), /terrain/);
});

test('diagonal speed and frame stalls are bounded and headings/pitch remain finite', async () => {
    const a = setup(), b = setup();
    await a.walker.start(point, new AbortController().signal);
    await b.walker.start(point, new AbortController().signal);
    a.walker.key('ArrowUp', true); b.walker.key('ArrowUp', true); b.walker.key('ArrowRight', true);
    a.walker.tick(10); b.walker.tick(0.1);
    const distance = p => Math.hypot((p.latitude - point.latitude), (p.longitude - point.longitude) * Math.cos(point.latitude * Math.PI / 180));
    assert.ok(Math.abs(distance(a.walker.status().position) - distance(b.walker.status().position)) < 1e-10);
    a.walker.look(1e4, -1e4); a.walker.tick(0.1);
    assert.ok(a.walker.status().pitch < Math.PI / 2);
    a.walker.stop(); b.walker.stop();
});
