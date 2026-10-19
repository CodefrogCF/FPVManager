# Coordinates and height references

## Horizontal coordinates

Application coordinates use WGS84 latitude/longitude in decimal degrees. Named
Dart fields are `latitude` and `longitude`; GeoJSON and Cesium's `fromDegrees`
use **longitude, latitude**. LV95 (CH1903+, EPSG:2056) uses **easting, northing**
in metres. A horizontal CRS alone does not define a height datum.

`GeoCoordinateService` implements swisstopo's approximate WGS84/LV95 formulas,
with a conservative Swiss bounding box and finite-input checks. The UI labels
these results as approximate; they are intended for map navigation. The bounds
are not a Swiss border polygon or a guarantee of service/data coverage.
Tests use the published swisstopo example at LV95 E 2,700,000 / N 1,100,000 and
check both directions, round trips and invalid inputs.

An explicitly requested REFRAME conversion returns its own LV95 coordinates.
The dialog then displays those coordinates and identifies REFRAME as their source.
REFRAME receives longitude as `easting` and latitude as `northing` on its
`wgs84tolv95` endpoint; those unusual parameter names do not change the input CRS.

## Vertical references

| Value | Meaning in FPVManager |
|---|---|
| `wgs84Ellipsoid` | Metres above the WGS84 reference ellipsoid; not AMSL |
| `besselEllipsoid` | Metres above the Swiss Bessel ellipsoid; intermediate REFRAME value |
| `ln02` | Swiss national map/levelling heights, displayed as AMSL (Swiss LN02) |
| `lhn95` | Swiss orthometric heights, displayed as AMSL (Swiss LHN95) |
| `unverified` | Unknown reference; cannot be converted or used in AGL arithmetic |
| AGL | Relative vertical distance above terrain at the same horizontal position; not a datum |

AMSL describes a height relative to mean sea level, but a usable number still
needs a named vertical reference. LN02 usual heights and LHN95 orthometric
heights are distinct Swiss systems and are not interchangeable. The app uses
LN02 for the optional Swiss ground-height display. It does not apply a fixed
ellipsoid/geoid offset or treat a raw ellipsoid value as AMSL.

### Terrain sampling

swisstopo's terrain service provides Cesium Quantized Mesh tiles. Cesium's
`sampleTerrain`/`sampleTerrainMostDetailed` returns heights relative to its
reference ellipsoid, rather than mean sea level. The renderer explicitly creates
the provider with `Ellipsoid.WGS84` and returns
`heightReference: "wgs84Ellipsoid"` with each sampled height. Dart requires that
reference, the requested coordinates, a finite value and a sampling method before
constructing a typed `TerrainElevation`. Missing/unknown/mismatched references
are rejected. Ellipsoid fallback mode cannot provide a detailed terrain sample.

Picked map-point heights come from the rendered mesh, which can have a coarser
level of detail than an explicit terrain query. Their display states the height
reference as well. A picked point without reference metadata remains unverified.
An old query result does not open a dialog after selection changes. Camera
`flyTo` altitude is an ellipsoid height used for visualization; a saved-spot
focus range is camera-to-target distance, not an aircraft AGL height.

### Optional Swiss height conversion

The dialog keeps the sampled WGS84 value visible and performs no automatic
REFRAME request. **Convert to Swiss height (LN02)** sends the selected
position and ground height to `geodesy.geo.admin.ch`, as explained next
to the button. The conversion is:

1. `wgs84tolv95`: WGS84 latitude/longitude plus ellipsoidal height -> LV95 plus
   **Bessel ellipsoidal height**. This response is not yet LN02.
2. `besseltoln02`: that LV95 position and Bessel height -> **LN02**.

`ReframeWgs84Service` and `ReframeHeightService` use typed references, finite-number
and region checks, bounded response sizes and 15-second timeouts per request.
Height-only responses must retain the requested horizontal position, allowing
1 cm for request rounding. Failure leaves the original value available, shows no
invented AMSL result and permits retry. Closing the dialog ignores late results.
The general height service also supports the documented Bessel/LN02/LHN95 paths;
it does not directly transform a WGS84 height through a Bessel-only endpoint.

### AGL calculation

`AboveGroundHeight` is a separate relative-height type. At a fixed horizontal
position, the calculator uses:

```text
absolute height = ground height + entered AGL
AGL = absolute height - ground height
```

The ground and absolute heights must have the **same known datum**. The service
rejects mixed LN02/LHN95/ellipsoid references, unverified heights, nonfinite values
and overflow. An entered AGL must be nonnegative; the inverse calculation may
return a negative AGL for a position below the terrain model. Zero AGL is the
sampled ground itself. Decimal comma input is accepted.

The dialog calculates a WGS84 height at the entered AGL, and an LN02 height only
after ground conversion succeeds. This is a local vertical-offset calculation,
not measured aircraft altitude, a flight-plan editor, a trajectory, pressure
altitude or verified obstacle clearance. Model resolution and vertical-datum
accuracy remain limits; adding an offset does not improve the terrain model.
Existing waypoint records with `heightReference = unverified` stay unverified.

## Verification and sources

Unit/widget tests cover coordinate examples, typed terrain-response validation,
REFRAME chaining and invalid responses, datum/AGL arithmetic, opt-in requests,
failure/retry, stale selection, closing pending work and small-screen layout.
Normal tests use fixed fixtures, without live network dependencies. Live service
probes and browser/device checks are separate from those tests.

- [swisstopo approximate coordinate formulas, December 2016](https://www.swisstopo.admin.ch/dam/en/sd-web/KLRCX9XIdXDu/ch1903wgs84-EN.pdf)
- [swisstopo REFRAME service overview](https://www.swisstopo.admin.ch/en/rest-api-geoservices-reframe-web)
- [REFRAME API manual, sections 4.1 and 4.12](https://www.swisstopo.admin.ch/dam/en/sd-web/3xmcWvfxgG6X/Report16-03.pdf)
- [geo.admin.ch terrain service](https://docs.geo.admin.ch/visualize-data/terrain-service.html)
- [Cesium terrain-sampling contract](https://cesium.com/learn/cesiumjs/ref-doc/global.html#sampleTerrain)
- [swisstopo geoid and height relationship](https://www.swisstopo.admin.ch/en/geoid-en)
