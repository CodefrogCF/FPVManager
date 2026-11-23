# Advanced environmental wind: regional continuation, gusts and terrain

**Simulation-only approximation — not a localized aviation forecast or a flight-safety tool.**

## Data provenance and handover

`lib/features/weather/wind_field_service.dart` still fetches Open-Meteo wind at nine
points in a 3×3 grid (±1.5 or ±5 km), at nominal 10, 80, 120 and 180 m AGL.
`web/features/weather/wind_field.js` retains the existing validated and bilinearly interpolated
*local* model field for 3D arrows. It is not modified or rescaled in that
footprint unless the pilot explicitly enables synthetic gust/turbulence or
terrain effects.

`web/features/weather/environmental_wind.js` is the **common environment provider** consumed by
the simulation. Input: `{latitude, longitude, agl, timeSeconds}` (degrees,
metres above terrain, simulated elapsed seconds). Output: `{north, east, up}`
(m/s) plus `source`, `available`, `approximate`, `extrapolated`,
`terrainEstimated` and `altitudeEstimated` diagnostics. It performs no requests,
uses no real-time clock or randomness, and provides bounded configuration.

- **Inside the loaded footprint:** existing wind-grid interpolation. No added
  regional modulation when synthetic options are disabled.
- **Outside:** clamp to the nearest grid edge and blend its last valid vector
  to a *derived* regional flow over 3 km, with cubic smoothstep. The regional
  vector is seeded from the loaded field (or explicit fallback) and varies
  smoothly over illustrative tens-of-kilometres length scales. It is **not**
  weather-model data for the region outside the footprint.
- **Altitude:** local weather levels are linearly interpolated in vector
  components, including meteorological heading wrap. Above the footprint,
  optional bounded power-law wind shear and gradual wind veer are applied to
  the *regional estimate* (not retroactively to local weather measurements).
- **Missing/expired field:** user-configurable fallback wind (speed m/s,
  meteorological wind-*from* bearing), otherwise explicitly assumed calm;
  expired weather is never silently treated as valid. The disabled wind
  toggle preserves existing no-wind operation.
- **Unknown AGL:** the environmental provider uses 80 m AGL as a documented
  fallback, marks `altitudeEstimated`, and skips terrain contributions.

## Optional, deterministic environmental effects

`gustSpeedMs` (0–25) and `turbulenceIntensity` (0–1) add continuous sine-based
vector variations driven by **position and simulated elapsed time**, not frame
rate. Their seed is bounded and reproducible. These are illustrative motions,
not a real atmospheric turbulence spectrum.

`ridgeLift` and `leeTurbulence` default to **off**. When enabled, and if the
model has valid rendered terrain heights, the provider samples the nearby
upwind, centre and downwind terrain. An increasing surface towards the wind
may generate bounded updraft; a descending lee side can generate downdraft
and correlated flow variation. The heuristic scales with wind speed, terrain
slope and height above terrain (fading to zero at 500 m AGL). It does **not**
model recirculation, rotors, thermals, structures or CFD. A missing/unknown
terrain height disables only those additional contributions. The provider
cannot certify safe mountain-surfing trajectories.

## Integration and resource limits

- `web/globe.js` provides the same wind sampler to `web/features/flight/free_flight.js` as
  before; Acro, Angle and GPS/Rescue continue to use air-relative velocity.
- `web/features/flight/free_flight.js` now passes **simulated physics time** to the provider;
  advanced fixed-step integration is independent of Cesium rendering rate.
- Wind arrows remain local and bounded as before; regional estimates do not
  generate unbounded animated primitives.
- Terrain cache capacity is capped at 128 entries in the provider, plus the
  existing bounded 256-height cache in the renderer. Terrain probes are made
  only when opt-in terrain effects are enabled and AGL is below 500 m.
- The environment is configured in the existing Flutter wind sheet and sent
  through the existing `set-wind-field` bridge payload. No drone profile,
  battery or persisted database schema migration is required. Wind settings
  are session-scoped, as with the current wind field.

## Scope and limitations

The regional continuation estimates **plausible wind**, not real, validated
forecast values for a moving drone. Future work may plug in additional
sampled regional weather fields, weather APIs or measured telemetry without
changing the flight engine's environment sampler. Features do not synthesize
new weather observations. Physical drone calibration and real flight-data
validation are separate work.
