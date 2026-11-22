'use strict';

const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const probeFile = join(__dirname, '../../tool/scenery/cesium_glb_probe.html');
const probeHtml = readFileSync(probeFile, 'utf8');
const scriptMatch = probeHtml.match(/<script>\s*(\(async\(\)=>\{[\s\S]*?\}\)\(\);)\s*<\/script>/);

test('GLB probe waits for Model.ready before accessing boundingSphere', async () => {
  assert.ok(scriptMatch, 'inline Cesium GLB probe script must exist');
  let frames = 0;
  let cameraPositioned = false;
  let boundingSphereAccessCount = 0;
  const status = { textContent: '', dataset: {} };
  const sphere = { radius: 10 };
  const model = {
    ready: false,
    get boundingSphere() {
      boundingSphereAccessCount++;
      assert.equal(this.ready, true, 'boundingSphere read before scene graph initialization');
      return sphere;
    },
  };
  const stub = { show: true };
  const viewer = {
    scene: {
      globe: { ...stub }, skyBox: { ...stub }, sun: { ...stub },
      moon: { ...stub }, skyAtmosphere: { ...stub },
      primitives: { add(addedModel) { assert.equal(addedModel, model); } },
    },
    camera: {
      viewBoundingSphere(bs) { assert.equal(bs, sphere); cameraPositioned = true; },
      lookAtTransform() {},
    },
  };
  const Cesium = {
    VERSION: '1.145',
    Viewer: class { constructor() { return viewer; } },
    Model: { async fromGltfAsync() { return model; } },
    EllipsoidTerrainProvider: class {},
    Color: { fromCssColorString() { return {}; } },
    Cartesian3: { fromDegrees() { return {}; } },
    Transforms: { eastNorthUpToFixedFrame() { return {}; } },
    HeadingPitchRange: class {},
    Math: { toRadians(value) { return value; } },
    Matrix4: { IDENTITY: {} },
  };
  const context = {
    Cesium,
    window: { Cesium },
    document: {
      getElementById() { return status; },
      createElement() { return { getContext() { return { VERSION: 1, getParameter() { return 'Mock WebGL'; } }; } }; },
    },
    URLSearchParams,
    location: { search: '' },
    performance: { now() { return frames * 16; } },
    requestAnimationFrame(callback) {
      setImmediate(() => { frames++; model.ready = frames >= 3; callback(); });
    },
    setTimeout(callback) { setImmediate(callback); },
    console: { log() {}, error(message) { throw message; } },
  };
  await vm.runInNewContext(scriptMatch[1], context, { timeout: 1000 });
  assert.ok(frames >= 3, 'probe must wait for render frames');
  assert.equal(boundingSphereAccessCount, 1);
  assert.equal(cameraPositioned, true);
  assert.equal(status.dataset.code, 'success', status.textContent);
});
