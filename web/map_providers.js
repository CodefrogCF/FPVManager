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
        return {
            imagery(style, offline = false) {
                const config = Object.hasOwn(styles, style) ? styles[style] : null;
                if (!config) throw new Error(`Unknown map style: ${style}`);
                if (offline) return new Cesium.GridImageryProvider();
                if (typeof config.url !== "string" || !Number.isInteger(config.maximumLevel) ||
                    config.maximumLevel < 0 || config.maximumLevel > 30) {
                    throw new Error("Invalid imagery provider configuration");
                }
                return new Cesium.UrlTemplateImageryProvider({ url: config.url,
                    maximumLevel: config.maximumLevel,
                    tilingScheme: new Cesium.WebMercatorTilingScheme(),
                    credit: credit(Cesium, config.source) });
            },
            terrain() {
                if (typeof elevation.url !== "string") throw new Error("Invalid terrain provider configuration");
                return Cesium.CesiumTerrainProvider.fromUrl(elevation.url,
                    { ellipsoid: Cesium.Ellipsoid.WGS84, credit: credit(Cesium, elevation.source) });
            },
            // Descriptors have no fabricated download/validity timestamps: a
            // tile service is not a fetched whole-dataset snapshot.
            describeImagery(style) { return styles[style]?.source ?? null; },
            describeTerrain() { return elevation.source; }
        };
    }
    return { createAdapters, escapeCredit, defaultImagery: imagery, defaultTerrain: terrain };
});
