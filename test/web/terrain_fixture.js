// Injected only by the explicit local fixture server. Production assets are unchanged.
(() => {
    const original = Cesium.CesiumTerrainProvider.fromUrl;
    window.fixtureProviderAttempts = 0;
    window.fixtureRootRequests = [];
    Cesium.CesiumTerrainProvider.fromUrl = (_url, options) => {
        window.fixtureProviderAttempts++;
        return original.call(Cesium.CesiumTerrainProvider, '/terrain-data/', options).then(provider => {
            const read = provider.requestTileGeometry.bind(provider);
            provider.requestTileGeometry = (...args) => {
                if (args[2] === 0) window.fixtureRootRequests.push(args.slice(0, 3));
                return read(...args);
            };
            return provider;
        });
    };
    const Viewer = Cesium.Viewer;
    const FixtureViewer = class extends Viewer {
        constructor(...args) { super(...args); window.fixtureViewer = this; }
    };
    const ScreenSpaceEventHandler = Cesium.ScreenSpaceEventHandler;
    class FixtureScreenSpaceEventHandler extends ScreenSpaceEventHandler {
        constructor(...args) { super(...args); window.fixtureRouteHandler = this; }
    }
    window.Cesium = { ...Cesium, Viewer: FixtureViewer,
        ScreenSpaceEventHandler: FixtureScreenSpaceEventHandler,
        UrlTemplateImageryProvider: new URLSearchParams(location.search).has('realImagery') ? Cesium.UrlTemplateImageryProvider : Cesium.GridImageryProvider };
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
