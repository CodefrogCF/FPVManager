# Live radio baseline comparison (R39)

This patch restores the November 21, 2026 implementation immediately before
Rüdersdorf was introduced. It is intended for **A/B device testing** of live
terrain sampling stability, not to roll back the FPVManager application.

## Git history

- `350985406bd99cf54f627e8fafe2afd5ec61b3da` (2026-11-20): *Extend Live Radio Line-of-Sight Analysis Beyond 6 km with Adaptive Terrain Sampling* (1–50 km)
- `d1fca7e1cffb22859cc7a10f8b111ee31d565711` (2026-11-21): final commit before Rüdersdorf
- `623d6bfb7b09e3ec8754f40f4af22ad1f2302266` (2026-11-22): first Rüdersdorf scenery and regional map commit

Source files were recovered from the provided pre-R36 project archive,
whose 50-km sampling policy and WebView module match the historical GitHub
implementation. The following four production files and three matching tests
were selectively restored:

- `lib/features/signal/live_radio_controller.dart`
- `lib/features/signal/live_sampling_policy.dart`
- `lib/features/signal/live_terrain_sampler.dart`
- `web/features/signal/live_radio.js`
- `test/features/signal/live_radio_controller_test.dart`
- `test/features/signal/live_terrain_sampler_test.dart`
- `test/js/live_radio.test.cjs`

No `web/globe.js`, Rüdersdorf GLB/FPC, flight physics, UI menus, radio
profiles, failsafe module or global terrain provider was reverted.
The current map's **BKG beta RF lockout** is intentionally retained because
its vertical datum is not validated.

## Test protocol

1. Record the same ground station, altitude, drone radio profile, terrain
   provider, route, speed and network conditions in both builds.
2. Compare `?` duration and proportion, query timeout counts, and visible
   correctness at 0.5, 1, 2, 5, 8 and 10 km. Compare slow and fast flight.
3. Do not treat an old clear profile as an indication that RF is really clear.
4. Run `node --test test/js/*.test.cjs`, `flutter analyze`, `flutter test`
   and a device test. CI results cannot verify network or device latency.

If the baseline still fails, isolate **terrain provider** and
`web/globe.js` integration, including BKG beta selection, request cancellation,
provider availability and scene-layer behavior, before changing more RF math.
