#!/usr/bin/env node
'use strict';
/* Compare explicitly selected local, homogeneous device runs; never upload. */
const fs = require('node:fs');
const { validateReport, percentile, writeJson } = require('./performance_report.cjs');
const MAX_INPUT_BYTES = 5 * 1024 * 1024;
function signature(report) {
  return JSON.stringify({
    kind: report.kind, platform: report.platform, scenario: report.scenario,
    datasetBytes: report.datasetBytes ?? null,
    featureCount: report.featureCount ?? null,
    conditions: Object.fromEntries(Object.entries(report.conditions).sort(([a], [b]) => a.localeCompare(b))),
  });
}
function summarize(reports) {
  if (!reports.length || reports.length > 100) throw new Error('Expected 1..100 local reports');
  reports.forEach(validateReport);
  if (reports.some(r => r.kind !== 'real-device')) throw new Error('Do not mix synthetic with real-device measurements');
  const first = signature(reports[0]);
  if (reports.some(r => signature(r) !== first)) throw new Error('Scenario/platform/dataset/conditions differ; benchmark sets must not be mixed');
  const keys = new Set(reports.flatMap(r => Object.keys(r.metrics)));
  const metrics = {};
  for (const key of [...keys].sort()) {
    const values = reports.map(r => r.metrics[key]).filter(v => v !== undefined);
    metrics[key] = {
      samples: values.length,
      p50: percentile(values, .5),
      p95: percentile(values, .95),
      min: Math.min(...values),
      max: Math.max(...values),
    };
  }
  return {
    schemaVersion: 1, ...JSON.parse(first), kind: 'real-device-summary',
    samples: reports.length, metrics,
    limitations: ['Homogeneous runs only; no baseline/after causation inferred.',
      'P50/P95 use nearest-rank percentiles. Small sample counts produce coarse estimates.',
      'Unmeasured metrics are omitted; missing is never treated as zero.',
      'CPU callback frame time is not GPU frame time. RSS is not peak heap.'],
  };
}
function main(args) {
  const paths = args.filter(x => !x.startsWith('--'));
  const opts = args.filter(x => x.startsWith('--'));
  if (opts.some(x => !x.startsWith('--out=')) || opts.length > 1) throw new Error('Only optional --out=path is supported');
  if (!paths.length) throw new Error('Provide local report filenames: node tool/performance_compare.cjs file1.json file2.json [--out=summary.json]');
  const reports = paths.map(file => {
    if (fs.statSync(file).size > MAX_INPUT_BYTES) throw new Error('Report exceeds size limit');
    const report = JSON.parse(fs.readFileSync(file, 'utf8'));
    validateReport(report);
    return report;
  });
  const result = summarize(reports);
  const dest = opts[0]?.slice('--out='.length);
  if (dest) writeJson(dest, result);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}
if (require.main === module) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = { summarize, signature };
