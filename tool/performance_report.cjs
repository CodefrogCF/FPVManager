#!/usr/bin/env node
'use strict';
/* Local, explicit, privacy-limited FPVManager #120 performance reports. */
const fs = require('node:fs');
const path = require('node:path');

const SCENARIOS = Object.freeze([
  'uas-cold-http200', 'uas-warm-http304', 'uas-warm-restart-cache', 'uas-offline-cache',
  'uas-renderer-reload', 'multi-layer-camera', 'multi-layer-simulation',
  'navigation-repeat', 'warm-resume', 'cold-start',
  'sqlite-cache', 'geojson-parse', 'bridge-transfer', 'scene-scheduling',
]);
const PLATFORMS = Object.freeze(['android', 'ios', 'windows', 'web', 'macos', 'linux', 'node']);
const METRICS = Object.freeze([
  'httpHeadersMs', 'httpBodyMs', 'httpTotalMs', 'decodeParseMs',
  'geojsonAssessmentMs', 'jsonEncodeMs', 'bridgeDispatchMs',
  'bridgeRoundTripMs', 'jsDecodeMs', 'jsParseMs', 'cesiumLoadMs',
  'firstPostRenderMs', 'timeToFirstFlutterFrameMs', 'timeToGlobeReadyMs',
  'warmResumeMs', 'navigationFirstFrameMs', 'coldStartMs',
  'framePacingP50Ms', 'framePacingP95Ms', 'framePacingMaxMs',
  'cpuRenderP50Ms', 'cpuRenderP95Ms', 'cpuRenderMaxMs',
  'sqlitePageMs', 'sqlitePruneMs', 'rssBytes', 'gpuMemoryBytes',
]);
const ENUMS = Object.freeze({
  network: ['offline', 'wifi', 'cellular', 'ethernet', 'unknown'],
  cache: ['cold', 'warm', 'offline', 'unknown'],
  graphics: ['quality', 'balanced', 'performance', 'unknown'],
  power: ['normal', 'battery-saver', 'unknown'],
  renderer: ['native-webview', 'webview2', 'browser', 'none', 'unknown'],
});
const PHASES = new Set([
  'app-start', 'first-flutter-frame', 'first-globe-ready',
  'renderer-loading', 'renderer-ready-terrain', 'renderer-ready-no-terrain',
  'resume-to-globe-ready', 'app-paused', 'app-resumed',
  'route-push-first-frame', 'route-pop-first-frame',
  'native-resume-hello-sent', 'windows-resume-hello-sent',
  'native-resume-reload', 'windows-resume-reload',
  'web-iframe-navigation',
  'native-view-created', 'native-view-disposed',
  'windows-view-created', 'windows-view-disposed',
]);
const LIMIT = 5 * 1024 * 1024;

function ensureNumber(n, key) {
  if (typeof n !== 'number' || !Number.isFinite(n) || n < 0 || n > 1e15) {
    throw new Error(`Invalid nonnegative numeric value for ${key}`);
  }
  return n;
}
function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
function percentile(values, fraction) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  return +sorted[Math.ceil((sorted.length - 1) * fraction)].toFixed(2);
}
function parseOptions(args) {
  const out = {};
  for (const arg of args) {
    if (!arg.startsWith('--') || !arg.includes('=')) throw new Error(`Expected --key=value: ${arg}`);
    const [key, ...value] = arg.slice(2).split('=');
    if (!(key in {
      scenario: 1, platform: 1, out: 1, 'dataset-bytes': 1,
      features: 1, metrics: 1, 'lifecycle-log': 1, 'scene-json': 1,
      network: 1, cache: 1, graphics: 1, power: 1, renderer: 1,
    })) throw new Error(`Unsupported option: --${key}`);
    if (Object.hasOwn(out, key)) throw new Error(`Duplicate option: --${key}`);
    out[key] = value.join('=');
  }
  return out;
}
function readLimited(file) {
  const size = fs.statSync(file).size;
  if (size > LIMIT) throw new Error('Diagnostic input exceeds 5 MiB limit');
  return fs.readFileSync(file, 'utf8');
}
function parseMetricPairs(value) {
  const metrics = {};
  if (!value) return metrics;
  for (const entry of value.split(',')) {
    const match = /^([A-Za-z][A-Za-z0-9]*)=([0-9]+(?:\.[0-9]+)?)$/.exec(entry);
    if (!match || !METRICS.includes(match[1]) || Object.hasOwn(metrics, match[1])) {
      throw new Error(`Unknown, duplicated or invalid timing metric: ${entry}`);
    }
    metrics[match[1]] = ensureNumber(Number(match[2]), match[1]);
  }
  return metrics;
}
function parseLifecycleLog(log) {
  const rows = {};
  for (const line of log.split(/\r?\n/)) {
    if (!line.includes('[FPVManager lifecycle]')) continue;
    const phase = /\bphase=([a-z0-9-]+)/.exec(line)?.[1];
    if (!PHASES.has(phase)) continue;
    const duration = /\bdurationMs=(\d+)/.exec(line)?.[1];
    const elapsed = /\belapsedMs=(\d+)/.exec(line)?.[1];
    if (!rows[phase]) rows[phase] = { count: 0, durations: [], elapsedMs: [] };
    const row = rows[phase];
    row.count++;
    if (duration !== undefined && row.durations.length < 10000) row.durations.push(Number(duration));
    if (elapsed !== undefined && row.elapsedMs.length < 10000) row.elapsedMs.push(Number(elapsed));
  }
  return Object.fromEntries(Object.entries(rows).sort(([a], [b]) => a.localeCompare(b)).map(([phase, row]) => [phase, {
    count: row.count,
    durationP50Ms: percentile(row.durations, .5),
    durationP95Ms: percentile(row.durations, .95),
    lastElapsedMs: row.elapsedMs.at(-1) ?? null,
  }]));
}
function parseSceneSnapshot(jsonText) {
  const snapshot = JSON.parse(jsonText);
  if (!isRecord(snapshot)) throw new Error('Invalid Cesium scene snapshot');
  const timing = (field) => {
    const item = snapshot[field];
    if (!isRecord(item)) throw new Error(`Missing scene ${field}`);
    const result = {};
    for (const key of ['p50', 'p95', 'max']) {
      if (item[key] !== null && item[key] !== undefined) result[key] = ensureNumber(item[key], `${field}.${key}`);
    }
    return result;
  };
  const tilesets = isRecord(snapshot.tilesets) ? snapshot.tilesets : {};
  const counts = {};
  for (const key of ['resident', 'visible', 'pending', 'estimatedBytes']) {
    if (tilesets[key] !== undefined) counts[key] = ensureNumber(tilesets[key], `tilesets.${key}`);
  }
  return {
    frames: ensureNumber(snapshot.frames, 'frames'),
    renderSamples: ensureNumber(snapshot.renderSamples, 'renderSamples'),
    intervalSamples: ensureNumber(snapshot.intervalSamples, 'intervalSamples'),
    over33Ms: ensureNumber(snapshot.over33Ms, 'over33Ms'),
    cpuRenderMs: timing('cpuRenderMs'),
    framePacingMs: timing('framePacingMs'),
    tilesets: counts,
    scope: 'CPU callbacks and sampled frame intervals; not GPU frame time or full GPU memory',
  };
}
function validateReport(report) {
  if (!isRecord(report) || report.schemaVersion !== 1) throw new Error('Unsupported report schema');
  if (!['real-device', 'synthetic'].includes(report.kind)) throw new Error('Invalid measurement kind');
  if (!SCENARIOS.includes(report.scenario)) throw new Error('Unknown scenario');
  if (!PLATFORMS.includes(report.platform)) throw new Error('Unknown platform');
  if (!/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d/.test(report.recordedAtUtc) || !Number.isFinite(Date.parse(report.recordedAtUtc))) {
    throw new Error('Invalid UTC timestamp');
  }
  if (!isRecord(report.conditions) || !isRecord(report.metrics)) throw new Error('Invalid conditions or metrics');
  for (const [key, value] of Object.entries(report.conditions)) {
    if (!ENUMS[key]?.includes(value)) throw new Error(`Unknown condition: ${key}=${value}`);
  }
  for (const [key, value] of Object.entries(report.metrics)) {
    if (!METRICS.includes(key)) throw new Error(`Unknown metric: ${key}`);
    ensureNumber(value, key);
  }
  for (const key of ['datasetBytes', 'featureCount']) {
    if (report[key] !== null && report[key] !== undefined) {
      if (!Number.isSafeInteger(report[key])) throw new Error(`Invalid integer: ${key}`);
      ensureNumber(report[key], key);
    }
  }
  if (report.lifecycle !== undefined) {
    if (!isRecord(report.lifecycle)) throw new Error('Invalid lifecycle data');
    for (const [phase, row] of Object.entries(report.lifecycle)) {
      if (!PHASES.has(phase) || !isRecord(row)) throw new Error('Invalid lifecycle phase');
      ensureNumber(row.count, `lifecycle.${phase}.count`);
      for (const key of ['durationP50Ms', 'durationP95Ms', 'lastElapsedMs']) {
        if (row[key] !== null && row[key] !== undefined) ensureNumber(row[key], key);
      }
    }
  }
  if (report.scene !== undefined) parseSceneSnapshot(JSON.stringify(report.scene));
  return true;
}
function fromManualOptions(options) {
  if (!options.scenario || !options.platform) throw new Error('--scenario and --platform are required');
  const conditions = {};
  for (const [key, allowed] of Object.entries(ENUMS)) {
    if (options[key] !== undefined) {
      if (!allowed.includes(options[key])) throw new Error(`Invalid ${key}`);
      conditions[key] = options[key];
    }
  }
  const intArg = key => {
    if (options[key] === undefined) return null;
    if (!/^\d+$/.test(options[key])) throw new Error(`${key} must be an integer`);
    const n = Number(options[key]);
    if (!Number.isSafeInteger(n)) throw new Error(`Invalid ${key}`);
    return n;
  };
  const report = {
    schemaVersion: 1,
    kind: 'real-device',
    scenario: options.scenario,
    platform: options.platform,
    recordedAtUtc: new Date().toISOString(),
    datasetBytes: intArg('dataset-bytes'),
    featureCount: intArg('features'),
    conditions,
    metrics: parseMetricPairs(options.metrics),
  };
  if (options['lifecycle-log']) report.lifecycle = parseLifecycleLog(readLimited(options['lifecycle-log']));
  if (options['scene-json']) report.scene = parseSceneSnapshot(readLimited(options['scene-json']));
  validateReport(report);
  return report;
}
function writeJson(file, content) {
  if (!file) throw new Error('Explicit --out=path is required; nothing is uploaded');
  fs.mkdirSync(path.dirname(path.resolve(file)), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(content, null, 2)}\n`, { flag: 'wx', mode: 0o600 });
}
function main(argv) {
  const opts = parseOptions(argv);
  const report = fromManualOptions(opts);
  writeJson(opts.out, report);
  process.stdout.write(`Local ${report.kind} report saved: ${opts.out} (${report.scenario}, ${report.platform})\n`);
}
if (require.main === module) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = {
  SCENARIOS, PLATFORMS, METRICS, ENUMS, PHASES,
  parseOptions, parseMetricPairs, parseLifecycleLog, parseSceneSnapshot,
  validateReport, fromManualOptions, writeJson, percentile,
};
