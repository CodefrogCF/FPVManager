# Advanced collision response

This describes a **simulation-only**, approximate collision response. It does
not infer structural survivability, clearance, or safe FPV flight envelopes.

## Existing swept detection retained

`web/free_flight.js` continues to query the existing swept terrain ray, the
supported tunnel/bridge/opt-in model geometry and a rendered-height sweep with
0.5 m maximum horizontal sampling interval. Existing scene and RF visual-only
exclusions are unchanged: LoS rays, Fresnel volumes and marker entities do not
become physical obstacles. Legacy mode retains the previous immediate-stop
behavior. Advanced uses the same source predicates and processes the contact
before moving into known geometry.

## Parameters and collision response

`web/collision_response.js` provides a deterministic bounded response for
world-axis velocity (north/east/up, m/s) and a normalized outward contact
normal. The reaction projects incoming velocity onto the normal and tangent,
removes the incoming normal component, reduces tangential speed by a
Coulomb-inspired friction impulse, and optionally rebounds at a limited
coefficient of restitution. It never increases kinetic energy and never
manufactures momentum from a separating contact.

| Option | Default | Range | Meaning |
| --- | ---: | ---: | --- |
| mode | slide | slide / rebound / hard-stop | Advanced response type |
| friction | 0.28 | 0–1 | Tangential velocity loss per collision impulse |
| restitution | 0.12 | 0–0.75 | Rebound ratio in `rebound` mode |
| minimumReboundSpeedMs | 1 | 0–10 | Impacts slower than this do not bounce |
| hardStopNormalSpeedMs | 22 | 1–150 | Normal impact speed at or above this fully stops the aircraft |
| terrainProbeMeters | 0.6 | 0.2–3 | Radius of height-gradient samples |

Settings are available in the Advanced Flight Physics section; Flutter sends
`collisionResponse` through `SimulationSettings.toCommand()`. The default is
`slide`. Existing flight settings do not contain this key and therefore use
the default without migrating saved data.

For terrain height-field contacts, the normal is estimated from four **finite**
nearby rendered height samples. Missing samples, excessive slopes, unsupported
model geometry, or a surface without an authoritative normal cause a hard
stop rather than a fabricated bounce or assumed flat collision plane. Swept
model sources that eventually expose a genuine normal and first-hit fraction
may return `{kind, normal: {north,east,up}, fraction}`. Current production
model sources generally supply only a collision type/boolean, so they retain
hard stops. A model envelope is **not** a surveyed surface.

The simulator stops short of the first confirmed contact. Gentle verified
impacts can continue tangentially through a bounded second sweep, without
skipping collision queries. Terrain-following correction is limited, and
remaining clearance along the candidate is checked at bounded increments.
High normal-speed impacts hard-stop. Rebound has a lower-speed dead zone to
avoid repeated micro-bounces under gravity. This is not a rigid-body solver:
rotor breakage, angular impulse, deformation, damage and impact friction
against moving objects are out of scope.

## Missing terrain and tunnel transitions

Missing rendered terrain returns **unknown** instead of confirmed clear or
confirmed solid. The existing `terrainVerification` sampling diagnostics,
accumulated unverified distance, tunnel handoff protection and model collision
sweeps remain in use. The simulator does not extrapolate a surface normal
through unloaded tiles, nor interpret the absence of a hit as a verified
clearance result. Collision diagnostics are exposed as `lastCollision` in the
flight state for inspection; they are not damage estimates.
