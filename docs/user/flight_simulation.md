# Flight simulator, radio links and GPS Rescue

This is a **user guide** for the simulated aircraft. For implementation details and
model assumptions, see the [developer's radio reference](../developer/radio_and_rescue.md)
and [simulation/collision reference](../developer/simulation_and_collision.md).

## Start and control a flight

1. Select a map location, then open **Map actions → Flight simulator**.
2. Select a drone profile and the **Angle**, **Acro** or **GPS** flight mode.
3. Check **spawn height**, controller assignment, camera settings and terrain availability.
4. Start the flight. Reopen **Flight settings** to adjust camera/HUD, graphics,
   wind and radio settings without recreating the flight.
5. Use **Reset flight** to return to the spawn state, or exit to the globe.

Angle self-levels; Acro responds to angular-rate inputs; GPS is an assisted
position/altitude-control mode. The **Advanced** physics model is the default
for new flights in v0.19.0. It couples motor/propeller estimates, battery load,
directional drag, inertia, wind, ground contact and GPS Rescue using a fixed
physics timestep. These are conservative simulation approximations, not a
measured aircraft certification or a Betaflight implementation. Missing motor
specifications use the existing approximate propulsion fallback. See the
[main user guide](../user_guide.md#start-a-session)
for the general session workflow.

## Physics selection and recording view

- **Advanced (default)** – hardware-aware manual flight, shared GPS/Rescue
  dynamics, and fixed 60/120/240 Hz physics (120 Hz initially recommended).
  Camera FPS is independent of physics frequency.
- **Legacy (fallback)** – explicitly selectable previous flight model. Existing
  drone/battery profiles and their stored values remain compatible.
- **Clean capture** – during an active simulation tap the crossed-out camera
  icon in the upper Flutter toolbar. This hides the Flutter menus, HUD, touch
  sticks, simulator flight panel, compass and optional legends for screen
  recording. **Tap the invisible 64×64 px top-left corner to restore the
  controls**, or press Android Back. External controllers/keyboard remain active;
  touchscreen flight sticks are deliberately hidden until restored. Cesium map
  attribution is not removed. The mode is transient, not a saved preference.

Advanced Acro Air Mode can apply bounded rotational corrections at low throttle.
Optional Ground Effect, Propwash, vortex-ring approximation and Assisted
Landing (on supported steep surfaces) are selectable independently. Assisted
Landing is a **convenience option**, not physically realistic rock-face
friction. For high-speed impacts and uncertain terrain, collision/clearance
limitations continue to apply.

Physics is deterministic at comparable simulation clock input; long frame
stalls can still drop explicitly reported catch-up time. The new model is the
preferred default following functional Android/Windows trials, but **real
Blackbox calibration and detailed Windows CPU/memory benchmarks remain open**.
Switch to Legacy if a particular device or configuration behaves poorly.
The [technical validation report](../developer/performance.md)
separates measured, synthetic and pending evidence.

## Environmental wind in extended flights

The wind sheet can load Open-Meteo model values for a **local** 3×3 grid.
Inside this grid, the simulated flight uses the model wind unchanged when
optional effects are off. **Outside**, the simulator blends the boundary wind
into a synthetic regional continuation rather than suddenly entering calm air.
The distant estimate is **not a verified weather forecast**. The wind arrows
still display only the originally loaded local data.

Under **Regional wind and terrain effects**, optionally configure gusts,
turbulence, altitude wind shear, a missing-weather fallback wind, ridge lift
and lee-side sink. Ridge/lee effects are approximate and use only nearby
available terrain heights. Disabling wind influence restores no-wind flight.
Settings are session-scoped; no weather outside the loaded region is measured.
For derivation and limits, see
[advanced environmental wind](../developer/simulation_and_collision.md).

## Optional ground effect and powered-descent airflow

Under **Ground effect & propwash** in Advanced
physics, three independent options approximate near-ground thrust improvement,
powered-descent buffeting and vortex-ring-like thrust loss. All three are
disabled by default. The model uses the configured rotor diameter, or the
actual propeller diameter from a valid drone hardware profile. You can adjust
each effect's intensity for calibration.

Ground effect is only estimated when a terrain height sample is available
at the drone's current location; missing tiles **do not** generate a fictional
surface. Powered descent can lose some effective thrust, whereas zero-throttle
free fall retains its passive drag and no motor-induced propwash. These
simplified approximations are **not** an aerodynamic prediction or a safety
assurance. See [advanced ground effect and propwash](../developer/simulation_and_collision.md)
for assumptions, limitations and tests.

## Live radio line of sight

Open the **Radio line of sight** section during a flight. The
operator/ground station defaults to the flight takeoff point. You may instead
use a selected map point, saved spot or manually specified coordinates. Set
antenna height above the local ground; use **Reset to takeoff position** when
appropriate. The station marker and line-of-sight/Fresnel drawing can be
shown independently.

The live terrain profiler supports horizontal paths up to 50 km, including
vertical links directly above the station. It needs valid terrain and at least
1 m of spatial antenna separation. The software limit is not a guaranteed radio
range. Results distinguish sampled clear terrain, Fresnel intrusion, obstruction
and unknown/limited data. Blockage does not automatically mean total RC loss.

A profile expires within five seconds and can become unknown sooner after rapid
movement, missing terrain or provider changes. `?` is a passive HUD notice; it
never starts failsafe or GPS Rescue by itself. Fast flight can combine terrain
sampling passes while retaining the existing precision/freshness requirements.
BKG beta heights remain unsuitable for RF until their reference is verified.
An optional diagnostic view shows sampling and result age. A **SIM free-space
only** preview cannot replace a terrain observation or establish RC recovery.

Simulator settings are saved across restarts, including the selected physics
model, controls, camera, battery and physics options. Valid flight quick-control
changes are saved too. New portable backups include these preferences; older
backups cannot restore settings they did not contain.

## Video and RC profiles

Under **SIM RF profiles**, configure **video** and **RC** independently.
Available scenarios include **EU/CE**, **FCC**, and **Custom** for the DJI O4 Pro
video and TBS Crossfire RC illustrative profiles. Custom numbers or imported
radio equipment are not overwritten when configuring the other band. Frequency,
effective EIRP, assumed receiver threshold and fade reserve affect the
**simulation only**; nothing changes a physical transmitter or establishes legal
permission to use an RF setting.

Video and RC link estimates are separate and are **not** measured RSSI, SNR or
packet-loss data. The numerical model does not fully account for antenna
orientation, multipath, foliage, bitrate adaptation or receiver implementation.
See [equipment and battery profiles](battery_and_power.md) for entering hardware.

## Signal indicators and analog interference

Under **Camera & display**, you can enable DJI-style weak-video warnings,
Betaflight-style **separate video/RC strength bars**, and optional simulated
analog interference. The terrain-only illustration, when enabled, is labeled
**SIM TERRAIN** and is not an RF measurement.

A brief gap in the video-quality estimate can retain the prior *visual-only*
analog interference for up to **1.1 seconds** with occasional extra flicker.
During that gap the link indicators remain **unknown**. Visual noise **never**
triggers or prevents simulated RC failsafe.

## Optional failsafe and GPS Rescue

Failsafe is **opt-in** and uses **modeled RC quality**, not a video warning,
missing terrain sample or an obstructed-looking line by itself. The test
signal source is for the current simulation session only. User-defined
loss/recovery thresholds and delays take precedence over defaults.

The simulated Rescue sequence is:

1. Confirm a sustained simulated RC outage, then hold/stabilize.
2. Climb approximately **100 m above altitude at link loss** (configurable).
3. Turn toward the **takeoff home point**.
4. Fly back at controlled altitude and speed, subject to normal flight limits.
5. Approach the home point and initiate automatic landing.

A recovered RC link alone does **not** cancel Rescue. After stable simulated
reconnection, a deliberate **yaw, pitch or roll** input can return control to
the pilot **at any stage**, including mid-return; throttle alone does not.
Short uncertain readings do not immediately revoke takeover eligibility; a
confirmed second loss or prolonged missing RF data requires requalification.

GPS Rescue does not avoid unknown terrain, guarantee clearance, reproduce a
specific firmware version, or prove sufficient battery reserve. Takeoff home
and operator radio position are separate locations.

## Terrain collisions and long-range flights

Loaded, supported terrain and model surfaces still participate in the simulator's
collision checks. Radio sightlines, Fresnel displays and ground-station markers
are **visual-only, non-collidable** objects.

If individual Cesium terrain tiles have not yet yielded height data, the
simulated drone may continue moving. The HUD marks **terrain collision
unverified** and cannot claim known AGL clearance for those sections. This is
not proof that an unseen mountain or obstacle is safe to traverse. The session
tracks missing height probes and unverified simulated distance. Starting a
flight still requires an available terrain provider and a valid starting
height; full provider loss is handled separately.

### Troubleshooting

| Symptom | Check |
|---|---|
| Radio line is absent | Enable live preview; confirm ground station and valid terrain; examine confidence/status. |
| RF strength appears unknown | Missing/insufficient terrain is not confirmed clear reception. Use the labeled free-space preview only as an assumption. |
| Rescue does not activate | Confirm failsafe is enabled, the **RC** quality source is modeled, and the configured loss threshold/delay are met. |
| Sticks do not cancel Rescue | Confirm stable RC reconnection and deliberate yaw/pitch/roll input; throttle alone is insufficient. |
| Terrain clearance becomes unknown | Rendered tiles are unavailable; no reliable AGL or collision clearance can be inferred. |
| Long flight still pauses | Check provider-wide terrain errors, known solid collisions and any other simulation stop reason rather than assuming a radio-range limit. |
| Analog noise disappears after a long gap | It intentionally stops after a sustained absence of usable simulated video input. |

For preflight and legal/data considerations, read [preflight and analysis](preflight.md),
[coordinate heights](coordinates_and_heights.md) and [map data sources](map_sources_and_attribution.md).

