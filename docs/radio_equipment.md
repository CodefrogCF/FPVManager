# Radio and video equipment profiles

The navigation drawer opens **Radio & video equipment** without waiting for the
map. Each local profile is an independent configuration: radio control, video or
telemetry. A profile can describe a complete transmitter/receiver link or just
the known components. Several profiles may be associated with the same drone,
and a reusable configuration may be associated with several drones. The editor
does not infer component compatibility from those associations.

## Recorded specifications

| Value | Storage contract |
|---|---|
| Frequency | MHz, finite and greater than zero |
| Channel bandwidth | kHz, finite and greater than zero |
| Maximum transmitter power | mW, finite and nonnegative; maximum conducted output before antenna gain and cable/connector loss; the actual operating setting may be lower |
| Transmitter and receiver antenna gain | dBi, any finite signed value |
| Transmitter and receiver cable/connector loss | dB, finite and nonnegative |
| Receiver sensitivity | dBm, any finite signed value; record the applicable mode in receiver specifications |

Protocol/system, transmitter and receiver model, each antenna's characteristics
and polarization, receiver specifications/operating mode, source/measurement
context and notes are stored separately. Antenna descriptions can include type,
pattern, orientation, connectors and diversity details. Short descriptions are
limited to 120 characters and long descriptions/notes to 4,000. Unknown optional
values remain `null` and are displayed as **Not recorded**. Zero power remains an
explicit recorded value, including receiver-only legacy equipment. Both decimal
point and decimal comma are accepted in the editor.

These fields and their explicit units support a future RF-analysis input model.
This feature records specifications only: it does not calculate propagation,
link margin, range or terrain obstruction, or determine permitted transmit power.
Source/context is entered manually; no manufacturer specifications are fetched
or assigned automatically.

## Persistence and recovery

`RadioProfileInput` validates a complete specification/assignment snapshot.
`RadioEquipmentRepository.saveProfile` commits it in one transaction. An invalid
drone foreign key rolls back both the equipment update and assignment changes.
Deleting equipment removes only its associations; deleting a drone removes only
that association, preserving the equipment. Profile observers refresh when
equipment, assignments or associated drone names change.

List/detail load failures provide Retry. Drone-option failures provide Refresh
drones, and Save waits for successfully loaded options. A drone removed while
editing can be refreshed and explicitly unchecked. Save failures retain all
draft entries for retry or cancellation. Delete requires a confirmation dialog.
The form scrolls while Save and Cancel remain outside the scrolling content.

Schema **v7** adds nullable RF columns and the composite-key
`radio_equipment_drones` association table. Migrations from v1 through v6 preserve
existing IDs, names, categories, frequency, power (including zero), notes and
unrelated records. Legacy/custom categories remain selectable when editing;
new profiles use control, video or telemetry. The original `updateEquipment`
API replaces its original fields while retaining newer RF fields and links.
`saveProfile` replaces the whole profile, clearing omitted optional values.

All records remain in the existing local SQLite database. Equipment operations
add no network requests or permissions. Injected repositories/database lifetimes
remain caller-owned, following the other equipment screens.

## Verification

Repository tests cover independent configurations, signed/zero RF values,
validation, complete replacement, rollback, legacy updates, observer updates and
cascading association removal. Migration tests validate every stored schema
v1-v6 against v7 and verify legacy RF values and existing battery assignments.
The temporary-file reopen test includes RF details and drone associations.

Widget tests cover create/edit/clear, independent video/control assignment,
legacy categories, save/load retry, deletion/cancellation, removed drone options,
menu navigation before map readiness and a 320 × 568 viewport with keyboard
insets. Browser and build results are recorded in the foundation issue audit.
Physical Android keyboard/layout and persistence after an actual app restart
remain device acceptance checks.
