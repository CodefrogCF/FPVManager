# Issue #91 — Cantonal forest-fire prevention measures

The **Environment** section now has two separate WMS controls:

- **Wildfire danger**: `ch.bafu.gefahren-waldbrand_warnung` (hazard level, never a legal decision)
- **Cantonal forest-fire prevention measures**: `ch.bafu.gefahren-waldbrand_praeventionsmassnahmen_kantone`

The new expandable **Kantonale Waldbrand-Präventionsmassnahmen** panel performs a
manual point lookup. The point is the selected globe location, the initial
saved-spot location or coordinates typed by the user. The explicit consent
checkbox is required before transmitting a coordinate to geo.admin.ch.
No query starts automatically when the panel or map opens.

## Official data and supported categories

- WMS rendering: `https://wms.geo.admin.ch/` (existing Cesium WMS infrastructure).
- Identify: `GET https://api3.geo.admin.ch/rest/services/ech/MapServer/identify`;
  `geometryType=esriGeometryPoint`, `sr=4326`, `tolerance=0`,
  `layers=all:ch.bafu.gefahren-waldbrand_praeventionsmassnahmen_kantone`,
  `returnGeometry=false`, `limit=50`.
- Legend and dataset publication status:
  `https://api3.geo.admin.ch/rest/services/api/MapServer/ch.bafu.gefahren-waldbrand_praeventionsmassnahmen_kantone/legend`.
- Published fields: `title_de`, `description_de`, `name_de`, `canton`,
  `valid_from` and `featureId`. Optional `valid_until` is retained if returned.
  The legend's `Datenstand`/`Data status` is a **dataset publication date**, not
  the validity start or retrieval time for each measure.
- Category mapping is **only** from the five official German `title_de`
  values (none, caution, conditional prohibition, absolute forest/proximity
  prohibition, absolute outdoor prohibition). Unrecognised titles remain
  unclassified, without inferring a legal prohibition.

The authoritative meaning of categories is published at
https://www.waldbrandgefahr.ch/de/bedeutung-der-massnahmen .
Local and cantonal orders take precedence. Additional local or municipal rules
may be absent from the mapped dataset; missing results never mean all-clear.

## Dates, failures and caching

- Snapshot retrieval time is shown in UTC, separately from the original
  dataset-publication string and the original per-record validity strings.
- Swiss publication dates do not specify a timezone; the original string is
  therefore retained and rendered without asserting a UTC offset.
- Unknown publication date, a dataset older than 48 hours, a fetched snapshot
  older than six hours, future dates or a failed refresh are flagged as
  **unconfirmed/outdated**. These are conservative UI thresholds, *not* a
  promise that the data source publishes on this schedule.
- No `results` or a truncated query never proves the absence of restrictions.
- Old snapshots are displayed with their retrieval and publication dates.
  A failed refresh preserves the existing snapshot and shows an explicit
  refresh-failed warning; it cannot produce a "no restrictions" result.
- The OSINT SQLite cache is separate from personal data and is not included in
  profile exports and backups. Each entry is integrity-checked, capped at
  120 KiB and retained for no more than 14 days, at most 16 coordinate keys.
- Query coalescing, a conservative 10-second minimum interval, 12 manual
  requests/hour, server-side point filtering, 50 returned features and
  300 KiB identify / 200 KiB legend caps limit load.
- The WMS layer uses existing renderer disposal, visibility controls, error
  reporting and retries; danger and measures toggles are independent.

## Attribution and terms

Data: **BAFU / Kantone · geo.admin.ch**. The WMS credit is displayed in the
Cesium globe and the detail panel links to the official publications and
cantonal offices:

- https://www.waldbrandgefahr.ch/de/aktuelle-massnahmen
- https://www.waldbrandgefahr.ch/de/kantonale-fachstellen
- https://www.geo.admin.ch/en/general-terms-of-use-fsdi

Use the dataset's geocat.ch metadata for data-specific legal restrictions.
The live WMS is not an official legal notice, and tile loading never validates
source publication or local rules.

## Validation

Run from the project root:

```powershell
dart format lib test
flutter analyze
flutter test test/features/mobility/wildfire_prevention
flutter test test/features/mobility/mobility_ui_test.dart
flutter test
node --test test/js/*.test.cjs
```

Manual check: in Environment enable **only** the prevention layer, then only
the danger layer, then both, adjusting opacity independently. Select a Swiss
map point, explicitly allow lookup, load official measures and inspect dates,
links and any overlap. Disable network and try an offline snapshot and a failed
refresh: neither must produce a green/all-clear message. Repeat on Android and
Web. Cross-origin requests and official data returned for individual cantons
have not been device-tested in this environment.
