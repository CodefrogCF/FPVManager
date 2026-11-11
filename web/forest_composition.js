(function (root, factory) {
    if (typeof module === 'object' && module.exports) {
        module.exports = factory(require('./dated_imagery_overlay.js').wgs84ToLv95);
    } else {
        root.FPVForestComposition = factory(root.FPVDatedImagery?.wgs84ToLv95);
    }
})(typeof globalThis === 'undefined' ? this : globalThis, function (wgs84ToLv95) {
    'use strict';

    // 320 m overview of the BAFU / WSL Forest Type NFI 2023 raster. The
    // source describes broadleaf probability over a grid, without assigning
    // species or leaf types to individual trees.
    const defaultUrl = 'assets/vegetation/forest_composition.bin';
    const headerBytes = 32;
    const magic = [70, 80, 86, 70, 79, 82, 49, 0]; // FPVFOR1\0

    function parse(data) {
        if (!wgs84ToLv95) throw new Error('Forest composition needs the LV95 projection');
        const bytes = data instanceof Uint8Array ? data : new Uint8Array(data);
        if (bytes.length < headerBytes || magic.some((value, index) => bytes[index] !== value)) {
            throw new Error('Invalid forest composition header');
        }
        const header = new DataView(bytes.buffer, bytes.byteOffset, headerBytes);
        const width = header.getUint32(8, true), height = header.getUint32(12, true);
        const west = header.getInt32(16, true), south = header.getInt32(20, true);
        const east = header.getInt32(24, true), north = header.getInt32(28, true);
        if (!width || !height || east <= west || north <= south ||
            width * height !== bytes.length - headerBytes) {
            throw new Error('Invalid forest composition dimensions');
        }
        const cellsPerEastMetre = width / (east - west);
        const cellsPerNorthMetre = height / (north - south);
        return (longitude, latitude) => {
            if (!Number.isFinite(longitude) || !Number.isFinite(latitude) ||
                longitude < 5 || longitude > 11 || latitude < 45 || latitude > 49) return undefined;
            const [easting, northing] = wgs84ToLv95(latitude, longitude);
            const x = Math.floor((easting - west) * cellsPerEastMetre);
            const y = Math.floor((north - northing) * cellsPerNorthMetre);
            if (x < 0 || x >= width || y < 0 || y >= height) return undefined;
            const value = bytes[headerBytes + y * width + x];
            return value <= 100 ? value / 100 : undefined;
        };
    }

    function create({url = defaultUrl, fetcher = globalThis.fetch} = {}) {
        let loading, sampleGrid;
        return {
            load() {
                loading ??= (async () => {
                    try {
                        const response = await fetcher(url);
                        if (!response.ok) return false;
                        sampleGrid = parse(await response.arrayBuffer());
                        return true;
                    } catch (_) {
                        return false;
                    }
                })();
                return loading;
            },
            sample(longitude, latitude) {
                return sampleGrid?.(longitude, latitude);
            }
        };
    }

    return {create, parse};
});
