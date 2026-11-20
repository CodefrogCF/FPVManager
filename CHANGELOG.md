# Change summary

### [Unreleased] - 2026-11-20

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
  walker is active. Correct the German ground-view tooltip to “Hier starten”.

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

- Grouped map/globe controls in **Karte & Ansicht**; shortened navigation and
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
