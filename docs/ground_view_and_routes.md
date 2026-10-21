# Ground inspection and local route editing

## Ground view

Select a terrain point or saved spot in the normal globe and use the walking
icon beside the right-hand map menu/layer control (**Spawn here**). The camera enters a first-person view
approximately two metres above the displayed terrain. Use the arrow keys to
walk forward/backward and sideways; drag the map to look around, including up a
slope. A transparent virtual stick in the lower-left map area provides analog
forward/backward and sideways movement, including simultaneous touch looking.
Releasing/cancelling the pointer, losing focus or leaving ground view clears the
stick. Maximum walking speed is about 3 m/s, with normalised diagonal movement. Looking is
limited to 85 degrees above/below the horizon.

Click the map to return keyboard focus after using other controls. **Return to
globe** (the same icon, now showing a globe) or Escape restores the camera position, orientation, near plane and
orbital controls from before entry. Home, coordinate navigation and spot focus
also exit the mode before their camera action. Opening another library exits
ground view. Losing focus clears held movement; hiding the renderer exits it.
Coordinates and ground/eye-height information appear at the top of the renderer;
a selected raw map point has no duplicate coordinate/height bar below the map.

Entry requires available terrain and a bounded terrain-height sample at the
spawn point. Movement follows loaded rendered terrain and pauses translation
when no rendered height is available. Terrain loss exits the mode. Cancelled or
late sampling cannot reactivate it. Polar regions within 0.1 degrees of either
pole are excluded from this walking approximation.

This is an inspection camera over the terrain mesh. Its eye clearance follows
terrain LOD changes; it does not model buildings, vegetation, collision with
objects or a real person's accessibility. It does not change the selected
point's geodetic height or convert it to a flight altitude.

## Flight routes

Open **Flight routes** in the navigation drawer and choose **New route**, or
open an existing local route. Enter a route name and edit directly on the map:

- Click terrain to append a numbered waypoint.
- Click a waypoint to select it. Drag it to move it, or choose **Move point**
  and click its new position. **Cancel move** returns to append mode.
- Right-click a waypoint, press Delete with the map focused, or use **Delete
  point** to remove it. **Undo waypoint change** reverses up to 50 draft edits.
- **Show entire route** frames the current draft with an editing distance of at
  least 300 metres, including routes consisting of a single point. Available
  terrain is sampled before framing, so a newly opened route is not focused
  below its terrain while its elevated markers are still loading.
- **Save** writes the route name and ordered waypoints together. Multiple routes
  have independent IDs and appear in the local library. Empty routes can be
  saved, including after deleting their final waypoint.

Changes stay in a draft until Save. Leaving an edited draft asks whether to
discard it; **Keep editing** retains it. Save failure retains the draft for
retry. Saving temporarily disables map edits. The unsaved draft survives a
renderer reload while the editor remains open; it is not an autosave across app
termination or a browser reload.

The editor and saved-route overlays use a **3D preview at 30 m AGL at each
waypoint**, sampled from available detailed terrain. Points and connecting
segments use sampled-terrain +30 m positions, with subtle vertical guides to
ground. The line is not clamped to terrain, so intervening terrain can occlude a
segment. The 30 m offset applies at the waypoints; it is not a guaranteed
clearance along the segment. Terrain loss hides this preview, and explicit
terrain recovery rebuilds it without inventing zero-height ground.

This is a display policy, not a rewrite of flight-plan heights. New points
are stored as position-only coordinates. Existing absolute-height references or
AGL offsets, plan drone/start-spot links and notes are retained when their points
are moved or the route is saved. The editor does not infer an altitude from a
clicked terrain point. Heights, planned speeds and a dedicated drone/battery
assignment workflow remain separate parts of #25. This change covers its direct
map editing and multiple local routes criteria, not the full issue.

### Saved route visibility

In the home map, open **Map layers → Flight routes** to select saved routes.
Each checkbox controls one route; its framing icon brings it into view. Up to 20
routes can be displayed together. Selection lasts for the current home-map
session, including library navigation and renderer reload; it does not persist
across an app restart. Selected routes stay visible when entering, moving
through and leaving ground view. Visibility changes preserve the ego camera.
Framing a route is an explicit camera action and returns to globe view.

Selected routes observe saved metadata/waypoint changes; deletion removes their
overlay. Load/render failures offer Retry route preview. Cancelled or superseded
height samples cannot restore hidden/older geometry. Sampling results are cached
for unchanged coordinates within the current terrain generation.

### Compact-control acceptance (2026-10-21)

The user confirmed the updated functionality and appearance with `flutter run`
on Android. Automated JavaScript checks cover analog movement, cancellation and
simultaneous looking, 30 m AGL geometry, independent saved-route visibility and
terrain-loss/recovery state. The extended actual-Cesium browser harness was not
rerun successfully in this update because integrated browser automation timed
out; the earlier harness results below refer to the previous ground controls.

Fatal-warning/info analysis and formatting for all **110** hand-written Dart
files passed. The complete Flutter suite passed all **237** tests, including
compact home-map controls, saved-route updates in ego mode, renderer reload,
stalled-render cancellation and load/render retry. All **34** JavaScript tests
and **4** Python tooling tests passed; the pinned Cesium verification covered
all **395** files.

The JavaScript Web release passed with `flutter build web --release --no-pub
--no-web-resources-cdn --no-wasm-dry-run`. The build's root and Flutter-asset
copies of all seven renderer modules matched the current sources. All pinned
vendor hashes, local CanvasKit and terrain-fixture exclusion checks passed.

The Android debug build passed with `flutter build apk --debug --no-pub`.
The resulting `build/app/outputs/flutter-apk/app-debug.apk` (219,733,868 bytes)
passed ZIP integrity, current renderer-module and pinned-vendor checks,
terrain-fixture exclusion, and SQLite ELF verification for armeabi-v7a,
arm64-v8a and x86_64.

## Implementation and checks

No additional database migration is required: schema v7 already contains flight plans
and ordered waypoints. `FlightPlanRepository.saveRoute` commits metadata and
waypoint replacement atomically. Battery-to-plan links retain their existing
plan IDs. Route map commands use editor identity, revision and stable draft
waypoint keys; stale, malformed or previous-session events cannot edit a newer
draft. A renderer reload restores the current draft overlay.

`ground_navigation.js` owns the cancellable walking state and input lifecycle;
`route_editor.js` owns terrain picking and waypoint entities. Both ship as
ordinary bundled Web/native assets. No new service, package or permission is
introduced. Rerun the checks in [CONTRIBUTING](../CONTRIBUTING.md).

The local loopback harness at `/interaction-smoke` exercises the actual Cesium
camera, keyboard handling, terrain picking, waypoint drag/delete handlers and
offline recovery against synthetic terrain. Start it with
`python tool/serve_globe_smoke.py --port 8765`; open
`http://127.0.0.1:8765/interaction-smoke`. Fixture scripts and terrain are test
resources, excluded from production assets. Real Android touch/keyboard,
background/resume and terrain quality checks remain device acceptance work.

The following records describe the original ground-view and route-editor
implementation, before the compact-control update above.

Recorded on **2026-10-21**: fatal-warning/info analysis passed; formatting passed
for **99** hand-written Dart files; the complete Flutter suite passed **216**
tests. A subsequent load-failure recovery case was added and the affected route,
ground-entry and flight-plan tests passed again (**20** tests, including that
additional case). All **29** JavaScript tests and **4** Python tooling tests
passed, and all **395** pinned Cesium files and the three cached Android SQLite
libraries passed verification. Dependency resolution with the enforced lockfile
passed without package changes. The actual Cesium/WebGL interaction harness
passed the synthetic terrain scenarios described above.

The built Web app was also exercised with live swisstopo terrain: point
selection, spawning, arrow-key movement, dragging to look up a slope and return
to the original globe camera passed. Two independent demo routes were created
through the visible editor; a three-waypoint route was changed by dragging a
map marker and saved to the local library. A single-waypoint camera-framing
defect found in this run was corrected with a minimum editing distance and a
terrain-sampled bounding sphere. The extended actual-Cesium harness verified
that the resulting camera stays above its synthetic 1000-metre terrain.

The final Web release and its root/Flutter copies of both interaction modules
passed bundled-asset verification. After closing and reopening the app on the
same isolated local test origin, both saved demo routes were present. The first
route's single point framed above the live terrain; the second route reopened
with three points and retained the moved point's coordinates. These checks used
demo data, not an existing personal database.

The Android debug build passed. ZIP integrity, pinned vendor hashes, current
renderer/terrain/provider scripts, both interaction modules and SQLite ELF
libraries for armeabi-v7a, arm64-v8a and x86_64 were verified in the resulting
`build/app/outputs/flutter-apk/app-debug.apk` (219,643,732 bytes). This is build
and package verification; physical-device interaction remains the acceptance
step described above.
