# Map preferences and overlay controls

The layer sheet controls the base-map style, UAS visibility/fill opacity, saved
spot visibility and the order of the two supported overlay sources. The sheet
lists overlays front to back. Up/down buttons change the Cesium data-source
collection order; terrain and the selected imagery layer remain below them.
Normal geometry, label and terrain depth testing still apply in a 3D scene;
source order does not force hidden objects to appear through mountains.

Preferences are read once after the renderer first becomes ready. Controls wait
for that read. No default rows are written merely by starting the app. Existing
three-key settings gain defaults for the two new keys without being rewritten.
There is no schema change. Repository saves remain atomic and preserve unrelated
settings. Writes are serialized so a slow older save cannot finish after a later
choice and overwrite it.

Only successful user commands update the persisted snapshot. Renderer metadata,
temporary loading/visibility changes, downloads, selection events and renderer
recovery never save preferences. A stored enabled UAS overlay causes an official
dataset request when the app next starts; disabling it stores that choice.
The current in-memory cache age and update state follow the
[provider contracts](osint_providers.md); re-enabling expired UAS data fetches and
replaces it. Persistent/offline cache policies remain separate work under #51.

A load failure disables preference editing and offers Retry or an explicit
Reset map preferences action. Reset affects only the five map preference keys.
A failed save keeps the current map choice visible, reports that it is unsaved,
and offers Retry. The home screen waits for pending local preference I/O before
closing its owned database. Injected repositories remain caller-owned.

On renderer reload/resume, the controller restores requested preferences and
saved markers for the current session. The renderer reapplies overlay order
after spot creation, UAS imports and UAS replacement, and retains hidden spots
when their marker dataset changes. Hiding spots clears their active selection.

See [local data](local_data.md) for stored keys and
[the foundation issue audit](foundation_issue_audit.md) for related open work.

## Validation record (2026-10-20)

- The complete Flutter suite passed 173 tests. The earlier focused map,
  repository and persistence run passed 47 tests; two additional UAS-race and
  hidden-selection regression cases were included in the final full suite.
- Analysis found no issues; all 73 handwritten Dart files passed formatting.
  Seven JavaScript bridge tests, pinned assets, workflow configuration and local
  documentation links passed their checks.
- Web release and Android debug builds succeeded. The Android command used all
  three default ABIs, matching CI rather than the earlier ARM64-only checks.
  Packaged renderer sources/assets and APK ZIP integrity were verified.
- The actual Web release retained Topo style, UAS-in-front source order and
  hidden saved spots after a complete page reload. No storage error was shown.
- The real offline Cesium/worker harness confirmed actual data-source order and
  spot visibility through marker updates, UAS import/replacement and iframe
  reload, without renderer errors.
- Widget coverage includes delayed/failed preference reads, explicit reset,
  failed-save retry, serialized rapid changes and a compact 360×640 layout.
  SQLite file reopen coverage includes the new keys. Physical Android UI/
  keyboard acceptance remains a separate device check; no device install was run.
