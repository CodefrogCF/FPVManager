# Ground inspection and local route editing

## Ground view

Select a terrain point in the normal globe and choose **Spawn here**, or select
a saved spot and choose **Spawn at spot**. The camera enters a first-person view
approximately two metres above the displayed terrain. Use the arrow keys to
walk forward/backward and sideways; drag the map to look around, including up a
slope. The on-map arrow buttons provide the same movement on touch screens.
Walking speed is about 3 m/s, with normalised diagonal movement. Looking is
limited to 85 degrees above/below the horizon.

Click the map to return keyboard focus after using other controls. **Return to
globe** or Escape restores the camera position, orientation, near plane and
orbital controls from before entry. Home, coordinate navigation and spot focus
also exit the mode before their camera action. Opening another library exits
ground view. Losing focus clears held movement; hiding the renderer exits it.

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
  below its terrain while its clamped markers are still loading.
- **Save** writes the route name and ordered waypoints together. Multiple routes
  have independent IDs and appear in the local library. Empty routes can be
  saved, including after deleting their final waypoint.

Changes stay in a draft until Save. Leaving an edited draft asks whether to
discard it; **Keep editing** retains it. Save failure retains the draft for
retry. Saving temporarily disables map edits. The unsaved draft survives a
renderer reload while the editor remains open; it is not an autosave across app
termination or a browser reload.

The visible line is a **ground projection** of the waypoint order. New points
are stored as position-only coordinates. Existing absolute-height references or
AGL offsets, plan drone/start-spot links and notes are retained when their points
are moved or the route is saved. The editor does not infer an altitude from a
clicked terrain point. Heights, planned speeds and a dedicated drone/battery
assignment workflow remain separate parts of #25. This change covers its direct
map editing and multiple local routes criteria, not the full issue.

## Implementation and checks

No database schema change is required: schema v6 already contains flight plans
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
