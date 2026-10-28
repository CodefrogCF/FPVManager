// The explicit test server injects this wrapper; all scene data stay official.
(() => {
    const Viewer=Cesium.Viewer;
    window.Cesium={...Cesium,Viewer:class extends Viewer{
        constructor(...args){super(...args);window.fixtureViewer=this;this.resolutionScale=.6;this.scene.msaaSamples=1;}
    }};
})();
