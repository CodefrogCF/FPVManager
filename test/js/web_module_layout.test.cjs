'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../..');
const web = path.join(root, 'web');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const scripts = html => [...html.matchAll(/<script\s+src="([^"]+)"/g)].map(match => match[1]);
const assets = new Set([...read('pubspec.yaml').matchAll(/^\s+-\s+(web\/[^\s#]+)\s*$/gm)].map(match => match[1]));
const found = asset => fs.statSync(path.join(web, asset)).isFile();

// These are classic scripts: their execution order is part of the renderer's
// public/global API. Keep dependencies before their consumers when adding modules.
const expectedOrder = require('../fixtures/web_globe_script_order.json');

test('globe keeps the declared classic-script dependency loading order', () => {
  const current = scripts(read('web/globe.html'));
  assert.deepEqual(current.map(name => path.posix.basename(name)), expectedOrder);
  for (const script of current) {
    assert.ok(found(script), `Missing globe script: ${script}`);
    if (script.startsWith('cesium/')) continue; // Registered as a Cesium directory.
    assert.ok(assets.has(`web/${script}`), `Missing native Flutter asset registration: ${script}`);
  }
});

test('all moved CommonJS dependencies resolve without legacy root shims', () => {
  const features = [path.join(web, 'core'), path.join(web, 'features')];
  let checked = 0;
  const visit = folder => {
    for (const item of fs.readdirSync(folder, {withFileTypes: true})) {
      const full = path.join(folder, item.name);
      if (item.isDirectory()) {visit(full); continue;}
      if (!item.name.endsWith('.js')) continue;
      checked++;
      const source = fs.readFileSync(full, 'utf8');
      for (const match of source.matchAll(/\brequire\s*\(\s*['"](\.{1,2}\/[^'"]+)['"]\s*\)/g)) {
        assert.ok(fs.existsSync(path.resolve(path.dirname(full), match[1])),
          `${path.relative(root, full)}: missing require ${match[1]}`);
      }
    }
  };
  for (const folder of features) visit(folder);
  assert.equal(checked, 64);
});

test('offline preparation HTML and workers resolve moved helpers from web root', () => {
  for (const script of scripts(read('web/offline_preparation.html'))) {
    assert.ok(found(script), `Offline preparation HTML script missing: ${script}`);
    assert.ok(assets.has(`web/${script}`), `Offline preparation helper not bundled: ${script}`);
  }
  for (const entry of ['web/offline_preparation_worker.js','web/offline_service_worker.js']) {
    const worker = read(entry);
    const deps = [...worker.matchAll(/['"]((?:features\/|vendor\/|offline_)[^'"+]+\.js)['"]/g)]
      .map(match => match[1]);
    assert.ok(deps.length >= 1, `Expected worker dependencies in ${entry}`);
    for (const dep of deps) {
      assert.ok(found(dep), `${entry}: missing importScripts dependency ${dep}`);
      assert.ok(dep.startsWith('vendor/') || assets.has(`web/${dep}`) || dep === 'offline_maps.js',
        `${entry}: worker helper not registered: ${dep}`);
    }
  }
});

test('browser smoke pages only load scripts at existing web-root URLs', () => {
  for (const name of fs.readdirSync(path.join(root, 'test/web')).filter(x => x.endsWith('.html'))) {
    const html = read(`test/web/${name}`);
    for (const script of scripts(html)) {
      if (!script.startsWith('/') || script === '/prepared-storage-test.js') continue;
      // Smoke fixture scripts are served by tool/browser/serve_globe_smoke.py.
      assert.ok(found(script.slice(1)), `${name}: missing script ${script}`);
    }
  }
});
