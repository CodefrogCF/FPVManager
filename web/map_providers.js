(function (root, factory) {
    const api = factory();
    if (typeof module === "object" && module.exports) module.exports = api;
    else root.FPVMapProviders = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
    "use strict";

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
    function credit(Cesium, metadata) {
        requireSource(metadata);
        return new Cesium.Credit(escapeCredit(metadata.attribution), true);
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
        return {
            imagery(style, offline = false) {
                const config = Object.hasOwn(styles, style) ? styles[style] : null;
                if (!config) throw new Error(`Unknown map style: ${style}`);
                const supported=cacheRoot&&['topographic','relief'].includes(style)&&config.url===imagery[style].url;
                if (offline&&!supported) return new Cesium.GridImageryProvider();
                if (typeof config.url !== "string" || !Number.isInteger(config.maximumLevel) ||
                    config.maximumLevel < 0 || config.maximumLevel > 30) {
                    throw new Error("Invalid imagery provider configuration");
                }
                const local=supported;
                const url=local?`${cacheRoot}imagery/${style}/{z}/{x}/{y}.${style==='relief'?'png':'jpeg'}?cacheOnly=${cached()?'1':'0'}`:config.url;
                if(cached()&&!local)return new Cesium.GridImageryProvider();
                return new Cesium.UrlTemplateImageryProvider({ url,
                    maximumLevel: config.maximumLevel,
                    tilingScheme: new Cesium.WebMercatorTilingScheme(),
                    credit: credit(Cesium, local?{...config.source,attribution:config.source.attribution+' · Local map cache: age/coverage in Offline & personal data'}:config.source) });
            },
            terrain() {
                if (typeof elevation.url !== "string") throw new Error("Invalid terrain provider configuration");
                const local=cacheRoot&&elevation.url===terrain.url;
                if(cached()&&!local)throw new Error('Offline caching unavailable for this terrain provider');
                const url=local?new Cesium.Resource({url:cacheRoot+'terrain/',queryParameters:{cacheOnly:cached()?'1':'0'}}):elevation.url;
                return Cesium.CesiumTerrainProvider.fromUrl(url,
                    { ellipsoid: Cesium.Ellipsoid.WGS84, credit: credit(Cesium, local?{...elevation.source,attribution:elevation.source.attribution+' · Local terrain cache: age/coverage in Offline & personal data'}:elevation.source) });
            },
            // Descriptors have no fabricated download/validity timestamps: a
            // tile service is not a fetched whole-dataset snapshot.
            describeImagery(style) { return styles[style]?.source ?? null; },
            describeTerrain() { return elevation.source; }
        };
    }
    return { createAdapters, escapeCredit, defaultImagery: imagery, defaultTerrain: terrain };
});
