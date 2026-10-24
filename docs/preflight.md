# Preflight and signal analysis

Open **Preflight & Telemetry** in the main menu. Checklists start with battery,
propeller, GPS, radio, video, weather and airspace items. Edit one item per line,
assign a drone/flight plan, or save a reusable template. Starting from a template
creates an independent, unchecked checklist. Changing its drone/plan resets
completion. Completion stays on this device;
start a new checklist for every flight. A checklist does not grant authorization.

In the route editor, choose **Route options → Terrain & radio path**. Set the
pilot coordinates, antenna height above terrain and actual radio frequency.
Analyze, close the sheet to inspect the 3D overlay, then **Save** the route to
retain the settings. Changing inputs or terrain invalidates results. Orange
marks possible LOS obstruction, purple Fresnel intrusion, cyan no obstruction at
sampled positions and gray unknown. The selected path shows a Fresnel wireframe.

The LOS model uses a straight WGS84 ECEF chord, including Earth curvature, and
Cesium/swisstopo terrain in WGS84 ellipsoidal heights. Only explicit AGL or WGS84
route heights are evaluated; the map's 30 m preview is not an analysis input.
Route targets are at most 100 m apart; communication profiles at most 25 m apart.
Limits: 128 targets, 16384 terrain samples, 50 km communication paths. Shorten or
split routes exceeding these limits. Sampling may miss narrow features.

First Fresnel radius: `sqrt(λ*d1*d2/(d1+d2))`, with wavelength and distances in
metres. The configurable clearance defaults to 60% of the radius. See
[ITU-R P.526-15, Annex 1 §2.1](https://www.itu.int/dms_pubrec/itu-r/rec/p/R-REC-P.526-15-201910-S!!PDF-E.pdf).
This is geometric screening, not a full ITU propagation implementation.
Refraction, diffraction loss, multipath, interference, antenna patterns and
received power are not modeled. It cannot guarantee reception or range.

No building/vegetation service is connected. Optionally import local surface
observations through **Import surface CSV**. Each record adds a constant AGL
height inside a circular footprint; overlapping records use the greatest height.
The source is retained. Up to 100 observations are stored with the route:

```csv
latitude,longitude,height_m_agl,radius_m,kind,source
47.0,8.003,18,30,vegetation,Local site observation 2026-10-24
```

Kinds: `building`, `vegetation`, `other`. Heights: 0–1000 m AGL; radius: 1–1000 m.
These observations are approximate and incomplete. Only the sampled centerline
is checked; this does not test every point of the Fresnel volume. The terrain
model itself does not establish the absence of buildings, vegetation or cables.

## Telemetry import and calibration

Import a CSV in **Preflight & Telemetry → Telemetry**. Preview its measurements,
choose the drone and flight plan, then confirm local storage. Raw bytes remain
in the personal database across restarts, independently of OSINT/map caches.
Delete a log from the same library to remove its raw data. Limits: 50 logs or
100 MiB total; no automatic upload or redistribution.

FPVManager telemetry CSV v1 is UTF-8, comma separated, decimal dot, with explicit
SI column names. `time_s` is elapsed time; airspeed is m/s, voltage V, current A:

```csv
time_s,airspeed_m_s,voltage_v,current_a
0,0,16,8
10,10,15.8,12
20,15,15.6,16
```

`groundspeed_m_s` may replace `airspeed_m_s`, but requires an explicit still-air
approximation for model comparison. Export/convert other flight-controller
formats to these columns before importing. One continuous flight is required:
2–20000 samples, at most 4 MiB, strictly increasing times, gaps ≤30 s and duration
≤6 h. Empty/invalid required readings are rejected, not replaced with zero.

A subset of [EdgeTX SD Logs](https://manual.edgetx.org/color-radios/model-settings/special-functions)
is also supported: `Date` (`YYYY-MM-DD`), `Time` (`HH:mm:ss.SSS`), one of
`GSpd(kmh)`, `GSpd(km/h)`, `GSpd(m/s)`, `GSpd(kts)`, `Curr(A)` and one of
`VFAS(V)`, `Bat(V)`. Names/units follow the
[EdgeTX CSV writer](https://github.com/EdgeTX/edgetx/blob/main/radio/src/logs.cpp).
Renamed, duplicate or unavailable required sensors and logs without calendar
timestamps require conversion. GPS speed stays identified as ground speed.
Calendar timestamps are used only for relative intervals; no timezone is inferred.

Duration includes all recorded idle time. Energy integrates `V × A` with the
trapezoidal rule; mean speed is time weighted. The comparison evaluates the
associated route's level-flight power curve at recorded speeds, using its mass
correction and no extrapolation. Complete route heights/speeds additionally
allow comparison of the planned outbound duration and mean speed. Check that
the recording actually covers that path; idle/return time is not auto-trimmed.

Calibration previews a `measured Wh / modeled Wh` factor, limited to 0.25–4.
Confirmation scales only the associated saved route's power curve and records
the telemetry ID as its source. A changed route must be reopened before applying
an old preview. Keep comparable mass, equipment and flight conditions: climbs,
maneuvers, wind and sensor errors can distort this fit. Drone specifications and
other routes are not automatically changed. Keep an original curve if needed;
the raw telemetry remains available for re-evaluation.
