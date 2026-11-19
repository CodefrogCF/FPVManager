# Live RF approximation, line-of-sight and rescue improvements

This update enhances four **simulation-only** subsystems, without adding live telemetry or a measured RF receiver.

## 1. Approximate default video/RC link model

`web/rf_estimation.js` is a stand-alone deterministic, bounded link-budget illustration. New flight sessions with an available detailed terrain model use the takeoff position as ground station by default; the DJI O4 Air Unit Pro **video** and TBS Crossfire **control** reference profiles are independently modeled. The model is only active for valid, fresh, sampled terrain profiles.

Reference defaults (for illustration; **not** a claim about receiver sensitivity):

| Parameter | O4 Pro video | Crossfire RC |
| --- | ---: | ---: |
| Reference frequency | 5,800 MHz | 868 MHz (European band) |
| Assumed effective EIRP | 14 dBm | 14 dBm (25 mW) |
| **Assumed** receiver threshold | -105 dBm | -120 dBm |
| **Assumed** fade budget | 12 dB | 10 dB |

Manufacturer documentation: [DJI O4 Pro product info](https://dl.djicdn.com/downloads/DJI_O4_Air_Unit_Series/PI/20250422/DJI_O4_Air_Unit_Series_Product_Information_v1.0.pdf), [TBS Crossfire manual](https://www.team-blacksheep.com/media/files/tbs-crossfire-manual.pdf).

**Crucial:** Transmit-power configurations are jurisdiction-, channel-, and device-dependent. The frequencies/powers above are conservative simulation references, **not instructions to configure real RF equipment**. Receiver thresholds, fade budget, terrain attenuation, signal-percentage mapping and loss/recovery behavior are simplified assumptions that have NOT been calibrated against actual DJI or TBS measurements. The indicated percentage is neither RSSI, packet delivery ratio, SNR, LQ nor a probability of connection. No signal is estimated when the terrain profile is unavailable, expired or outside the 6 km preview limit.

Users may turn this approximation off, or edit both link profiles independently under **Transmitter / Details → SIM RF profiles**. Explicit manual RC training values still take priority over the RF model. Custom profiles currently apply to the current simulator session, not a persisted global equipment database.

### Data flow

`Flutter LiveRadioController` → existing `calculateRadioLink()` → `LiveLinkAssessment.toJson()` → `web/live_radio.js` → `web/rf_estimation.js` → shared `controlLink`/`videoLink` → HUD / optional RC failsafe.

The geometry calculation remains distinct from RF estimation; no terrain result by itself is taken as proof of a physical link failure. The failsafe remains disabled unless enabled by the user.

## 2. Analog video visualization

`web/signal_hud.js` uses a stronger progressive noise curve and more pronounced short dropouts at critical/lost **simulated video** quality. No canvas readback or dynamic textures were introduced. Analog effects remain opt-in and Betaflight-style only; DJI-style receives only the signal warning edge. Signal bar and DJI warning options are on for new installations but can be disabled independently. Saved preferences continue to apply.

## 3. Live LoS sampling and non-collision

Telemetry throttle: 800 ms below 12 m/s, 450 ms at 12–30 m/s, 250 ms at 30 m/s or faster. The Dart terrain controller uses the same pace, capped by one outstanding request. Plan spacing is `max(8 m, distance/250)` with at most approximately 251 sample positions per profile (including endpoints). Results that are too old for current position/altitude are discarded. The underlying terrain cache and 6 km safety boundary are unchanged.

These limits greatly reduce the spacing in flight position between updates but **cannot guarantee** detection of every very narrow ridge, transient occlusion or sub-grid obstacle. Further profiling on mobile hardware is required to validate query load and latency.

The live line of sight omits the point marker directly on top of the aircraft; its Cesium polylines are **visualization only**, explicitly marked `fpvVisualOnly` and `fpvNonCollidable`. Flight movement/collision remains driven by the dedicated terrain/tunnel/infrastructure collision services; the visual ray must not be fed into those systems.

## 4. GPS Rescue speed control

`web/rescue_velocity.js` replaces the former inertial exponential controller in the autonomous movement path with a speed-vector controller using the configured acceleration and deceleration bounds. The target speed is capped by the drone profile. Braking begins as the home point approaches, using `sqrt(2 * deceleration * remainingDistance)` rather than a permanently low proportional target. Climb/approach and collision handling remain on the normal flight simulation path. A requested target speed is *not* guaranteed near home, in a headwind or when physical limits intervene.

No obstacle avoidance or safe return is guaranteed; this is educational simulation, not a reproduction of Betaflight GPS Rescue control firmware.

## Follow-up: derived ideal range and reception budget (2026-11-19)

`web/rf_estimation.js` now exports pure, deterministic functions
`freeSpaceLossDb(distanceM, frequencyMhz)`, `theoreticalRangeMeters(profile,
extraLossDb)` and `excessTerrainLossDb(...)`. The shared `assess()` result also
includes, independently for video and RC:

- `distanceMeters`: ground distance, or an approximate three-dimensional slant
  distance when both WGS84 heights are present;
- `freeSpaceLossDb`, `estimatedTerrainLossDb`, and `estimatedRxPowerDbm`;
- `linkMarginDb` (and the retained `marginDb` alias for older consumers);
- `estimatedMaxRangeM`: *hypothetical* 0 dB-margin range under **unobstructed
  free-space conditions** at the configured receiver threshold and fade reserve;
- `estimatedTerrainScenarioRangeM`: theoretical range under the **same fixed
  assumed terrain loss** as the most recent sampled obstruction. This is not a
  prediction of how terrain will vary with distance;
- `rangeFraction`, `confidence: 'assumptionBased'`, and a monotonic illustrative
  `quality` score used by the HUD and optionally enabled failsafe.

The formulas are:

```text
FSPL(dB) = 32.44 + 20 log10(frequency_MHz) + 20 log10(distance_km)
P_RX_est(dBm) = EIRP(dBm) - FSPL(dB) - assumed_terrain_loss(dB)
link_margin(dB) = P_RX_est - assumed_receiver_threshold - fade_reserve
ideal_range_km = 10 ^ ((EIRP - receiver_threshold - fade_reserve
                        - 32.44 - 20 log10(frequency_MHz)) / 20)
```

**Important default-profile example:** At 5,800 MHz, 14 dBm EIRP, assumed
-105 dBm effective threshold, and 12 dB fade reserve, the illustrative free-space
range is ~0.92 km. At 868 MHz, 14 dBm EIRP, assumed -120 dBm threshold, and
10 dB fade reserve, it is ~43.6 km. These very different outputs reflect the
unvalidated assumptions, **not actual DJI O4 Pro or Crossfire range, nor
recommended operating distances**. In particular, the theoretical value may
exceed line-of-sight/radio-horizon limits. The published idealized DJI O4 Pro
CE figure of up to 8 km is a manufacturer test scenario, not a calibration of
this simulator or a substitute for a verified receiver sensitivity curve.

The system deliberately does **not** infer a clear physical link from missing,
expired or unsupported terrain data. The live terrain profiler retains its
6 km operational limit; the free-space distance is a separate mathematical
scenario, not proof of viable reception at that distance. Neither RC nor video
percentages should be interpreted as RSSI, real LQ, SNR, packet loss or link
availability probability. User RF values remain editable and both links use
independent profiles. Manual RC training input retains priority and does not
silently alter the underlying modeled link.

The 3D radio details panel now includes both estimated link reserves and ideal
free-space distances for available, modeled telemetry. The Betaflight video/RC
bar tooltips expose the same results without occupying additional HUD area.
New tests check exact formula consistency, monotonic distance falloff,
frequency/power/fade sensitivity, attenuation scenarios, slant range and the
absence of invented estimates when terrain samples are unavailable.
