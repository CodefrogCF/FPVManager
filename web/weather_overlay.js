/* FPVManager weather samples: no interpolation, 3-D heights or claimed native resolution. */
(function (root) {
    'use strict';
    function rgb(kind, value) {
        if (kind === 'wind') {
            if (value < 3) return [50, 161, 114];
            if (value < 7) return [248, 196, 73];
            if (value < 12) return [237, 132, 45];
            return [205, 64, 65];
        }
        if (value < 0.2) return [72, 160, 194];
        if (value < 1) return [52, 116, 218];
        if (value < 3) return [99, 76, 193];
        return [157, 67, 177];
    }
    function validate(command) {
        if (!command || !['wind', 'precipitation'].includes(command.kind) ||
            !Array.isArray(command.cells) || command.cells.length > 100 ||
            typeof command.source !== 'string' || command.source.length > 200 ||
            !Number.isFinite(Date.parse(command.timestampUtc)) ||
            ![1000, 5000].includes(command.gridSpacingMeters)) {
            throw new Error('Invalid weather overlay metadata');
        }
        for (const c of command.cells) {
            if (![c.west, c.south, c.east, c.north, c.value].every(Number.isFinite) ||
                c.west < -180 || c.east > 180 || c.south < -90 || c.north > 90 ||
                c.west >= c.east || c.south >= c.north || c.value < 0) {
                throw new Error('Invalid weather grid sample');
            }
        }
    }
    function showLegend(command) {
        const element = typeof document === 'undefined' ? null : document.getElementById('weather-legend');
        if (!element) return;
        if (!command) { element.hidden = true; element.textContent = ''; return; }
        const legend = command.kind === 'wind'
            ? 'Wind (m/s): green <3 · yellow 3–7 · orange 7–12 · red ≥12'
            : 'Precipitation (mm/h): cyan <0.2 · blue 0.2–1 · violet 1–3 · purple ≥3';
        element.textContent = `Open-Meteo sampled grid · ${command.timestampUtc} · ${legend} · ${command.gridSpacingMeters / 1000} km display cells, no interpolation; native model resolution varies and is not independently verified.`;
        element.hidden = false;
    }
    function create(Cesium, viewerFn) {
        let source = null;
        let previous = null;
        async function replace(command) {
            validate(command);
            const viewer = viewerFn();
            if (!viewer) throw new Error('Globe is not ready');
            if (!source) {
                source = new Cesium.CustomDataSource('Weather samples – Open-Meteo');
                await viewer.dataSources.add(source);
            }
            source.entities.removeAll();
            for (let index = 0; index < command.cells.length; index++) {
                const cell = command.cells[index];
                const [r, g, b] = rgb(command.kind, cell.value);
                const color = Cesium.Color.fromBytes(r, g, b, 105);
                source.entities.add({
                    id: `weather-${index}`,
                    name: `Open-Meteo ${command.kind} sample`,
                    polygon: {
                        hierarchy: Cesium.Cartesian3.fromDegreesArray([
                            cell.west, cell.south, cell.east, cell.south,
                            cell.east, cell.north, cell.west, cell.north
                        ]),
                        material: color,
                        classificationType: Cesium.ClassificationType.TERRAIN,
                        heightReference: Cesium.HeightReference.CLAMP_TO_GROUND,
                        outline: false
                    },
                    properties: {
                        sampledValue: cell.value,
                        sampledAtUtc: command.timestampUtc,
                        sampledSource: command.source,
                        gridLatitudeDegrees: command.gridSpacingLatitudeDegrees,
                        gridLongitudeDegrees: command.gridSpacingLongitudeDegrees
                    }
                });
            }
            source.show = true;
            previous = command;
            showLegend(command);
            viewer.scene.requestRender();
            return {sampleCount: source.entities.values.length};
        }
        function clear() {
            if (source) { source.entities.removeAll(); source.show = false; viewerFn()?.scene.requestRender(); }
            previous = null;
            showLegend(null);
            return {};
        }
        function dispose() { clear(); if (source) viewerFn()?.dataSources.remove(source, true); source = null; }
        return {replace, clear, dispose, get current() { return previous; }};
    }
    root.FPVWeatherOverlay = {create, validate, rgb};
})(typeof globalThis !== 'undefined' ? globalThis : this);
