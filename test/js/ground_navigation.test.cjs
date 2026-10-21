const test = require('node:test');
const assert = require('node:assert/strict');
const { createWalker, bindControls } = require('../../web/ground_navigation.js');

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

test('analog stick scales speed, normalizes combined keyboard input and clears on focus loss', async () => {
    const slow = setup(), fast = setup();
    await slow.walker.start(point, new AbortController().signal);
    await fast.walker.start(point, new AbortController().signal);
    slow.walker.stick(0.5,0); fast.walker.stick(1,0);
    slow.walker.tick(0.1); fast.walker.tick(0.1);
    const north = p => p.latitude - point.latitude;
    assert.ok(Math.abs(north(slow.walker.status().position) * 2 - north(fast.walker.status().position)) < 1e-10);
    const previous = fast.walker.status().position;
    fast.walker.clearKeys(); fast.walker.tick(0.1);
    assert.deepEqual(fast.walker.status().position,previous);
    fast.walker.stick(NaN,Infinity); fast.walker.tick(0.1);
    assert.deepEqual(fast.walker.status().position,previous);
    slow.walker.stop(); fast.walker.stop();
});

test('joystick pointer capture permits simultaneous looking and stops on cancel, blur and disposal', async () => {
    class Target {
        constructor() {this.listeners = new Map(); this.style = {};}
        addEventListener(type,fn) {if(!this.listeners.has(type))this.listeners.set(type,new Set()); this.listeners.get(type).add(fn);}
        removeEventListener(type,fn) {this.listeners.get(type)?.delete(fn);}
        fire(type,values={}) {for(const fn of this.listeners.get(type)||[])fn({button:0,pointerId:1,clientX:50,clientY:50,preventDefault(){},...values});}
        focus() {} setPointerCapture() {}
        getBoundingClientRect() {return {left:0,top:0,width:100,height:100};}
    }
    const page = setup(); await page.walker.start(point,new AbortController().signal);
    const canvas=new Target(), stick=new Target(), thumb=new Target(), panel=new Target(), host=new Target(), doc=new Target();
    panel.querySelector = selector => selector === '[data-stick]' ? stick : thumb;
    const dispose = bindControls(page.walker,canvas,panel,host,doc);
    stick.fire('pointerdown',{clientY:0}); page.walker.tick(.1);
    assert.ok(page.walker.status().position.latitude>point.latitude);
    const moved=page.walker.status().position;
    canvas.fire('pointerdown',{pointerId:2}); canvas.fire('pointermove',{pointerId:2,clientX:100,clientY:0});
    page.walker.tick(.1); assert.ok(page.walker.status().pitch>0);
    assert.notDeepEqual(page.walker.status().position,moved,'look finger must not release walking finger');
    stick.fire('pointerdown',{pointerId:3,clientX:100});
    stick.fire('pointerup',{pointerId:3});
    const beforeCancel=page.walker.status().position;
    stick.fire('pointercancel'); page.walker.tick(.1);
    assert.deepEqual(page.walker.status().position,beforeCancel);
    assert.equal(thumb.style.transform,'translate(0px, 0px)');
    stick.fire('pointerdown',{clientY:0}); host.fire('blur'); page.walker.tick(.1);
    assert.deepEqual(page.walker.status().position,beforeCancel);
    dispose.reset(); stick.fire('pointerdown',{clientY:0});
    doc.hidden=true; doc.fire('visibilitychange');
    assert.equal(page.walker.status().active,false);
    dispose(); assert.equal(stick.listeners.get('pointermove').size,0);
});
