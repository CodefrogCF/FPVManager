# Foundation issue audit (2026-10-20)

The six issue descriptions and their current checklists were read in the private
GitHub repository and compared with the checkout after drone profiles (#13).
An open checkbox is not by itself evidence of missing code. No GitHub issues or
checklists were changed during this audit.

| Issue | Present in the code | Remaining work |
|---|---|---|
| [#2 Evaluate 3D Globe Rendering Engines](https://github.com/CodefrogCF/FPVManager/issues/2) | Cesium runs through an iframe on Web and WebView on Android, with typed bridge, camera controls, bundled resources and flat offline fallback. | A reviewable engine comparison/decision and technical iOS assessment are still missing. There is no iOS runner. Existing build/smoke checks do not establish device FPS, memory budgets or iOS runtime compatibility. |
| [#4 OSINT Provider Abstraction & Data Provenance](https://github.com/CodefrogCF/FPVManager/issues/4) | Shared listenable provider/cache/error contracts, normalized GeoJSON adapter, source/licence metadata, explicit retrieval/cache/official-validity semantics and provenance of the actually displayed dataset. Imagery/terrain factories and endpoints are behind a replaceable adapter boundary. Layer metadata uses the injected source; expired overlays refresh on reactivation. Analysis, format, 193 Flutter / 22 JavaScript / 4 Python tests, Web release and Android debug builds passed with asset verification. The built Web app imported live UAS data; live 320-pixel renderer and terrain-fault checks passed. See [provider contracts](osint_providers.md). | Ready for acceptance review of the current provider boundary, with Android device UI/network checks still separate. Unverified source licence/official validity stay unknown; legal/source verification remains #44. Additional weather/traffic products and persistent/offline cache policies (#40/#51) are separate features. |
| [#5 Privacy-First Architecture & Permission Policy](https://github.com/CodefrogCF/FPVManager/issues/5) | Local personal records, no required account/tracker, explicit device-location action with permission handling, no automatic publishing. The consolidated [privacy/permission policy](privacy_and_permissions.md) now records all current external requests and their data flows, including saved UAS enablement. | Ready for acceptance review against its four criteria for the current scope; several unchecked boxes predate the implementation. Source/license auditing remains separate under #8/#44. Reassess the policy when future network/sharing features are added. |
| [#7 Integrate swisstopo 3D Terrain](https://github.com/CodefrogCF/FPVManager/issues/7) | Terrain service state now covers runtime tile errors, offline transitions, bounded connection/probe/sampling, a labelled flat fallback and explicit recovery without replacing the viewer. Height queries and picked heights are invalidated across terrain generations. Analysis, format, 182 Flutter tests, 21 JavaScript tests and 4 Python tests passed. Web release and Android debug builds passed, including bundled-asset verification. The built Web app recovered through its visible retry action; actual Cesium/WebGL tests passed with synthetic HTTP 503/404/500, delayed tiles, preserved camera/layers and late responses, plus live swisstopo checks; see [terrain recovery](terrain_recovery.md). | Physical Android acceptance remains for actual network loss/recovery and orientation changes. Browser fixture events are not a physical Wi-Fi test. |
| [#8 Satellite Imagery & Map Style Switching](https://github.com/CodefrogCF/FPVManager/issues/8) | Three styles with on-screen attribution; SWISSIMAGE Background includes CNES/Spot Image/NPOC and the product-specific Planet notice; terrain has an explicit source despite empty upstream attribution metadata. Exact endpoints, official terms and evidence are recorded in [map sources and attribution](map_sources_and_attribution.md). Automated checks and actual WebGL checks passed, including live style changes/reload at 320 pixels. Web release and Android debug builds passed; their renderer/vendor assets were verified, as was the built Web UI. | Check Android readability on a device, including selected coordinates and portrait/landscape. #44 remains the broader external-source/dependency and release documentation audit. |
| [#9 Layer Manager & Map Controls](https://github.com/CodefrogCF/FPVManager/issues/9) | Visibility, UAS fill opacity, source/download metadata; this change adds stored startup preferences, saved-spot visibility and configurable overlay source order. | Validate the new paths on Web and Android. See [map preferences](map_preferences.md) for the implementation and recorded limits. |

## Working order

1. Fix the reported SQLite Android artifact download failure in CI, with hash
   verification intact and a local build covering all three Android ABIs.
2. Complete the concrete #9 persistence/order gap using the existing settings
   repository, without a schema migration.
3. Review #5 against the consolidated current-flow policy, then review #8's
   imagery/terrain source notices and documented terms. The broader #44 remains
   a release documentation task.
4. Address #7 runtime network/terrain failures, then #4 provenance/provider
   contracts before adding more external providers.
5. Continue equipment work with #14 Battery Inventory & Battery Health, then #15.
   The #2 engine decision/iOS assessment remains a separate research deliverable;
   iOS execution requires its own runner/toolchain validation.
6. Continue the airspace milestone with #16 UAS zone inspection/content gaps,
   then #17 spatial intersection checks. The rule/classification work in #50
   remains separate from displaying source attributes.

The current gaps fit existing issues. This audit does not justify duplicate
issues for the same criteria. New independently reproducible defects can be
drafted separately once evidence establishes their scope.

Relevant implementation: `lib/core/osint/`,
`lib/features/airspace/data/swiss_uas_provider.dart`,
`lib/features/spots/data/spot_location_service.dart`,
`lib/features/globe/globe_controller.dart`, `web/globe.js`,
`lib/core/database/repositories/user_preferences_repository.dart`.

## Equipment follow-up: #14

The private [Battery Inventory & Battery Health issue](https://github.com/CodefrogCF/FPVManager/issues/14)
was checked against its four current acceptance criteria. The implementation now
records cell count, capacity, nominal voltage, explicit energy and weight;
distinguishes reusable type templates from individual packs; supports optional
manual charge, cycles, condition notes and availability; and associates packs
with saved drones and flight plans. Type changes preserve independent pack
specifications. Schema v6 preserves existing battery records and adds
transactional assignment tables. See [battery inventory](battery_inventory.md)
for behavior, migration and validation evidence.

The complete Flutter suite (207 tests), JavaScript (22), Python tooling (4),
fatal-warning analysis, formatting and bundled Cesium checks passed. The built
Web app was exercised for type/pack creation, independent specifications,
condition records, persistence after reload and drone assignment. Web release
and Android debug builds passed with bundled-asset verification, including all
three Android SQLite architectures. An Android
device check remains for keyboard/layout, persistence after app restart and the
same create/edit/assignment flows. This does not establish automatic battery
health estimation or electrical compatibility; those are outside the current
acceptance criteria. Existing flight-plan records can be selected; the battery
editor does not provide a flight-plan creation workflow.

Next in the agreed equipment order is #15. No additional issue is needed for
the current #14 criteria, and its GitHub checklist remains unchanged pending
acceptance review.

## Inserted work: ground view and selected #25 criteria (2026-10-21)

Before continuing with #15, the requested terrain-relative inspection camera
and the map-editing/local-storage part of
[#25 Interactive 3D Waypoint Route Editor](https://github.com/CodefrogCF/FPVManager/issues/25)
were implemented. The current four criteria were read in the private issue.
This work covers placing, moving and deleting waypoints directly on the map,
and saving multiple flight routes locally. Heights/speeds and the full
drone/battery assignment workflow remain outside this inserted scope. No GitHub
checkboxes or issue state were changed.

The actual Cesium/WebGL fixture check passed for terrain +2 m camera placement,
arrow-key movement, focus loss, Escape/restored camera, terrain-picked route
points, waypoint drag/delete and an offline exit. The fixture uses local
synthetic terrain, with no claim about real-world terrain accuracy or Android
device interaction. See [ground view and route editing](ground_view_and_routes.md)
for controls, persistence/draft semantics and acceptance evidence.

Fatal-warning analysis, formatting (99 hand-written Dart files), the complete
Flutter run (216 tests) and the subsequent affected-test run (20, including an
additional load-recovery case) passed. JavaScript (29), Python tooling (4) and
vendor checks passed. The final Web release was exercised with live terrain,
ground movement/look and saved routes after reopening; terrain-aware route
framing was also checked with the actual Cesium fixture. Web release and
Android debug builds passed with packaged-source/vendor/SQLite verification.
Android touch/keyboard, background/resume and app-restart behavior remain device
acceptance checks.

## Equipment follow-up: #15 (2026-10-21)

The private [Radio & Video Equipment Profiles issue](https://github.com/CodefrogCF/FPVManager/issues/15)
was read against its four current acceptance criteria:

| Criterion | Implementation |
|---|---|
| Independent radio control and video configuration | Separate locally saved control/video/telemetry profiles with their own protocol, transmitter, receiver and antennas; changes to one profile do not overwrite another. |
| Frequency, power, antennas and receiver specifications | Explicit MHz, mW, kHz, dBi, dB and dBm fields, separate antenna descriptions/polarization, receiver mode/specifications and source/context. Unknowns stay null; signed gain/sensitivity and explicit zero power/loss are supported. |
| Assignment to drone profiles | Transactional many-to-many associations; one drone can use separate control and video profiles. Removal preserves unrelated drones/equipment. |
| Model supports future RF propagation analysis | Structured numeric values with fixed units and separate transmitter/receiver fields, plus recorded context. Propagation calculations, operating-power selection and terrain obstruction remain future analysis work. |

Schema v7 preserves legacy equipment categories, frequency, power (including
zero), notes and unrelated records. List/editor/detail screens are reachable
from the drawer before map readiness. See [radio equipment](radio_equipment.md)
for validation, replacement, recovery and migration contracts. GitHub checkboxes
and issue state remain unchanged pending acceptance review.

Fatal-warning analysis, formatting (106 hand-written Dart files), locked
dependency resolution and the complete Flutter suite (232 tests) passed.
JavaScript (29), Python tooling (4) and all 395 bundled Cesium file/hash checks
also passed. Repository and widget checks include atomic failure recovery,
signed/nonfinite RF input, legacy categories, drone removal, 320-pixel keyboard
layout and persisted RF/assignment data after a SQLite file reopen.

The Web release build and packaged renderer/vendor checks passed. In the actual
built Web app, synthetic demo records exercised drone creation, separate control
and video profiles, RF values with decimal commas and signed gains/sensitivity,
an edit to the control profile and a shared drone assignment. After closing and
reopening the app, both profiles and the edited values/associations persisted.
Saved screenshots show the profile list, control details and RF values. The
local preview server was stopped after verification.

The Android debug build passed as well. APK ZIP integrity, packaged renderer
sources, vendor hashes, fixture exclusion and SQLite ELF libraries for
armeabi-v7a, arm64-v8a and x86_64 were verified. Physical Android acceptance
remains for the new forms with keyboard/rotation and persistence after an actual
app restart. No additional issue is needed for the current #15 criteria.

## Airspace follow-up: #16 (2026-10-21)

The private [Swiss UAS Geographical Zones Overlay issue](https://github.com/CodefrogCF/FPVManager/issues/16)
was read against its four current criteria. The existing overlay, attribution
and download/HTTP-modified metadata remain the foundation. The current change
adds a compact zone card and structured source inspection, separate height
units/references, source times and authority/contact fields, plus the raw
attribute list with explicit display-limit notices.

Empty/partial or locally unusable content and missing key details are labelled
in the layer metadata and a compact map banner. Source counts/next-page hints
are checked without following arbitrary URLs. Entirely unusable replacements
retain the previous displayed snapshot and a later explicit attempt bypasses
the rejected cache. Successful retrieval never establishes complete coverage
or legal applicability. Classification/rule interpretation remains #50;
intersection checks are #17 and DABS/NOTAM integration is #18.

Formatting (118 hand-written Dart files), fatal-warning/info analysis, locked
dependency resolution, 250 complete-suite Flutter tests, 35 JavaScript tests,
4 Python tests and all 395 Cesium file/hash checks passed. Web release and
Android debug builds passed with packaged-source/vendor/SQLite verification.
The built Web app imported live official data and its inspection/metadata were
checked with a 320-pixel layout against synthetic terrain. Android device
acceptance remains for the new inspection sheet. See [UAS zone inspection](uas_zone_inspection.md)
for evidence, recovery behavior and limits. GitHub issue state and checkboxes
were not changed; no duplicate issue is needed for these criteria.
