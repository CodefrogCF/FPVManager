#!/usr/bin/env node
'use strict';
/* CI-safe synthetic protocol checks + optional explicit local JSON report. */
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { validateReport, writeJson } = require('./performance_report.cjs');
const root = path.resolve(__dirname, '..');
const baseline = require('./performance_ci_baselines.json');

function runJson(script, args = []) {
  const stdout = execFileSync(process.execPath, [path.join(root, script), ...args], {
    cwd: root, encoding: 'utf8', timeout: 120000, maxBuffer: 1024 * 1024,
    env: { ...process.env, CI: 'true' },
  });
  return JSON.parse(stdout);
}
function verify(bridge, scene, rules = baseline) {
  const failures = [];
  const test = (label, predicate) => {
    if (!predicate) failures.push(label);
  };
  test('bridge feature count', bridge.features === rules.bridge.features);
  test('bridge payload large enough', bridge.jsonCharacters >= rules.bridge.minimumJsonCharacters);
  test('compressed payload smaller than JSON', bridge.gzipBase64Characters / bridge.jsonCharacters <= rules.bridge.maxGzipToJsonCharactersRatio);
  test('compressed bridge frame reduction', bridge.predictedNativeFrameCalls?.reductionPct >= rules.bridge.minimumCompressionFrameReductionPct);
  test('bridge frame counts positive', bridge.predictedNativeFrameCalls?.gzipBase64 > 0 && bridge.predictedNativeFrameCalls?.json > 0);
  test('bridge decode completed', Number.isFinite(bridge.bridgeDecodeAndParseMs) && Number.isFinite(bridge.jsonParseMs));
  test('Cesium import explicitly not measured', typeof bridge.cesiumImportMs === 'string' && bridge.cesiumImportMs.includes('not measured'));
  test('scene fixture synthetic', scene.fixture === 'synthetic');
  test('scene frame count', scene.frames === rules.scene.frames);
  test('scene repeat command count', scene.repeatCommands === rules.scene.repeatCommands);
  for (const [key, expected] of Object.entries(rules.scene.stablePhase)) {
    test(`scene stable ${key}`, scene.stablePhase?.[key] === expected);
  }
  test('scene responds to camera-height crossing', scene.heightCrossingShowWrites >= rules.scene.minHeightCrossingShowWrites);
  for (const [key, expected] of Object.entries(rules.scene.resources)) {
    test(`scene resources ${key}`, scene.resources?.[key] === expected);
  }
  return failures;
}
function reports(bridge, scene, time = new Date().toISOString()) {
  const common = { schemaVersion: 1, kind: 'synthetic', platform: 'node', recordedAtUtc: time,
    datasetBytes: null, conditions: { renderer: 'none', network: 'offline' } };
  const items = [
    { ...common, scenario: 'bridge-transfer', featureCount: bridge.features,
      metrics: { jsonEncodeMs: bridge.encodeJsonMs, bridgeRoundTripMs: bridge.bridgeDecodeAndParseMs,
        jsParseMs: bridge.jsonParseMs },
      syntheticFixture: { jsonCharacters: bridge.jsonCharacters,
        gzipBase64Characters: bridge.gzipBase64Characters,
        jsonFrames: bridge.predictedNativeFrameCalls.json,
        gzipFrames: bridge.predictedNativeFrameCalls.gzipBase64,
        gzipReductionPct: bridge.predictedNativeFrameCalls.reductionPct } },
    { ...common, scenario: 'scene-scheduling', featureCount: null,
      metrics: {}, syntheticFixture: { frames: scene.frames, repeatCommands: scene.repeatCommands,
        elapsedMs: scene.elapsedMs, stablePhase: scene.stablePhase,
        heightCrossingShowWrites: scene.heightCrossingShowWrites,
        tilesetResources: scene.resources } },
  ];
  for (const item of items) validateReport(item);
  return items;
}
function parseArgs(args) {
  const options = { check: false, out: null };
  for (const arg of args) {
    if (arg === '--check') options.check = true;
    else if (arg.startsWith('--out=')) options.out = arg.slice('--out='.length);
    else throw new Error(`Unknown option ${arg}. Usage: node tool/performance_suite.cjs [--check] [--out=local-file.json]`);
  }
  if (!options.check && !options.out) throw new Error('Use --check for CI or --out=... for explicit local export');
  return options;
}
function main(args) {
  const options = parseArgs(args);
  const bridge = runJson('tool/benchmark_globe_transfer.cjs');
  const scene = runJson('tool/benchmark_scene_scheduling.cjs', [String(baseline.scene.frames)]);
  const failures = verify(bridge, scene);
  if (failures.length) {
    for (const failure of failures) console.error(`FAIL: ${failure}`);
    process.exitCode = 1;
    return;
  }
  const result = {
    schemaVersion: 1,
    purpose: 'synthetic protocol regression only',
    ciCorrectnessChecks: 'passed',
    reports: reports(bridge, scene),
    limitations: [
      'Timings are observed but never CI pass/fail thresholds.',
      'No network/WebView/Cesium GPU or physical-device execution.',
      'RSS, GPU heap, frame pacing, startup and user data are not measured.',
    ],
  };
  if (options.out) writeJson(options.out, result);
  console.log(`FPVManager synthetic CI invariants passed (bridge=${bridge.features} features, scene=${scene.frames} frames).`);
  if (options.out) console.log(`Local report: ${options.out}`);
}
if (require.main === module) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(error.stack ?? String(error)); process.exitCode = 1; }
}
module.exports = { verify, reports, parseArgs };
