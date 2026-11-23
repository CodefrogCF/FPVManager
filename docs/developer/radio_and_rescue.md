# Live radio LoS, RF modeling and GPS Rescue

**Status:** current architectural reference for the simulator at v0.18.0.
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
4. `web/live_radio.js` and `web/rf_estimation.js` compute separate video/RC
   *assumed* link budgets when reliable terrain is available. The HUD and
   optional failsafe consume separate presentation and RC-quality channels.
5. `web/simulated_failsafe.js` manages opt-in RC link loss/recovery; flight
   movement is implemented through `web/free_flight.js` and normal collision
   checks. `web/rescue_velocity.js` handles bounded return acceleration/braking.

Keep the operator/antenna position independent of the flight home/takeoff
point. Repositioning the ground-station marker does not change GPS Rescue home.

## 50-km live terrain sampling

The live sampler works from **1 m to 50 km**. It creates a coarse full-path
profile then optionally refines gaps near obstacles, Fresnel intrusion and
large elevation changes. Each bridge request contains at most **256 positions**.
Requests are sequential, cached height samples are reused and stale/outdated
flight results are rejected. Final budget/update intervals vary with distance
and speed; see the current `LiveSamplingTier` implementation for executable
configuration rather than copying fixed values into new call sites.

| Distance | Coarse point budget | Additional refinement budget | Approximate gap limit |
|---|---:|---:|---:|
| 1 m–6 km | Up to 251 | 0 | 40 m |
| >6–15 km | Up to 128 | Up to 128 | 80 m |
| >15–30 km | Up to 96 | Up to 96 | 165 m |
| >30–50 km | Up to 96 | About 64–96 | 300 m |

These are conservative **budgets**, not source DEM resolution or measured device
performance. Short critical terrain features may be missed. The renderer's
terrain-height cache is bounded, and assessments expire when insufficiently
fresh for the current simulated aircraft position.

**Confidence rule:** a coarsely sampled or missing path may be `limited` or
`unknown`. Do not turn sparse samples into confirmed clear reception; do not
feed a free-space-only preview, a stale assessment or a terrain-only
illustration into simulated RC failsafe. The radio details display counts,
maximum sample gap, elapsed work and confidence. The 50-km limit is a software
boundary, not a real-world flight distance claim.

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

`web/simulated_failsafe.js` owns the state transitions. The optional behavior
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
