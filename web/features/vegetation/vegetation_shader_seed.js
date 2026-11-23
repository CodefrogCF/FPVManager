(function (root, factory) {
    const api = factory();
    if (typeof module === 'object' && module.exports) module.exports = api;
    else root.FPVVegetationShaderSeed = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    'use strict';

    // One instance exercises the same Cesium i3dm material path as a forest tile.
    // Every bundled tree uses the same attributes and alpha-masked material.
    function seedTile() {
        const encoder = new TextEncoder();
        const padded = value => value.padEnd(Math.ceil(value.length / 8) * 8, ' ');
        const features = encoder.encode(padded(JSON.stringify({
            INSTANCES_LENGTH: 1, POSITION: {byteOffset: 0}, NORMAL_UP: {byteOffset: 12},
            NORMAL_RIGHT: {byteOffset: 24}, SCALE: {byteOffset: 36}
        })));
        const instance = new Float32Array([6378137, 0, 0, 1, 0, 0, 0, 1, 0, 12]);
        const batch = encoder.encode(padded('{"Height":[12]}'));
        const model = encoder.encode(padded('assets/vegetation/tree-conifer-1.glb'));
        const data = new Uint8Array(32 + features.length + instance.byteLength + batch.length + model.length);
        data.set(encoder.encode('i3dm'));
        const header = new DataView(data.buffer);
        header.setUint32(4, 1, true);
        header.setUint32(8, data.length, true);
        header.setUint32(12, features.length, true);
        header.setUint32(16, instance.byteLength, true);
        header.setUint32(20, batch.length, true);
        data.set(features, 32);
        data.set(new Uint8Array(instance.buffer), 32 + features.length);
        data.set(batch, 32 + features.length + instance.byteLength);
        data.set(model, data.length - model.length);
        return data.buffer;
    }

    function create(C, viewer) {
        const {scene} = viewer;
        const commands = [];
        let cancel, disposed = false, prepared = false;

        async function prepare(tileset, signal) {
            if (disposed || signal?.aborted || !C.Model3DTileContent?.fromI3dm || !scene.context?.shaderCache) return [];
            if (prepared) return commands.slice().reverse();
            cancel?.();
            return new Promise(resolve => {
                const seedTileset = new C.Cesium3DTileset({shadows: C.ShadowMode.DISABLED});
                seedTileset._modelUpAxis = tileset?._modelUpAxis ?? C.Axis.Y;
                seedTileset._modelForwardAxis = tileset?._modelForwardAxis ?? C.Axis.X;
                const environment = seedTileset.environmentMapManager;
                const tile = {computedTransform: C.Matrix4.IDENTITY};
                const seen = new Set(commands.map(command => command.shaderProgram));
                let content, finished = false, withEnvironment = false, timer;
                const primitive = {update, isDestroyed: () => finished, destroy};

                function destroy() {
                    if (finished) return;
                    finished = true;
                    clearTimeout(timer);
                    signal?.removeEventListener('abort', stop);
                    try {
                        content?.destroy();
                    } finally {
                        environment._radianceCubeMap = undefined;
                        seedTileset.destroy();
                        cancel = undefined;
                        resolve(commands.slice().reverse());
                    }
                }

                function stop() {
                    if (!scene.isDestroyed?.() && scene.primitives.contains(primitive)) scene.primitives.remove(primitive);
                    destroy();
                }

                function update(frameState) {
                    try {
                        content.update(seedTileset, frameState);
                        const runtimeNodes = content._model.sceneGraph?._runtimeNodes;
                        if (runtimeNodes) {
                            let foundShader = false;
                            for (const node of runtimeNodes) for (const part of node?.runtimePrimitives ?? []) {
                                const shader = part.drawCommand?.command?.shaderProgram;
                                if (!shader) continue;
                                foundShader = true;
                                if (seen.has(shader)) continue;
                                seen.add(shader);
                                // Hold the base program so Cesium keeps its derived
                                // log-depth and HDR programs after the seed is removed.
                                const shaderProgram = frameState.context.shaderCache.getShaderProgram({
                                    vertexShaderSource: shader._vertexShaderSource,
                                    fragmentShaderSource: shader._fragmentShaderSource,
                                    attributeLocations: shader._attributeLocations
                                });
                                commands.push({shaderProgram});
                            }
                            if (withEnvironment) {
                                prepared = foundShader;
                                frameState.afterRender.push(() => {stop(); return false;});
                                return;
                            }
                            if (foundShader) {
                                // Later tiles use the environmental lighting
                                // variant. Supply lighting only to the seed.
                                withEnvironment = true;
                                environment._radianceCubeMap = frameState.context.defaultCubeMap;
                                environment._sphericalHarmonicCoefficients = Array(9).fill(C.Cartesian3.ZERO);
                                content._model.resetDrawCommands();
                            }
                        }
                        scene.requestRender();
                    } catch (_) {
                        frameState.afterRender.push(() => {stop(); return false;});
                    }
                }

                cancel = stop;
                signal?.addEventListener('abort', stop, {once: true});
                timer = setTimeout(stop, 6000);
                const resource = new C.Resource({url: new URL('vegetation-seed.i3dm', globalThis.location.href).href});
                C.Model3DTileContent.fromI3dm(seedTileset, tile, resource, seedTile(), 0).then(loaded => {
                    if (finished || scene.isDestroyed?.()) {loaded.destroy(); stop(); return;}
                    content = loaded;
                    content._model.show = false;
                    scene.primitives.add(primitive);
                    scene.requestRender();
                }, stop).catch(stop);
            });
        }

        return {
            prepare,
            dispose() {
                disposed = true;
                cancel?.();
                if (!scene.isDestroyed?.()) for (const {shaderProgram} of commands) shaderProgram.destroy();
                commands.length = 0;
            }
        };
    }

    return {create};
});
