(function (root, factory) {
    const api = factory();
    if (typeof module === 'object' && module.exports) module.exports = api;
    else root.FPVVegetationModels = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
    'use strict';

    const sourcePath = '/ch.swisstopo.vegetation.3d/v1/';
    const source = `https://3d.geo.admin.ch${sourcePath}`;
    const registries = new WeakMap();
    const degrees = 180 / Math.PI;

    function repairSourceIndex(json) {
        // The official root mixes revisioned external JSON with bare i3dm
        // paths. The latter are available under the same published revision.
        const versions = new Set(), unversioned = [];
        const stack = json?.root ? [json.root] : [];
        while (stack.length) {
            const node = stack.pop();
            const content = node.content;
            const field = content?.uri === undefined ? 'url' : 'uri';
            const uri = content?.[field];
            if (typeof uri === 'string') {
                const match = /^(\d{8})\/tileset\d+\.json$/.exec(uri);
                if (match) versions.add(match[1]);
                if (/^\d+\/\d+\/\d+\.i3dm$/.test(uri)) unversioned.push({content, field, uri});
            }
            for (const child of node.children ?? []) stack.push(child);
        }
        if (versions.size === 1) {
            const [version] = versions;
            for (const {content, field, uri} of unversioned) content[field] = `${version}/${uri}`;
        }
        return json;
    }

    function sourceResource(C, url) {
        if (url !== `${source}tileset.json` || !C.Resource?.prototype?.fetchJson) return url;
        const resource = new C.Resource({url});
        const clone = resource.clone, fetchJson = resource.fetchJson;
        let fetched = false;
        // fromUrl and loadJson each derive their own Resource. Preserve this
        // root-only JSON fix through those clones without modifying Cesium.
        function cloneIndex(...args) {
            const copy = clone.apply(this, args);
            if (!fetched && copy.url === url) {
                copy.clone = cloneIndex;
                copy.fetchJson = function (...args) {
                    if (this.url !== url || fetched) return fetchJson.apply(this, args);
                    const pending = fetchJson.apply(this, args);
                    if (!pending) return pending;
                    fetched = true;
                    return pending.then(repairSourceIndex);
                };
            }
            return copy;
        }
        resource.clone = cloneIndex;
        return resource;
    }

    function modelUrl(base, uri, assetBase, composition) {
        if (typeof uri !== 'string' || !base.startsWith(source)) return;
        const tree = new URL(uri, base);
        if (!tree.href.startsWith(source) || !/^\d{8}\/Tree-[123]\.glb$/.test(tree.pathname.slice(sourcePath.length))) return;
        const tile = new URL(base);
        // One choice per existing instance group. Stable across requests and
        // independent of the camera and the order in which tiles arrive.
        const key = `${tile.pathname}:${tile.searchParams.get('compositeIndex') ?? ''}:${tree.pathname}`;
        let hash = 2166136261;
        for (let i = 0; i < key.length; ++i) hash = Math.imul(hash ^ key.charCodeAt(i), 16777619);
        hash = Math.imul(hash ^ (hash >>> 16), 0x85ebca6b);
        hash = (hash ^ (hash >>> 13)) >>> 0;
        const family = (hash >>> 8) / 0x1000000 < (composition() ?? .5) ? 'broadleaf' : 'conifer';
        const variant = (hash & 255) % 3 + 1;
        return new URL(`tree-${family}-${variant}.glb`, assetBase).href;
    }

    function tileComposition(C, tile, sample) {
        const region = tile._header?.boundingVolume?.region;
        if (region?.length === 6 && region[0] <= region[2]) {
            return sample((region[0] + region[2]) * .5 * degrees, (region[1] + region[3]) * .5 * degrees);
        }
        const center = tile.boundingSphere?.center;
        const point = center && C.Ellipsoid?.WGS84?.cartesianToCartographic(center);
        return point ? sample(point.longitude * degrees, point.latitude * degrees) : undefined;
    }

    function attach(C, tileset, {sample = () => undefined, assetBase} = {}) {
        const factory = C.Cesium3DTileContentFactory;
        if (typeof factory?.i3dm !== 'function' || !C.Resource?.prototype?.getDerivedResource) return;
        assetBase ??= new URL('assets/vegetation/', globalThis.location.href);

        let registry = registries.get(factory);
        if (!registry) {
            const original = factory.i3dm;
            const owners = new WeakMap();
            let count = 0;
            async function load(tileset, tile, resource, buffer, offset) {
                const owner = owners.get(tileset);
                if (!owner || !resource.url.startsWith(source)) return original(tileset, tile, resource, buffer, offset);
                let replaced = false;
                const scoped = resource.clone();
                const clone = scoped.clone;
                // I3dmLoader clones its base resource before resolving the
                // external glTF. Scope the substitution to that clone only.
                scoped.clone = function (...args) {
                    const copy = clone.apply(this, args);
                    const derive = copy.getDerivedResource;
                    copy.getDerivedResource = function (options) {
                        let url;
                        try {
                            url = modelUrl(resource.url, options.url, owner.assetBase, () => tileComposition(C, tile, owner.sample));
                        } catch (_) { /* retain the source model for unexpected metadata */ }
                        if (!url) return derive.call(this, options);
                        replaced = true;
                        return new C.Resource({url});
                    };
                    return copy;
                };
                try {
                    return await original(tileset, tile, scoped, buffer, offset);
                } catch (error) {
                    if (!replaced || owners.get(tileset) !== owner || tileset.isDestroyed?.() ||
                        tile.isDestroyed?.() || tile._request?.cancelled ||
                        (C.RequestState && tile._request?.state === C.RequestState.CANCELLED)) throw error;
                    return original(tileset, tile, resource, buffer, offset);
                }
            }
            registry = {
                set(tileset, owner) {
                    if (!owners.has(tileset) && count++ === 0) factory.i3dm = load;
                    owners.set(tileset, owner);
                },
                delete(tileset, owner) {
                    if (owners.get(tileset) !== owner) return;
                    owners.delete(tileset);
                    if (--count === 0 && factory.i3dm === load) factory.i3dm = original;
                },
            };
            registries.set(factory, registry);
        }
        const owner = {sample, assetBase};
        registry.set(tileset, owner);
        return () => registry.delete(tileset, owner);
    }

    return {attach, sourceResource};
});
