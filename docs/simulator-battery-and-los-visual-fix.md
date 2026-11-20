# Simulator: motor-aware battery draw and non-collidable radio overlays

## Background and scope

This update is for *simulated* FPV flying. It does not predict measured pack
current, cell temperatures, real-world battery life, or regulatory radio range.
The route energy model is unchanged; the live Acro/Angle flight simulator now
uses its existing motor-thrust estimate for battery consumption.

## Power model

- Manual **Acro** flight uses the already simulated motor acceleration relative
  to gravity (`motorThrust / 9.80665`) as an approximate thrust-to-weight ratio.
  A zero-throttle ballistic fall consumes an estimated minimum electronics/
  idle power, **not** level-flight power proportional to its vertical speed.
- Manual **Angle** flight uses the commanded supported thrust in the same
  approximation. Both modes use horizontal air-relative speed for the optional
  speed-related aerodynamic component.
- Estimated motor electrical demand scales roughly with the **1.5 power** of
  thrust-to-weight, normalized to the user-configured hover power. An additional
  bounded forward-flight cost uses the existing speed/power profile. No extra
  climb-work term is added when motor thrust is already modeled.
- **GPS flight, automated rescue, and route replay** continue to use the
  original speed-based proxy (with positive climb work) because thrust demand
  cannot be reliably reconstructed from their setpoint/recorded trajectory.
- A former unconditional 10% live power multiplier was removed. If max-power
  metadata are configured, the motor-based power estimate respects that cap.
  Model parameters are approximate; the power cap is a specified bound, not a
  guarantee of real thrust at that demand.

### 7-inch RC example

A nominal LiPo 6S 4500 mAh pack contains about **99.9 Wh** at 22.2 V.
The test fixture models a **1,320 g** 7-inch quad with example hover/cruise/
maximum power inputs of **180 / 290 / 1100 W**. These power numbers are **test
assumptions**, not measured specifications of the Axisflying 287 1750KV,
MEPSKING Space 60A ESC or HQProp 7x3.5x3V1S propellers. An accurate estimate
requires voltage/current or discharged-mAh logs from comparable real flights.

At **0 mΩ per cell**, the editor has no manufacturer-validated resistance
value. The simulation therefore selects a nonzero *chemistry reference*;
enter a positive measured or manufacturer-verified value to override it.

## Non-collidable LoS visualisation

Cesium `Scene.sampleHeight` can sample arbitrary drawn primitives in addition to
physical 3D buildings or ground. The sampled-height collision estimator now
passes **all entities owned by `fpvVisualOnly` data sources** to Cesium's
`objectsToExclude` parameter. The standalone simulated ground-station marker
is marked visual-only too. Physical 3D models are not excluded and retain their
existing optional collision behavior. The terrain/tunnel collision subsystems
are unchanged. This is not a comprehensive real-world obstacle detector.
