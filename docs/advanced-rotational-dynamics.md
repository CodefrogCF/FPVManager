# Advanced Acro rotational dynamics

This is an **optional, estimated** flight model enabled only when simulation `physicsModel` is `advanced` and `flightMode` is `acro`. Existing legacy Acro behaviour, legacy stick values and the assisted GPS/Angle flight modes are retained. These are *not* measured inertia/torque curves or an implementation of the Betaflight PID loop.

## Coordinate frames and state

- Right-handed local body coordinates: **x** forward / roll, **y** right / pitch, **z** down / yaw. Pitch stick input is sign-inverted as in the existing Acro implementation.
- Configured `rollInertiaKgM2`, `pitchInertiaKgM2`, `yawInertiaKgM2` (kg·m²) represent a **diagonal approximation** to the aircraft's rotational inertia tensor. Cross-axis gyroscopic coupling is not simulated.
- `rollTorqueNm`, `pitchTorqueNm`, `yawTorqueNm` (N·m) are **estimated maximum control torque** per axis, not raw motor torques or manufacturer specifications.
- `rollAccelerationLimitDegs2`, etc. (°/s²) additionally cap the angular acceleration of each axis. `controllerGainPerSecond` (1/s) converts rate error to requested acceleration.
- A separate `motorResponseTimeConstantSeconds` first-order filter smooths the **actuator torque**, independently of the already present thrust/propulsion motor response. Sudden available-power loss immediately clamps torque.
- `passiveDampingPerSecond` is an *estimated* angular damping term. It does not level the aircraft on centred sticks.

For a body axis \(i\), the simplified control calculation is:

```text
requestedTorque_i = clamp(inertia_i * gain * (targetRate_i - omega_i), +/- maxTorque_i * authority)
actualTorque_i    = firstOrderActuator(requestedTorque_i, previousTorque_i, motorResponseTimeConstantSeconds)
angularAccel_i    = clamp(actualTorque_i / inertia_i - passiveDamping * omega_i, +/- maxAngularAccel_i)
omega_i(next)     = omega_i + angularAccel_i * dt
```

The actuator output is also hard-clamped to the **current** `maxTorque_i * authority` after filtering. `authority` is calculated from actual delivered motor thrust (including available battery voltage/current, motor/ESC limits when available) relative to the configured thrust-to-weight scale. If the motors are unpowered, no *active* motor torque is generated; passive damping remains. This is an approximate authority model, not per-motor propwash or differential propeller mixing.

The orientation quaternion integrates the **midpoint angular velocity** over each bounded substep and is normalized after every update. Rotation uses the same fixed-time physics runtime as translation and is independent of Cesium render frames. Pauses, resets and stops reset actuator/rate state as appropriate.

## Rate shaping

The existing `acroRollRate`, `acroPitchRate`, and `acroYawRate` parameters remain **full-stick target rates in °/s**; `acroRateExpo` stays in `[0, 1]`.

- **Betaflight-inspired** (advanced default): cubic expo then normalized `superRate` shaping with a softer centre and full-stick rate preserved. This is not exactly Betaflight's RC Rate/Super Rate mapping.
- **Classic expo**: identical normalized cubic command curve to legacy Acro, but subject to inertia and torque limits.
- **Linear**: direct proportional rate setpoint with the same physical torque limits.

`superRate` in `[0, .95]` is only applied to the Betaflight-inspired profile. Rate shaping affects desired rates, never bypasses the rotational acceleration bound.

## Initial reference estimates

The default diagonal moments (.018 / .021 / .030 kg·m²), torque caps (1 / 1 / .45 N·m) and acceleration caps (4000 / 4000 / 2200 °/s²) are **illustrative** for an FPV quad and have **not** been validated on the 1.32 kg reference 7-inch craft. Suitable calibration requires measured step-response/Blackbox rates, ideally with motor/ESC and battery telemetry, plus reliable mass and frame dimensions. Modify the advanced settings to fit the measured aircraft; these defaults must not be used as manufacturer-certified performance values.
