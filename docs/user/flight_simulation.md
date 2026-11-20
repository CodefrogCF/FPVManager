# Flight simulator, radio links and GPS Rescue

This is a **user guide** for the simulated aircraft. For implementation details and
model assumptions, see the [developer's radio reference](../developer/radio_and_rescue.md)
and [simulation/collision reference](../developer/simulation_and_collision.md).

## Start and control a flight

1. Select a map location, then open **Kartenaktionen → Flugsimulator**.
2. Select a drone profile and the **Angle**, **Acro** or **GPS** flight mode.
3. Check **spawn height**, controller assignment, camera settings and terrain availability.
4. Start the flight. Reopen **Flugeinstellungen** to adjust camera/HUD, graphics,
   wind and radio settings without recreating the flight.
5. Use **Flug zurücksetzen** to return to the spawn state, or exit to the globe.

Angle self-levels; Acro retains rotational momentum; GPS is an assisted
position/height-control mode. These are **approximations**, not a Betaflight
flight-controller implementation. The [main user guide](../user_guide.md#ground-inspection-and-flight-simulation)
explains keyboard, touchscreen and external-controller input.

## Live radio line of sight

Open the **Radio line of sight / Funkvorschau** section during a flight. The
operator/ground station defaults to the flight takeoff point. You may instead
use a selected map point, saved spot or manually specified coordinates. Set
antenna height above the local ground; use **Reset to takeoff position** when
appropriate. The station marker and line-of-sight/Fresnel drawing can be
shown independently.

The live terrain profiler supports **1 m to 50 km** of geometric path length.
Long paths use a coarse profile followed by targeted refinement at uncertain
or potentially obstructed sections. A 50-km software analysis limit is **not**
a legal, achievable or guaranteed RC range. Assessments can be:

- **Clear within sampled terrain**: no obstruction in the available samples;
  gaps or unsampled obstacles can still exist.
- **Fresnel intrusion / obstructed**: the sampled terrain potentially affects
  the path, without proving the actual receiver will lose connection.
- **Unknown / limited confidence**: terrain is missing, stale or too sparsely
  sampled to confirm visibility. Such results must not be shown as confirmed
  reception or used as confirmed RC loss.

The diagnostic view reports the sampling tier, sampled points, terrain queries,
elapsed sampling time and largest gap. A separately labeled **SIM free-space only**
calculation may remain available even when terrain visibility is unknown.

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
