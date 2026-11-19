# Battery chemistry profile fields (phase 2)

The battery profile stores optional pack-specific continuous C-rating, burst C-rating, burst duration in seconds and cell-equivalent internal resistance in milli-ohms. None is required. Missing values retain the conservative chemistry model (not a manufacturer claim).

The battery editor uses six stable chemistry IDs from `assets/battery/chemistries.json`. Recognized legacy aliases are normalized on save. Unknown historical values remain as a selectable `Unsupported (preserved)` entry until deliberately changed, without data loss.

Schema v11 adds nullable columns to `batteries` with a normal Drift migration from v10; no rows are rewritten. New backups include the fields automatically. Older backups are read through their existing column intersection logic and missing fields remain null. Backups produced with schema v11 require a client that supports schema v11. Users should export a backup before migration.

Live-simulation uses the pack-specific continuous rating and resistance ahead of chemistry assumptions. Burst rating is only valid with an explicit duration; the simplified model counts consecutive time above continuous load conservatively, without instant recovery. Route analysis compares segment power demand with the same lookup curve and checks whether a segment fits in the declared burst duration. This does **not** simulate temperature, ageing, current draw during each acceleration transient or manufacturer-validated burst specifications. No real telemetry is measured.
