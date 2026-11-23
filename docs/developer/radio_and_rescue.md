# Live radio LoS, RF modeling and GPS Rescue

**Status:** current simulator architecture and live-RF profile behavior.
This is a deterministic **illustrative** modeling system, not measured RF
telemetry, transmitter configuration or validated flight safety logic.

## Data flow and modules

1. `lib/features/signal/live_radio_controller.dart` owns the active ground
   station, lifecycle, sampling schedule and stale-result protection.
2. The existing route geometry kernel `calculateRadioLink()` evaluates
   sampled geometric obstruction and Fresnel margins; a separate LoS engine
   is not introduced. Samples are positioned by geodesic fraction because
   long-range refinement produces uneven spacing.
3. `lib/features/signal/live_link_assessment.dart` provides the immutable
   assessment contract. The renderer receives `set-live-radio-result`.
4. `web/features/signal/live_radio.js` and `web/features/signal/rf_estimation.js` compute separate video/RC
   *assumed* link budgets when reliable terrain is available. The HUD and
   optional failsafe consume separate presentation and RC-quality channels.
5. `web/features/signal/simulated_failsafe.js` manages opt-in RC link loss/recovery; flight
   movement is implemented through `web/features/flight/free_flight.js` and normal collision
   checks. `web/features/flight/physics/rescue_velocity.js` handles bounded return acceleration/braking.

Keep the operator/antenna position independent of the flight home/takeoff
point. Repositioning the ground-station marker does not change GPS Rescue home.

## 50-km live terrain sampling — baseline with R40 reliability fixes

**Baseline:** GitHub commit `d1fca7e` (2026-11-21), immediately before the
Rüdersdorf integration (`623d6bf`). The 50-km implementation was introduced
by `3509854` (2026-11-20). The live radio modules are restored from a
project archive carrying that post-50-km implementation. R36/R37 experiments
are not active in this build; they remain available in the Git history.
R40 makes narrowly scoped reliability corrections to the restored R39 baseline.

The live sampler supports **1 m to 50 km**. It obtains an initial full-path
profile, then samples selected midpoints of gaps, steep relief and potential
Fresnel conflicts only while they remain necessary. An already sampled
obstruction can be reported after the first terrain batch. A clear result
requires the tier-specific gap limit; sparse clear data stay limited. There is no second LoS engine: the route analysis kernel
is shared, and samples use geodesic fractions. Each terrain bridge request
contains **at most 256 positions**; sequential batches and a bounded 30-second
cache avoid unlimited requests. A concurrent browser terrain request is
rejected rather than queued (historical behavior). A limited coverage result
never asserts unobstructed RF reception.

| Distance | First-pass points (max) | Refinement points (max) | Coverage gap limit | Minimum interval |
|---|---:|---:|---:|---:|
| 1 m–6 km | 129 | 384 | 16 m | 250 ms |
| >6–15 km | 128 | 128 | 80 m | 450 ms |
| >15–30 km | 96 | 96 | 165 m | 850 ms |
| >30–50 km | 96 | 96 decreasing to 64 | 300 m | 1500 ms |

The controller also adapts update intervals and permissible position drift
to aircraft speed and path distance. **HUD profiles expire after five seconds**
and may become `unknown` earlier when the aircraft moves too far from the
sampled endpoint, the terrain changes or a query fails. Unknown means the
profile is not validated; it is not a measured RC signal loss. The bounded
simulated link estimate and optional failsafe continue to use independent
RC/video channels.

This rollback is an **A/B test baseline**, not a claim that historical behavior
is universally faster or more accurate. In particular, high-speed position
changes can invalidate pending calculations in this original implementation.
The Rüdersdorf/BKG beta terrain restriction remains in the modern map layer;
its unvalidated heights are not used for RF planning.

### R40 live-update and fast-motion rules

A movement-driven invalidation clears an obsolete *displayed* assessment but
does **not** cancel a newer terrain request. The controller uses distinct
generation and message revision counters, so older unknown notifications
cannot overwrite successful newer results. A truly superseded path causes a
fresh query for the current pose; provider switches, paused flights, respawns
and disabled monitoring still invalidate in-flight results.

When the aircraft has already moved past a pending profile, sampled terrain
points may only be reused to confirm a **deep geometric obstruction** on the
current ray: an interior sample must be within 2 m of the new horizontal ray
and show at least 8 m negative clearance when recalculated against the current
3D aircraft position. The resulting assessment is explicitly
`confidence: limited` and labeled `recheckedMovingPath`; it must never be
used to infer clear reception. Without this strict evidence the result stays
unknown and is resampled. Any endpoint ground value in this limited mode is
from the nearest earlier sample, not a newly sampled aircraft ground height.

The terrain sampler now ends refinement as soon as it has a sampled
obstruction or sufficiently dense clear coverage. This avoids repeated queries
on short, already fully sampled paths; missing terrain and sparse clear
coverage remain unknown. Neither failsafe thresholds nor GPS Rescue behaviour
are changed.

## Independent video and control link budgets

The model uses frequency, EIRP, assumed effective receive threshold, fade
reserve and heuristic terrain loss. Its free-space component follows:

```text
FSPL(dB) = 32.44 + 20 log10(frequency_MHz) + 20 log10(distance_km)
estimated RX power = EIRP - FSPL - assumed terrain loss
estimated margin = estimated RX power - assumed threshold - fade reserve
```

The simplified link quality is neither RSSI, SNR, packet success rate nor an
actual connection probability. Terrain/frequency-dependent fade, antenna
orientation, multipath, adaptive bitrate, radio horizon, foliage and
manufacturing differences are incompletely modeled.

### Regional reference scenarios

| Preset | Frequency | Reference EIRP | Assumed effective threshold | Fade reserve |
|---|---:|---:|---:|---:|
| DJI O4 Pro EU/CE video | 5800 MHz | 13.9 dBm | -124 dBm | 12 dB |
| DJI O4 Pro FCC video | 5800 MHz | 32.9 dBm | -110.3 dBm | 12 dB |
| TBS Crossfire EU/CE RC | 868 MHz | 14 dBm | -120 dBm | 10 dB |
| TBS Crossfire FCC sample RC | 915 MHz | 24 dBm | -120 dBm | 10 dB |

The O4 receive thresholds are **derived planning parameters**, intentionally
adjusted relative to idealized manufacturer test ranges; **they are not real
measured sensitivity**. The Crossfire FCC row is one sample 250-mW profile,
not a legal or universally supported hardware setting. EU/CE, FCC and Custom
settings are separate for each channel. Scenario selection never operates a
transmitter or licenses its use.

## RC failsafe and manual takeover

`web/features/signal/simulated_failsafe.js` owns the state transitions. The optional behavior
is **disabled by default**. Loss/recovery require appropriate modeled RC
quality, thresholds and duration, with separate hysteresis. Unknown terrain,
video impairment and the optional terrain-only video demonstration do **not**
assert RC loss. A session-only manual training RC input can demonstrate modes.

The GPS Rescue state sequence is **hold → climb approximately 100 m above loss
altitude → turn toward home → controlled-altitude return → auto-land near the
home ground surface**. Flight movement still uses its usual bounded velocity,
wind and terrain/model contact handling. Inadequate navigation or known battery
shortfall must not be presented as a guaranteed safe return.

A stable RC reconnection alone does not cancel the maneuver: a deliberate
pitch/roll/yaw action is required. Once reconnection is qualified, brief
unknown values or intermediate hysteresis-band values do not immediately revoke
pilot takeover; sustained renewed loss or about five seconds without modeled
RC data does. Throttle alone is not a deliberate control takeover. The RC
state, not the video overlay, authorizes takeover.

## Regression and performance checks

```sh
node --test test/js/*.test.cjs
flutter test test/features/signal/live_radio_controller_test.dart
node tool/benchmark_simulator_terrain_gaps.cjs
```

Check paths around **5.9, 6.1, 10, 20, 30 and 49.9 km**; record terrain query
counts, elapsed time, maximum spatial gap and coverage classification. Repeat
on Android/Windows in profile mode and distinguish cold/warm caches. For the
full measurement procedure see [performance](performance.md). Synthetic Node
benchmarks are **not** GPU/real-tile evidence.

Read the [user-facing flight guide](../user/flight_simulation.md) and
[historical implementation notes](../../CHANGELOG.md) for context; dated
notes may describe superseded defaults such as the old 6-km cap.
