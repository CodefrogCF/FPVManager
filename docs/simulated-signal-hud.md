# Simulated signal indicators and analog FPV effects

## Overview

This implementation separates link assessment, its presentation model, and
rendering effects. The new `web/signal_hud.js` module owns visual thresholds,
smoothing, mapping and DOM effects. `web/flight_hud.js` provides the integration
without changing flight physics or navigation controls.

## Enabling

From the simulator's **Camera & display** controls, individually enable:

- **DJI bottom-edge warning**: orange for weak video, red for critical/lost.
- **Betaflight signal bars**: separate video and RC indicators; absent link
  estimates are *unknown*, not zero-quality reception.
- **Betaflight analog interference**: inexpensive, CSS-only scanline/static
  overlays, updated at most at the existing HUD update rate (about 10 Hz).
- **Terrain-risk illustration**: a separately enabled, visual training proxy
  mapping known clear/Fresnel-obstructed/obstructed geometry to approximate
  *video* quality. The label says `SIM TERRAIN` and must never be called RSSI,
  measured LQ or an RF link-budget result. RC remains unknown.

Thresholds (weak > critical > loss) and noise intensity are configurable in
flight and in the Flutter simulation settings. They are saved in the existing
local SQLite user-preferences store as `simulation.hud.signal.v1`, without
telemetry, accounts, remote services or new database migrations. Preferences
reset with the other map/simulator preferences.

## Signal inputs and limits

The existing `LiveLinkAssessment` from the existing live radio analysis supplies `visibility`,
`source`, `confidence`, and separate `controlLink`/`videoLink` fields. Until a
proper RF model is available, the production controller sets **both to
`unknown`**. The rendering module accepts a quality between 0 and 1 only from
an explicitly marked `rfModel` or `estimatedModel`. These are **model outputs**,
never measurements. A terrain visual proxy is available only on user opt-in and
is *not* fed back into the link assessment or future failsafe system.

Without available data, warning edges and noise are hidden and signal bars
show an unknown state. Pauses, expired terrain assessments and the start of a
new flight reset the overlays rather than carrying forward stale warnings.
Video-only effects do not alter RC quality or flight behavior. This is not a
prediction of range, link loss, or legal flight safety. Fresnel geometry alone
cannot justify an RC failsafe in a future failsafe feature.

## Performance

The generated interference uses fixed DOM elements and CSS gradients, not
frame-by-frame texture uploads, canvas readbacks or terrain sampling. It is
updated only on flight HUD refresh/assessment changes and disabled when not
shown.