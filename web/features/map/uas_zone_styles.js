/* FPVManager v0.4.0 classification palette for CesiumJS 1.145.
 * BAZL CodeZoneType (properties.type) defines the zone representation, commonly
 * 'COMMON'. The restriction level is CodeRestrictionType
 * (properties.restriction), including explicit .MTOM_* and .CTR variants.
 * Unrecognised restriction codes always remain grey; no color is clearance.
 */
(function (root, factory) {
    const api = factory();
    if (typeof module === 'object' && module.exports) module.exports = api;
    if (root) root.FPVUasZoneStyles = api;
})(typeof window !== 'undefined' ? window : null, function () {
    'use strict';
    const colors = Object.freeze({
        prohibited: '#d32f2f',
        authorisation: '#ef6c00',
        conditional: '#f9a825',
        informational: '#1976d2',
        unknown: '#757575',
    });
    // Official Swiss CodeRestrictionType v1.0 variants have distinct map
    // colors to avoid hiding weight/CTR differences behind a single orange.
    const restrictionColors = Object.freeze({
        'REQ_AUTHORISATION.MTOM_ALL': '#ef6c00',
        'REQ_AUTHORISATION.MTOM_FROM': '#b8860b',
        'REQ_AUTHORISATION.CTR': '#7b1fa2',
    });
    function normalizedCode(value) {
        return String(value == null ? '' : value).trim().toUpperCase()
            .replace(/-/g, '_').replace(/^REQ_AUTHORIZATION(?=\.|$)/, 'REQ_AUTHORISATION');
    }
    function classify(restriction) {
        switch (normalizedCode(restriction)) {
        case 'PROHIBITED': return 'prohibited';
        case 'REQ_AUTHORISATION':
        case 'REQ_AUTHORISATION.MTOM_ALL':
        case 'REQ_AUTHORISATION.MTOM_FROM':
        case 'REQ_AUTHORISATION.CTR': return 'authorisation';
        case 'CONDITIONAL': return 'conditional';
        case 'NO_RESTRICTION': return 'informational';
        default: return 'unknown';
        }
    }
    function colorFor(restriction) {
        const code = normalizedCode(restriction);
        return restrictionColors[code] || colors[classify(code)];
    }
    function sourceValue(value, time) {
        // Cesium Entity properties are ConstantProperty/Property instances.
        if (value && typeof value.getValue === 'function') return value.getValue(time);
        return value;
    }
    function applyToDataSource(dataSource, Cesium, opacity, time) {
        if (!dataSource || !dataSource.entities || !Array.isArray(dataSource.entities.values) ||
            !Cesium || !Cesium.Color || !Number.isFinite(opacity) || opacity < 0 || opacity > 1) {
            throw new TypeError('Invalid Cesium UAS data source or opacity');
        }
        const counts = {prohibited: 0, authorisation: 0, conditional: 0,
            informational: 0, unknown: 0};
        for (const entity of dataSource.entities.values) {
            if (!entity || !entity.polygon) continue;
            const props = entity.properties;
            // NEVER classify by props.type: in Swiss GeoJSON it is generally
            // COMMON (CodeZoneType), not a restriction level.
            const restriction = props ? sourceValue(props.restriction, time) : undefined;
            const category = classify(restriction);
            const outline = Cesium.Color.fromCssColorString(colorFor(restriction));
            // Per-feature color is visual guidance, not legal classification of
            // aircraft class, altitude or actual activation during a flight.
            entity.polygon.material = outline.withAlpha(opacity);
            entity.polygon.outline = true;
            entity.polygon.outlineColor = outline.withAlpha(Math.min(1, opacity + 0.45));
            counts[category]++;
        }
        return counts;
    }
    return Object.freeze({colors, restrictionColors, classify, colorFor, applyToDataSource});
});
