# Changelog

## [0.20.0] - 2026-11-28

### Performance and scene reliability

- Add local route playback benchmarks with layer/RF and Structures LOD/cache/support matrices, separate warmup statistics, JSON/CSV exports and stationary rotation checks. Standardized comparison profiles can enable or disable schematic tunnels and obstacle models without saving overrides.
- Stabilize synthetic bridge supports with source-anchored stations, validated session caches, bounded initial discovery, adaptive GPU-pick pacing and distance/frustum retention. Reuse independently confirmed heights; preserve geometry across visual-only portal updates.
- Tune Structures independently of buildings/vegetation, retaining conservative cache defaults and a targeted 48 MiB Balanced/navigation budget for Xclipse 920. Benchmark overrides remain explicit.
- Improve renderer timing, bridge-cache and geometry diagnostics; distinguish requested layers, admitted geometry, incomplete data and verified comparisons. Preserve RF and collision precision.
- Fix benchmark flight initialization, render-scale/wind profile handling, export capacity and Chromium regression-test isolation.
- Consolidate current procedures, measured evidence and limits in the [performance guide](docs/developer/performance.md).

### Added

- Real-world scenery management with georeferenced local GLB/glTF imports, external OGC 3D Tiles, interactive alignment, control points, independent collision meshes and selective replacement of base buildings and terrain.
- Distance-based scenery streaming, visual LOD alternatives, bounded loading and memory budgets, and independent physical geometry.
- Portable `.fpvscenery` packages with offline assets, integrity checks, versioned metadata, explicit redistribution permissions and backup references.
- Material-aware scenery RF attenuation, estimated Fresnel obstruction, live and saved-route analysis with separate RC/video links.
- External geospatial conversion tools for CityGML, DEM, orthophotos, classified LAS/LAZ and reconstructed meshes; reproducible reference routes and validation for the experimental Rüdersdorf environment.
- Persistent Developer options and an optional performance overlay with frame, physics, terrain, scenery and RF diagnostics.
- Regional German map layers and opt-in BKG 3D test service; its unverified height reference remains unavailable for RF analysis.

### Changed

- Reuse station-local terrain tiles and unchanged scenery replacement state; retain existing sampling precision, graphics detail and fixed-step physics.
- Preserve simulation preferences, alignments, source attribution and local data across restarts and backups. Documentation now describes current behavior without duplicated development reports.

### Fixed

- Recover from terrain request failures, provider transitions, delayed calibration and invalid optional underlays; isolate scenery failures geographically instead of blocking unrelated RF paths.
- Preserve base-building replacement after small alignment corrections; require renewed terrain-mask validation after edits.
- Improve RF scheduling, vertical paths, stale-data handling and recovery; unknown observations do not trigger failsafe.
- Fix editor picking, geometry restoration, obstacle retention, suspension-bridge supports and compact settings layout.
- Make browser and storage regression tests more robust without weakening integrity or collision checks.

## [0.19.0] - 2026-11-21

### Advanced Flight Physics & Hardware-Aware Simulation

- Selectable Advanced (default) and unchanged Legacy fallback; unified manual/autonomous physics, fixed 60/120/240 Hz steps, bounded catch-up and interpolated camera rendering independent of render FPS.
- Hardware-aware propulsion with motor KV/count, propeller geometry, mass, optional manufacturer curves, spin dynamics, coupled voltage/current/thrust and chemistry-aware battery sag; independent battery/ESC/motor limits and auxiliary load accounting. Preserve ballistic free fall and distinguish DC from motor/ESC electrical estimates.
- Directional body-frame drag, air-relative velocity, propeller drag, inertia, bounded torque/rate control, quaternion integration, Betaflight-inspired/Classic Expo/Linear rates and optional Air Mode. Brake rotation on stick release without artificial torque from depleted batteries.
- GPS flight/Rescue uses the same thrust, attitude and power constraints, wind compensation and braking-distance-aware navigation. Preserve recovery phases, deliberate takeover, terrain/model collision and RF behavior.
- Interpolated local/regional wind, altitude/shear, deterministic gusts and turbulence, optional ridge lift/lee downdrafts, bounded terrain sampling and explicit missing-data fallbacks.
- Optional ground effect, propwash and vortex-ring-like descent effects with bounded forces, reliable terrain clearance, individual intensity controls and defaults off. Fix the Flutter descent-settings PageStorage collision.
- Momentum-aware swept collision resolution: Hard Stop, Sliding and Rebound, friction/restitution, supported terrain normals and hard-stop fallback. Stable low-speed landing (2.5 m/s vertical, 1.5 m/s tangential), sustained contact friction and takeoff; optional Assisted Landing up to 75° is a simulation aid.
- Refine live RF terrain verification with bounded adaptive midpoint refinement and the most detailed available terrain; keep missing or under-resolved paths unknown.
- Deterministic regression/CPU benchmarks for physics, environmental effects, collision and rescue; two reference aircraft, 13 scenarios each, 30/60/120 FPS, Legacy and injected stalls. Optional local normalized CSV telemetry alignment, bias/MAE/RMSE and quaternion error; synthetic timing, heap/RSS, electrical consistency and endurance estimates; local device diagnostics.
- Preserve existing aircraft/battery profiles, routes, settings and backups without migrations. Document calibration and validation limits: simplified propulsion, airflow, rotor/landing/contact and Air Mode models, no full Betaflight controller or guaranteed GPS recovery. See [simulation and collision](docs/developer/simulation_and_collision.md) and [performance](docs/developer/performance.md).

## [0.18.0] - 2026-11-20

- Add live radio ground-station marker, independent sightline and map-selection/takeoff-reset workflow. Extend terrain LoS from 6 km to 50 km with bounded coarse-to-fine ridge/Fresnel refinement, adaptive motion scheduling and caching; limited-confidence or missing data stays unknown, with explicit free-space-only preview.
- Add approximate independent DJI O4 Pro video and TBS Crossfire RC link budgets, EU/CE and FCC simulation scenarios and custom profiles; expose derived range, path loss, receive power and margins. Reference assumptions are not measured sensitivities or real transmitter configuration.
- Add opt-in DJI/Betaflight warnings and separate RC/video bars, analog interference and terrain-only demonstration. Brief missing video updates (<1.1 s) retain visual interference without inventing reception or triggering failsafe. Exclude RF/marker/Fresnel visuals from physical collision queries.
- Add simulated RC failsafe with hold, descend and GPS Rescue (hold, climb ~100 m above loss altitude, turn, return, land), loss/recovery hysteresis and configurable timing, propulsion/navigation safeguards and bounded collision sweeps. Stable reconnection enables deliberate yaw/pitch/roll takeover; revoke after renewed loss or five seconds without modeled RC data. Include session-only RC test source.
- Continue long-range simulation across missing rendered terrain without invented clearance; keep known collisions and unverified-distance diagnostics. Add deterministic 49.9 km CPU terrain-gap benchmark; device/GPU validation remains separate.
- Chemistry-aware shared Dart/JS battery profiles (LiPo, LiHV, Li-ion, LiFePO₄, NiMH, NiCd), charge guidance, live voltage/sag, energy accounting, warnings and route-load analysis. Schema v11 adds C-ratings, burst duration and per-cell resistance; zero resistance override means unspecified. Preserve unknown legacy chemistry and records.
- Schema v12 adds optional ESC per-channel and motor per-motor current ratings with equal-share DC proxy warnings, not measured phase current. Preserve nullable records/backups. Correct zero-throttle Acro/Angle power and remove arbitrary 10% uplift; GPS/replay estimates remain separate.
- Correct German labels/branding and strengthen Flutter/browser tests for localized iframe input, renderer setup and HUD defaults; cover rescue takeover and requalification.

## [0.17.2] - 2026-11-18

- Simplify generated 3D road and railway tunnel portals to the existing
  yellow/orange outline. Remove the oversized, visual-only front facades while
  preserving tunnel shells, lane markings, terrain apertures and collisions.
- Refine automatic 3D tunnel elevation handling for steep Alpine terrain.
  Accept short, native-bridge-supported portal transitions; recheck suspect
  terrain samples with bounded detailed centre-and-shoulder probes instead of
  rejecting all deviations above 40 m. Continue to reject unverified floating
  bores, preserve route continuity and collision, and clarify diagnostics.
- Migrate the German and English Flutter UI translations to official gen-l10n
  ARB catalogs and generated, type-safe accessors. Preserve saved language
  preferences and compatibility with remaining dynamic translation keys.
- Record simulator airspeed separately from ground speed, along with route
  sample heights and timing. Use known segment telemetry in energy analysis;
  offer conservative estimates for missing inputs only when enabled, and
  identify modeled values separately from recorded data.
- Add an optional SIM BAT voltage indicator to the flight HUD. Estimate
  pack and per-cell voltage from the selected drone and battery profiles,
  with configurable warning levels and optional modeled voltage sag. Display
  simulated values explicitly rather than presenting them as real telemetry.
- Add lightweight 3D models for communication towers, lattice masts and
  observation towers. Improve tall-obstacle classification and the conditional
  Säntis tower visualization without altering source obstacle positions,
  reported heights or existing collision limitations.

## [0.17.1] - 2026-11-18

- Include GeoTIFF.js, h5wasm and Windows native component notices. Bundle
  the MeteoSwiss radar decoder locally.
- Restore dated imagery in native builds, support the Blatten RGB
  mosaics and include the acquisition year in swissEO credits.
- Publish a privacy policy and preserve cache-only base maps across
  restarts. Add the iOS foreground location purpose and exclude its
  public-data cache from device backups.
- Document the showcase credits and checks for built release packages.

## 2026-11-15

- Anchor restored spots and their labels to the terrain mesh currently drawn.
- Retain more terrain around ground view and preload adjacent tiles while the
  walker is active. Correct the localized ground-view start tooltip.

## 2026-11-14

- Prepare the instanced vegetation shaders before flight controls activate.
  Read partitioned 3D tileset headers directly from memory during streaming.
- Reduce transparent margins on the foliage geometry for the six tree models.
- Analyze all saved route waypoints for radio coverage in bounded batches.
  The map shows the page containing the selected result.
- Preserve the full route profile and original segment indices for local 3D
  infrastructure checks. Skip distant vector obstacles before detailed checks.

## 2026-11-11

- Replaced the stock tree models with six textured broadleaf and conifer
  variants at the same triangle count. Existing swisstopo instance groups use
  a bundled BAFU/WSL forest composition raster to guide model choice.
- Resolved bare vegetation tile paths against the revision published in the
  official index, restoring coverage for affected parts of the tileset.
- Added a German and English language setting for the app, map controls and
  flight interface. The choice is saved on the device.
- Prepared the Sun, Moon and Sun bloom programs during flight preparation.
  Briefly reduced Cesium's terrain-loading time slice during fast rotations
  and low, fast climbs or dives.

## 2026-11-10

- Fixed premature disappearance of large buildings at the edge of the flight
  view. Geographic culling bounds now enclose overhanging source content and
  propagate through loaded parent tiles, including the header-memory fallback.
- Anchored saved-place markers and labels to terrain instead of roofs, trees
  or bridge decks, including restored places after restarting the renderer.
- Removed the bridge search's recurring horizon terrain pick during flight
  and ground navigation; discovery now follows the current aircraft position.
- Spread large explicit 3D tileset header construction over small local
  subtilesets while preserving source geometry, materials and LOD settings.
- Prepared the shared 3D material-lighting lookup before flight activation
  when a 3D layer is enabled, instead of waiting for its first streamed model.
- Moved common terrain shader preparation before flight activation, with
  progress, cancellation and reuse on repeat flights, to reduce first-use
  graphics-driver pauses without reducing the selected image quality.
- Limited terrain collision sweeps to reachable rendered tiles and reused exact
  terrain vertices with bounded spatial acceleration for height/contact queries.
- Applied flight and ground camera updates before Cesium's motion and
  underground-state detection during rapid maneuvers.
- Prevented an empty globe after transient terrain-root failures; startup now
  validates and reuses all required roots and retries twice in the background.
- Disabled Windows route snapshots of the live WebView2 texture to prevent a
  native engine crash when opening saved places after selecting a map point.
- Added temporary terrain-refinement relief during fast turns and low-altitude
  streaming stalls, with staged restoration of normal detail.
- Included long in-flight frame pauses in opt-in performance diagnostics.
- Fixed blank grey coordinate fields on first expansion of the BAKOM,
  forest-fire prevention and dated-imagery panels, and constrained long imagery
  collection labels on narrow screens.
- Adopted Apache-2.0 for original project material; preserved separate software,
  data and service rights and the additional notices bundled by dependencies.
- Consolidated and refreshed user/developer documentation and in-app help.
- Removed development-ticket references and superseded documentation.

## 2026-11-09

- Grouped map/globe controls in **Map & view**; shortened navigation and
  simulator menus and moved secondary details into expandable sections.
- Replaced verbose map credits with a compact sources control while retaining
  full notices and required visible provider attributions.
- Removed legacy tunnel-axis overlays and surface exploration controls;
  automatic 3D tunnels and their internal source catalogue remain available.
- Stabilized long-tunnel handoffs, portal heights and underground junctions.
  Portal openings preserve roads; tunnel walls render opaque from both sides.
- Added schematic bridge supports using mapped or verified native deck data.
- Reduced tunnel-build and depth-query bursts; large render stalls no longer
  produce large simulation catch-up movements.

Synthetic fixtures and desktop measurements do not establish Android frame rate,
surveyed tunnel geometry, real-world obstacle clearance or permission to fly.
