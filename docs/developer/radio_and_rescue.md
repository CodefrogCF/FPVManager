# Live LoS, modeled RF and GPS Rescue

This is an illustrative simulator model, not measured receiver telemetry.
Geometric terrain visibility and modeled RC/video reception are separate.

## Data flow

`LiveRadioController` receives aircraft/home telemetry, selects the configured
antenna position and schedules `LiveTerrainSampler`. The sampler uses the shared
`calculateRadioLink()` route kernel. `set-live-radio-result` carries geometry,
observation quality, generation/request IDs and expiry through the existing
[globe bridge](globe_bridge.md). The renderer's `rf_estimation.js` supplies
independent RC/video estimates; `simulated_failsafe.js` consumes only valid modeled
RC evidence. `free_flight.js` and `rescue_velocity.js` implement flight movement.
Changing the antenna location does not change GPS Rescue home.

## Scheduling and sampling

One request is active with at most the latest aircraft pose pending. Timeout,
provider generation, pause, respawn and disable guards release obsolete work;
older messages cannot replace newer observations. Expiring a displayed result
does not cancel a newer in-flight calculation. Timings use a monotonic clock.

| Horizontal distance | Coarse points | Refinement budget | Clear-coverage gap | Minimum tier interval |
|---|---:|---:|---:|---:|
| 0–6 km | 256 | 384 | 16 m | 200 ms |
| >6–15 km | 128 | 128 | 80 m | 450 ms |
| >15–30 km | 96 | 96 | 165 m | 850 ms |
| >30–50 km | 96 | 96 down to 64 | 300 m | 1500 ms |

Speed-dependent scheduling can lengthen these intervals. Fast near-field flight
can fuse a full midpoint wave into the first query (511 samples near 5–6 km).
Requests retain the 4096-position geometry bound, bounded provider-aware caches
and four terrain tile workers. Sampling stops when a measured obstruction or
adequate clear coverage is available. Sparse clear coverage remains uncertain.

Profiles expire within five seconds from the captured aircraft pose, sooner if
movement/provider changes invalidate them. Near-field position drift is bounded
to 12–24 m with a separate 12 m height guard. A departed ray can reuse only recent,
closely aligned, deep obstruction evidence; it cannot establish a new clear ray.

Vertical and near-vertical links above the station are supported. Fractions on an
exactly vertical profile use the height interval; clearance is measured against
the finite antenna segment. The RF minimum of 1 m applies to spatial antenna
separation. Valid ground samples remain necessary. BKG 3D Beta RF requires a locally prepared GCG2016 grid and is limited to the experimental Rüdersdorf region. Other German coverage remains unavailable.

## Observation quality and flight state

`valid`, `pending`, `stale`, `unknown` and `error` describe observation quality.
They do not mean RC recovery or loss. Failures are classified as `PENDING`,
`TIMEOUT`, `TERRAIN_UNAVAILABLE`, `SAMPLING_ERROR`, `STALE`, `SUPERSEDED`,
`BRIDGE_ERROR` or `INVALID_RESULT`. Optional diagnostics are disabled by default,
retain bounded latency history and update the HUD at most once per second.

Uncertainty alone is a passive HUD notice: it must not initiate Hold, descent,
failsafe or GPS Rescue or intercept pilot controls. Brief gaps pause a pending
loss interval; beyond the five-second evidence horizon an unconfirmed interval
is discarded. A maneuver already activated by confirmed modeled RC loss keeps
its configured recovery criteria and requires fresh valid recovery evidence.

## Link budget and Rescue

`rf_estimation.js` uses each profile's frequency, EIRP, assumed receive threshold,
fade reserve and heuristic terrain loss:

```text
FSPL(dB) = 32.44 + 20 log10(frequency_MHz) + 20 log10(distance_km)
RX estimate = EIRP - FSPL - terrain loss
margin = RX estimate - assumed threshold - fade reserve
```

The score is not RSSI, packet probability or real-world range. Antenna patterns,
multipath, foliage and adaptive radio behavior are incompletely represented.
Preset constants and validation live in `rf_estimation.js` and `rf_profile_settings.dart`;
keep them out of duplicated documentation tables. A free-space-only preview when
terrain is missing cannot supply RC evidence. Blockage alone does not guarantee
RC loss; limited coverage may provide obstruction evidence only under the existing
strict negative-clearance/sample-count rules.

Failsafe is opt-in with configured loss/recovery thresholds, delays and hysteresis.
GPS Rescue uses home, configured rescue altitude/return/climb speeds, normal
collision handling and the selected physics model. GPS Rescue handoff requires the existing fresh recovery evidence and deliberate
pilot action; other failsafe modes retain their configured `autoRecover` option. Manual training input is explicitly labeled and resets independently of
terrain observations.

## Checks

Run signal Dart tests and the full JS suite from [Contributing](../../CONTRIBUTING.md).
The regression set covers vertical paths, mountain ridges, missing data, timeouts,
out-of-order/provider changes, fast motion, uncertainty and Rescue transitions.
Reproduce device behavior using [performance procedures](performance.md); dated
benchmark files are not current phone latency claims.

## Imported scenery RF geometry

The renderer intersects the antenna-to-aircraft segment in each enabled,
resident FPC1 collider's committed local frame. It reuses the collision BVH,
not visual GLB triangles, texture alpha, GPU picking or the aircraft's swept
sphere. Walls, roofs, floors, beams and other structural surfaces are
intersected from either side regardless of physical collision sidedness.
Alignment, scale and terrain calibration follow the same committed transform
as the scenery collider. Visual LOD changes do not select RF geometry.

Each collision asset may specify `rf` with a material and optional thickness
and attenuation overrides (see [package format](scenery_package.md)). The
built-in model uses these illustrative surface losses at 868/5800 MHz and a
nominal material loss in dB/m. They are simulator tuning assumptions, not
published measurements or surveyed construction properties.

| Material | 868 MHz (dB) | 5800 MHz (dB) | Nominal dB/m |
|---|---:|---:|---:|
| Unknown | 12 | 22 | 12 |
| Concrete | 14 | 24 | 20 |
| Reinforced concrete | 22 | 36 | 35 |
| Brick | 9 | 16 | 15 |
| Metal | 35 | 55 | 60 |
| Glass | 3 | 6 | 5 |
| Wood | 4 | 8 | 8 |

Interpolate on log frequency, clamping outside the two reference frequencies.
An explicit thickness adds material loss along the oblique path with a cosine
floor of 0.2. Default dB/m increases by up to 50% with frequency; user overrides
are constant. Surface loss is limited to 100 dB, total scenery loss to 160 dB.
Coincident surface intersections (within 1 cm) count once, retaining the
strongest assumption. Opposite faces are treated as one slab only when the
explicit thickness agrees with separation and normals; the model does not
infer solid volumes or actual thickness from photogrammetry. The conservative
unknown preset is used for unclassified meshes. Material applies to the entire
collision asset, not individual triangles; split distinct materials into meshes.

Direct intersections take priority. An otherwise clear path is checked against
a conservative swept envelope of the configured first Fresnel-zone fraction
using the actual band and length. Possible intrusion adds an illustrative 4 dB
if there are no direct crossings. This is not exact diffraction or a multipath,
reflection, antenna polarization, or material transmission solver. The
terrain profile and user-supplied surface model remain intact. To avoid double
counting potentially overlapping terrain/surface/scenery loss, the link budget
uses the larger of terrain and scenery loss, not their sum. Coincident custom
geometry is also deduplicated; the base visual building tiles are not queried
as a second RF mesh, and terrain-only underlays are excluded. Distinct terrain
and scenery obstacles may therefore have underestimated combined loss.

Live video and control profiles use separate frequency-specific rays in the
existing asynchronous terrain-result path, not within a fixed physics step.
The result augments existing diagnostics with crossings, assumed materials,
scenery loss, coverage completeness and processing time. Explicit external
modeled links remain authoritative. Unavailable terrain does not become a
valid link estimate merely because scenery exists. For incomplete scenery
coverage, clear or merely partial results cannot establish modeled recovery;
confirmed terrain obstruction keeps its previous RF model, and a computed
zero-quality link can retain its positive loss evidence. No new failsafe
thresholds or rescue movement logic are introduced.

Saved-route LoS uses the existing configured route frequency and antenna
height and sends terrain-valid target paths in batches of at most 16. The
renderer yields between rays. The selected profile retains the scenery
summary; its plotted terrain samples remain terrain samples. A scene that
is not resident is not loaded just for analysis. If its declared coverage
intersects the ray, a clear route becomes unknown until the scene loads and
the analysis is repeated. A confirmed terrain or scenery obstruction is
retained. Visual-only scenes have no RF geometry; provider-specific terrain
height-reference restrictions (including the BKG beta gate) still apply.

### Bounded work and benchmark

One band query shares a maximum of 8192 BVH nodes, 4096 triangles and 128 raw
crossings with a 6 ms cooperative deadline. This is a soft CPU deadline,
not a real-time guarantee. Exhaustion produces an incomplete result; no new
mesh copies, GPU readbacks or network requests are made for RF. The existing
live sampling intervals and fixed-step physics clock are unchanged.

Run from the repository root:

```sh
node tool/benchmarks/benchmark_scenery_rf.cjs 200
```

CPU-only reference results are in `tool/benchmarks/reference/scenery_rf_node.json`; see [device measurement](performance.md) for full validation.

### Station-local detailed terrain retention

The decoded-tile cache retains up to 32 requested tiles within 500 m of the
selected station (spawn or custom antenna) as a separate LRU partition within
its existing 128-tile total cap. There is no eager network prefetch or persistent
storage. Station moves discard the station partition; provider changes discard
both partitions. The 120-second tile TTL, exact-coordinate interpolation,
highest-available level checks, four tile workers and RF freshness/obstruction
rules are unchanged. For long rays beyond 7 km, only the station-near subset is
eligible for this cache; the moving remainder keeps native bulk sampling.
If native availability discovery reveals finer station data, those positions
are sampled again. The marker visibility setting does not affect retention.

Station retention is covered by deterministic cache and interpolation tests. Compare actual cache hits and frame pacing on the same device and route.

### German terrain height diagnostic

The BKG terrain RF guard remains active outside the explicitly prepared experimental region. The [basemap.de 3D product documentation](https://sgx.geodatenzentrum.de/web_public/gdz/dokumentation/deu/basemap.de_3d.pdf)
identifies the DGM5 mesh and its horizontal CRS but does not explicitly establish
the height datum of delivered mesh values. DHHN2016 source heights and WGS84
ellipsoid heights must not be interchanged.

For independent control heights, obtain an official local DGM GeoTIFF with
ETRS89/UTM32 or UTM33 and documented unscaled DHHN2016 metre heights. Obtain
the [GCG2016 PROJ grid](https://cdn.proj.org/de_bkg_gcg2016.tif) and place it
in a local directory. With the scenery conversion dependencies installed, run
`tool/scenery/reference/prepare_bkg_rf_controls.py --help`. Supply the DEM,
`--source` (edition and attribution), `--grid-dir`, `--confirm-dhhn2016`,
`--output controls.json` and at least three distinct `--point LON LAT` pairs
on stable, flat, unobstructed ground inside the raster. The tool rejects
missing grids, invalid heights and steep or duplicate sample cells. The
result records both independent normal and ellipsoid heights at actual DEM
pixel centers. Repeat with separate DEMs across different regions.

From the repository root, start `python -m http.server 8765 --bind 127.0.0.1`
and open `http://127.0.0.1:8765/tool/scenery/reference/bkg_rf_probe.html`.
Select the control JSON and run the comparison. It uses the existing BKG
runtime-only transport and RF terrain tile cache, then compares cold and warm
sampling with native Cesium most-detailed sampling and the independent heights.
Only export the diagnostic report, not provider tiles. Local agreement (2 m RMS,
3 m maximum residual as initial diagnostic thresholds) is not certification:
confirm provider metadata and representative regions, then validate live/route
RF, coverage, provider transitions and real device performance. The diagnostic
never changes application settings or authorizes RF automatically.

### Local Rüdersdorf RF test

The September 2026 [provider update](https://basemap.de/die-basemap-de-3d-bleibt-vorerst-im-beta-status/) retains beta status. Keep explicit test consent and runtime-only transport. The local probe matched DHHN2016 at eight controls; a ninth southern point differed by 14 m and is outside the test rectangle. This is a local experimental hypothesis, not nationwide validation.

Generate the small local correction grid from the actual GCG2016 raster and exported probe report:

```powershell
python tool/scenery/reference/prepare_bkg_rf_grid.py --grid "$HOME/Downloads/de_bkg_gcg2016.tif" --report "$HOME/Downloads/bkg-rf-probe.json"
```

Rebuild the app after generation. The unprepared default asset is null and fails closed. The grid covers 13.775–13.800° E, 52.481–52.491° N; positions outside return unavailable. GCG2016 is credited to BKG, CC BY 4.0 (local interpolated derivative). Eight independent DGM control heights are checked once against the current terrain provider before RF sampling; a failed check is retried after a cooldown. The existing RF cache retains native heights; query responses and live poses are converted to ellipsoid heights, while rendered RF paths and scenery RF intersections use the native scene frame. No per-sample network request is added. General elevation queries, absolute route preview/playback and recording semantics are unchanged; do not use unverified recordings as absolute RF targets. Device and regional coverage validation remain required.
