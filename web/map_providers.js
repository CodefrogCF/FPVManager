(function (root, factory) {
    const api = factory();
    if (typeof module === "object" && module.exports) module.exports = api;
    else root.FPVMapProviders = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
    "use strict";

    // Cesium deduplicates equal static credits on add, but removes by object
    // identity. Keep one registered representative until all our layer owners
    // release it, so hiding labels cannot remove a still-visible model's source.
    const staticOwners = new WeakMap(), configuredDisplays = new WeakMap();
    function retainStaticCredit(display, value) {
        if (!display?.addStaticCredit || !value) return;
        let state = staticOwners.get(display);
        if (!state) { state = {owners:new Map(), entries:new Map()}; staticOwners.set(display,state); }
        if (state.owners.has(value)) return;
        const key = typeof value.html === 'string' ? JSON.stringify([value.html,value.showOnScreen??value.onScreen??false]) : value;
        let entry = state.entries.get(key);
        if (!entry) {
            entry = {credit:value, owners:new Set(), key}; state.entries.set(key,entry);
            display.addStaticCredit(value);
        }
        entry.owners.add(value); state.owners.set(value,entry);
    }
    function releaseStaticCredit(display, value) {
        const state = display && staticOwners.get(display), entry = state?.owners.get(value);
        if (!entry) return;
        state.owners.delete(value); entry.owners.delete(value);
        if (!entry.owners.size) { display.removeStaticCredit(entry.credit); state.entries.delete(entry.key); }
        if (!state.owners.size) staticOwners.delete(display);
    }
    function prepareCredits(C, {usesIon = false} = {}) {
        if (usesIon || !C?.CreditDisplay || !C?.Credit) return false;
        // The current scene streams direct provider data, not ion assets.
        // Only replace the optional default logo. Cesium's actual ion credits
        // and providers' non-collapsible credits keep their native handling.
        C.CreditDisplay.cesiumCredit = new C.Credit('');
        return true;
    }
    function weatherCredits(C) {
        return [new C.Credit('<a href="https://open-meteo.com/" target="_blank" rel="noopener">Open-Meteo</a>',true),
            new C.Credit('<a href="https://open-meteo.com/" target="_blank" rel="noopener">Open-Meteo</a> · <a href="https://creativecommons.org/licenses/by/4.0/" target="_blank" rel="noopener">CC BY 4.0</a> · Für die Kartendarstellung aufbereitet; Wind räumlich interpoliert.',false)];
    }
    function configureCredits(C, viewer) {
        const display = viewer?.cesiumWidget?.creditDisplay ?? viewer?.creditDisplay;
        if (!display) return {open(){},dispose(){}};
        if (configuredDisplays.has(display)) return configuredDisplays.get(display);
        const container = display.container, viewport = display.viewport ?? container?.ownerDocument;
        const expand = container?.querySelector?.('.cesium-credit-expand-link');
        if (expand) {
            expand.textContent = 'Quellen'; expand.setAttribute('aria-label','Quellen und Lizenzen');
            expand.setAttribute('title','Quellen und Lizenzen');
        }
        const dialog = viewport?.querySelector?.('.cesium-credit-lightbox');
        if (dialog) {
            dialog.setAttribute('aria-label','Quellen und Lizenzen');
            const title = dialog.querySelector('.cesium-credit-lightbox-title');
            if (title) title.textContent = 'Quellen und Lizenzen';
            const close = dialog.querySelector('.cesium-credit-lightbox-close');
            if (close) { close.setAttribute('aria-label','Quellen schließen'); close.setAttribute('title','Schließen'); }
        }
        const renderer = C?.Credit ? new C.Credit('<a href="https://cesium.com/platform/cesiumjs/" target="_blank" rel="noopener">CesiumJS</a> · <a href="https://www.apache.org/licenses/LICENSE-2.0" target="_blank" rel="noopener">Apache-2.0</a>',false) : null;
        if (renderer) retainStaticCredit(display,renderer);
        let disposed = false;
        const controls = {open(){ if (!disposed) display.showLightbox?.(); },dispose(){
            if (disposed) return; disposed = true;
            if (renderer) releaseStaticCredit(display,renderer);
            configuredDisplays.delete(display);
        }};
        configuredDisplays.set(display,controls);
        return controls;
    }

    const terms = "https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices";
    function source(id, name, attribution, metadataUri) {
        return Object.freeze({ id, name, publisher: "swisstopo", attribution,
            licenseName: "swisstopo OGD terms (with product-specific notices)",
            licenseUri: terms, metadataUri, validity: null });
    }
    const productPage = "https://www.swisstopo.admin.ch/en/orthoimage-swissimage-10";
    const imagery = Object.freeze({
        satellite: Object.freeze({
            source: source("ch.swisstopo.swissimage", "SWISSIMAGE Background",
                "© swisstopo · © CNES, Spot Image, NPOC · " +
                "Includes material © (2016-2018) Planet. All rights reserved", productPage),
            url: "https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.swissimage/default/current/3857/{z}/{x}/{y}.jpeg",
            maximumLevel: 19
        }),
        topographic: Object.freeze({
            source: source("ch.swisstopo.pixelkarte-farbe", "National map", "© swisstopo",
                "https://map.geo.admin.ch/?layers=ch.swisstopo.pixelkarte-farbe"),
            url: "https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.pixelkarte-farbe/default/current/3857/{z}/{x}/{y}.jpeg",
            maximumLevel: 19
        }),
        relief: Object.freeze({
            source: source("ch.swisstopo.swissalti3d-reliefschattierung", "swissALTI3D hillshade", "© swisstopo",
                "https://map.geo.admin.ch/?layers=ch.swisstopo.swissalti3d-reliefschattierung"),
            url: "https://wmts.geo.admin.ch/1.0.0/ch.swisstopo.swissalti3d-reliefschattierung/default/current/3857/{z}/{x}/{y}.png",
            maximumLevel: 18
        })
    });
    const terrain = Object.freeze({
        source: source("ch.swisstopo.terrain.3d", "swisstopo 3D terrain", "© swisstopo",
            "https://docs.geo.admin.ch/visualize-data/terrain-service.html"),
        url: "https://3d.geo.admin.ch/ch.swisstopo.terrain.3d/v1/"
    });

    function requireSource(value) {
        if (!value || ["id", "name", "publisher", "attribution", "metadataUri"]
            .some(key => typeof value[key] !== "string" || !value[key].trim())) {
            throw new Error("Invalid map source metadata");
        }
    }
    function credit(Cesium, metadata, collapsible = false) {
        requireSource(metadata);
        return new Cesium.Credit(escapeCredit(metadata.attribution), !collapsible);
    }
    function escapeCredit(value) {
        if (typeof value !== "string" || !value.trim() || value.length > 2000) {
            throw new Error("Invalid source attribution");
        }
        return value.replaceAll("&", "&amp;")
            .replaceAll("<", "&lt;").replaceAll(">", "&gt;");
    }
    function createAdapters(Cesium, configuration = {}) {
        const styles = configuration.imagery ?? imagery;
        const elevation = configuration.terrain ?? terrain;
        const cached=()=>configuration.cacheOnly===true||globalThis.navigator?.onLine===false;
        const cacheRoot=typeof configuration.cacheRoot==='string'?configuration.cacheRoot:null;
        const prepared=configuration.prepared;
        if(prepared&&(!/^[0-9a-f]{64}$/.test(prepared.packageId)||!cacheRoot))throw new Error('Invalid prepared provider');
        const contains=(lon,lat)=>!prepared||(lon>=prepared.west&&lon<=prepared.east&&lat>=prepared.south&&lat<=prepared.north&&
            (prepared.scope!=='radius'||Math.hypot((lon-prepared.centerLongitude)*111.195*Math.cos(prepared.centerLatitude*Math.PI/180),(lat-prepared.centerLatitude)*111.195)<=prepared.radiusKm));
        return {
            terrainProbe:prepared?[1,0,0]:[0,0,0],
            containsTerrainPoint:contains,
            imagery(style, offline = false) {
                if(configuration.preparedUnavailable) return new Cesium.GridImageryProvider();
                if(prepared){
                    if(!(prepared.maps??['topographic']).includes(style))return new Cesium.GridImageryProvider();
                    return new Cesium.UrlTemplateImageryProvider({
                        url:`${cacheRoot}prepared/${prepared.packageId}/imagery/${style}/{z}/{x}/{y}.png`,
                        maximumLevel:prepared.imageryLevel,tilingScheme:new Cesium.WebMercatorTilingScheme(),
                        rectangle:Cesium.Rectangle.fromDegrees(prepared.west,prepared.south,prepared.east,prepared.north),
                        credit:credit(Cesium,{...imagery.topographic.source,attribution:'© swisstopo · Abgeleitete Offline-Karte · '+prepared.preparedAtUtc},true)});
                }
                const config = Object.hasOwn(styles, style) ? styles[style] : null;
                if (!config) throw new Error(`Unknown map style: ${style}`);
                const supported=cacheRoot&&['topographic','relief'].includes(style)&&config.url===imagery[style].url;
                if (offline&&!supported) return new Cesium.GridImageryProvider();
                if (typeof config.url !== "string" || !Number.isInteger(config.maximumLevel) ||
                    config.maximumLevel < 0 || config.maximumLevel > 30) {
                    throw new Error("Invalid imagery provider configuration");
                }
                const local=supported;
                const official=config.url===imagery[style]?.url&&config.source?.id===imagery[style]?.source.id;
                const url=local?`${cacheRoot}imagery/${style}/{z}/{x}/{y}.${style==='relief'?'png':'jpeg'}?cacheOnly=${cached()?'1':'0'}`:config.url;
                if(cached()&&!local)return new Cesium.GridImageryProvider();
                return new Cesium.UrlTemplateImageryProvider({ url,
                    maximumLevel: config.maximumLevel,
                    tilingScheme: new Cesium.WebMercatorTilingScheme(),
                    credit: credit(Cesium, config.source, official) });
            },
            terrain() {
                if(configuration.preparedUnavailable)throw new Error('Offline package metadata unavailable');
                if(prepared){
                    if(prepared.includeTerrain===false)throw new Error('No offline terrain selected; elevation unavailable');
                    return Cesium.CesiumTerrainProvider.fromUrl(`${cacheRoot}prepared/${prepared.packageId}/terrain/`,{
                        ellipsoid:Cesium.Ellipsoid.WGS84,credit:credit(Cesium,{...terrain.source,attribution:'© swisstopo · Abgeleitetes Offline-Gelände · '+prepared.preparedAtUtc},true)
                    }).then(provider=>{
                        const read=provider.requestTileGeometry.bind(provider);
                        provider.requestTileGeometry=(...args)=>{
                            const result=read(...args);if(result===undefined)return undefined;
                            return Promise.resolve(result).then(tile=>{
                                const interpolate=tile.interpolateHeight.bind(tile);
                                tile.interpolateHeight=(rectangle,lon,lat)=>contains(lon*180/Math.PI,lat*180/Math.PI)?interpolate(rectangle,lon,lat):undefined;
                                return tile;
                            });
                        };
                        return provider;
                    });
                }
                if (typeof elevation.url !== "string") throw new Error("Invalid terrain provider configuration");
                const local=cacheRoot&&elevation.url===terrain.url;
                const official=elevation.url===terrain.url&&elevation.source?.id===terrain.source.id;
                if(cached()&&!local)throw new Error('Offline caching unavailable for this terrain provider');
                const url=local?new Cesium.Resource({url:cacheRoot+'terrain/',queryParameters:{cacheOnly:cached()?'1':'0'}}):elevation.url;
                return Cesium.CesiumTerrainProvider.fromUrl(url,
                    { ellipsoid: Cesium.Ellipsoid.WGS84, credit: credit(Cesium, elevation.source, official) });
            },
            // Descriptors have no fabricated download/validity timestamps: a
            // tile service is not a fetched whole-dataset snapshot.
            describeImagery(style) { return styles[style]?.source ?? null; },
            describeTerrain() { return elevation.source; }
        };
    }
    return { createAdapters, escapeCredit, defaultImagery: imagery, defaultTerrain: terrain,
        prepareCredits,configureCredits,retainStaticCredit,releaseStaticCredit,weatherCredits };
});
