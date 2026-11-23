# Advanced physics: focused references

This section documents mechanisms that supplement the **current** [flight physics architecture](../flight_physics_architecture.md). It is intended for implementation and regression work; user controls and flight limitations belong in the [flight simulation handbook](../../user/flight_simulation.md).

- [Body-axis aerodynamics](advanced-body-axis-aerodynamics.md): translational air drag and model assumptions.
- [Rotational dynamics](advanced-rotational-dynamics.md): attitude rates, inertia and Acro response.
- [Environmental wind](advanced-environmental-wind.md): gusts, regional continuation and terrain influence.
- [Ground effect and propwash](advanced-ground-effect-propwash.md): near-ground thrust and descending airflow.
- [Collision response](advanced-collision-response.md): swept contact, landing and residual limitations.
- [GPS-assisted flight control](advanced-gps-rescue-flight-control.md): autonomous control and GPS Rescue flight phases.

Use [Advanced physics validation](../advanced_physics_validation.md) for repeatable tests and device measurements. Model defaults and limits are **simulation approximations**, not measured performance of an individual airframe.
