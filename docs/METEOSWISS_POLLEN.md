# Issue #92 — MeteoSwiss pollen monitoring station observations

## Official source and scope

The source is the FSDI STAC collection `ch.meteoschweiz.ogd-pollen`:
https://data.geo.admin.ch/api/stac/v1/collections/ch.meteoschweiz.ogd-pollen

MeteoSwiss reference: https://opendatadocs.meteoswiss.ch/a-data-groundbased/a7-pollen-stations

- Station metadata: `https://data.geo.admin.ch/ch.meteoschweiz.ogd-pollen/ogd-pollen_meta_stations.csv`
- Per-station STAC item: `/items/{lowercase_station_abbr}`; select the published `ogd-pollen_<station>_h_now.csv` asset. Asset URLs are accepted only from the official FSDI host and collection path.
- `h_now` contains **hourly average observations** of airborne pollen concentration. The MeteoSwiss changelog (17 July 2026, version 1.2.0) says this file is updated roughly **every 20 minutes**, which does not mean each station creates a new hourly observation every 20 minutes.
- Seven pollen types with hourly parameter IDs (`kaalnuh0`, `kafraxh0`, `kabetuh0`, `kafaguh0`, `kacoryh0`, `kaquerh0`, `khpoach0`); published hourly unit is **No/m³ (pollen grains per cubic metre of air)**. Missing values are not zero.
- MeteoSwiss CSV time references (`dd.mm.yyyy HH:MM`) are **UTC** and are not converted to a presumed local time. Raw station ID, position, name, canton, observation UTC, source STAC updated UTC when provided and retrieval UTC are preserved.
- Until 2022 manual monitoring provided daily averages; from 1 January 2023 observations use an automatic method. Because manual and automatic series are not directly comparable, this issue loads **only automatic hourly `h_now`**, never interpolates or merges historical manual daily data, and explicitly labels the measurement method.
- Station coordinates indicate measuring locations, **not** the pollen exposure precisely at the selected FPV spot. The list orders at most five geographically closest monitoring stations; it does not claim that all five are within any fixed radius.

**Attribution:** `Source: MeteoSwiss`. The app preserves source information and links to the station details page when available. MeteoSwiss open data may be reused subject to published terms: https://opendatadocs.meteoswiss.ch/general/terms-of-use

## UI and data lifecycle

`Weather & FPV suitability` → `Official MeteoSwiss pollen stations` is distinct from forecast provider/radar controls. Users intentionally discover monitoring stations and independently load the selected station's hourly observations. Nothing polls in the background and no medical recommendations, pollen forecasts, seasonal classifications or automatic exposure estimates are generated.

The existing independent OSINT SQLite database stores only:
- limited station metadata
- up to **24 most recent automatic hourly samples** for each station (seven supported types)
- per-station source asset URL, source STAC updated UTC if provided, and retrieval UTC

Cache is **not** part of personal profiles or backups. The service bounds metadata download to 120 KiB, STAC JSON to 160 KiB, CSV to 700 KiB, and handles a maximum of 500 rows before keeping 24 samples. Requests coalesce per station and impose a local limit of 20 requests/hour and a 15-second gap **per resource**. These are FPVManager safeguards, not an official MeteoSwiss quota.

A stored snapshot is considered *within the local freshness window* only if its retrieval is no more than 20 minutes old and its latest station observation no more than two hours old, without a failed refresh or clock discrepancy. **This is a local display policy, not a MeteoSwiss quality guarantee.** Retrieval time, STAC publication/update time, and observation time remain distinct. A failed refresh retains the old snapshot as *stale / cached / refresh failed*, not as a new reading. Undated publication stays undated; unknown/unsupported parameters are never assigned inferred severity categories.