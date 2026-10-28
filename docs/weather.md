# Weather

Open **Weather intelligence** from the map menu. Choose a saved spot, provider,
forecast time and drone. Wind, gust, precipitation and optional visibility limits
are stored locally per drone. **Refresh forecast** checks the source again even
while a cached forecast is available.

## Sources and limits

- [MeteoSwiss E4](https://opendatadocs.meteoswiss.ch/e-forecast-data/e4-local-forecast-data):
  official Swiss point forecasts. FPVManager uses the nearest published point,
  shows its distance and selects the latest complete supported hourly run from
  [STAC](https://data.geo.admin.ch/api/stac/v1/collections/ch.meteoschweiz.ogd-local-forecasting).
  Wind and gusts are converted from km/h to m/s. Visibility and 80 m wind are
  unavailable. The five national parameter files can require substantial data;
  comparisons are limited to three spots. Repeated requests for the same source
  point and run reuse a bounded memory cache.
- [Open-Meteo](https://open-meteo.com/en/docs): model forecasts, including visibility
  and 80 m wind where available. Its [free API terms](https://open-meteo.com/en/terms)
  permit non-commercial use and require attribution. The API does not supply a
  forecast issue time in the response used here. Comparisons are limited to eight spots.

Both providers require attribution. Forecasts are requested directly from the
device; selected coordinates are sent to the provider. Sources are never silently
combined. Downloads are cached in memory for 45 minutes, not retained offline.
Forecast times are stored in UTC and displayed in local time; hourly rain totals
refer to the preceding hour. Unknown values remain unknown.

The weather map always uses Open-Meteo, independently of the forecast provider.
It displays 49 sampled points for wind or precipitation, with a legend and forecast
timestamp. The 1 km / 5 km setting controls display spacing, **not native model
resolution or accuracy**. No spatial interpolation or native MeteoSwiss raster is
provided. Missing cells are omitted; cells with different forecast timestamps are
not combined. The overlay can be cleared and is restored after renderer reload.

**Map layers → Map → 3D-Wind und Prognose** adds an independent animated 3D wind
field. It is also available before flight and through **HUD settings → Wind**.
Choose current model wind or a forecast time, load the selected map point/view,
then enable arrows and/or flight influence. The free Open-Meteo API is for
non-commercial use. Current values are model output, not local live measurements.
Nine grid queries provide available 10/80/120/180 m AGL vectors; horizontal and
vertical interpolation is approximate, with the nearest height held outside
known layers. The arrows follow airflow (opposite meteorological wind-from).
Angle/Acro use air-relative drag; GPS counters wind within its airspeed limit.
No synthetic gusts, thermals or building turbulence are added. Missing/outside/
expired data suspend wind forces and are shown as unavailable, not calm.
Current wind refreshes every 15 minutes while visible or used in flight, pausing
in the background. Snapshots stay in memory, expire after at most 30 minutes
(current) or 3 hours (forecast), and replay after renderer reload. Wind and sun
times are independent; changing sun time does not silently replace wind data.

Suitability explains each configured threshold. Missing or invalid required
values, downloads or known source runs older than 24 hours, and implausible future
timestamps prevent a positive assessment. The age limit is a local planning policy,
not official meteorological validity. Optional terrain inspection samples nearby
relief; it does not predict turbulence and is separate from the weather comparison.
Weather results do not establish flight permission or obstacle clearance.

## Development

Provider, normalization, cache, suitability and overlay fixtures are in
`test/features/weather/`; renderer tests include `test/js/weather_overlay.test.cjs`
and `test/js/wind_field.test.cjs`. The local `tool/serve_globe_smoke.py` server
provides `/wind-smoke` for animated arrows, wind drift and expiry on synthetic terrain.
Use the checks in [CONTRIBUTING.md](../CONTRIBUTING.md). For manual Android/Web
verification, test provider and time changes during loading, forced refresh,
missing data, offline errors, terrain inspection, wind/rain overlays and renderer
reload. Do not infer a platform pass from unit tests.
