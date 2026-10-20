# Battery inventory and condition records (#14)

Open **Battery inventory** from the navigation drawer, including while the map
is loading. The **Packs** tab contains individual physical batteries; **Types**
contains reusable specification templates. Both support create, inspect, edit
and confirmed deletion, with a scrollable editor and retryable save errors.

## Specifications and templates

Each record stores a name, chemistry, positive whole-number cell count and
capacity in mAh. Nominal voltage (V), recorded energy (Wh), weight (g) and notes
are optional. Unknown values remain empty. Nominal voltage is entered explicitly,
not inferred from chemistry or cell count.

When voltage is known, the app separately displays calculated nominal energy:
`capacity_mAh / 1000 × nominal_voltage_V`. A supplied Wh value is kept separately.
This calculation describes nominal specifications, not remaining usable energy.

**Add pack from type** copies technical specifications into a new independent
pack, retaining an optional link to the template. Existing packs keep their
specifications when a template is edited. In the editor, **Copy type specifications**
explicitly replaces the technical fields with the selected template's values.
Pack names, condition and assignments are separate. A record's pack/type kind
cannot be changed after creation.

Deleting a type clears its links while retaining every pack and its copied
specifications. Templates and packs may use the same descriptive name; each has
its own stable ID. Record one entry per physical battery.

## Optional condition and availability

Individual packs can record charge from 0 to 100 percent, a nonnegative whole
cycle count, condition notes and availability (not recorded, available,
unavailable or retired). Empty charge/cycle fields are unknown; explicit zero
is retained. These are manual observations. No health percentage, remaining
lifetime or flight endurance is inferred from cycle count or charge.

## Drone and flight-plan links

The pack editor offers the existing local drones and saved flight plans as
independent multi-select assignments. Empty lists describe the absence of saved
records; the editor does not create flight-planning projects. Assignments are
manual links. Electrical compatibility and reservation rules require separate
models.

A complete profile, condition and both assignment sets are saved atomically.
An invalid/deleted target cannot partially update the battery or drop its
previous links. Associated names are shown in details and update after a target
rename. Deleting a drone or plan removes its battery links. Deleting a battery
removes its links and retains drones, flight plans and route waypoints.

## Storage and migration

Schema **v6** extends `batteries` with the pack/type discriminator, optional
template self-reference, explicit voltage/Wh, charge, availability and condition
notes. Cycle count becomes nullable. `battery_drones` and `battery_flight_plans`
store the two many-to-many relationships with composite primary keys and foreign
keys.

Existing v2-v5 batteries retain IDs, name, chemistry, cells, capacity, weight,
cycles and notes. Recorded zero cycles remain zero; no voltage, charge, type
classification or health data is invented. Older records become individual packs
with unknown availability and no assignments. The migration rebuilds the battery
table with Drift's `TableMigration`; v1 creates the current table because it had
no battery table. Old schema snapshots remain unchanged, with an added v6 snapshot
and generated fixture. Foreign keys are enabled before normal repository use.

`BatteryInput` is a validated complete snapshot; `BatteryRepository.saveProfile`
saves it in one transaction. `watchProfile` includes both relationship tables and
their targets, keeping details consistent with committed changes. UI-created
resources use the home's shared local database. Injected repositories and their
database remain caller-owned. All battery records are local, with no new network
service or permission.

## Verification

Regression tests cover all prior schemas through v6, preserved battery values,
optional versus explicit zero state, independent templates, foreign-key deletion,
transaction rollback, profile streams and SQLite file reopening. Widget tests
cover editing/validation, assignments, save failure/retry, cancellation, deletion,
320-pixel layout with the keyboard and navigation before map readiness.

Run the standard checks and both builds listed in [CONTRIBUTING](../CONTRIBUTING.md).
Android device acceptance remains separate from builds and automated UI tests.

Recorded locally on **2026-10-20**: enforced-lockfile dependency resolution,
analysis with fatal warnings/infos, format check for **90** hand-written Dart
files, **207** complete-suite Flutter tests, **22** JavaScript tests and **4**
Python tooling tests passed. All **395** pinned Cesium files passed hash and
asset-path verification. The complete-suite run includes the sequential SQLite
file-reopen test without a multiple-database warning.

The Web release build passed with local CanvasKit and verified bundled renderer,
provider, terrain and Cesium assets; test fixtures are excluded from the build.
In the actual built Web app, a type (6S, 1500 mAh, 22.2 V, 240 g) was saved and
used to create an independent pack (245 g). The details displayed calculated
33.30 Wh separately from the empty recorded-Wh field. Manual charge (80%),
cycles (12), availability and condition notes persisted after a page reload.
An existing drone profile was then assigned through the editor and appeared in
the saved details. Flight-plan links are covered by repository and widget tests;
the browser scenario had no saved flight plans. The local browser harness used
synthetic terrain and isolated demo records, so this result makes no new claim
about external terrain providers or personal production records.

The Android debug APK also built successfully. Its ZIP integrity, all pinned
vendor hashes, current renderer/provider/terrain modules, fixture exclusion and
SQLite ELF libraries for armeabi-v7a, arm64-v8a and x86_64 were verified. The
resulting `build/app/outputs/flutter-apk/app-debug.apk` is 219,608,794 bytes.
Physical Android acceptance remains for create/edit, template copying,
drone/flight-plan assignments where targets exist, keyboard/layout and stored
records after restarting the app. The build and native SQLite tests do not
establish those device interactions.
