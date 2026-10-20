# Foundation issue audit (2026-10-20)

The six issue descriptions and their current checklists were read in the private
GitHub repository and compared with the checkout after drone profiles (#13).
An open checkbox is not by itself evidence of missing code. No GitHub issues or
checklists were changed during this audit.

| Issue | Present in the code | Remaining work |
|---|---|---|
| [#2 Evaluate 3D Globe Rendering Engines](https://github.com/CodefrogCF/FPVManager/issues/2) | Cesium runs through an iframe on Web and WebView on Android, with typed bridge, camera controls, bundled resources and flat offline fallback. | A reviewable engine comparison/decision and technical iOS assessment are still missing. There is no iOS runner. Existing build/smoke checks do not establish device FPS, memory budgets or iOS runtime compatibility. |
| [#4 OSINT Provider Abstraction & Data Provenance](https://github.com/CodefrogCF/FPVManager/issues/4) | Generic `OsintProvider<T>` / `OsintDataset<T>` interfaces; injectable UAS adapter; deduplicated downloads, one-hour memory cache and retained data after refresh failures. | Dataset contracts lack source display name, license, official validity and explicit freshness/update status. Imagery/terrain endpoints remain in the renderer. Replacing every provider independently of the map UI is not established by the existing UAS adapter. |
| [#5 Privacy-First Architecture & Permission Policy](https://github.com/CodefrogCF/FPVManager/issues/5) | Local personal records, no required account/tracker, explicit device-location action with permission handling, no automatic publishing. The consolidated [privacy/permission policy](privacy_and_permissions.md) now records all current external requests and their data flows, including saved UAS enablement. | Ready for acceptance review against its four criteria for the current scope; several unchecked boxes predate the implementation. Source/license auditing remains separate under #8/#44. Reassess the policy when future network/sharing features are added. |
| [#7 Integrate swisstopo 3D Terrain](https://github.com/CodefrogCF/FPVManager/issues/7) | Terrain provider, adaptive Cesium detail, credits, bounded initialization wait with ellipsoid fallback, explicit elevation references and correlated query errors. | Handle/report tile failures and interrupted networks after initialization, define recovery and verify them against the actual renderer. A successful initial load or an offline startup smoke does not complete this criterion. |
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

The current gaps fit existing issues. This audit does not justify duplicate
issues for the same criteria. New independently reproducible defects can be
drafted separately once evidence establishes their scope.

Relevant implementation: `lib/core/osint/`,
`lib/features/airspace/data/swiss_uas_provider.dart`,
`lib/features/spots/data/spot_location_service.dart`,
`lib/features/globe/globe_controller.dart`, `web/globe.js`,
`lib/core/database/repositories/user_preferences_repository.dart`.
