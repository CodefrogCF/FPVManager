'use strict';
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path');
const http = require('node:http');
const { browser, runPage } = require('./support/scenery_browser.cjs');
const repo = path.resolve(__dirname, '../..');

test('real Chromium host timers sample terrain through the JSON bridge',
    { skip: browser ? false : 'Chromium is not installed; use FPV_CHROME to run this integration test', timeout: 90000 }, async () => {
    const sourceRoot = process.env.FPV_RF_RUNTIME_SOURCE_ROOT
        ? path.resolve(process.env.FPV_RF_RUNTIME_SOURCE_ROOT) : repo;
    const overridable = new Set(['/web/features/signal/live_radio.js',
        '/web/features/signal/live_terrain_tile_cache.js']);
    const server = http.createServer((request, response) => {
        const name = new URL(request.url, 'http://localhost').pathname;
        const root = overridable.has(name) ? sourceRoot : repo;
        const file = path.resolve(root, '.' + decodeURIComponent(name));
        if (!file.startsWith(root + path.sep)) { response.writeHead(403).end(); return; }
        fs.readFile(file, (error, data) => {
            if (error) { response.writeHead(404).end(); return; }
            response.setHeader('Content-Type', name.endsWith('.js') ? 'text/javascript' : 'text/html');
            response.end(data);
        });
    });
    try {
        await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
        const url = `http://127.0.0.1:${server.address().port}/test/web/live_radio_runtime_smoke.html`;
        // Use real elapsed time and poll the page's explicit completion state.
        // --dump-dom with a virtual-time budget can stall on native timers
        // and waits for the browser process to exit even after the test is done.
        const result = await runPage(url, { timeoutMs: 25000, disableGpu: true });
        assert.equal(result.status, 'pass', JSON.stringify(result));
        assert.equal(result.checks.length, 11);
        assert.equal(result.maximumActiveTileRequests, 4);
        assert.equal(result.fallbackCalls, 0);
        console.log('Browser runtime:', JSON.stringify(result));
    } finally {
        server.closeAllConnections();
        await new Promise(resolve => server.close(resolve));
    }
});
