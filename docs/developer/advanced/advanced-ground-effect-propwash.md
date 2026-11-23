# Advanced ground effect, propwash and simplified descent aerodynamics

**Optional simulation heuristics — not validated aerodynamics, CFD, or a
vortex-ring-state detector.** These effects default **OFF** independently.
They only run in the advanced physics model; legacy trajectories are unchanged.

## Input contract and provenance

`web/features/flight/physics/descent_aerodynamics.js` exports `configuration` and `evaluate`.
Input includes delivered **free-air** thrust acceleration (m/s²), commanded
motor fraction, orientation quaternion, **air-relative** velocity in
north/east/up (m/s), a terrain clearance if verified (m), propeller diameter
(m), number of rotors, aircraft mass and deterministic simulated time (s).
The motor diameter and mass are taken from the validated propulsion hardware
profile when available. Without a complete hardware profile, the configured
assumed diameter defaults to **0.1778 m (7 inches)**, mass to **1.3 kg**,
and rotor count to four. These are **assumptions**, not measurements.

The module returns an adjusted thrust acceleration and a bounded 3D force
perturbation along with diagnostic fractional gain/loss values. It changes
**effective aerodynamic force only**, not reported motor thrust, electrical
power, current, or battery state. It cannot supply motor thrust when the
physical motor output is zero or commanded off.

## Near-ground thrust enhancement

Ground effect approximates reduced induced power required near a horizontal
supporting surface. Let D be rotor diameter, h verified rotor-centre height
above rendered terrain, T delivered thrust acceleration and u the vertical
component of the body thrust axis. The non-dimensional gain is:

```
P = clamp(1 - h / (4D), 0, 1)
G = clamp(0.25 * groundIntensity * P² * min(T/g, 1) * max(u,0)², 0, 0.30)
```

`T_effective = T * (1+G)` before other effects. **No gain** is introduced if
motor power is absent, terrain height is unknown, terrain clearance is
negative/nonfinite, the aircraft is inverted, or the aircraft is farther than
four rotor diameters from verified terrain. This is a bounded approximation:
it does not simulate blade-to-blade downwash interaction, rotor separation,
surface roughness, walls, ceilings, grass or sloping-ground recirculation.

The collision/terrain sweep remains authoritative, with its existing 0.5 m
safety floor. Each physics step reads the already-sampled terrain height at
the **current position**. If the simulated craft moves more than 0.5 m
horizontally from that sampled location during the step, the ground boost is
suppressed rather than extrapolating a flat ground plane. No additional
terrain queries, fabricated ground heights or collision bypasses are added.

## Powered descent: propwash and vortex-ring-like loss

The approximation uses rotor-disc axial descent relative to **air**, not
ground speed, and ignores the effect at zero motor power. A representative
induced velocity is estimated from current free-air thrust and the total rotor
disc area: `v_i ≈ sqrt(T_newtons / (2 * rho * A_total))` with `rho=1.225`
kg/m³. A smooth peaked exposure envelope rises for descent around 0.2–0.7
`v_i`, then fades by 2.5 `v_i`. Crossflow progressively suppresses the
exposure. The envelope is a **heuristic**, not a physical VRS instability
boundary or blade-element simulation.

- **Propwash**: at most 18% power-dependent thrust loss, with bounded
  simulated-time sinusoidal lateral buffeting (independent of FPS).
- **Vortex-ring-like behavior**: a separately switched, additional capped
  thrust reduction, at most 40%, with no claimed detection of actual VRS.
- **Combined**: the final delivered effective thrust multiplier remains
  within **0.50–1.30** of the free-air motor thrust. These effects cannot
  reverse thrust or inject energy without motors.
- **Free fall**: at zero motor command/thrust all enhancements and disturbances
  vanish; the existing body-axis drag, including optional passive propeller
  drag, still determines ballistic motion.

The simulation uses one set of modifiers for Advanced Acro, Angle, GPS and
GPS Rescue. All modes still go through the same motor/battery limits,
body-axis drag, fixed timestep and swept terrain/model collision checks.
The added force is deliberately **not** fed back into the control system as
extra electrical capability or as an instant correction to velocity.

## Configuration

In the simulation settings under **Ground effect & propwash / Bodeneffekt &
Propwash**, independently enable ground effect, propwash and vortex-ring-like
loss. Each has a calibration intensity in `[0,2]`; rotor diameter fallback
in metres can be set in `[0.0254,0.762]`. Enabled options and intensities
are serialized in the `descentAerodynamics` settings object, preserved when
changing camera options, and validated on both Dart and JavaScript sides.
Existing configurations without this object remain compatible, with all
new effects disabled. The optional model itself remains separate from the
existing Advanced directional drag/low-power passive propeller drag.
