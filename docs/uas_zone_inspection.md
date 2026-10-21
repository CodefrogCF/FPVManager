# UAS zone inspection and dataset limitations (#16)

Select a zone on the map, then choose **Inspect restrictions**. The compact map
card opens a scrollable inspection sheet with source classification codes,
restriction text, separate lower/upper height limits, source time windows,
authority/contact information and dataset provenance. The **All source
attributes** section retains additional fields, including unknown future codes.
The supplied zone name takes precedence over Cesium's generic title fallback;
long titles retain their full source value in the attribute section.

## Interpretation boundaries

Codes such as `COMMON`, `NATURE` and `REQ_AUTHORISATION` are displayed as supplied.
This feature does not classify legal applicability, resolve overlapping zones,
calculate current activation or determine permission to fly. Those workflows
remain separate from source inspection (#17/#19/#50).

Each height limit retains its own unit and vertical reference. For example,
`0 M · AGL` and `900 M · AMSL` are separate source values; the app does not subtract
them or infer an AMSL datum. Date/time strings and explicit offsets are retained.
An explicitly permanent zone can omit start/end dates without being labelled
incomplete. A temporary zone missing either date is identified as missing details.

Source names, text and URLs render as selectable plain text. The app does not
execute source HTML or automatically navigate to contact/website URLs. The
inspection uses the selected provider's provenance, including alternate adapters.
Download time is labelled UTC and remains distinct from official validity.

## Content assessment and recovery

The map-layer sheet distinguishes loaded features from source features and shows
coverage as **Not independently verified** or **Limited / incomplete data**. A
compact map banner appears only for detected limitations, with a shortcut to the
layer metadata. Coverage uncertainty is explained even when no local content
problem was detected.

Local checks identify:

- An empty FeatureCollection.
- Features with absent, unsupported or structurally unusable geometry, including
  nonfinite/out-of-range coordinates, invalid lines and unclosed polygon rings.
  Usable features are imported as a subset; omitted features remain counted.
- Missing identification, category, restriction, permanence or height details.
  These are local inspection checks, not a claim to validate an official schema.
- Declared `numberMatched`/`totalFeatures` above the downloaded feature count,
  inconsistent `numberReturned` or total counts, and a declared next-page link.
  The app does not follow arbitrary next-page URLs automatically.

If a nonempty response has no usable geometry, replacement fails and the last
displayed dataset, its provenance and assessment remain in place. The rejected
snapshot is bypassed on the next explicit enable/refresh attempt, so its fresh
cache lifetime cannot prevent recovery. A renderer replacement failure likewise
retains the assessment belonging to the previously displayed data. Renderer
reload clears displayed metadata until data is imported into the new renderer.

Empty responses are displayed with an explicit limitation notice; an empty map
is not presented as evidence of unrestricted airspace. Structural checks do not
establish geometry topology, geographic coverage, official validity or currency.
The [FOCA guidance](https://www.bazl.admin.ch/de/geografische-flugeinschraenkungen)
describes the geographical-zone map and DABS as separate information sources.
DABS/NOTAM integration remains #18.

## Attribute transfer limits

The renderer sends up to 128 source attributes with keys up to 120 characters
and values up to 8,000 characters. Key restriction/height fields are prioritized.
An 80 Ki-character serialized budget includes escaping and shortened-field
metadata, leaving room within the bridge's 128 Ki-character event limit.
Null/empty/zero/false values are retained as text rather than silently removed.

Omitted attributes and shortened/unsupported values are explicitly identified
in the inspection sheet. Oversized keys are omitted rather than renamed into
another field. Source text is never interpreted as HTML.

## Source evidence

Checked on **2026-10-21** against the
[official FOCA catalogue](https://opendata.swiss/en/dataset/geografische-uas-gebiete-der-schweiz)
and its [GeoJSON resource](https://data.geo.admin.ch/ch.bazl.einschraenkungen-drohnen/einschraenkungen-drohnen/einschraenkungen-drohnen_4326.geojson).
The inspected snapshot contained 1,252 features (1,243 Polygons and 9
MultiPolygons). All had explicit height units (`M`); 70 upper limits used `AMSL`
and 1,182 used `AGL`, while all lower limits used `AGL`. All 1,251 explicitly
permanent zones had empty start/end dates; the single temporary zone supplied
both dates. Counts describe this snapshot, not expected future totals or proof
of complete coverage.

The downloaded snapshot's SHA-256 was
`27e4f77f7a683fec8bcb399a0922cac7e6e13296c6cbf0704e44c17a95bf96f1`.
No real contact records or downloaded source data are added to test fixtures.

## Validation

Regression tests cover mixed height references, zero and unknown values,
temporary/permanent periods, malformed/partial/empty geometry, declared partial
responses, failed replacement/recovery, bounded attribute transfer and narrow
scrollable inspection UI. Recorded on **2026-10-21**:

- Locked dependency resolution passed without changing dependency versions.
- Formatting passed for **118** hand-written Dart files and analysis passed
  with fatal warnings/infos enabled.
- The complete Flutter suite passed **250** tests; all **35** JavaScript tests,
  **4** Python tooling tests and **395** pinned Cesium file/hash checks passed.
- Applying the actual assessment to the inspected official snapshot accepted
  all 1,252 features, with zero skipped features or detected key-detail gaps.
  Source coverage still remained explicitly unverified.
- The JavaScript Web release passed with `--no-web-resources-cdn
  --no-wasm-dry-run`. The root/Flutter copies of all seven renderer modules,
  vendor hashes, local CanvasKit and fixture exclusion passed verification.
- The Android debug build passed. Its APK (181,723,208 bytes) passed ZIP
  integrity, renderer/source and vendor checks, fixture exclusion and SQLite
  ELF verification for armeabi-v7a, arm64-v8a and x86_64.

The built Web app imported 1,252 live FOCA features, displayed retrieval and
HTTP-modified timestamps separately from coverage/official validity, and opened
the structured inspection of a real CTR zone. Restriction text, category codes,
height limits, authority and source metadata were inspected; the scrollable
sheet was checked at 320 pixels. The test server supplied synthetic terrain,
not real elevation data. Physical Android layout/touch and rotation checks
remain device acceptance work; source-condition error cases are covered by
controlled regression tests rather than claims about live source outages.

The final built renderer was checked again after the source-name correction:
selecting a real zone displayed **CTR ZURICH** (CTR0015), and its complete set
of 40 source attributes could be expanded and scrolled in the 320-pixel view.
Desktop/mobile inspection screenshots were saved; the final browser check
reported no console errors. The temporary preview and loopback server were
closed after verification.
