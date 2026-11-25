#!/usr/bin/env node
'use strict';
// Compare prescribed-latency controller fixtures, not real device/network performance.
const fs = require('node:fs');
const path = require('node:path');
const [beforeName, afterName, outputName] = process.argv.slice(2);
if (!beforeName || !afterName || !outputName) {
    throw Error('Usage: node tool/compare_live_rf_motion.cjs before.json after.json output.json');
}
const before = JSON.parse(fs.readFileSync(path.resolve(beforeName), 'utf8'));
const after = JSON.parse(fs.readFileSync(path.resolve(afterName), 'utf8'));
const key = row => [row.distanceMeters, row.speedKmh, row.motion, row.terrain,
    row.prescribedBatchLatencyMs].join('/');
if (JSON.stringify(before.fixture) !== JSON.stringify(after.fixture)) {
    throw Error('Motion benchmark fixtures do not match');
}
const indexed = new Map(after.scenarios.map(row => [key(row), row]));
if (indexed.size !== after.scenarios.length || indexed.size !== before.scenarios.length) {
    throw Error('Motion scenario counts or keys do not match');
}
const scenarios = before.scenarios.map(original => {
    const replacement = indexed.get(key(original));
    if (!replacement) throw Error('Missing after scenario: ' + key(original));
    return {
        key: key(original),
        steadyValidTimeChangePercentagePoints:
            100 * (replacement.steadyValidTimeFraction - original.steadyValidTimeFraction),
        terrainBatchChange: replacement.terrainBatches - original.terrainBatches,
        requestedSampleChange: replacement.requestedSamples - original.requestedSamples,
        before: original,
        after: replacement,
    };
});
const report = {
    schemaVersion: 1,
    kind: 'synthetic-controller-motion-comparison',
    fixture: before.fixture,
    unmeasured: before.unmeasured,
    scenarios,
};
const output = path.resolve(outputName);
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
const lateralClear = scenarios.filter(row => row.before.motion === 'lateral' &&
    row.before.terrain === 'clearMountainRing');
for (const row of lateralClear) {
    console.log(JSON.stringify({ key: row.key,
        steadyValidPercentBefore: +(100 * row.before.steadyValidTimeFraction).toFixed(1),
        steadyValidPercentAfter: +(100 * row.after.steadyValidTimeFraction).toFixed(1),
        terrainBatches: [row.before.terrainBatches, row.after.terrainBatches],
        requestedSamples: [row.before.requestedSamples, row.after.requestedSamples],
    }));
}
if (scenarios.some(row => row.after.falseClearPublications !== 0 ||
    row.after.maximumActiveTerrainBatches > 1)) {
    throw Error('After fixture violates clear-classification or single-flight invariant');
}
