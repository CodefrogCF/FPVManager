# Contributing

## Branching and review

- Keep `main` as the integration branch.
- Start focused work from current `main`, using `feature/<short-topic>` or
  `fix/<short-topic>` branches.
- Keep one independently reviewable concern per branch/PR where practical.
- Describe the user-visible change, related issue, validation and known limits.
- Run the checks below before submitting a PR. CI must pass before merge;
  branch protection must be configured separately by a repository administrator.
- Do not close a broad issue merely because a subset of its criteria is complete.

Suggested commit subjects follow the existing history, for example
`fix(globe): keep map selections consistent` or
`chore(ci): add Flutter quality gates`.

## Coding conventions

Use the Dart formatter and the rules from `analysis_options.yaml`.
Keep feature-specific UI and behavior in `lib/features/<feature>/`, and shared
database, geospatial and provider contracts in `lib/core/`.

Inject repositories or provider clients where tests need to control I/O.
Resources created internally are disposed internally; injected resources remain
owned by their callers. Check `mounted` before updating widgets after an `await`.

Treat renderer messages and downloaded data as external input. Apply a complete
state update before notifying listeners. Keep raw source metadata distinct from
interpreted restrictions and distinguish fetch timestamps from official validity.
Preserve explicit units, coordinate systems and vertical references.

Add regression tests for meaningful defects. Prefer observable behavior over
duplicating implementation details. Controller tests do not replace widget tests
for controls that must rebuild, and build success does not replace device checks.

## Local validation

Run from the repository root with the Flutter/Dart versions listed in README:

```sh
flutter pub get --enforce-lockfile
dart run tool/check_format.dart
python tool/vendor_cesium.py --check
python -m unittest discover -s test/tool -p 'test_*.py'
node --test test/js/globe_bridge.test.cjs test/js/map_attribution.test.cjs test/js/terrain_service.test.cjs test/js/ground_navigation.test.cjs test/js/route_editor.test.cjs
flutter analyze --no-pub
flutter test --no-pub
```

For changes affecting platform integration, also run:

```sh
flutter build web --release --no-pub --no-web-resources-cdn
python tool/prepare_sqlite_android.py
flutter build apk --debug --no-pub
```

The same commands are in `.github/workflows/ci.yml`. That workflow uses actions
pinned to commit SHAs, read-only repository permissions and no deployment step.
When upgrading Flutter, update its workflow pin and README together, intentionally
refresh `pubspec.lock` if needed, and repeat both platform builds.

The real renderer/lifecycle test is
`flutter test integration_test/globe_runtime_test.dart -d <android-device-id>`.
Use [the local browser smoke harness](docs/cesium_assets.md) for WebGL verification.

## Database changes

`fpv_database.g.dart` is generated and committed, so a clean checkout can build.
After editing Drift tables, regenerate it:

```sh
dart run build_runner build --delete-conflicting-outputs
```

For a schema change, preserve the previous schema snapshot, increment
`schemaVersion`, implement the migration and update schema snapshots and
generated migration fixtures using Drift tooling. Add tests that open the old
schema, migrate it, preserve existing user records and verify affected relations.
Do not replace an old fixture with a newly generated current schema.

Do not hand-edit `.g.dart` or files in `test/generated_migrations/`. They are
excluded from the hand-written formatting check but remain covered by analysis
and tests.

## Manual map regression checks

Run these on Web and an Android device after map/bridge changes:

1. Start the globe and check terrain, credits and camera navigation.
2. Enable UAS zones, wait for loading, then disable and re-enable the cached layer.
   The switch, loading indicator, metadata and error state must match the renderer.
3. Change opacity and verify both polygon fill and the displayed percentage.
4. Select map point A, then saved spot B. The raw-point terrain action must be
   disabled, and Add Spot must not prefill A's coordinates.
5. Select a fresh map point and verify terrain queries and Add Spot defaults.
6. Select a UAS feature, close its panel and verify old point selections do not
   reappear. Edit/delete a saved spot and check marker synchronization.

Record the target/device, revision, scenario and result. Network loss, renderer
reloads and large datasets need additional checks under #7, #43 and #48.
