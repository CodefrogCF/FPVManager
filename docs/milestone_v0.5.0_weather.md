# v0.5.0 – Weather Intelligence & Spot Recommendations

Implementation status: **feature implementation / pre-release verification**. Do not close the milestone before Flutter integration tests, live API checks and Android/Web map smoke tests pass.

## Sources and legal use (checked 2026-10-23)

1. **Official MeteoSwiss E4 local forecasts** (Switzerland; CC BY; attribution required):
   https://opendatadocs.meteoswiss.ch/e-forecast-data/e4-local-forecast-data
   Collection: `ch.meteoschweiz.ogd-local-forecasting` through the official `data.geo.admin.ch` STAC interface.
   - Free, no API key. ~6,000 Swiss point forecasts, hourly values for up to approximately nine calendar days.
   - Metadata: `ogd-local-forecasting_meta_point.csv`, points identified by **(point_type_id, point_id)**, with WGS84 coordinates.
   - Official E4 parameters: `fu3010h0` wind **km/h**, `fu3010h1` gust **km/h**, `dkl010h0` direction **degrees**, `rre150h0` hourly precipitation **mm**, `tre200h0` temperature **°C**. Wind and gust convert to **m/s** by dividing by 3.6.
   - The point is the nearest published forecast point, **not** the drone's GPS location. Distance and point name are shown. These are forecasts, not current observations.
   - Important: one file **per parameter per run** contains all Swiss points and may be up to **33 MB**. Requests use stream filtering and a 36 MB size ceiling. Five requested parameters can still transfer considerable data, particularly in repeated comparisons. Limit requests accordingly. No source model is inferred beyond E4's mix of inputs.
   - No automatic 80-metre wind or visibility values are assigned: E4 does not provide these variables.
   - Timestamps are `YYYYMMDDHHmm` **UTC**. Hourly quantities often refer to the **preceding hour** ending at that time. The UI presents local time with no pseudo-interpolation.
   - MeteoSwiss's native ICON-CH1/CH2 ensemble archives are GRIB2; this client does **not** load GRIB2 in Cesium or pretend E4 is a gridded raster product.

2. **Open-Meteo free forecast API**, https://open-meteo.com/en/docs / https://open-meteo.com/en/terms
   - No API key; free tier is **non-commercial only**, subject to published rate limits. Open-Meteo and underlying model data require attribution (CC BY 4.0). Paid customer-api keys **are not requested or supported** under FPVManager's free-key-only rule.
   - Hourly requests explicitly request wind m/s, precipitation mm, temperature Celsius and GMT timestamps; extra model variables 80-metre winds and visibility may be absent/null for some model selections.
   - **Never merge missing values from another provider.** Unknown values remain missing. Model source/point resolution depends on Open-Meteo's selected underlying model.

Neither service is a certified aviation meteorological briefing and both carry uncertainty. Requests go directly from the user device to the provider with coordinates selected in the app. No FPVManager account, analytics, telemetry or backend is required.

## Implementation architecture

| Issue | Files / behavior | Limitations |
|---|---|---|
| #20 MeteoSwiss provider | `weather_models.dart`, `weather_providers.dart`: E4 metadata selection, STAC discovery, streaming CSV point filtering, SI-normalised hourly forecast, errors and in-memory coalescing cache | Live source schema and network still require integration verification; large bandwidth; missing parameters not substituted |
| #21 Configurable sources | `WeatherScreen` provider dropdown; MeteoSwiss and Open-Meteo; `weather_preferences.dart` persisted in existing Drift `appSettings` table, per-drone threshold settings | Source choice persists locally; no provider key fields because both use free unauthenticated APIs |
| #22 FPV-specific analysis | Time selector, wind direction/speed/gusts/precipitation/temperature/visibility/80m winds where available, optional five-point Cesium relief sampling | Turbulence not forecast from terrain. 80m wind represents model-level estimates only, not wind along flight path |
| #23 Weather map | `weather_overlay_service.dart` 7×7 local grid around spot (user-selectable 1-km or 5-km sample spacing); `web/weather_overlay.js` terrain-clamped sampled **weather polygons**, legend and timestamp on globe; selectable time + wind/rain, separate Cesium datasource | 1-km or 5-km weather **display sample cells**, not a native high-resolution meteorological grid/tile product. No spatial interpolation, and only Open-Meteo overlays in this phase. Full spatial high-resolution acceptance needs native grid/raster support |
| #24 Explainable suitability | `fpv_suitability.dart`, `weather_screen.dart`: user thresholds per selected drone; per-factor values; compare saved spots; missing/stale required data blocks favorable result; separate link to official airspace panel | Weather suitability is NEVER legal authorisation. Comparison caps at 8 spots (Open-Meteo) / 3 (MeteoSwiss) to limit requests; terrain scan is optional and independent |

### Safety invariants

- Weather may be "within configured forecast limits", **never** "safe to fly" or "flight permitted".
- A missing wind/gust/precipitation value, stale download, time outside available forecast, or missing required visibility gives `insufficient`, **not** favorable.
- Drone speed capability is **not** automatically converted to wind tolerance. Thresholds are chosen by the pilot and saved locally per drone.
- Terrain exposure is an optional local relief estimate from Cesium with five terrain samples, **not** a turbulence prediction or site safety guarantee.
- Weather overlays are **not** Swiss UAS zones; they have an independent datasource and always label Open-Meteo as the source even when MeteoSwiss is selected for the forecast panel.
- On renderer reload, the last overlay command is re-sent; it does **not** automatically trigger additional external weather downloads.
- No commercial or unverified API key input is presented.

## Acceptance tests

Run from the repository root after restoring a working Flutter SDK:

```sh
flutter pub get --enforce-lockfile
# The new Dart files have not been run through dart format in this environment:
dart format lib/features/weather lib/main.dart lib/features/globe/globe_controller.dart test/features/weather
flutter analyze
flutter test
node --test test/js/*.test.cjs
python3 -m unittest discover -s test/tool -p 'test_*.py'
flutter build web --release --no-web-resources-cdn
flutter build apk --debug
```

Manual scenarios on **Android and Web**:

1. On a saved Swiss spot, fetch Open-Meteo and compare two future hours and weather parameters, inspecting UTC/local time and data source.
2. Switch to MeteoSwiss; verify nearest published forecast point, location/distance, date, normalised m/s, large-download warning, missing visibility and 80-metre wind. Verify a missing/changed STAC schema produces an error, not invented values.
3. Go offline: ensure a failed uncached fetch reports an error and does not turn into a good assessment. Repeat for HTTP 429 and malformed response.
4. Select a stored drone and adjust its wind/gust/rain thresholds, reopen weather view and verify saved values. Compare several saved spots with same source and time.
5. Test missing precipitation/gust and a required visibility parameter: no positive assessment. Check legal/UAS status remains separate.
6. Run optional terrain sampling with and without detailed Cesium terrain: errors explicit, no synthetic turbulence data.
7. Create wind and rain overlays at two separate forecast hours. Verify globe labels/legend/source/time, camera zoom, terrain rendering, clear action and reload persistence. Validate rectangles do not claim 1-km source resolution.
8. Measure network traffic on Android: MeteoSwiss E4 can be expensive. Consider selective local disk cache of CSVs or streaming batch for multi-spot comparison before a broad rollout.
9. Test source attribution / privacy: only selected coordinates sent to source APIs; no third-party code or API credentials embedded.

## Remaining for full milestone completion

- Flutter SDK isn't installed in the analysis container, so **Dart formatting, `flutter analyze`, Flutter widget/unit tests and Android/Web builds were not performed**; ensure CI succeeds before merging.
- Live HTTP access from this container is disabled; STAC response fields and Open-Meteo multi-location requests must be tested against current live endpoints.
- **#23 native high-resolution spatial weather layers** are not yet fulfilled by the 7×7 sample-cell visualization (even when sampled every 1 km). Consider MeteoSwiss GRIB2/raster tile service, or a supported appropriately licensed WMS/WMTS with true native-grid timestamp and legend metadata.
- Meteorological relief/turbulence assessment is a *warning and sample-based uncertainty check*, not predictive mountain wind modelling. Operational aviation briefing is outside this milestone.
