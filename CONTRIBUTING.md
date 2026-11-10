# Contributing

Open a focused pull request against `main`. Describe the problem, resulting
behavior and relevant checks. Use the Flutter/Dart versions in [README](README.md).

## License

Original contributions submitted for inclusion in FPVManager are provided under
[Apache-2.0](LICENSE), unless explicitly identified otherwise. Keep existing
copyright, licence and attribution notices with imported code or data, and identify
their origin. Third-party components and datasets retain their separate terms;
see [the third-party notices](THIRD_PARTY_NOTICES.md). No copyright assignment or
separate contributor agreement is required by this contribution workflow.

## Code

Use the Dart formatter and `analysis_options.yaml`. Feature code belongs in
`lib/features/`; shared database, geospatial and provider contracts belong in
`lib/core/`. Inject repositories and clients for testable I/O. Callers own
injected resources; components dispose resources they create.

Treat renderer messages and downloaded data as external input. Preserve explicit
units, coordinate/height references and the distinction between source data and
interpreted restrictions. Add regression tests for meaningful behavior changes.

## Checks and builds

Run from the repository root. Python 3.9+ and Node.js 20+ are needed for tooling.

```sh
flutter pub get --enforce-lockfile
dart run tool/check_format.dart
python tool/check_docs.py
python tool/vendor_cesium.py --check
python -m unittest discover -s test/tool -p 'test_*.py'
node --test test/js/*.test.cjs
node tool/performance_suite.cjs --check
flutter analyze --no-pub
flutter test --no-pub
```

Format edited sources with `dart format <path>`. The format check excludes
generated Dart and migration fixtures. CI runs these checks before both builds:

```sh
flutter build web --release --no-pub --no-web-resources-cdn
python tool/prepare_offline_web.py
python tool/prepare_sqlite_android.py
flutter build apk --debug --no-pub
```

Serve the complete `build/web/` over HTTPS (or localhost). Offline Web startup
requires the generated integrity manifest and a completed online installation.
Close all app tabs and reopen to activate an updated snapshot. `flutter run`
without the manifest supports map caching, but not a verified offline app shell.

The SQLite preparation helper downloads ARM/ARM64/x64 libraries using the
resolved package's expected hashes, reuses verified cache entries and retries
failed downloads up to three times. Use `--refresh` to request fresh downloads;
never override a failed hash check.

For map changes, run the [browser harnesses](docs/cesium_assets.md) and the native
renderer test:

```sh
flutter test integration_test/globe_runtime_test.dart -d <android-device-id>
```

Check navigation, selection, layers, visible credits, terrain failure/retry and
affected controls on Web and Android. Builds and synthetic fixtures do not verify
device gestures, permission dialogs or real network recovery. When upgrading
Flutter, update README and the CI pin together and repeat both builds.
Use [the performance guide](docs/performance.md) for local diagnostics and
reproducible device measurements. Never present synthetic timings as device FPS.

## Database changes

Generated database code is committed. After editing Drift tables, run:

```sh
dart run build_runner build --delete-conflicting-outputs
```

For schema changes, increment `schemaVersion`, implement the migration, preserve
old snapshots and generate the new snapshot/migration fixtures with Drift tooling.
Test migration from supported old schemas, record preservation and affected
relationships. Do not hand-edit `.g.dart` files or `test/generated_migrations/`.
