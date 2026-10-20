# OSINT provider contracts and provenance (#4)

The provider boundary separates transport and normalization from the map UI.
Current implementations cover WGS84 GeoJSON airspace, raster imagery and Cesium
terrain. The generic Dart contract can also carry future normalized weather or
traffic models; this change does not add those products or download regions.

## Snapshot data adapters

`OsintProvider<T>` exposes source identity, a fetch operation with explicit
`forceRefresh`, a listenable status snapshot and disposal. `CachedOsintProvider<T>`
implements the shared memory-cache and update lifecycle. Adapters implement
`download()` and normalize their response into `OsintDataset<T>`.

- `OsintSource` records source name, publisher, data/metadata URIs, nullable
  licence declaration/terms URI, attribution and coordinate reference.
- `OsintDataset<T>` records successful retrieval time, local cache expiry,
  optional official validity bounds and the raw optional HTTP Last-Modified.
- `OsintProviderState<T>` distinguishes idle/loading/ready/failed/disposed updates
  from not-loaded/fresh/stale/clock-skew cache status. It also records the latest
  attempt and whether a fetch used memory cache. Expiry is checked against an
  injected clock, including the exact TTL boundary and clock rollback.
- `OsintProviderException` has a provider ID, category, safe display message and
  optional HTTP status. Network, timeout, HTTP and invalid-data failures remain
  distinct. An error never turns a failed refresh into a successful fetch.

Concurrent requests share one update, including reentrant listeners. An ordinary
cache hit does not clear the last failed network refresh; a successful update
does. A failed update retains the last good snapshot. Disposed providers reject
new requests and cannot install late responses or notify retired listeners.
Injected clients/providers remain owned by the caller.

`GeoJsonOsintProvider` handles FeatureCollections already in EPSG:4326. An
explicit incompatible CRS is rejected; this adapter does not reproject data.
`SwissUasProvider` supplies only the current Swiss source descriptor. A different
compatible airspace adapter/source is injected into `GlobeController`, without
editing `MapLayersSheet` or the map widget. Different source formats require a
normalizing adapter, rather than interpreting arbitrary payloads in the UI.

The controller keeps the dataset successfully imported by the renderer separate
from the provider's latest downloaded snapshot. Failed imports/updates retain the
previous displayed dataset and its provenance. Re-enabling an expired overlay
fetches and replaces it; a fresh overlay can reuse the existing renderer source.
The Layer dialog shows source/licence, download time, local cache status,
official validity and update failures. While open, its cache-age display refreshes
once per minute without network requests. Closing the dialog stops that timer.

## Tile adapters

`web/map_providers.js` owns imagery and terrain configuration and their Cesium
factories. `web/globe.js` calls the adapter methods and handles map interaction.
Default endpoints and complete credits are unchanged. Source notices are escaped
as text, and the UAS import receives its attribution from the normalized dataset.

`createAdapters(Cesium, configuration)` accepts alternative imagery definitions
for the existing style keys and a terrain definition. Local composition can
supply `window.FPVMapProviderConfig` before `globe.js`; it is not a remote setting
or a new UI entry point. Replacing a Cesium adapter implementation is also confined
to this boundary. Unsupported upstream formats need an adapter, not map-UI edits.

Tile source descriptors record name, publisher, licence/terms, attribution and
metadata URI. Their official validity is unknown. A live tile service is not a
fetched whole-dataset snapshot: the app does not invent one retrieval/expiry time
for all visible tiles or claim a coherent offline dataset. Cesium retains its
request scheduling; terrain failures use the existing [recovery state machine](terrain_recovery.md).
Persistent caches and offline freshness policies remain #40/#51.

## Evidence and unknown values

Checked **2026-10-20**:

- The [official FOCA catalogue](https://opendata.swiss/en/dataset/geografische-uas-gebiete-der-schweiz)
  links the exact current GeoJSON URL. Its
  [catalogue API](https://ckan.opendata.swiss/api/3/action/package_show?id=geografische-uas-gebiete-der-schweiz)
  has null `license_id`/`license_title`; the
  [GeoJSON resource page](https://opendata.swiss/en/dataset/geografische-uas-gebiete-der-schweiz/resource/7509dfd4-7cd7-4d31-92ad-c997c250f42c)
  does not supply a licence text. The adapter therefore records an unknown licence,
  with the catalogue as its evidence link. Public access does not establish CC or
  swisstopo OGD licensing for FOCA data. Source/legal verification remains #44.
- No dataset-wide official applicability period is inferred from HTTP headers,
  the catalogue's modification date, per-feature attributes or download time.
  A future adapter may supply explicit official `OsintValidityPeriod` bounds.
  Cache freshness is local policy and does not establish permission to fly.
- Map service rights and product-specific notices follow the existing
  [map-source evidence](map_sources_and_attribution.md), including
  [swisstopo's own OGD terms](https://www.swisstopo.admin.ch/en/terms-of-use-free-geodata-and-geoservices).
  They are not presented as a Creative Commons licence.

## Verification

The regression tests exercise cache expiry/clock rollback, shared requests,
failed refresh retention, typed failures, disposal/late responses, source identity,
official validity boundaries, replaceable GeoJSON and imagery/terrain adapters,
and the visible Layer metadata/status with an alternate provider.

Use the commands in [CONTRIBUTING](../CONTRIBUTING.md), both platform builds and
the actual renderer smoke in [Cesium assets](cesium_assets.md). A local build or
browser fixture does not establish Android device/network acceptance.

Recorded locally on **2026-10-20**: enforced-lockfile dependency resolution,
format check for **83** hand-written Dart files, analysis with fatal warnings and
infos, **193** complete-suite Flutter tests, **22** JavaScript tests and **4**
Python tooling tests all passed. The pinned **395** Cesium files passed hash and
asset-path verification.

The Web release build with local renderer resources passed. Its current renderer,
terrain and map-provider scripts matched the sources at both Web-root and Flutter
asset paths; vendor hashes, local CanvasKit and fixture exclusion passed. In the
compiled app, a live official UAS download/import succeeded and the Layer dialog
showed retrieval/cache status separately from unknown licence/official validity.
The live swisstopo renderer smoke also passed in a 320-pixel map viewport,
including all styles/credits, geometry worker, overlays and an actual iframe reload.
The built terrain fault harness passed all HTTP 503/404/500, stalled-tile,
offline/online and late-response recovery cases after the adapter extraction.
The Android debug build passed. Its APK passed ZIP integrity, current renderer /
terrain / provider-script comparison, original Cesium hashes and fixture exclusion;
SQLite ELF libraries matched ARMv7, ARM64 and x86_64. Android device UI/network
acceptance remains a separate manual check.
