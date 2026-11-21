const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const capture = require('../../web/capture_mode.js');

test('clean capture changes only the class and is fully reversible', () => {
    const classes = new Set();
    const doc = {body: {classList: {
        toggle(name,enabled){enabled?classes.add(name):classes.delete(name);return enabled;},
    }}};
    assert.deepEqual(capture.set(doc,true),{enabled:true});
    assert.equal(classes.has('capture-mode'),true);
    assert.deepEqual(capture.set(doc,false),{enabled:false});
    assert.equal(classes.has('capture-mode'),false);
    assert.throws(()=>capture.set(doc,'on'));
    assert.throws(()=>capture.set(null,true));
});

test('clean capture hides HUD/menu but preserves map credits', () => {
    const html=fs.readFileSync(path.join(__dirname,'../../web/globe.html'),'utf8');
    assert.match(html,/body\.capture-mode #navigation-hud/);
    assert.match(html,/body\.capture-mode #flight-actions/);
    assert.match(html,/body\.capture-mode #ground-controls/);
    assert.doesNotMatch(html,/body\.capture-mode [^\n]*credit/);
    assert.match(html,/<script src="capture_mode\.js"><\/script>/);
    const config=fs.readFileSync(path.join(__dirname,'../../pubspec.yaml'),'utf8');
    assert.match(config,/- web\/capture_mode\.js/);
    const renderer=fs.readFileSync(path.join(__dirname,'../../web/globe.js'),'utf8');
    assert.match(renderer,/case 'set-capture-mode'/);
    assert.match(renderer,/command\.enabled && !flyer\?\.active/);
});
