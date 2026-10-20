# Spot search, classification and details

Spots may have one optional category (40 characters) and up to ten tags (32
characters each). Category display spelling is retained; category filters ignore
case. Tags are trimmed, lowercase, deduplicated and sorted. The editor and filter
dialog accept comma-separated tags and offer up to twenty existing suggestions.
New labels can always be typed. Control characters are rejected.

Search checks name, description, category and tags. Each whitespace-separated
term must occur somewhere in the spot's searchable text. Matching ignores case
using Dart lowercasing, including German umlauts. It does not strip accents or
apply linguistic stemming. `%`, `_` and quotes are literal characters. Queries
are bound SQL parameters, limited to 160 characters and debounced by 250 ms.
Category, every selected tag, favorites and search are combined with AND.

The list watches at most fifty summaries at a time, newest ID first. Previous
and Next use an ID cursor rather than OFFSET. Changing filters resets to page
one. The UI retains cursor history, not previous pages' rows. New records appear
on page one; returning to an earlier page refreshes it against current records.
An emptied page still offers Previous. Summary queries select at most 120 notes
characters and no photo BLOBs. List rows open a live detail screen containing the
full description, classification, favorite action, gallery, editing, deletion
and an explicit Show on map action.

All saved spots remain on the globe; list filters do not hide map markers. A
marker selection offers Details. Marker queries read only ID, name and WGS84
coordinates, and unchanged projections are suppressed. Favorite, description
and classification changes therefore do not resend the complete marker set.
Marker rendering is still one Cesium entity per spot; this feature does not add
clustering or viewport-based marker loading. Controller and renderer accept at
most 10,000 markers; collections beyond that remain searchable in the list but
exceed the complete-map synchronization limit. Removing that limit requires a
different marker loading/rendering strategy and target-device profiling.

Schema v4 adds nullable `category`, canonical `category_key`, `search_text` and
`spot_tags` with cascading spot ownership. Category/ID, favorite/ID and tag/spot
indexes support exact filters. Legacy search text is backfilled in batches of
200, preserving photos, favorites and references. Spot metadata, classification
and photo writes share a transaction. Omitting classification in a repository
update preserves it; explicitly passing an empty classification clears it.

Tests cover migration from all three older schemas, Unicode/literal search,
combined filters, pagination, reactive details, rollback and file reopen. The
10,000-record file-backed SQLite test records native query timings and checks
bounded pages plus the lightweight map projection. These timings do not measure
Android/Web UI latency, frame rate, memory use or Cesium rendering performance.

## Validation record (2026-10-20)

- 145 Flutter tests and 7 JavaScript bridge tests passed. Analysis, repository
  formatting, pinned asset verification and documentation link checks passed.
- Web release and Android ARM64 debug APK built successfully. Packaged Cesium
  assets matched their hashes, current renderer scripts matched the sources,
  and APK ZIP integrity passed. The APK was not installed on a physical device.
- In the Web release, synthetic spots with categories, normalized/deduplicated
  tags and favorites were saved. Combined filters and Unicode/literal-percent
  search selected the expected spot. Category suggestions, details and Show on
  map worked. Classification, description and favorite status survived a full
  page reload.
- The 10,000-record native file-backed test measured 2.1 ms for the first list
  page, 1.6 ms with combined filters, 1.7 ms for the next filtered page, and
  381.8 ms for the complete lightweight marker projection in this run. These are
  observations on this Windows host, not performance guarantees for other targets.
- The actual WebGL renderer accepted 10,000 synthetic markers via indexed block
  transfer in 4,174 ms, rejected a 10,001-marker snapshot without replacing the
  valid data, and accepted restored markers after a real iframe reload in
  5,422 ms. Local geometry workers, UAS fixture import and correlated offline
  terrain errors also passed. The renderer reported no render errors. These are
  command timings, not FPS measurements. Dense labels still overlap; clustering
  and Android performance profiling remain separate follow-up work.
