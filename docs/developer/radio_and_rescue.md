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
separation. Valid ground samples remain necessary. BKG 3D Beta's unverified height
reference is explicitly unavailable to RF, with retry suspended until inputs or
provider change.

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
