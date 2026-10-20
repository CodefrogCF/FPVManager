# Verified SQLite Android downloads

The reported Linux CI failure stopped in the `sqlite3` 3.5.2 build hook while
checking `libsqlite3.x64.android.so`. Its received SHA-256 began `c361095a...`,
while the locked package expected
`949965f0eba976f707ae364cdcb42c342b5f0626081f8d7f0378fb7b52848772`.
The official immutable release metadata and a fresh download both match the
expected hash (1,808,568 bytes). The supplied log does not identify the wrong
response's contents or establish why it was received.

The [upstream hook documentation](https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/doc/hook.md)
describes package-pinned binary hashes and the shared native-asset download
cache. The installed 3.5.2 hook verifies cached/downloaded bytes but performs
no download retry. Its downloader also streams HTTP response bodies into the
hash check without rejecting non-200 status codes first.

`python tool/prepare_sqlite_android.py` runs after locked dependency resolution
and before the Android CI build. It resolves the actual `sqlite3` package through
`.dart_tool/package_config.json`, reads its release tag and expected hashes,
and prepares ARM, ARM64 and x64 libraries in that hook's shared cache. The tool:

- Accepts only successful HTTP responses, enforces a size limit and verifies
  SHA-256 before atomically installing a downloaded file.
- Tries each download at most three times with bounded timeouts and fresh URLs
  to avoid reusing an expired cached release redirect.
- Reuses already verified files, preserves a good file if a forced refresh
  fails, and removes only its own temporary download files.
- Fails the job if no verified artifact is received. The upstream hook still
  performs its own normal validation during the build.

This does not alter dependencies, expected hashes or package sources. It is
resilience for an external download, not a bypass of an integrity failure.
Package-hook cache layout changes require review of this helper.

Run download failure tests without network access:

```sh
python -m unittest discover -s test/tool -p 'test_*.py'
```

For a fresh download check and the same ABI coverage as CI:

```sh
python tool/prepare_sqlite_android.py --refresh
flutter build apk --debug --no-pub
```

A passing local all-ABI build does not certify a future GitHub Actions run.

## Validation record (2026-10-20)

- All four Python failure/manifest/cache tests passed, covering HTTP 503,
  mismatched content, oversized responses, retry exhaustion, preserved good
  cache files, removed partial files and hashes read from the resolved package.
- Fresh ARM, ARM64 and x64 downloads all matched the locked release hashes.
  The subsequent preparation step reused those verified cache entries.
- The unchanged full build command `flutter build apk --debug --no-pub`
  succeeded locally for `android-arm,android-arm64,android-x64`; packaged renderer
  resources and APK ZIP integrity passed their checks. There was no SQLite hash
  override, package-cache source edit or dependency upgrade.
- The finished APK contains Flutter and SQLite ELF libraries with matching
  machine types for `armeabi-v7a`, `arm64-v8a` and `x86_64`, and its kernel
  contains the current map preference/order UI and protocol code.
- The updated workflow still requires the quality job before Android/Web builds.
  A new hosted CI run remains to be checked after the changes are pushed.
