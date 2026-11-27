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
    // Resize only when the native credit bar actually changes size. The HUD
    // must not cover required notices even on a narrow screen or in capture mode.
    function observeCreditHeight(container, Observer=globalThis.ResizeObserver) {
        const root=container?.ownerDocument?.documentElement;
        if(!root?.style || !container?.getBoundingClientRect) return ()=>{};
        let previous=-1;
        const update=()=>{const height=Math.ceil(container.getBoundingClientRect().height);
            if(height!==previous){previous=height;root.style.setProperty('--fpv-credit-height',`${height}px`);}};
        update();
        const observer=typeof Observer==='function'?new Observer(update):null;
        observer?.observe(container);
        return ()=>{observer?.disconnect();root.style.removeProperty('--fpv-credit-height');};
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
        const stopHeight=observeCreditHeight(container);
        let disposed = false;
        const controls = {open(){ if (!disposed) display.showLightbox?.(); },dispose(){
            if (disposed) return; disposed = true;
            stopHeight();
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

    // Official LGB WMS services cover Berlin AND Brandenburg. Rectangles keep
    // these regional layers from replacing the existing Swiss providers. WMS
    // is imagery only: DGM hillshade does NOT supply terrain elevations.
    const regionalCredit = '© GeoBasis-DE/LGB, dl-de/by-2-0; © Geoportal Berlin, dl-de/zero-2-0';
    const regionalBounds = Object.freeze([11.1528, 51.2635, 14.8390, 53.6099]);
    const regionalImagery = Object.freeze({
        satellite: Object.freeze({
            url: 'https://isk.geobasis-bb.de/mapproxy/dop20c/service/wms?',
            layers: 'bebb_dop20c',
            source: Object.freeze({id:'de.bb.be.dop20c', name:'Berlin/Brandenburg DOP20c (20 cm)',
                publisher:'GeoBasis-DE/LGB / Geoportal Berlin',attribution:regionalCredit,
                licenseName:'Datenlizenz Deutschland BY 2.0 / Berlin Zero 2.0',
                licenseUri:'https://www.govdata.de/dl-de/by-2-0',
                metadataUri:'https://geoportal.brandenburg.de/detailansichtdienst/render?url=https%3A%2F%2Fgeoportal.brandenburg.de%2Fgs-json%2Fxml%3Ffileid%3D7a503f0f-db46-4772-80e3-b27733fd7acd',validity:null})
        }),
        topographic: Object.freeze({
            url: 'https://isk.geobasis-bb.de/mapproxy/basemapde-bebb_2025/service/wms?',
            layers: 'basemapde_farbe_2025',
            source: Object.freeze({id:'de.bb.be.basemapde.2025',name:'Berlin/Brandenburg basemap.de 2025',
                publisher:'GeoBasis-DE/LGB / Geoportal Berlin',attribution:regionalCredit,
                licenseName:'Datenlizenz Deutschland BY 2.0 / Berlin Zero 2.0',
                licenseUri:'https://www.govdata.de/dl-de/by-2-0',
                metadataUri:'https://geoportal.brandenburg.de/detailansichtdienst/render?url=https%3A%2F%2Fgeoportal.brandenburg.de%2Fgs-json%2Fxml%3Ffileid%3De4989df9-4ad1-4e06-b023-63af4727c2bc',validity:null})
        }),
        relief: Object.freeze({
            url: 'https://isk.geobasis-bb.de/mapproxy/dgm/service/wms?',
            layers: 'dgmshade',
            source: Object.freeze({id:'de.bb.be.dgmshade',name:'Berlin/Brandenburg DGM1 hillshade',
                publisher:'GeoBasis-DE/LGB / Geoportal Berlin',attribution:regionalCredit,
                licenseName:'Datenlizenz Deutschland BY 2.0 / Berlin Zero 2.0',
                licenseUri:'https://www.govdata.de/dl-de/by-2-0',
                metadataUri:'https://geoportal.brandenburg.de/detailansichtdienst/render?url=https%3A%2F%2Fgeoportal.brandenburg.de%2Fgs-json%2Fxml%3Ffileid%3D414f568f-639b-4b5a-ba92-57fdac396799',validity:null})
        })
    });

    // Official nationwide basemap.de Web Raster is open CC BY 4.0, unlike
    // basemap.de 3D test services. These WMS images are never prepared offline
    // by FPVManager; offline is deliberately handled by the Swiss package path.
    const germanyBounds = Object.freeze([5.98865,47.30248,15.01700,54.98311]);
    const germanyLicense = 'https://sgx.geodatenzentrum.de/web_public/gdz/lizenz/deu/nutzungsbedingungen_basemapde.pdf';
    const germanyCredit = () => `© GeoBasis-DE / <a href="https://www.bkg.bund.de" target="_blank" rel="noopener">BKG</a> (2026) · <a href="https://creativecommons.org/licenses/by/4.0/" target="_blank" rel="noopener">CC BY 4.0</a> · verändert`;
    const germanyImagery = Object.freeze({
        // No nationwide aerial-photo WMS has been licensed/configured. Show the
        // official topographic map outside the detailed BB ortho-photo region
        // rather than mislabelling Swiss satellite imagery as German imagery.
        satellite: Object.freeze({url:'https://sgx.geodatenzentrum.de/wms_basemapde?',layers:'de_basemapde_web_raster_farbe'}),
        topographic: Object.freeze({url:'https://sgx.geodatenzentrum.de/wms_basemapde?',layers:'de_basemapde_web_raster_farbe'}),
        relief: Object.freeze({url:'https://sgx.geodatenzentrum.de/wms_basemapde_schummerung?',layers:'de_basemapde_web_raster_combshade'})
    });
    const germanImagerySource = Object.freeze({
        id:'de.basemapde.web.raster',name:'basemap.de Web Raster (Deutschland)',
        publisher:'GeoBasis-DE / BKG',attribution:`© GeoBasis-DE / BKG (2026), CC BY 4.0; verändert`,
        licenseName:'CC BY 4.0',licenseUri:'https://creativecommons.org/licenses/by/4.0/',
        metadataUri:'https://basemap.de/produkte-und-dienste/web-raster/',validity:null
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
            // Country-wide base WMS, then higher-detail Berlin/Brandenburg
            // ortho/relief overlays. All remote-only and unavailable offline.
            regionalImagery(style, offline = false) {
                if (!Object.hasOwn(germanyImagery, style)) throw new Error(`Unknown regional map style: ${style}`);
                if (offline || cached() || prepared || configuration.preparedUnavailable ||
                    configuration.regionalImagery === false ||
                    (configuration.imagery != null && configuration.regionalImagery !== true)) return [];
                if (typeof Cesium.WebMapServiceImageryProvider !== 'function') return [];
                const webMercator=new Cesium.WebMercatorTilingScheme();
                const wms=(item, rectangle, tileCredit)=>new Cesium.WebMapServiceImageryProvider({
                    url:item.url,layers:item.layers,rectangle,
                    tilingScheme:webMercator,parameters:{format:'image/png',transparent:true,version:'1.3.0'},
                    maximumLevel:19,credit:tileCredit
                });
                const base=germanyImagery[style];
                const providers=[wms(base,Cesium.Rectangle.fromDegrees(...germanyBounds),
                    new Cesium.Credit(germanyCredit(),true))];
                // LGB DOP20c is licensed for Brandenburg/Berlin only, not for
                // Germany as a whole. Keep it as the actual satellite source.
                if(style==='satellite'||style==='relief'){
                    const local=regionalImagery[style];
                    providers.push(wms(local,Cesium.Rectangle.fromDegrees(...regionalBounds),
                        new Cesium.Credit(`<a href="${local.source.metadataUri}" target="_blank" rel="noopener">${escapeCredit(local.source.name)}</a> · © GeoBasis-DE/LGB, <a href="https://www.govdata.de/dl-de/by-2-0" target="_blank" rel="noopener">dl-de/by-2-0</a> (verändert); © Geoportal Berlin, <a href="https://www.govdata.de/dl-de/zero-2-0" target="_blank" rel="noopener">dl-de/zero-2-0</a>`,false)));
                }
                return providers;
            },
            describeRegionalImagery(style) { return germanyImagery[style] ? germanImagerySource : null; },
            describeLocalRegionalImagery(style) { return regionalImagery[style]?.source ?? null; },
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
        defaultRegionalImagery:regionalImagery, regionalBounds,germanyBounds,germanyImagery,
        prepareCredits,configureCredits,observeCreditHeight,retainStaticCredit,releaseStaticCredit,weatherCredits };
});
