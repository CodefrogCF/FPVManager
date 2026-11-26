# Changelog

## Unreleased

Current development build: **0.19.29+56**. These entries describe the implemented
working state; they do not announce a published v0.20.0 release.

### Fixed

- Scenery control-point picking hides editor gizmos/bounds and bypasses handle
  dragging while picking surfaces, so handles cannot consume pointer releases or
  contaminate target depth. Extend the real browser regression for the reported CI failure.
- Nearby aviation obstacles (including the Säntis tower) remain loaded through
  camera rotations, horizon views and temporary terrain-tile eviction. A padded,
  camera-centered region follows existing model ranges; identical region events
  do not cancel an in-flight obstacle query. Zoom-in regions are re-evaluated
  after delayed terrain arrives, without requiring another camera movement.
  Display/cache limits remain bounded.
- Live terrain-dependent RF analysis now handles vertical and near-vertical
  paths above the takeoff/ground-station position. Distance includes antenna
  height separation; missing terrain still remains unknown.
- Simulator settings, including Advanced/Legacy selection, controller mapping,
  camera, battery and physics configuration, survive restarts and portable
  backup restore. Flight quick controls save valid changes without allowing
  an idle renderer to overwrite preferences.
- Clearly tagged or explicitly named suspension bridges no longer receive
  guessed intermediate pillars, including overlapping imported/native decks.
  Explicitly mapped supports remain available.
- Live RF scheduling uses one active calculation with the latest pending pose,
  generation/revision guards, recoverable timeouts and bounded freshness.
  Expiring an old HUD observation does not cancel a newer query. Fast flight
  preserves terrain precision and can fuse the required refinement pass.
- Pending, stale or unavailable RF observations show a passive HUD notice.
  Uncertainty alone does not trigger Hold, failsafe or GPS Rescue. Actual
  modeled RC loss and fresh recovery retain the configured delays/hysteresis.

### Changed

- Standardize project documentation on English; retain the integrated guides
  and German quick start in their existing languages.
- Group developer tools by build, data, benchmarks, browser, quality,
  maintenance and scenery; update CI, tests and documented commands together.
- Consolidate current documentation, retire individual fix/delivery reports,
  and keep dated measurement evidence with benchmark tools. ZIP updates include
  a checksum-protected cleanup plan that preserves locally edited files.
- Simplify public menus; internal diagnostics remain opt-in with
  `FPV_DEVELOPER_MENUS=true`.

### Added

- Import independent scenery collision meshes (FPC1 or compatible local GLB/glTF),
  or generate a static triangle BVH from a visual GLB. Retain real geometric
  openings, bake node transforms/winding and support front/back/double-sided sweeps.
  Persist verified collision files separately from visuals with atomic commits,
  shared-file cleanup and offline loading. Custom colliders load independently of
  visual LOD/opacity, validate in an abortable worker and expose optional wireframe
  visualization. Missing required geometry pauses affected movement with a clear
  HUD reason without creating an RC failsafe. Add synthetic rooms, openings,
  curved pipes, dense BVH, physics, persistence and real browser regressions.
- Add interactive globe scenery alignment with direct model selection, ENU
  translation and rotation handles, numerical placement, top-down/perspective
  views, terrain snap and opacity controls. Fit local models to geographic 3D
  control points with visible residuals; display origin, bounds and footprint.
  Bounded undo/redo and cancellation retain the original configuration and camera.
  Confirmed edits persist through the existing database and backup architecture,
  with conflict/session guards and shared visual/collision transformations.
- Add configurable external HTTPS OGC 3D Tiles 1.0/1.1 scenery providers using
  the existing catalog, persistence and backup architecture. Check endpoints,
  preserve source georeferencing, configure optional ENU corrections, detail,
  activation distances and HTTP caching, and retain source credits. Scoped,
  abortable loading shares Cesium's scheduler and cooperative header loader;
  partial tile failures retain loaded geometry and report degraded streaming.
  Include an official Brandenburg preset and tested live integration, plus
  deterministic lifecycle, bridge, persistence and real Cesium rendering tests.
  External scenery is online and visual only; offline map modes stop requests.
- Import local static GLB/glTF 2.0 scenery with platform file selection, safe
  resource resolution and self-contained model storage. Models retain core
  materials, transparency and PNG/JPEG textures; unsupported/compressed assets
  and resource limits produce explicit errors. Placement supports ENU, WGS84 or
  terrain-relative heights, heading/pitch/roll and scale with recalculated bounds.
  Imports persist after restart; native loopback and Web cache-only loading keep
  model bytes local. New imports are visual only, and model bytes are not yet
  included in portable backups. Add import, persistence, bounds and real Cesium
  rendering/offline-asset regression coverage.
- Persistent scenery definitions with a versioned, provider-independent manifest,
  database migration and backup/restore support. Existing scenery activation and
  alignment are migrated without replacing user settings. Scenery management can
  create configurations from existing model templates, edit placement and remove
  definitions. Unsupported providers/formats remain explicitly unavailable.
- Runtime scenery catalog updates preserve unchanged models and reject obsolete
  loads. Multiple visual/collision assets share ENU heading, pitch, roll and scale.
- Official Berlin/Brandenburg online imagery, topographic and relief layers
  alongside the existing Swiss/offline providers, with regional source credits.
- Experimental Rüdersdorf photogrammetry scenery with local georeferencing,
  approximate repairs and matching collision assets. BKG 3D Beta is separately
  gated; its unverified vertical reference is not accepted as RF evidence.

## [v0.19.0] - 2026-11-21

### Advanced Flight Physics & Hardware-Aware Simulation

Introduce a selectable, physically consistent and hardware-aware flight
simulation model for realistic FPV flight behavior, including freestyle,
long-range flights, mountain surfing, high-speed dives and autonomous
recovery.

The existing Legacy physics model remains available and unchanged.

### Flight Physics Architecture

- Introduce selectable Advanced (default) and Legacy (fallback) flight
  physics modes, reusing existing aircraft configurations, battery
  profiles, collision detection and RF simulation.
- Establish a unified physics-state architecture shared across manual and
  autonomous flight modes.
- Decouple simulation physics from Cesium rendering using a configurable
  60/120/240 Hz fixed timestep.
- Add bounded catch-up, queued/dropped-time diagnostics and interpolated
  camera rendering.
- Preserve deterministic simulation behavior across different rendering frame
  rates.
- Maintain independent battery-time integration and backward compatibility
  with existing profiles.

### Hardware-Aware Propulsion and Battery Simulation

- Introduce a motor and propeller model using configured motor KV, motor
  count, propeller geometry, aircraft mass and battery characteristics.
- Estimate motor RPM, available thrust, electrical demand and physically
  bounded acceleration.
- Support generic propulsion coefficients and optional manufacturer-provided
  performance curves.
- Model motor spin-up and spin-down dynamics.
- Couple battery terminal voltage, current demand, available motor RPM and
  thrust through a bounded iterative electrical model.
- Respect battery internal resistance, chemistry, charge state, continuous/
  burst discharge ratings and independent ESC, motor and power limits.
- Include estimated auxiliary electronics and video-system power consumption
  without double-counting electrical loads.
- Distinguish battery DC current from estimated motor and ESC electrical
  quantities.
- Preserve zero-throttle ballistic free fall without artificial motor thrust
  when no active rotational correction is required.
- Provide conservative fallback behavior when detailed hardware specifications
  are unavailable.

### Directional Aerodynamics and Rotational Dynamics

- Replace uniform Advanced-mode drag with orientation-dependent aerodynamic
  forces calculated in aircraft body coordinates.
- Introduce independently configurable forward, backward, lateral and
  vertical drag characteristics.
- Account for aircraft orientation, air-relative velocity and optional low-
  throttle propeller drag.
- Improve momentum preservation and aerodynamic behavior during high-speed
  dives, sideways drift and vertical descents.
- Introduce configurable roll, pitch and yaw moments of inertia.
- Implement a simplified rate controller translating stick inputs into angular
  acceleration through bounded control torque.
- Add configurable torque limits, angular acceleration limits and motor-
  response dynamics.
- Support Betaflight-inspired, Classic Expo and Linear rate profiles.
- Prevent unrealistic instantaneous rotational reversals while preserving
  independent axis control.
- Improve quaternion orientation integration for numerically stable flips,
  rolls and yaw rotations.
- Introduce an optional Air Mode for Advanced Acro flight, maintaining limited
  rotational control authority at low or zero throttle.
- Prevent uncontrolled continuous rotation after stick release by allowing the
  rate controller to actively brake angular motion without requiring
  additional pilot throttle input.
- Maintain responsive roll, pitch and yaw control during low-throttle
  maneuvers, including rapid stick reversals and corrective inputs.
- Integrate Air Mode torque authority with existing motor, ESC and battery
  limitations, avoiding artificial control torque when propulsion power is
  unavailable.
- Preserve zero-throttle ballistic free fall when no active rotational
  correction is required.
- Keep Air Mode independently configurable without changing Legacy Acro
  behavior.

### Unified GPS Flight and GPS Rescue

- Integrate GPS-assisted flight and GPS Rescue with the same Advanced physical
  aircraft model used for manual flight.
- Replace direct velocity manipulation with physically constrained attitude,
  thrust and rotational commands.
- Translate target horizontal velocity, altitude and heading into achievable
  acceleration and aircraft orientation.
- Respect available motor thrust, battery performance, maximum tilt and
  rotational limits.
- Introduce braking-distance-aware deceleration when approaching the home
  position.
- Support wind compensation within available propulsion limits.
- Preserve GPS Rescue Hold, Climb, Turn, Return and Landing phases.
- Preserve manual takeover following stable RC reconnection and deliberate
  pilot input.
- Maintain existing terrain, 3D-model collision and RF-link behavior.
- Preserve existing GPS Rescue settings and Legacy-mode functionality.

### Regional Wind and Terrain-Dependent Environmental Effects

- Introduce a unified environmental wind provider supporting local weather
  fields and regional fallback conditions.
- Extend wind simulation beyond local Open-Meteo sampling boundaries without
  abrupt transitions to calm air.
- Apply smooth interpolation across horizontal positions, altitude and
  regional wind boundaries.
- Model approximate altitude-dependent wind speed, wind direction and wind
  shear.
- Add configurable, deterministic gust and turbulence intensity.
- Introduce optional terrain-dependent ridge lift, lee-side downdrafts and
  turbulence approximations.
- Add bounded terrain sampling and caching to control computational overhead.
- Handle missing or outdated weather and terrain information through explicitly
  defined fallback assumptions.
- Maintain air-relative aerodynamic calculations across long-distance flights.

### Ground Effect and Descent Aerodynamics

- Introduce optional ground-effect modeling based on rotor diameter, aircraft
  clearance, orientation and available propulsion.
- Apply ground effect only when reliable terrain elevation information is
  available.
- Model simplified propwash disturbances during powered descent.
- Introduce an optional vortex-ring-like thrust-loss approximation for relevant
  descent conditions.
- Preserve physically distinct low-throttle and zero-throttle ballistic flight
  behavior.
- Limit aerodynamic corrections to prevent excessive thrust amplification or
  unstable acceleration.
- Add independently configurable effect switches and intensity settings.
- Preserve existing simulation behavior by keeping the new descent effects
  disabled by default.
- Fix a Flutter PageStorage key collision that could render a grey error panel
  when enabling Ground Effect, Propwash, or Vortex-Ring options in Advanced
  settings.

### Collision Response and Surface Interaction

- Introduce momentum-aware collision resolution for the Advanced physics model.
- Reuse existing swept collision detection for terrain and 3D geometry.
- Separate impact velocity into normal and tangential components.
- Preserve tangential movement during suitable glancing collisions.
- Add configurable Hard Stop, Sliding and Rebound collision modes.
- Support adjustable surface friction, restitution and severe-impact thresholds.
- Approximate terrain contact normals using reliable neighboring elevation
  samples.
- Prevent continued penetration through additional collision checks and bounded
  contact resolution.
- Preserve hard-stop fallback behavior when reliable surface normals are
  unavailable.
- Exclude visual-only radio, Fresnel and marker entities from physical collision
  responses.
- Maintain explicit uncertainty when terrain tiles or collision geometry are
  missing.
- Improve Advanced collision response with stable ground contact handling for
  controlled landings, preventing unrealistic sliding on terrain.
- Introduce low-speed landing detection with contact thresholds of 2.5 m/s
  vertical and 1.5 m/s tangential velocity.
- Maintain stationary ground contact on verified terrain until sufficient motor
  thrust is available for takeoff.
- Apply sustained ground-contact friction instead of relying exclusively on the
  initial collision impulse.
- Preserve sliding behavior during high-speed glancing impacts while keeping
  severe-impact handling and Legacy collision behavior unchanged.
- Add optional Assisted Landing on verified steep terrain (up to 75°) for slow,
  nearly vertical touchdowns; this is explicitly a simulation aid, not realistic
  rock-face friction.

### Testing, Performance and Compatibility

- Extend deterministic regression coverage for propulsion, battery discharge,
  aerodynamic forces, rotational dynamics and autonomous flight.
- Add tests for flips, rolls, yaw spins, rapid stick reversals, free fall,
  high-speed dives and controlled landings.
- Validate GPS Rescue recovery phases, RC reconnection, low-power behavior and
  automatic landing.
- Cover regional wind transitions, missing environmental data, ground effect,
  propwash and repeated collision contacts.
- Improve live radio terrain verification with bounded adaptive midpoint
  refinement and the most detailed available terrain data rather than fixed
  Cesium level 12; keep under-resolved or missing terrain explicitly unknown.
- Add widget regression coverage for toggling all three Advanced descent effects
  without invalid PageStorage scroll-offset restoration.
- Add regression tests for stable ground contact, controlled landing thresholds,
  stationary behavior and transitions from landing to takeoff.
- Validate low-throttle rotational braking, stick release, corrective stick
  inputs and Air Mode behavior with hardware-aware propulsion limits.
- Verify that depleted batteries cannot provide artificial rotational control
  torque.
- Verify deterministic physics behavior at 30, 60 and 120 FPS rendering rates.
- Introduce CPU-only benchmarks for propulsion, environmental wind sampling,
  descent aerodynamics and collision processing.
- Preserve existing aircraft and battery profiles, simulation settings, Legacy
  physics and route-planning functionality.
- Maintain compatibility without requiring database or backup migrations.
- Document model assumptions, approximations, configurable parameters and
  calibration limitations.
- Add a combined Advanced physics validation runner with two documented benchmark
  aircraft profiles, 13 controlled scenarios per profile, 30/60/120 FPS
  comparisons, Legacy reference runs and injected-stall diagnostics.
- Support optional local, normalized telemetry CSV comparison with explicit units,
  time alignment, missing-channel handling, bias/MAE/RMSE and quaternion
  orientation error; no binary Blackbox decoder or automatic calibration.
- Record synthetic CPU time, integration-step latency, frame timing, sampled
  heap/RSS, electrical consistency and steady-load endurance estimates, with
  representative reproducible results.
- Add opt-in local Android/Windows profile-build diagnostics and a device
  measurement template for repeatable Cesium and physics performance comparisons.
- Consolidate user and developer guidance for physics modes, benchmark procedures,
  provenance and remaining calibration limitations; select Advanced as the new
  default while preserving Legacy as an explicit fallback.

### Known Limitations

- Motor thrust, propulsion efficiency, aerodynamic coefficients and moments of
  inertia remain approximate unless calibrated with manufacturer data or real
  flight telemetry.
- Regional wind extrapolation and terrain-dependent airflow effects are simplified
  approximations, not computational fluid dynamics or verified local weather
  predictions.
- Ground effect, propwash and vortex-ring-like behavior do not reproduce detailed
  rotor aerodynamics.
- Sliding and rebound require reliable collision normals; unsupported geometry
  retains conservative hard-stop behavior.
- Ground contact stabilization uses simplified landing thresholds and friction
  assumptions rather than a detailed landing gear or structural deformation model.
  Assisted steep-slope landing deliberately exceeds realistic static friction and
  must not be treated as a real-world landing prediction.
- Air Mode provides simplified low-throttle rotational control and does not
  emulate the complete Betaflight motor mixing and PID control system.
- GPS Rescue cannot guarantee recovery when available propulsion, battery energy
  or environmental conditions are insufficient.

### [0.18.0] - 2026-11-20

- Allow simulated long-range flight to continue when individual rendered
  Cesium terrain heights are unavailable, without inventing ground clearance;
  keep loaded terrain/model collisions and expose unverified-distance diagnostics.
- Maintain visual-only analog video interference across brief (<1.1 s) missing
  video RF updates, with occasional extra flicker; keep RC/video signal state
  unknown and never reuse these visuals for failsafe decisions.
- Add a deterministic CPU-only 49.9 km long-range terrain-gap benchmark and
  regression tests; document that device/GPU and real terrain performance
  still require measurement.
- Correct live battery consumption during zero-throttle free fall: Acro/Angle
  power estimates now account for simulated motor thrust rather than treating
  vertical falling airspeed as powered forward flight. Remove the arbitrary 10%
  live power uplift and preserve separate GPS/replay speed-based estimates.
- Treat a battery internal-resistance override of `0 mΩ` as unspecified,
  selecting the chemistry-based approximation rather than a physically ideal
  zero-resistance pack. Preserve positive manufacturer-specific values.
- Explicitly exclude visual-only radio LoS/Fresnel and ground-station Cesium
  entities from model-collision height sampling. They remain visible but cannot
  be interpreted as 3D model surfaces.
- Make the Chrome simulation/dropdown iframe-input regression independent of
  responsive close-button visibility and translated option labels.
- Keep a confirmed simulated RC reconnection available for deliberate GPS
  Rescue pilot takeover throughout the return flight, including short terrain
  sampling gaps and link values within the RF hysteresis band. Revoke takeover
  after sustained renewed RC loss or five seconds without modeled RC data;
  require a fresh stable reconnection before re-enabling takeover. Add rescue
  regression tests for mid-return control, lost-link requalification, and
  throttle-only inputs. No change to real RC equipment or radio legality.
- Extend terrain-based live radio LoS from 6 km up to
  50 km using bounded coarse-to-fine sampling and targeted ridge/Fresnel
  refinement. Keep shared route radio geometry, adaptive speed/distance update
  intervals and terrain height caching.
- Identify under-resolved long-range profiles as limited-confidence, never
  inferred clear visibility or confirmed RC loss. Display terrain query/sample
  counts and a clearly labelled free-space-only RF preview when LOS is unknown.
- Correct the browser iframe simulation dialog test host to register the
  generated German localization delegate (Chrome web regression).
- Refine simulation-only GPS Rescue to hold, climb approximately 100 m above
  current loss altitude, turn toward home, return at controlled cruise altitude
  and speed, then land automatically near the home-point ground surface.
  Recovered RC alone does not cancel rescue: a deliberate yaw/pitch/roll stick
  input is required; retain bounded terrain and model collision sweeps.
- Make modeled terrain obstruction more influential in RC/video link budgets;
  shorten default simulated failsafe activation/recovery delays while retaining
  user controls, hysteresis and unavailable-terrain safeguards.
- Introduce independent EU/CE and FCC reference scenarios for DJI O4 Pro video
  and TBS Crossfire RC, plus custom numeric profiles. Preset EIRP/frequencies
  reflect documented bands or explicitly labeled simulation assumptions;
  derived receiver thresholds are NOT measured hardware sensitivities.
  Selecting an RF scenario never configures an actual transmitter or grants
  radio-operation permission.
- Add chemistry-dependent charge references: lithium CC/CV per-cell maximums and
  explicit nickel delta-peak/temperature cutoff guidance (no invented fixed
  nickel charge voltage). Both languages show the appropriate battery-editor hint.
- Persist independent optional ESC continuous per-channel and motor continuous
  per-motor current ratings in drone profile schema v12. Show distinct estimated
  limit warnings in route analysis and live battery estimates using a clearly
  labeled equal-share DC current proxy; motor phase currents are not measured.
- Retain existing battery, drone, and backup records across the nullable schema
  migration. Unknown electrical limits remain unknown, not assumed adequate.
- Replace free-text battery chemistry with localized LiPo, LiHV, Li-ion, LiFePO₄,
  NiMH, and NiCd selections; preserve unsupported legacy chemistry strings.
- Persist individual continuous/burst C-ratings, burst duration, and per-cell
  internal resistance (mΩ) in database schema v11; copy values from type templates.
- Pass specifications into the existing chemistry-aware live-voltage simulation and
  route energy/load analysis. Chemistry defaults remain explicitly approximate.
- Correct known German localization defects including Betaflight branding and
  simulator spawn labels.
- Centralize estimated RC battery chemistry behavior with generated, shared Dart/JavaScript
  reference presets (LiPo, LiHV, Li-ion, LiFePO4, NiMH and NiCd). The flight HUD now uses
  chemistry-specific discharge voltage and load sag, charge/energy accounting and automatic
  low-voltage warnings; route energy assessments flag estimated current requirements above
  generic chemistry reference limits without overwriting recorded Wh. Custom warning
  thresholds remain available, and existing battery records/backups are unchanged.
- Extend simulated DJI O4 Pro and Crossfire RF estimation with derived free-space
  maximum ranges, receive power, path loss and remaining link margins for each
  band, retaining conservative terrain uncertainty and custom parameters.
  Expose estimates in radio details/HUD tooltips, not as measured reception.
- Stabilize Flutter tests affected by additional renderer radio setup commands:
  verify feature-specific commands rather than absolute command-list positions,
  and compare preference resets against the current HUD defaults.
- Add default, explicitly approximate DJI O4 Air Unit Pro video and TBS Crossfire
  RC link-budget profiles with optional custom radio parameters. Expose independent
  video/RC signal estimates when fresh terrain profiles exist, retain unknown
  reception on unavailable data, and feed the existing optional failsafe.
- Improve adaptive live sightline sampling at higher flight speeds, keep rays
  strictly visualization-only and non-collidable, increase optional analog
  video interference at poor simulated reception and speed up GPS Rescue
  target-speed tracking with bounded acceleration and braking.
- Add an opt-in, deterministic simulated RC failsafe with hold, descend and
  illustrative GPS Rescue to the takeoff point. Sustain loss and recovery
  thresholds with hysteresis, handle unknown/insufficient navigation and battery
  information, keep manual/video/RC channels separate, and reuse existing
  flight collision sweeps. Provide simulation-only HUD status, persisted settings
  and a session-only manual RC test source; no terrain-only RF-loss assertions.
- Add opt-in simulated video-link warnings to the goggles HUD and separate
  video/RC strength bars in the Betaflight OSD, with optional analog interference.
  Smooth the visuals and persist thresholds/intensity locally. An explicit
  terrain-only demonstration can illustrate possible video degradation without
  asserting measured RF quality or RC failure; unknown conditions show no
  invented reception. All effects are presentation-only and cannot trigger
  failsafe.
- Extend the existing live geometric radio preview with a separately visible
  ground station marker, independently controlled sightline, and an explicit
  takeoff reset/map-selection workflow. Share an immutable assessment model
  for future HUD/failsafe work while keeping RC and video reception unknown
  without a dedicated RF model. Existing route radio analysis is reused.

### [0.17.2] - 2026-11-18

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
