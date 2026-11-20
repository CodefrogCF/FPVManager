# Simulated RC failsafe and GPS Rescue

> **Historical implementation note (November 2026).** This document records an earlier development stage. Some limits, defaults or statements have since changed. For current behavior use the [user guide](../../user_guide.md), [flight simulation guide](../../user/flight_simulation.md), [radio model reference](../../developer/radio_and_rescue.md) and [battery reference](../../developer/battery_model.md).


## Purpose and boundaries

- Training/visualization only, **not** Betaflight or DJI firmware emulation, RF prediction, or a guarantee of a safe return.
- The feature is **off by default**. It activates only from a valid explicitly modeled `controlLink` object (`source: rfModel` or `estimatedModel`) with quality in `[0, 1]`. A visual terrain-risk illustration, a missing profile, and video-link loss **cannot** cause a failsafe.
- No production RF propagation model is currently added. To demonstrate the behavior, enable the explicit **manual RC test signal** in the in-flight options and move its slider from 100% to 0%. The test value is session-only, is identified by `detail: manualTraining`, and resets on leaving the flight.

## Architecture

- `web/simulated_failsafe.js`: pure, deterministic state machine independent of Cesium, Flutter, HUD and frame-rate. Config validation, simulated link provenance, delayed activation, recovery hysteresis, recovery handoff and navigation preconditions.
- `web/live_radio.js`: exposes a session-local, opt-in manual training RC quality while preserving the separate geometric visibility and video channels. No per-frame terrain sampling added.
- `web/free_flight.js`: feeds simulated link assessment into the state machine and implements an approximate GPS-guided automatic velocity controller. Every automatic movement traverses the existing normal **terrain and 3D collision sweep**. Manual controls are ignored during takeover and sticks cleared on entry and handback. Playback never activates failsafe; reset/start/dispose return it to normal.
- `web/flight_hud.js`, `web/globe.html`, `web/globe.js`, and CSS: separate state labels and controls. Flight settings persist via a dedicated `simulation.failsafe.v1` user preference; training signal does **not** persist.
- `lib/features/simulation/failsafe_settings.dart`: validated model used by Flutter's simulation settings and preferences storage, with no schema migration.

## Logic

- Default action is `hold` (assisted approximate position hold), optionally `descend` or `gpsRescue`.
- Only sustained RC quality <= `lossThreshold` for `activationDelaySeconds` triggers takeover.
- A recovered RC quality >= `recoveryThreshold` for `recoveryDelaySeconds` permits automatic recovery or an explicit manual handback. Unknown RC state is neither confirmed loss nor proof of recovery.
- GPS Rescue uses the **takeoff point**, which is independent of the selected operator/ground-station position. It climbs toward `takeoff altitude + rescueAltitudeMeters` and then travels toward home, slowing as it approaches. It does not change the launch point, teleport the drone, avoid all obstacles or perform a guaranteed landing.
- Estimated power from the existing battery profile is used to reject returns when **known insufficient**. With no battery profile there is insufficient evidence to declare a safe return; the simulation can run but must not be interpreted as a reserve assessment.
- If position/altitude is missing or estimated reserve is inadequate, the state becomes `unavailable` and the controller attempts an assisted hold instead of pretending rescue works.
- Both RC and video link can be unknown. Setting terrain illustration to obstructed does not affect control.

**Known limitation:** GPS-assisted rescue is illustrative and uses a simplified assisted-speed controller and chosen altitude relative to the takeoff point. It cannot validate real Betaflight GPS Rescue logic or ensure adequate clearance over a different mountain along the return path.
