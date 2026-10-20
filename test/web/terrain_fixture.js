// Injected only by the explicit local fixture server. Production assets are unchanged.
(() => {
    const original = Cesium.CesiumTerrainProvider.fromUrl;
    window.fixtureProviderAttempts = 0;
    Cesium.CesiumTerrainProvider.fromUrl = (_url, options) => {
        window.fixtureProviderAttempts++;
        return original.call(Cesium.CesiumTerrainProvider, '/terrain-data/', options);
    };
    const Viewer = Cesium.Viewer;
    const FixtureViewer = class extends Viewer {
        constructor(...args) { super(...args); window.fixtureViewer = this; }
    };
    window.Cesium = { ...Cesium, Viewer: FixtureViewer,
        UrlTemplateImageryProvider: Cesium.GridImageryProvider };
    let online = true;
    Object.defineProperty(navigator, 'onLine', { get: () => online });
    window.addEventListener('message', event => {
        if (event.source !== parent || event.origin !== location.origin ||
            typeof event.data?.fixtureOffline !== 'boolean') return;
        online = !event.data.fixtureOffline;
        window.dispatchEvent(new Event(online ? 'online' : 'offline'));
    });
    const label = document.createElement('div');
    label.textContent = 'Synthetic terrain test — no real elevation data';
    label.style.cssText = 'position:absolute;right:8px;top:70px;z-index:10;color:#fff;background:#542;padding:6px;font:12px sans-serif;max-width:250px';
    document.body.append(label);
})();
