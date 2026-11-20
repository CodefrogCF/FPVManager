# Adaptive live radio line-of-sight (1 m to 50 km)

> **Historical implementation note (November 2026).** This document records an earlier development stage. Some limits, defaults or statements have since changed. For current behavior use the [user guide](../../user_guide.md), [flight simulation guide](../../user/flight_simulation.md), [radio model reference](../../developer/radio_and_rescue.md) and [battery reference](../../developer/battery_model.md).


## Data path and scope

`LiveRadioController` uses `LiveTerrainSampler` and the existing `RouteSamplingPlan` (WGS84 great-circle positions) and `calculateRadioLink()` geometry/Fresnel kernel. No second LOS engine is introduced. Both route and live analyses continue to use WGS84 ellipsoidal heights. The shared kernel now locates each sample along the radio path by its *geodesic fraction*, not by its index, because refinement generates unevenly spaced heights.

The first Cesium sampling pass covers the entire path. When configured, a second pass prioritizes gap midpoints close to an existing sampled Fresnel intrusion/obstruction, sections with notable elevation changes, and large under-sampled intervals. Each bridge request has a hard limit of 256 positions. Sampling is sequential, with an existing single-flight request guard; outdated results are discarded via revision and flight checks. The browser retains a 30-second height cache capped at 4096 positions.

| Ground distance | Stage-one positions (maximum) | Targeted refinement positions (maximum) | Minimum refresh interval | Approximation gap threshold |
|---|---:|---:|---:|---:|
| 1 m–6 km | 251 | 0 | 250 ms* | 40 m |
| >6–15 km | 128 | 128 | 450 ms* | 80 m |
| >15–30 km | 96 | 96 | 850 ms* | 165 m |
| >30–50 km | 96 | 96 down to 64 | 1500 ms* | 300 m |

*The speed-aware interval may be longer. Limits are initial conservative **sample budgets**, not measured Android/Windows performance targets. A tier's maximum gap threshold is **not** an elevation model's true spatial resolution.*

The profile budget can be overridden by injecting a `LiveSamplingTier Function(double)` into `LiveRadioController` for testing or future device-specific tuning. The bounds and geographic range are validated; UI tuning is intentionally out of scope.

### Confidence and RF

- If coverage gaps remain larger than the configured threshold, the assessment is `limited`. An under-resolved clear sample must **not** be presented as verified unobstructed visibility. For such a result the WebGL HUD shows `LOS: ?` and no green clear ray.
- A *limited* path does not supply estimated RC/video link quality to failsafe; both stay `unknown`. The same applies when terrain is absent, stale, invalid, or beyond 50 km.
- Radio details can still show independent, labelled **SIM free-space only** link budgets based on selected EU/FCC/custom radio presets. These values are mathematical assumptions, not a reception measurement and **never** enter the failsafe's RC-quality input.
- With adequately sampled terrain (still approximate due to level-12 DEM and unknown material attenuation) existing video and RC RF calculations remain independent, including Fresnel intrusion, obstruction, assumed receiver thresholds and fade margins.
- Any sampled obstruction is an indication, not a certainty that a real link will fail. Surface vegetation and buildings require explicit observations and are not universally included.

### Diagnostics

The `set-live-radio-result` bridge records the selected sampling tier, coarse and refined point counts, number of terrain queries, elapsed processing milliseconds, maximum sample gap, and whether coverage was limited. The radio details display the sampling tier, sample count, maximum gap and uncertainty. The Dart `LiveRadioController.samplingDiagnostics` holds the latest result. This is session-only diagnostic information; no telemetry or statistics are uploaded.

The 50-km upper bound is a **software limit**, not usable, safe, guaranteed, or legally permitted FPV flight range. Airspace restrictions, national aviation rules and radio-equipment legal limits are outside this estimation.
