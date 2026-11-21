# Advanced flight physics validation

## Reproduce the controlled benchmark

From the repository root, using Node.js 20+:

```sh
node tool/benchmark_advanced_validation.cjs
node tool/benchmark_advanced_validation.cjs --out=.local-performance/advanced-run-001.json
node tool/benchmark_advanced_validation.cjs --profile=reference-7-inch --scenario=climb --model=advanced --fps=60
node --test test/js/advanced_validation.test.cjs
```

Create `.local-performance/` before writing reports; output files are never
silently overwritten. With no scenario argument the runner exercises both
profiles at 30, 60 and 120 render FPS with 120 Hz physics, compares all 10 Hz
sampled state channels, runs Legacy at 60 FPS for each scenario, and injects one
2-second frame stall per hardware profile. The stall trace is explicitly marked
as script-clock rather than a normal telemetry comparison. No network, Cesium,
actual controller, or real weather is used. No data is uploaded.

The [profile definitions](../../tool/physics_validation/profiles.json) distinguish
the user-supplied reference 7-inch, 1,320 g, 1750 KV, HQProp 7×3.5×3, 6S 4500 mAh
quad from an illustrative 650 g 5-inch synthetic quad. Pack ratings and ESC
ratings are reference specifications, not independently verified current limits.
Resistance, maximum electrical input, drag, moments of inertia, hover/cruise
parameters and manufacturer-independent thrust coefficients remain estimates.
Neither aircraft is calibrated by these benchmarks. Retain a second real
configuration as a holdout before changing the global model.

| Scenario | Scripted input / conditions |
|---|---|
| `hover` | GPS neutral, 10 s |
| `climb` | Acro, throttle 0.8, 5 s |
| `cruise` | GPS forward 1, 15 s, target 12 m/s |
| `dive` | Acro powered pitch at 0 s, zero throttle at 1 s, recovery inputs at 5/6 s, total 8 s |
| `braking` | GPS forward for 6 s, neutral for 6 s |
| `freefall` | Acro, neutral/zero throttle, 5 s, reference initial clearance 200 m |
| `rotation` | Acro roll, zero-throttle reversal, stick release, pitch/yaw and recovery, 6 s |
| `lowPower` | Acro full throttle, 12% charge and synthetic 0.2C limit, 5 s |
| `wind` | Seeded environmental provider with synthetic 7 m/s fallback, gust and turbulence; forward 6 s then neutral 6 s |
| `landing` | Acro spawn 1 m AGL, zero throttle 3 s, then takeoff command for 2 s |
| `collision` | GPS diagonal flight toward synthetic swept-model barrier, 8 s |
| `rescue` | GPS outbound 4 s, modeled RC loss, 36 s for rescue |
| `takeover` | Acro, simulated RC loss at 1 s, restored at 4 s, deliberate roll at 5 s, total 8 s |

Exact inputs are in `tool/physics_validation/scenarios.cjs`. All positions use
an artificial flat terrain elevation of 1000 m; the collision barrier is a mock
known obstruction rather than proof of real Cesium raycasting coverage. Report
sampled traces and assertions verify behavior and numerical consistency, not
physical accuracy. The energy consumption and constant-load endurance proxy
are estimates. The latter divides remaining modeled Wh by the mean modeled
power over the final five seconds of hover/cruise; it is not a full discharge
measurement or a recommended real-world flight duration.

The [published synthetic reference](../performance/advanced_physics_synthetic_reference.json)
contains the captured Node version, host CPU, both profiles, per-scenario final
samples, frame-rate differences, memory observations and step/frame timings.
Step latency is instrumented elapsed time around `stepCore` (excludes Advanced
camera interpolation; Legacy presentation is still inside its step). CPU time
is process user + system time, including harness instrumentation. Heap and RSS
are sampled, not allocation counts, retained-memory measurements or worst-case
peaks; Node JIT/GC and shared host noise affect results. Do not compare a single
Legacy step against an Advanced step as though they had identical dt. Compare
CPU per simulated second and frame/timing distributions using repeated fresh
runs. No hard timing threshold is enforced in CI on variable hosts.

## Optional real telemetry comparison

Export your own Blackbox log using an appropriate decoder, or use an existing
flight-controller/GPS export. This tool does not decode binary Blackbox logs.
Select an already recorded or independently safe, controlled maneuver; no need
to fly risky dives or induce a real RF failsafe to test the simulation. Trim to a
matching maneuver, convert units explicitly and align start time and commands.
Use a normalized UTF-8 numeric CSV (comma delimiter, decimal point, no quoted
fields). The first column must be `time_s`, nonnegative seconds, strictly
increasing. Empty fields mean unavailable; do not substitute zero. File limit
20 MiB / 100,000 samples. Example of the format only (not measured data):

```csv
time_s,speed_mps,vertical_speed_mps,altitude_change_m,voltage_v,current_a,energy_wh
0,0,0,0,24.8,3,0
0.1,1,0.5,0.02,24.5,8,0.004
```

Supported optional columns:

| Field | Meaning |
|---|---|
| `speed_mps`, `horizontal_speed_mps`, `vertical_speed_mps` | Ground-relative magnitude, horizontal magnitude, signed up velocity (m/s) |
| `airspeed_mps` | Air-relative 3D speed, only if actually available |
| `altitude_change_m` | Altitude minus recording start height, consistent vertical datum; not AGL over changing landscape |
| `speed_change_mps2`, `vertical_accel_mps2` | Finite-difference scalar speed change or signed vertical acceleration, not raw accelerometer specific force; use matching 0.1 s intervals |
| `roll_deg`, `pitch_deg`, `yaw_deg` | Angles in degrees with the simulator's body/local convention |
| `qw`, `qx`, `qy`, `qz` | All four unit quaternion components, body forward/right/down to local north/east/down; convert source conventions first |
| `voltage_v`, `current_a`, `power_w` | Loaded pack voltage, nonnegative pack DC current and input watts, not motor phase current |
| `energy_wh` | Cumulative consumed Wh since segment start; convert reliable energy/current data explicitly |

GPS-only recordings generally do not contain orientation, currents, airspeed or
pilot commands. Do not invent those channels. If needed, derive power from
synchronized pack voltage/current and integrate over known valid samples; leave
energy empty across unverified gaps. Radio reconnection/return data should be
from existing logs or safe assisted simulations; do not perform real signal-loss
experiments merely to complete the checklist.

```sh
node tool/benchmark_advanced_validation.cjs --profile=reference-7-inch --scenario=climb --telemetry=.local-performance/recorded-climb.csv --offset=0 --out=.local-performance/compare-climb.json
```

The offset maps recorded time to simulation time (`recorded + offset`). The
comparison uses interpolation on the simulation trace, no extrapolation; gaps
above 0.25 s are skipped. Missing channels are omitted, and the report contains
matched/skipped row counts and per-channel sample counts, signed bias, MAE,
RMSE and maximum absolute error. Euler errors wrap at 360 degrees; the
quaternion error is the unsigned shortest orientation angle. A comparison with
few matching samples or unmatched input trajectories is not a calibration.
For recorded endurance, compare usable measured Wh and mean stable pack power
only under comparable conditions; do not compare full-flight duration to the
synthetic five-second constant-load estimate without matching the usable energy
and load window. Preserve raw logs separately; no coordinates or personal
identifiers are required. The importer does not fit coefficients automatically.

Record the aircraft, firmware, propeller, pack age/temperature, charge level,
input timings, wind, sensor accuracy and calibration status with every
comparison. Save differences even when the match is poor. Validate at least
hover, climb, cruise, braking and rotational/deceleration responses over both
configurations using suitable existing data. Compare simulation GPS return
against available independently collected assisted-return logs where applicable.
A missing channel or missing maneuver remains **not evaluated**, not a pass.

## Android and Windows validation

Run the app in profile mode with explicit opt-in local diagnostics (disabled
in ordinary builds):

```sh
flutter devices
flutter run --profile -d <android-id> --dart-define=FPV_PHYSICS_VALIDATION=true
flutter run --profile -d windows --dart-define=FPV_PHYSICS_VALIDATION=true
```

Keep the application console or `flutter logs` output. Every two seconds during
an active simulation, the app requests aggregate physics and scene metrics and
logs a line prefixed `[FPV physics validation]`. On the first sample the scene
probe starts; exiting the flight stops it at the next poll. The probe measures
integration wall-time, cumulative count/total/max and bounded rolling p50/p95
(up to 240 recent samples), plus scene CPU callbacks and frame pacing. Physics
clock counters record simulated, queued and dropped seconds. The last sampled
queue is not a maximum; short spikes can be missed. The probe adds a little
overhead and does not sample every frame over the bridge. It contains no
location or pilot input data. Resetting a flight resets the physics clock;
exit and wait for the probe to stop before beginning another measurement.
Use the opt-in build for local tests, not for release distribution.

On **Android** use Android Studio System Trace/Profiler or
`adb shell dumpsys meminfo com.codefrog.fpvmanager` (verify installed package
ID), capturing the app and WebView renderer processes where possible. On
**Windows** use Task Manager/Performance Monitor or Windows Performance Recorder,
including WebView2 child processes. Record process CPU time and private/RSS
memory at start, during flight and after exit; record allocation/GC traces when
supported. Flutter DevTools does not measure all WebView or GPU memory.

Run at least three comparable 60-second flights per mode and condition:

- Open terrain: warm-up, straight cruise, braking, repeated roll/pitch, landing.
- Complex terrain: repeat the same route with terrain, bridges, buildings and
  3D tunnel models loaded, including fast turns and high-speed simulated motion.
- Rescue and controller transitions: simulated link loss, reconnect, deliberate
  takeover, automatic landing, and a run with a weak selected battery.
- Stability: at least one 10-minute continuous session per mode/platform, with
  repeated resets and a return to the globe; inspect for rising memory or stalls.

Use identical app revision, graphics profile, resolution, overlay/model
settings, aircraft, locations, controls, cache state and thermal conditions.
Test 120 Hz first; repeat Advanced at 60/240 Hz if useful. Record device model,
OS/WebView versions, CPU/GPU, RAM, power mode, display refresh, data/cache
conditions and actual route or reproducible reference. Note whether conditions
are cold or warm. Do not mix synthetic results with device results.

Use [the device measurement template](../performance/advanced_physics_device_template.json)
per run. Suggested initial review gates (project targets, not measured results):
no crash/hang, no collision bypass or control regression, stable physics clock
(no sustained backlog; dropped time explicitly investigated), and median/p95
frame interval and CPU/memory acceptable relative to Legacy on the same device.
Aim for p95 frame interval at most 33.4 ms during continuous flight and p95
integration time below the selected step budget (8.33 ms at 120 Hz); review
combined multi-step and renderer cost too. If Legacy itself misses a target,
record that separately; do not automatically pass Advanced. Confirm acceptable
controller response and thermal/memory stability by repeated measurement.

## Completion and default-model decision

| Evidence | Current status |
|---|---|
| Reference hardware definitions, provenance and controlled scenario suite | Implemented |
| Frame independence, low-voltage limits, collision, rescue and compatibility regressions | Synthetic tests available |
| Reproducible CPU, step latency, sampled memory and stall reports | Synthetic results captured |
| Real flight comparisons / calibrated parameter differences | Pending suitable recorded telemetry |
| Android Galaxy S25 Ultra and Windows with actual Cesium terrain / 3D data | Pending measurements |
| Flutter analysis, Flutter tests and target builds | Run on development machine / CI |
| Advanced as default | Not approved; retain Legacy until gates are satisfied |

Revisit the default only after recording real-flight differences and actual
device evidence, reviewing critical regressions, and documenting accepted
calibration limits. Synthetic green tests are necessary but insufficient to
claim physical validation or release readiness. Both physics modes preserve
existing profile formats; no database or backup migration is introduced.
