'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { SCENARIOS, fromManualOptions, parseMetricPairs, parseLifecycleLog,
    parseSceneSnapshot, validateReport, writeJson } = require('../../tool/performance_report.cjs');
const { verify, reports } = require('../../tool/performance_suite.cjs');
const { summarize } = require('../../tool/performance_compare.cjs');
const rules = require('../../tool/performance_ci_baselines.json');
const scenarioDefinitions = require('../../docs/performance/scenarios_issue_120.json');
const issue47 = require('../../docs/performance/issue47_reference_2026-11-05.json');

test('documented scenario IDs and manual recording command stay consistent', () => {
  assert.equal(new Set(SCENARIOS).size, SCENARIOS.length);
  assert.deepEqual(new Set(scenarioDefinitions.scenarios.map(s => s.id)), new Set(SCENARIOS));
  for (const s of scenarioDefinitions.scenarios) {
    assert.ok(s.precondition && s.steps && s.record && s.safety, s.id);
  }
  const report = fromManualOptions({ scenario: 'uas-cold-http200', platform: 'android',
    cache: 'cold', network: 'wifi', 'dataset-bytes': '13494348', features: '1256',
    metrics: 'httpTotalMs=1828,bridgeRoundTripMs=979' });
  assert.equal(report.kind, 'real-device');
  assert.equal(report.datasetBytes, 13494348);
  assert.equal(report.conditions.cache, 'cold');
  assert.deepEqual(report.metrics, { httpTotalMs: 1828, bridgeRoundTripMs: 979 });
  assert.equal(validateReport(report), true);
});

test('unknown metrics, arbitrary metadata, paths and identifiers are rejected', () => {
  assert.throws(() => parseMetricPairs('userPosition=48.1'), /Unknown/);
  assert.throws(() => parseMetricPairs('httpTotalMs=1,httpTotalMs=2'), /Unknown/);
  assert.throws(() => parseMetricPairs('httpTotalMs=-1'), /Unknown/);
  assert.throws(() => fromManualOptions({ scenario: 'cold-start', platform: 'android', network: 'private-local-ssid' }), /Invalid/);
  assert.throws(() => fromManualOptions({ scenario: 'cold-start', platform: 'android', 'dataset-bytes': '1.5' }), /integer/);
  assert.throws(() => fromManualOptions({ scenario: 'unknown', platform: 'android' }), /Unknown scenario/);
});

test('lifecycle import strips arbitrary text and keeps only bounded timing summaries', () => {
  const text = [
    '[FPVManager lifecycle] phase=route-push-first-frame elapsedMs=180 count=1 durationMs=13 coord=47.0,8.0 accessToken=secret',
    '[FPVManager lifecycle] phase=route-push-first-frame elapsedMs=230 count=2 durationMs=19',
    '[FPVManager lifecycle] phase=app-resumed elapsedMs=300 count=1 durationMs=15000',
    '[FPVManager lifecycle] phase=secret-private-note elapsedMs=400 count=1 durationMs=7',
  ].join('\n');
  const parsed = parseLifecycleLog(text);
  assert.deepEqual(parsed['route-push-first-frame'], { count: 2, durationP50Ms: 19, durationP95Ms: 19, lastElapsedMs: 230 });
  assert.equal(parsed['app-resumed'].durationP50Ms, 15000);
  assert.equal(parsed['secret-private-note'], undefined);
  assert.doesNotMatch(JSON.stringify(parsed), /secret|accessToken|coord/);
});

test('scene snapshot excludes arbitrary fields and retains CPU/frames scope', () => {
  const scene = parseSceneSnapshot(JSON.stringify({
    running: false, frames: 100, renderSamples: 30, intervalSamples: 29,
    over33Ms: 4, coordinates: [47, 8], token: 'secret',
    cpuRenderMs: { p50: 4, p95: 12, max: 20, location: 'foo' },
    framePacingMs: { p50: 16, p95: 38, max: 50 },
    tilesets: { resident: 3, visible: 3, pending: 0, estimatedBytes: 2000, url: 'private' },
  }));
  assert.equal(scene.frames, 100);
  assert.equal(scene.cpuRenderMs.p95, 12);
  assert.equal(scene.tilesets.estimatedBytes, 2000);
  assert.doesNotMatch(JSON.stringify(scene), /token|secret|coordinates|private|location/);
  assert.throws(() => parseSceneSnapshot('{}'), /Invalid nonnegative/);
});

test('synthetic CI invariants gate correctness, never elapsed time', () => {
  const bridge = { features: 18000, jsonCharacters: 6009250, gzipBase64Characters: 359836,
    predictedNativeFrameCalls: { json: 64, gzipBase64: 6, reductionPct: 90.6 },
    bridgeDecodeAndParseMs: 100, jsonParseMs: 35,
    encodeJsonMs: 22, cesiumImportMs: 'not measured (no real Cesium)' };
  const scene = { fixture: 'synthetic', frames: 10000, repeatCommands: 100,
    stablePhase: { showWrites: 0, budgetWrites: 0, requests: 0, loads: 0, removes: 0 },
    heightCrossingShowWrites: 6, elapsedMs: 1000,
    resources: { resident: 3, visible: 3, pending: 0, estimatedTilesetBytes: 0 } };
  assert.deepEqual(verify(bridge, scene, rules), []);
  bridge.bridgeDecodeAndParseMs = 20000;
  scene.elapsedMs = 900000;
  assert.deepEqual(verify(bridge, scene, rules), [], 'variable CI timing must not fail');
  const snapshots = reports(bridge, scene);
  assert.ok(snapshots.every(r => r.kind === 'synthetic' && r.platform === 'node'));
  assert.equal(snapshots[0].featureCount, 18000);
  scene.stablePhase.requests = 1;
  assert.match(verify(bridge, scene, rules).join(','), /scene stable requests/);
  scene.stablePhase.requests = 0;
  bridge.features = 17999;
  assert.match(verify(bridge, scene, rules).join(','), /bridge feature count/);
});

test('explicit local output creates a new report only; never overwrites', () => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'fpv-perf-'));
  const filename = path.join(folder, 'report.json');
  try {
    assert.throws(() => writeJson(null, {}), /Explicit/);
    writeJson(filename, { kind: 'synthetic' });
    assert.equal(JSON.parse(fs.readFileSync(filename, 'utf8')).kind, 'synthetic');
    assert.throws(() => writeJson(filename, { kind: 'real-device' }), /EEXIST/);
    assert.equal(JSON.parse(fs.readFileSync(filename, 'utf8')).kind, 'synthetic');
  } finally { fs.rmSync(folder, { recursive: true, force: true }); }
});

test('Issue #47 historical real-device reference retains source labels and is not a CI threshold', () => {
  assert.equal(issue47.referenceIssue, 47);
  assert.equal(issue47.datasetBytes, 13494145);
  assert.equal(issue47.features, 1256);
  assert.equal(issue47.measurements.length, 6);
  assert.equal(issue47.measurements[0].metricsMs.httpTotalMs, 3553);
  assert.equal(issue47.measurements[1].metricsMs.httpTotalMs, 1840);
  assert.equal(issue47.measurements[2].metricsMs.httpTotalMs, 28188);
  assert.equal(issue47.measurements[4].scenario, 'uas-warm-restart-cache');
  assert.ok(!Object.hasOwn(rules, 'issue47'), 'Device/network timings must never gate CI');
  assert.ok(fs.existsSync(path.join(__dirname, '../../', issue47.source)));
});

test('normal Airspace menu contains no developer benchmark output', () => {
  const panel = fs.readFileSync(path.join(__dirname, '../../lib/features/airspace/airspace_safety_panel.dart'), 'utf8');
  assert.doesNotMatch(panel, /lastTransferMetrics|lastDownloadMetrics|benchmark.*ms|renderParseMs/);
});


test('device summaries use homogeneous conditions and do not substitute missing timings with zero', () => {
  const a = fromManualOptions({ scenario: 'uas-cold-http200', platform: 'android', network: 'wifi',
    cache: 'cold', features: '1256', metrics: 'httpTotalMs=100,bridgeRoundTripMs=30' });
  const b = { ...a, metrics: { httpTotalMs: 140 } };
  const result = summarize([a, b]);
  assert.equal(result.kind, 'real-device-summary');
  assert.equal(result.samples, 2);
  assert.equal(result.metrics.httpTotalMs.p95, 140);
  assert.equal(result.metrics.bridgeRoundTripMs.samples, 1);
  assert.equal(result.metrics.bridgeRoundTripMs.min, 30);
  assert.throws(() => summarize([a, { ...b, platform: 'windows' }]), /differ/);
  assert.throws(() => summarize([a, { ...b, kind: 'synthetic' }]), /synthetic/);
});
