// Opt-in LOCAL development preview. Not an importer, terrain cutter or collision source.
(function (root, factory) {
    const api = factory(typeof module === 'object' && module.exports
        ? require('./scenery_alignment.js') : root.FPVSceneryAlignment);
    if (typeof module === 'object' && module.exports) module.exports = api;
    else root.FPVReferenceSceneryPreview = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function (alignment) {
    'use strict';
    function create(Cesium, viewer, options = {}) {
        if (!alignment || !viewer?.scene?.primitives) throw Error('Scenery preview unavailable');
        const modelUrl = options.modelUrl || './assets/scenery/local_reference.glb';
        const configUrl = options.configUrl || './assets/scenery/reference_alignment.json';
        const fetchConfig = options.fetchConfig || (url => fetch(url, {cache:'no-store'}).then(response => {
            if (!response.ok) throw Error(`Alignment JSON HTTP ${response.status}`);
            return response.json();
        }));
        const modelFactory = options.modelFactory || (config => Cesium.Model.fromGltfAsync({
            url: modelUrl,
            modelMatrix: alignment.modelMatrix(Cesium, config),
            scale: config.scale,
            allowPicking: false
        }));
        const status = options.onStatus || (() => {});
        let model = null;
        let disposed = false;
        async function load() {
            try {
                const config = alignment.normalize(await fetchConfig(configUrl));
                if (disposed) return null;
                const created = await modelFactory(config);
                if (disposed) { created.destroy?.(); return null; }
                model = created;
                alignment.apply(Cesium, model, config);
                viewer.scene.primitives.add(model);
                viewer.camera.flyTo({
                    destination: Cesium.Cartesian3.fromDegrees(config.longitude, config.latitude, 550),
                    orientation: {heading: 0, pitch: Cesium.Math.toRadians(-65), roll: 0}, duration: 1.5
                });
                viewer.scene.requestRender?.();
                status({state:'loaded', message:'Local scenery preview loaded (visual only, no collision)'});
                return model;
            } catch (error) {
                status({state:'error', message:String(error?.message || error)});
                return null;
            }
        }
        function dispose() {
            disposed = true;
            if (model) { viewer.scene.primitives.remove(model); model = null; }
        }
        return {load,dispose};
    }
    return {create};
});
