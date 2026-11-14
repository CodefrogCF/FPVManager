'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const Cesium = require('../../web/cesium/index.cjs');
const {create} = require('../../web/vegetation_shader_seed.js');

function fixture() {
    let primitive, contentDestroyed = 0, shaderReleased = 0;
    const draws = [], programs = [];
    const frameState = {afterRender: [], context: {defaultCubeMap: {}, shaderCache: {
        getShaderProgram({fragmentShaderSource}) {
            const shader = programs.find(p => p._fragmentShaderSource === fragmentShaderSource);
            assert.ok(shader);
            return shader;
        }
    }}};
    const C = {...Cesium, Model3DTileContent: {
        async fromI3dm(tileset, tile, resource, data, offset) {
            const parsed = C.I3dmParser.parse(data, offset);
            assert.equal(parsed.featureTableJson.INSTANCES_LENGTH, 1);
            assert.equal(parsed.gltfFormat, 0);
            assert.equal(new TextDecoder().decode(parsed.gltf).trim(), 'assets/vegetation/tree-conifer-1.glb');
            assert.equal(tile.computedTransform, C.Matrix4.IDENTITY);
            const drawCommand = {command: {}};
            let reset = true;
            return {
                _model: {show: true, sceneGraph: {_runtimeNodes: [{runtimePrimitives: [{drawCommand}]}]},
                    resetDrawCommands() {reset = true;},
                },
                update() {
                    draws.push(this._model.show);
                    if (!reset) return;
                    reset = false;
                    const shader = {_fragmentShaderSource: {environment: !!tileset.environmentMapManager.radianceCubeMap},
                        destroy() {shaderReleased++;}};
                    programs.push(shader);
                    drawCommand.command.shaderProgram = shader;
                    assert.equal(tileset.environmentMapManager.radianceCubeMap,
                        programs.length === 2 ? frameState.context.defaultCubeMap : undefined);
                },
                destroy() {contentDestroyed++;}
            };
        }
    }};
    const scene = {context: frameState.context, requestRender() {}, primitives: {
        add(value) {primitive = value;}, contains(value) {return primitive === value;},
        remove() {const removed = primitive; primitive = undefined; removed.destroy();}
    }};
    return {
        seed: create(C, {scene}), programs, draws,
        frame() {
            primitive.update(frameState);
            for (const callback of frameState.afterRender.splice(0)) callback();
        },
        get contentDestroyed() {return contentDestroyed;},
        get shaderReleased() {return shaderReleased;}
    };
}

test('the hidden i3dm seed retains both tree shaders after releasing its temporary model', async t => {
    Object.defineProperty(globalThis, 'location', {configurable: true, value: {href: 'https://example.test/web/globe.html'}});
    t.after(() => {delete globalThis.location;});
    const f = fixture();
    try {
        const pending = f.seed.prepare();
        await Promise.resolve();
        f.frame();
        f.frame();
        const commands = await pending;
        assert.deepEqual(f.draws, [false, false]);
        assert.deepEqual(commands.map(c => c.shaderProgram), f.programs.slice().reverse());
        assert.equal(f.contentDestroyed, 1);
        assert.equal(f.shaderReleased, 0);
        assert.deepEqual(await f.seed.prepare(), commands);
    } finally {f.seed.dispose();}
    assert.equal(f.shaderReleased, 2);
});
