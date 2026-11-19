# configurable ground station and live terrain visibility

## Existing functionality reused

The live radio controller already samples the same `calculateRadioLink()`
kernel as the saved-route radio analysis. It compares a fixed pilot antenna
position with the simulated drone's **WGS84 ellipsoidal** height. A terrain
profile uses Cesium terrain level 12 at nominal intervals of up to 25 m, up to
6 km. The controller attempts updates no more often than every 2 seconds,
caches terrain in the renderer for up to 30 seconds and expires completed
results after 5 seconds. No queries run every rendered frame.

## How to use

1. Start the flight simulator and open **Radio line of sight**.
2. Enable the live preview. The default transmitter location is the **flight
   takeoff point**, not the moving drone.
3. To relocate it, tap the map at the intended transmitter location before
   opening the settings. Change **Transmitter position** to **Fixed spot /
   coordinates**, then choose **Selected map point** (alternatively choose a
   saved spot or enter WGS84 coordinates manually). The location is retained
   during the current controller/simulation session.
4. Set the antenna height in metres **above the local ground**. Use the
   **Reset to takeoff position** control to follow the next flight's home point.
5. **Show ground station marker** and **Show live line of sight** are separate
   controls. The marker can remain on the map after a sampled line expires;
   the line itself is removed when the result becomes unknown.

## Assessment contract for future HUD/failsafe work

`lib/features/signal/live_link_assessment.dart` defines an immutable result:

- `visibility`: `unknown`, `clear`, `fresnelIntrusion`, `obstructed`
- `source`: `unavailable` or `sampledTerrain`
- `confidence`: `unavailable` or `approximate`
- `sampledAt`, `sampleCount`, minimum terrain and Fresnel margins
- `rcQuality`, `videoQuality`: **independently unknown** in the current implementation

Only the geometric path is evaluated. Clear sampled terrain means **no
obstruction among sampled locations**, not adequate reception. A Fresnel
intrusion is not proof of lost RC or video; an obstructed geometric path is
not a measured radio outage. No RF link budget, path loss, antenna pattern,
frequency-dependent attenuation, multipath, materials, weather or interference
is estimated. RC/video quality and simulated failsafe must remain independent
until later dedicated models explicitly provide these values.

Missing/invalid terrain, excessive distance, expiry, a new flight, renderer
restart or interrupted flight invalidate the current geometry assessment.
The marker is kept in a separate lightweight Cesium source so it does not
re-create the full ray/Fresnel envelope during marker changes.