'use strict';
const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const http = require('node:http'), { spawn } = require('node:child_process');
const repo = path.resolve(__dirname, '../..');
const browser = [process.env.FPV_CHROME,
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser']
    .find(file => file && fs.existsSync(file));

test('real Chromium host timers sample terrain through the JSON bridge',
    { skip: browser ? false : 'Chromium is not installed; use FPV_CHROME to run this integration test', timeout: 45000 }, async () => {
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
    const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'fpv-rf-browser-'));
    let child;
    try {
        await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
        const url = `http://127.0.0.1:${server.address().port}/test/web/live_radio_runtime_smoke.html`;
        const output = await new Promise((resolve, reject) => {
            child = spawn(browser, ['--headless', '--disable-gpu', '--no-first-run',
                '--no-default-browser-check', '--disable-extensions', '--no-proxy-server',
                '--user-data-dir=' + profile, '--virtual-time-budget=10000', '--dump-dom', url],
                { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
            let stdout = '', stderr = '';
            const timer = setTimeout(() => { child.kill(); reject(Error('Browser runtime test timed out')); }, 35000);
            child.stdout.on('data', data => { stdout += data; });
            child.stderr.on('data', data => { stderr = (stderr + data).slice(-4000); });
            child.once('error', error => { clearTimeout(timer); reject(error); });
            child.once('close', code => {
                clearTimeout(timer);
                code === 0 ? resolve(stdout) : reject(Error(`Browser exited ${code}: ${stderr}`));
            });
        });
        const match = output.match(/<pre id="result">([\s\S]*?)<\/pre>/);
        assert.ok(match, 'Browser did not produce a runtime result');
        const content = match[1].replace(/&quot;/g, '"').replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>').replace(/&amp;/g, '&');
        const result = JSON.parse(content);
        assert.equal(result.status, 'pass', content);
        assert.ok(/data-status="pass"/.test(output), 'Browser page status must agree with the result');
        assert.equal(result.checks.length, 11);
        assert.equal(result.maximumActiveTileRequests, 4);
        assert.equal(result.fallbackCalls, 0);
        console.log('Browser runtime:', JSON.stringify(result));
    } finally {
        child?.kill();
        server.closeAllConnections();
        await new Promise(resolve => server.close(resolve));
        // Delete only this test's freshly created profile inside the OS temp directory.
        const target = path.resolve(profile), base = path.resolve(os.tmpdir());
        assert.ok(target.startsWith(base + path.sep) && path.basename(target).startsWith('fpv-rf-browser-'));
        try { fs.rmSync(target, { recursive: true, force: true }); } catch (_) { /* Browser shutdown may retain a temp lock. */ }
    }
});
