# Weather, radar and observations

Open **Wetter** from navigation or the map actions. Forecast provider, forecast
time and drone criteria are independent of the map's lighting time. Unknown
readings stay unknown; a suitable forecast does not establish flight permission
or obstacle clearance.

## Forecasts and comparisons

Choose a saved place or selected coordinates, a provider and a time. Drone-specific
wind, gust, precipitation and optional visibility thresholds are stored locally.
**Refresh forecast** requests the source again even when cached values exist.

| Provider | App behavior |
|---|---|
| [MeteoSwiss local forecasts](https://opendatadocs.meteoswiss.ch/e-forecast-data/e4-local-forecast-data) | Uses the nearest published Swiss forecast point and shows its distance. National parameter files are matched locally. Wind/gusts are converted from km/h to m/s. Visibility and 80 m wind are not supplied by this adapter; comparisons cover up to three places. |
| [Open-Meteo](https://open-meteo.com/en/docs) | Sends the selected coordinates for model forecasts. Visibility and 80 m wind are available where supplied; comparisons cover up to eight places. The response used here does not supply a forecast issue time. |

The source is never silently switched or merged. Forecasts use a 45-minute
memory cache, not a complete offline forecast archive. UTC forecast times are
shown in local time; hourly precipitation is the preceding-hour total. Known
old source runs, invalid/missing required values and failed downloads prevent a
positive threshold assessment. The app's freshness policy is separate from
meteorological validity. Optional terrain inspection describes nearby relief,
not predicted turbulence.

Open-Meteo's [free API terms](https://open-meteo.com/en/terms) restrict free-service
access to non-commercial use; the data licence and the API access conditions are
separate. The project's Apache-2.0 code licence does not extend those terms.
Source attribution remains available through the map's **Quellen** control.

## Forecast map and 3D wind

The sampled weather map uses Open-Meteo independently of the selected point-
forecast provider. Wind, cloud, total precipitation, large-scale rain, snowfall,
snow depth and temperature have independent visibility/opacity but share one
forecast time. The 1 km / 5 km choice is display sampling, not native model
resolution. Missing cells are omitted; expired grids are hidden. These model
cells are neither measured clouds nor radar observations.

**Karte & Ansicht → Karte → 3D-Wind und Prognose** loads a separate wind field.
It is also available in flight settings and **Flugeinstellungen → Wind**.
Select the region/time, load it, then enable arrows and/or flight influence.
Nine query points supply available vectors at 10/80/120/180 m AGL; interpolation
between points/heights is approximate. Arrows follow airflow, opposite the
meteorological wind-from direction.

Angle/Acro use wind-relative drag; GPS counters wind within its airspeed limit.
No building turbulence, thermals or synthetic gusts are added. Outside, missing
or expired data suspend forces and are unavailable rather than calm. Active
current wind refreshes every 15 minutes in the foreground; forecasts refresh
explicitly. Snapshots remain in session memory and expire after at most 30 minutes
(current) or three hours (forecast). Changing sun time does not replace wind.

## Observed precipitation radar

The weather screen includes **Official MeteoSwiss precipitation radar**. Discover
published times, choose a product and show a frame; older/newer controls and
forward playback retain the actual timestamp gaps. Discovery is user-triggered
and bounded to 12 published frames.

Supported products are the RZC radar estimate in mm/h and CPC CombiPrecip
60-minute totals in mm. The renderer decodes HDF5 data and projects the selected
LV95 raster onto the globe. Source quality flags, where supplied, remain visible.
Data/decoder access can fail on Web or Android; a failure is reported and does
not turn missing pixels into dry weather. Radar is an observation, not a forecast
or a nowcast. Unsupported products are not substituted.

## Measured stations

**Messstationen** shows MeteoSwiss SwissMetNet and BAFU hydrological observations
near a point, place or route. Station identity/elevation, native units, timestamps
and available validation states remain visible. MeteoSwiss precipitation is a
ten-minute total; BAFU live values are uncorrected and are kept separate from
ten-minute means.

Licensed snapshots use the separate public-data cache; failed updates retain
dated values. Refresh follows the product cadence. A station measurement is not
interpolated into the 3D wind field and does not drive flight-simulation wind.

See [privacy and permissions](privacy_and_permissions.md) for requests and storage,
[sources](map_sources_and_attribution.md) for attribution, and
[Contributing](../CONTRIBUTING.md) for renderer checks. Unit/browser fixtures do
not replace checking provider access and gestures on a real device.
