# Coordinates and heights

## Position and datum

App positions use WGS84 decimal-degree **latitude, longitude**. GeoJSON and
Cesium coordinate arrays use **longitude, latitude**. Swiss LV95 (CH1903+,
EPSG:2056) uses **easting, northing** in metres. A horizontal CRS does not identify
the height reference.

Local WGS84/LV95 conversion uses swisstopo's approximate formulas inside conservative
Swiss bounds. It supports navigation, not surveying or a border/coverage guarantee.
Explicit online REFRAME conversion reports its own coordinates separately.

| Reference | Meaning in the app |
|---|---|
| WGS84 ellipsoid | Metres above the ellipsoid; not AMSL |
| Bessel ellipsoid | Intermediate Swiss ellipsoidal height |
| LN02 | Swiss national map/levelling height |
| LHN95 | Swiss orthometric height, distinct from LN02 |
| AGL | Vertical offset above terrain at the same horizontal position; not a datum |
| Unverified | Unknown reference; excluded from height conversion/AGL arithmetic |

Terrain queries return WGS84 ellipsoidal height; rendered mesh sampling can use
coarser loaded detail. A flat fallback has no measured height. Camera altitude
and camera-to-target distance are visualization values, not aircraft AGL. UAS
limits keep their supplied units and AGL/AMSL labels; no unspecified AMSL datum
is inferred.

## Conversion and local AGL arithmetic

**Convert to Swiss height (LN02)** explicitly sends the selected position/height
to REFRAME. `wgs84tolv95` yields LV95 and Bessel height; `besseltoln02` yields LN02.
The first service names its WGS84 longitude/latitude parameters `easting` and
`northing`. Inputs/regions are checked and failures retain the original value;
there is no substitute fixed geoid offset.

The local calculator uses `absolute = ground + AGL`, or the inverse subtraction.
Both heights must have the same known reference. Entered AGL is finite and
nonnegative; an inverse result can be negative. Unknown/mixed references and
overflow are rejected. This arithmetic neither improves terrain accuracy nor
establishes obstacle clearance.

## Published aviation obstacles

The [BAZL/Skyguide product specification](https://www.bazl.admin.ch/dam/de/sd-web/CpfHnV604RSJ/dps_obstacle_datenset_aixm.pdf)
defines the dataset's absolute KML elevations as LN02. The app uses the bundled
CHGeo2004/HTRANS grid for an ETRS89 ellipsoid conversion, used as a WGS84 display
approximation. Original values remain in the source attributes.

For an isolated source Point with plausible `maxHeightAGL`, both rendered foot
and tip use the same currently rendered terrain sample:

```text
foot = rendered ground
rendered tip = rendered ground + source maxHeightAGL
```

Both move together when terrain detail changes. If that ground sample is missing,
the AGL-derived stem/marker is hidden. The display can differ from the converted
published absolute height; it is not a resurvey. A Point without valid AGL can
retain a published absolute elevation but receives no invented vertical stem.

For a line/polygon, maximum AGL can occur anywhere along/across the feature. It
is not applied to every vertex. Additional KML label Points are not rendered as
separate floating obstacles. Cables keep their published 3D vertices; sag is not
reconstructed. Supported obstacle models use supplied heights but illustrative
shape/width/heading. These rules concern visualization, not measured clearance.

## Simulation and imported routes

HUD AGL is relative to local rendered/modelled ground; **H START** is relative
to spawn ground. Synthetic tunnel floors/portals are estimated from source axes
and road/terrain context. Connected windows preserve the established corridor,
but the result is not surveyed tunnel geometry. Optional native-model contact
uses a bounded approximation; it does not change source height references.

GeoJSON renders declared WGS84 ellipsoid elevations directly. GPX or imported
absolute heights without a declared datum stay unverified. A marked 30 m AGL
route preview is a display fallback and is not an analysis input or an assigned
real-world altitude.

## Reference documents

- [swisstopo coordinate formulas](https://www.swisstopo.admin.ch/dam/en/sd-web/KLRCX9XIdXDu/ch1903wgs84-EN.pdf)
- [REFRAME overview](https://www.swisstopo.admin.ch/en/rest-api-geoservices-reframe-web) and [API manual](https://www.swisstopo.admin.ch/dam/en/sd-web/3xmcWvfxgG6X/Report16-03.pdf)
- [Terrain service](https://docs.geo.admin.ch/visualize-data/terrain-service.html)
- [swisstopo geoid and heights](https://www.swisstopo.admin.ch/en/geoid-en)
- [Privacy and conversion requests](privacy_and_permissions.md)
