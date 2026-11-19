# Simulation RF scenarios and GPS Rescue refinements

This implementation is a **simulation-only educational approximation**. It is not a
measured radio propagation model, a real Betaflight flight-controller clone, a
validated return-to-home controller, or evidence that a frequency or power is
permitted where the user operates.

## Independent regulatory reference scenarios

The **Live radio line of sight > SIM RF profiles** sheet offers separate selectors
for video and RC: **EU / CE**, **FCC**, and **Custom**. Choosing a preset explicitly
updates that band's frequency, effective EIRP, planning threshold, and fade reserve.
Editing any of its numeric fields changes that band's selection to Custom.
Importing a saved equipment profile also creates a Custom configuration.
Existing other-band values are retained during the switch.

| Reference | Frequency | Illustrative EIRP | Effective planning threshold | Margin |
|---|---:|---:|---:|---:|
| DJI O4 Pro, EU/CE (5.8-GHz 40 MHz use case) | 5800 MHz | 13.9 dBm | -124 dBm | 12 dB |
| DJI O4 Pro, FCC | 5800 MHz | 32.9 dBm | -110.3 dBm | 12 dB |
| TBS Crossfire, EU/CE | 868 MHz | 14 dBm | -120 dBm | 10 dB |
| TBS Crossfire, FCC example | 915 MHz | 24 dBm (250 mW) | -120 dBm | 10 dB |

The effective O4 thresholds are **not receiver sensitivity measurements**.
They are deliberately adjusted to approximately reproduce DJI's published
idealized 8-km CE / 15-km FCC *video range* within this simple model. Those
published maxima are not guaranteed real-world flight distances. In particular,
the low-power 5.8-GHz EU reference and its threshold must not be interpreted as
physically validated 40-MHz noise-floor predictions. DJI documents 5.8-GHz
O4 Pro limits of **<14 dBm CE** and **<33 dBm FCC**. Crossfire 868/915-MHz
modes differ by regional firmware, output-power options and LBT behavior;
250 mW is a sample FCC scenario rather than an assertion about every model.

Bandwidth (such as 40 MHz) does not directly add radiated power. The current
model does not incorporate bitrate adaptation, diversity, temperature,
antenna pointing, body shielding or actual RF measurements. Free-space range
also excludes radio horizon and terrain; the existing **live** terrain profile
still has a separate 6-km analysis cutoff pending the long-range sampling
follow-up issue. Missing terrain produces unknown reception, not a fabricated
clear link or automatically confirmed RC loss.

Sources:
- https://www.dji.com/o4-air-unit/specs
- https://dl.djicdn.com/downloads/DJI_O4_Air_Unit_Series/PI/20250422/DJI_O4_Air_Unit_Series_Product_Information_v1.0.pdf
- https://www.team-blacksheep.com/media/files/tbs-crossfire-manual.pdf

## Terrain attenuation and failsafe

A clear sampled ray uses only the approximate free-space loss; a Fresnel
intrusion adds heuristic attenuation; modeled terrain obstruction adds a
higher, depth-dependent attenuation. This is a conservative *risk scenario*
not a claim that the actual RC receiver would fail at the same point.
Unknown/outdated terrain cannot trigger or clear the simulated failsafe.
The default loss threshold is 20% model quality and requires 0.6 s of
confirmed simulated loss; recovery requires a separate 45% threshold for
0.6 s. Existing saved settings may retain their previous custom timing.

## Betaflight-inspired simulated rescue sequence

1. A sustained, modeled RC-loss event activates failsafe (opt-in).
2. **Hold** position briefly while stabilizing.
3. **Climb** approximately 100 m above the altitude at link loss (configurable).
4. **Turn** toward the home point without automatically moving horizontally.
5. **Return** toward home at the chosen attainable speed and reached altitude,
   with normal acceleration, stopping distance, wind and collision constraints.
6. **Land** near the original takeoff ground height, preserving collision probes.

When modeled RC quality has recovered beyond the configured threshold long
enough, a deliberate yaw/pitch/roll stick movement of at least 30%, keyboard
flight command or manual resume control may cancel rescue. An idle throttle
signal alone never cancels it. Recovery does not automatically cancel GPS Rescue.
No obstacle avoidance, guaranteed safe ascent or accurate GPS accuracy is
claimed. The simulation may stop on terrain/model contacts.

Betaflight documentation: https://betaflight.com/docs/wiki/guides/current/GPS-Rescue
