import 'dart:async';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/drone_repository.dart';
import '../airspace/airspace_safety_panel.dart';
import '../globe/globe_controller.dart';
import '../spots/data/spot_repository.dart';
import 'fpv_suitability.dart';
import 'weather_models.dart';
import 'weather_overlay_service.dart';
import 'weather_preferences.dart';
import 'weather_providers.dart';
import 'spot_terrain_exposure.dart';
import 'radar/meteo_radar_section.dart';
import 'pollen/pollen_section.dart';
import '../observations/observations_screen.dart';
import '../mobility/road_routing.dart' show MobilityPoint;

/// The UI never represents a favorable weather forecast as legal clearance.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({
    super.key,
    required this.spots,
    required this.drones,
    required this.globe,
    required this.preferences,
    this.initialLatitude,
    this.initialLongitude,
    this.availableProviders,
    this.overlayService,
  });
  final SpotRepository spots;
  final DroneRepository drones;
  final GlobeController globe;
  final WeatherPreferencesRepository preferences;
  final double? initialLatitude, initialLongitude;
  final Map<WeatherProviderId, WeatherProvider>? availableProviders;
  final WeatherOverlayService? overlayService;

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late final Map<WeatherProviderId, WeatherProvider> _providers =
      widget.availableProviders ??
      {
        WeatherProviderId.meteoSwiss: CachedWeatherProvider(
          MeteoSwissWeatherProvider(),
        ),
        WeatherProviderId.openMeteo: CachedWeatherProvider(
          OpenMeteoWeatherProvider(),
        ),
      };
  late final WeatherOverlayService _overlays =
      widget.overlayService ?? WeatherOverlayService();
  List<Spot> _spots = [];
  List<Drone> _drones = [];
  int? _spotId, _droneId;
  WeatherProviderId _providerId = WeatherProviderId.openMeteo;
  Map<int, FpvWeatherCriteria> _criteriaByDrone = {};
  WeatherForecast? _forecast;
  DateTime? _selectedTime;
  WeatherOverlayKind _overlayKind = WeatherOverlayKind.wind;
  double _gridSpacingMeters = 1000;
  bool _loading = false,
      _initializing = true,
      _comparisonLoading = false,
      _overlayLoading = false;
  String? _error, _comparisonError;
  List<({Spot spot, FpvWeatherResult? result, String? error})> _comparison = [];
  int _requestToken = 0;
  int _terrainOperation = 0, _comparisonOperation = 0, _overlayOperation = 0;
  SpotTerrainExposure? _terrain;
  bool _terrainLoading = false;
  String? _terrainError;
  FpvWeatherCriteria get _criteria =>
      _criteriaByDrone[_droneId ?? 0] ?? const FpvWeatherCriteria();
  WeatherProvider get _provider => _providers[_providerId]!;
  Spot? get _spot {
    for (final spot in _spots) {
      if (spot.id == _spotId) {
        return spot;
      }
    }
    return null;
  }

  double? get _latitude => _spot?.latitude ?? widget.initialLatitude;
  double? get _longitude => _spot?.longitude ?? widget.initialLongitude;
  DateTime get _time =>
      _selectedTime ?? DateTime.now().toUtc().add(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final saved = await widget.preferences.load();
      final spots = await widget.spots.getAllSpots();
      final drones = await widget.drones.getAllDrones();
      if (!mounted) {
        return;
      }
      setState(() {
        _providerId = _providers.containsKey(saved.provider)
            ? saved.provider
            : _providers.keys.first;
        _criteriaByDrone = {...saved.criteriaByDrone};
        _spots = spots;
        _drones = drones;
        _spotId = spots.isNotEmpty ? spots.first.id : null;
        _droneId = drones.isNotEmpty ? drones.first.id : null;
        _initializing = false;
      });
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _save() async {
    try {
      await widget.preferences.save(
        WeatherPreferences(
          provider: _providerId,
          criteriaByDrone: _criteriaByDrone,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                "Weather preferences could not be saved",
                (l10n) => l10n.weatherWeatherPreferencesCouldNot1aa91b1b,
              ),
            ),
          ),
        );
      }
    }
  }

  void _invalidateComparison() {
    _comparisonOperation++;
    _comparison = [];
    _comparisonError = null;
    _comparisonLoading = false;
  }

  void _invalidateOverlay() {
    _overlayOperation++;
    _overlayLoading = false;
    _overlays.cancel();
    unawaited(widget.globe.clearWeatherOverlay().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _requestToken++;
    _terrainOperation++;
    _comparisonOperation++;
    _overlayOperation++;
    if (widget.availableProviders == null) {
      for (final provider in _providers.values) {
        provider.dispose();
      }
    }
    if (widget.overlayService == null) {
      _overlays.dispose();
    } else {
      _overlays.cancel();
    }
    super.dispose();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final lat = _latitude, lon = _longitude;
    final token = ++_requestToken;
    setState(() {
      _terrainOperation++;
      _terrainLoading = false;
      _terrain = null;
      _terrainError = null;
      _invalidateComparison();
      _invalidateOverlay();
      _selectedTime = null;
      _loading = lat != null && lon != null;
      _forecast = null;
      _error = lat == null || lon == null
          ? 'Select a saved spot or choose a position on the globe first.'
          : null;
      _comparison = [];
    });
    if (lat == null || lon == null) {
      return;
    }
    try {
      final result = await _provider.forecast(
        lat,
        lon,
        forceRefresh: forceRefresh,
      );
      if (!mounted || token != _requestToken) {
        return;
      }
      final valid = result.samples
          .where((s) => s.timeUtc.isAfter(DateTime.now().toUtc()))
          .toList();
      setState(() {
        _forecast = result;
        _selectedTime = valid.isEmpty ? null : valid.first.timeUtc;
        _loading = false;
      });
    } catch (error) {
      if (mounted && token == _requestToken) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _checkTerrain() async {
    final latitude = _latitude, longitude = _longitude;
    if (latitude == null || longitude == null) {
      return;
    }
    final operation = ++_terrainOperation;
    bool current() => mounted && operation == _terrainOperation;
    setState(() {
      _terrainLoading = true;
      _terrain = null;
      _terrainError = null;
    });
    try {
      final terrain = await inspectSpotTerrain(
        widget.globe,
        latitude,
        longitude,
        isCancelled: () => !current(),
      );
      if (current()) {
        setState(() => _terrain = terrain);
      }
    } catch (error) {
      if (current()) {
        setState(() => _terrainError = 'Terrain analysis unavailable: $error');
      }
    } finally {
      if (current()) {
        setState(() => _terrainLoading = false);
      }
    }
  }

  Future<void> _showOverlay() async {
    final lat = _latitude, lon = _longitude;
    if (lat == null || lon == null || !widget.globe.isReady) {
      return;
    }
    final operation = ++_overlayOperation;
    bool current() => mounted && operation == _overlayOperation;
    setState(() => _overlayLoading = true);
    try {
      final overlay = await _overlays.load(
        latitude: lat,
        longitude: lon,
        timeUtc: _time,
        kind: _overlayKind,
        spacingMeters: _gridSpacingMeters,
      );
      if (!current()) {
        return;
      }
      await widget.globe.showWeatherOverlay(overlay.toGlobeCommand());
      if (!mounted || !current()) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.localizedWithArgs(
              "{0} independent Open-Meteo samples shown on globe.",
              [overlay.cells.length],
              (l10n, value) =>
                  l10n.weatherIndependentOpenMeteoSamples4c5f32a2(value(0)),
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted && current()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localizedWithArgs(
                "Weather overlay unavailable: {0}",
                [error],
                (l10n, value) =>
                    l10n.weatherWeatherOverlayUnavailablef9e466e1(value(0)),
              ),
            ),
          ),
        );
      }
    } finally {
      if (current()) {
        setState(() => _overlayLoading = false);
      }
    }
  }

  Future<void> _compare() async {
    if (_selectedTime == null || _spots.isEmpty) {
      return;
    }
    final operation = ++_comparisonOperation;
    bool current() => mounted && operation == _comparisonOperation;
    setState(() {
      _comparisonLoading = true;
      _comparison = [];
      _comparisonError = null;
    });
    final source = _provider;
    final criteria = _criteria;
    final target = _time;
    final selectedSpots = _spots
        .take(source.id == WeatherProviderId.meteoSwiss ? 3 : 8)
        .toList();
    final results = <({Spot spot, FpvWeatherResult? result, String? error})>[];
    // Sequential requests avoid hammering public weather services.
    for (final spot in selectedSpots) {
      if (!current()) return;
      try {
        final forecast = await source.forecast(spot.latitude, spot.longitude);
        results.add((
          spot: spot,
          result: evaluateFpvWeather(forecast, target, criteria),
          error: null,
        ));
      } catch (error) {
        results.add((spot: spot, result: null, error: '$error'));
      }
      if (!current()) {
        return;
      }
    }
    int priority(FpvWeatherResult? result) => switch (result?.assessment) {
      FpvWeatherAssessment.favorableForecast => 0,
      FpvWeatherAssessment.caution => 1,
      FpvWeatherAssessment.unsuitable => 2,
      _ => 3,
    };
    results.sort((a, b) => priority(a.result).compareTo(priority(b.result)));
    if (current()) {
      setState(() {
        _comparison = results;
        _comparisonLoading = false;
      });
    }
  }

  String _date(DateTime value) =>
      '${value.toLocal().day.toString().padLeft(2, '0')}.'
      '${value.toLocal().month.toString().padLeft(2, '0')} '
      '${value.toLocal().hour.toString().padLeft(2, '0')}:'
      '${value.toLocal().minute.toString().padLeft(2, '0')}';
  String _number(double? value, String suffix) =>
      value == null ? 'Not available' : '${value.toStringAsFixed(1)} $suffix';
  String _assessment(FpvWeatherAssessment value) => switch (value) {
    FpvWeatherAssessment.favorableForecast =>
      'Within configured weather limits (NOT a clearance)',
    FpvWeatherAssessment.caution => 'Uncertain',
    FpvWeatherAssessment.unsuitable => 'Weather thresholds exceeded',
    FpvWeatherAssessment.insufficient => 'Insufficient weather data',
  };

  Widget _limit(
    String label,
    double value,
    double min,
    double max,
    String unit,
    void Function(double) changed, {
    int divisions = 40,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label: ${value.toStringAsFixed(1)} $unit'),
      Slider(
        value: value.clamp(min, max).toDouble(),
        min: min,
        max: max,
        divisions: divisions,
        label: value.toStringAsFixed(1),
        onChanged: (v) {
          setState(_invalidateComparison);
          changed(v);
        },
        onChangeEnd: (_) => unawaited(_save()),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final forecast = _forecast;
    final reading = forecast?.at(_time);
    final result = forecast == null || _selectedTime == null
        ? null
        : evaluateFpvWeather(forecast, _time, _criteria);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.localized(
            "Weather & FPV suitability",
            (l10n) => l10n.weatherWeatherFpvSuitabilitye893355f,
          ),
        ),
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Text(
                      context.localized(
                        "Weather forecasts are planning aids, not real-time flight safety or legal authorisation.",
                        (l10n) =>
                            l10n.commonWeatherForecastsArePlanning5820a8ab,
                      ),
                    ),
                    const SizedBox(height: 18),
                    MeteoRadarSection(globe: widget.globe),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<WeatherProviderId>(
                      initialValue: _providerId,
                      decoration: InputDecoration(
                        labelText: context.localized(
                          "Active forecast provider",
                          (l10n) => l10n.weatherActiveForecastProvider589a3851,
                        ),
                      ),
                      items: _providers.values
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.title),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _providerId = value);
                        unawaited(_save());
                        unawaited(_load());
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(_provider.capabilities.description),
                    Wrap(
                      spacing: 8,
                      children: [
                        ..._provider.capabilities.variables.map(
                          (v) => Chip(label: Text(v.name)),
                        ),
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(_provider.termsUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(
                            context.localized(
                              "Provider terms / data source",
                              (l10n) =>
                                  l10n.weatherProviderTermsDataSource3870b023,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    if (_spots.isNotEmpty)
                      DropdownButtonFormField<int>(
                        initialValue: _spotId,
                        decoration: InputDecoration(
                          labelText: context.localized(
                            "Saved flying spot",
                            (l10n) => l10n.weatherSavedFlyingSpotedf5fa9d,
                          ),
                        ),
                        items: _spots
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          setState(() => _spotId = id);
                          unawaited(_load());
                        },
                      )
                    else
                      Text(
                        _latitude != null
                            ? context.localizedWithArgs(
                                "Selected globe location ({0}, {1})",
                                [
                                  _latitude!.toStringAsFixed(4),
                                  _longitude!.toStringAsFixed(4),
                                ],
                                (l10n, value) =>
                                    l10n.commonSelectedGlobeLocation8a849707(
                                      value(0),
                                      value(1),
                                    ),
                              )
                            : context.localized(
                                "No saved spot selected. Select a point on the globe or save a spot.",
                                (l10n) =>
                                    l10n.weatherNoSavedSpotSelected8861bd5c,
                              ),
                      ),
                    const SizedBox(height: 12),
                    if (_loading) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_latitude != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _loading
                              ? null
                              : () => _load(forceRefresh: true),
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            context.localized(
                              "Refresh forecast",
                              (l10n) => l10n.weatherRefreshForecastfe3dbc62,
                            ),
                          ),
                        ),
                      ),
                    if (forecast != null) ...[
                      Text(
                        forecast.source,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        context.localizedWithArgs(
                          "Location: {0}{1}",
                          [
                            forecast.locationDescription,
                            forecast.distanceToSourceKm == null
                                ? ''
                                : ' (${forecast.distanceToSourceKm!.toStringAsFixed(1)} km away)',
                          ],
                          (l10n, value) =>
                              l10n.weatherLocation77d72845(value(0), value(1)),
                        ),
                      ),
                      Text(
                        context.localizedWithArgs(
                          "Resolution: {0}",
                          [forecast.modelResolution],
                          (l10n, value) =>
                              l10n.weatherResolutiona39d34b8(value(0)),
                        ),
                      ),
                      Text(
                        context.localizedWithArgs(
                          "Downloaded: {0} UTC",
                          [forecast.retrievedUtc.toUtc().toIso8601String()],
                          (l10n, value) =>
                              l10n.weatherDownloadedUtc177de02a(value(0)),
                        ),
                      ),
                      if (forecast.sourceIssuedUtc != null)
                        Text(
                          context.localizedWithArgs(
                            "Forecast issued: {0}",
                            [forecast.sourceIssuedUtc!.toIso8601String()],
                            (l10n, value) =>
                                l10n.weatherForecastIssued2ab834ac(value(0)),
                          ),
                        )
                      else
                        Text(
                          context.localized(
                            "Forecast issue time: not supplied by provider",
                            (l10n) => l10n.weatherForecastIssueTimeNot72c0daa9,
                          ),
                        ),
                      Text(
                        context.localized(
                          "Hourly precipitation refers to the preceding hour ending at the forecast timestamp.",
                          (l10n) =>
                              l10n.weatherHourlyPrecipitationRefersTob7611db2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<DateTime>(
                        initialValue: _selectedTime,
                        decoration: InputDecoration(
                          labelText: context.localized(
                            "Planned flight time (local)",
                            (l10n) =>
                                l10n.weatherPlannedFlightTimeLocal410bf657,
                          ),
                        ),
                        items: forecast.samples
                            .where(
                              (s) => s.timeUtc.isAfter(DateTime.now().toUtc()),
                            )
                            .toList()
                            .asMap()
                            .entries
                            .where(
                              (e) =>
                                  e.key % 3 == 0 ||
                                  e.value.timeUtc == _selectedTime,
                            )
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.value.timeUtc,
                                child: Text(_date(e.value.timeUtc)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _selectedTime = value;
                          _invalidateComparison();
                          _invalidateOverlay();
                        }),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              'Wind ${_number(reading?.windMs, 'm/s')}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              context.localizedWithArgs(
                                "Direction {0}",
                                [_number(reading?.directionDegrees, '°')],
                                (l10n, value) =>
                                    l10n.weatherDirection2373dfc9(value(0)),
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Gusts ${_number(reading?.gustMs, 'm/s')}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              context.localizedWithArgs(
                                "Niederschlag {0}",
                                [_number(reading?.precipitationMm, 'mm / 1 h')],
                                (l10n, value) =>
                                    l10n.weatherNiederschlagf18088c2(value(0)),
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Temp ${_number(reading?.temperatureC, '°C')}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              context.localizedWithArgs(
                                "Visibility {0}",
                                [_number(reading?.visibilityMeters, 'm')],
                                (l10n, value) =>
                                    l10n.weatherVisibility1b929d6e(value(0)),
                              ),
                            ),
                          ),
                          if (reading?.wind80mMs != null)
                            Chip(
                              label: Text(
                                'Wind 80 m AGL ${_number(reading?.wind80mMs, 'm/s')}',
                              ),
                            ),
                        ],
                      ),
                      Text(
                        context.localized(
                          "Model wind at 10 m and 80 m is not a prediction of local rotor turbulence. Valleys, ridges, obstacles and thermals may cause major deviations.",
                          (l10n) => l10n.commonModelWindAtM9f419984,
                        ),
                      ),
                    ],
                    const Divider(height: 30),
                    Text(
                      context.localized(
                        "Local terrain exposure",
                        (l10n) => l10n.weatherLocalTerrainExposuref78de89b,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      context.localized(
                        "Optional Cesium relief check within 300 m (centre and four neighbours). Not an aerodynamic turbulence model.",
                        (l10n) => l10n.weatherOptionalCesiumReliefCheckff9531d9,
                      ),
                    ),
                    TextButton.icon(
                      onPressed:
                          _terrainLoading ||
                              !widget.globe.isReady ||
                              _latitude == null
                          ? null
                          : _checkTerrain,
                      icon: const Icon(Icons.terrain),
                      label: Text(
                        context.localized(
                          "Inspect local terrain",
                          (l10n) => l10n.weatherInspectLocalTerrainc851b2af,
                        ),
                      ),
                    ),
                    if (_terrainLoading) const LinearProgressIndicator(),
                    if (_terrainError != null) Text(_terrainError!),
                    if (_terrain != null)
                      Text(
                        context.localizedWithArgs(
                          "Nearby relief {0} m from {1} terrain samples. {2}",
                          [
                            _terrain!.localReliefMeters.toStringAsFixed(0),
                            _terrain!.samples,
                            _terrain!.warning,
                          ],
                          (l10n, value) =>
                              l10n.weatherNearbyReliefMFrom3afbc3bf(
                                value(0),
                                value(1),
                                value(2),
                              ),
                        ),
                      ),
                    const Divider(height: 30),
                    Text(
                      context.localized(
                        "FPV suitability thresholds",
                        (l10n) => l10n.weatherFpvSuitabilityThresholdsd468f61f,
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_drones.isNotEmpty)
                      DropdownButtonFormField<int>(
                        initialValue: _droneId,
                        decoration: InputDecoration(
                          labelText: context.localized(
                            "Drone profile (user thresholds)",
                            (l10n) =>
                                l10n.weatherDroneProfileUserThresholdsf3e5ce7b,
                          ),
                        ),
                        items: _drones
                            .map(
                              (d) => DropdownMenuItem(
                                value: d.id,
                                child: Text(d.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _droneId = value;
                          _invalidateComparison();
                        }),
                      )
                    else
                      Text(
                        context.localized(
                          "No drone profiles saved; configure generic thresholds below.",
                          (l10n) => l10n.weatherNoDroneProfilesSaved1b2919fa,
                        ),
                      ),
                    Text(
                      context.localized(
                        "These are personal limits, not manufacturer-approved wind tolerances.",
                        (l10n) => l10n.commonTheseArePersonalLimits77b30a8a,
                      ),
                    ),
                    _limit(
                      'Maximum mean wind',
                      _criteria.maximumWindMs,
                      1,
                      25,
                      'm/s',
                      (v) => setState(() {
                        _criteriaByDrone[_droneId ?? 0] = FpvWeatherCriteria(
                          maximumWindMs: v,
                          maximumGustMs: _criteria.maximumGustMs,
                          maximumPrecipitationMm:
                              _criteria.maximumPrecipitationMm,
                          minimumVisibilityMeters:
                              _criteria.minimumVisibilityMeters,
                        );
                      }),
                    ),
                    _limit(
                      'Maximum gust',
                      _criteria.maximumGustMs,
                      1,
                      35,
                      'm/s',
                      (v) => setState(() {
                        _criteriaByDrone[_droneId ?? 0] = FpvWeatherCriteria(
                          maximumWindMs: _criteria.maximumWindMs,
                          maximumGustMs: v,
                          maximumPrecipitationMm:
                              _criteria.maximumPrecipitationMm,
                          minimumVisibilityMeters:
                              _criteria.minimumVisibilityMeters,
                        );
                      }),
                    ),
                    _limit(
                      'Maximum hourly precipitation',
                      _criteria.maximumPrecipitationMm,
                      0,
                      5,
                      'mm',
                      (v) => setState(() {
                        _criteriaByDrone[_droneId ?? 0] = FpvWeatherCriteria(
                          maximumWindMs: _criteria.maximumWindMs,
                          maximumGustMs: _criteria.maximumGustMs,
                          maximumPrecipitationMm: v,
                          minimumVisibilityMeters:
                              _criteria.minimumVisibilityMeters,
                        );
                      }),
                    ),
                    SwitchListTile.adaptive(
                      title: Text(
                        context.localized(
                          "Require visibility forecast",
                          (l10n) =>
                              l10n.weatherRequireVisibilityForecastc232c2a0,
                        ),
                      ),
                      subtitle: Text(
                        context.localized(
                          "MeteoSwiss E4 does not provide this parameter.",
                          (l10n) => l10n.weatherMeteoswissEDoesNota574859d,
                        ),
                      ),
                      value: _criteria.minimumVisibilityMeters != null,
                      onChanged: (v) {
                        setState(() {
                          _invalidateComparison();
                          _criteriaByDrone[_droneId ?? 0] = FpvWeatherCriteria(
                            maximumWindMs: _criteria.maximumWindMs,
                            maximumGustMs: _criteria.maximumGustMs,
                            maximumPrecipitationMm:
                                _criteria.maximumPrecipitationMm,
                            minimumVisibilityMeters: v ? 1000 : null,
                          );
                        });
                        unawaited(_save());
                      },
                    ),
                    if (_criteria.minimumVisibilityMeters != null)
                      _limit(
                        'Minimum visibility',
                        _criteria.minimumVisibilityMeters!,
                        500,
                        10000,
                        'm',
                        (v) => setState(() {
                          _criteriaByDrone[_droneId ?? 0] = FpvWeatherCriteria(
                            maximumWindMs: _criteria.maximumWindMs,
                            maximumGustMs: _criteria.maximumGustMs,
                            maximumPrecipitationMm:
                                _criteria.maximumPrecipitationMm,
                            minimumVisibilityMeters: v,
                          );
                        }),
                        divisions: 38,
                      ),
                    if (result != null) ...[
                      Text(
                        _assessment(result.assessment),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(result.explanation),
                      ...result.factors.map(
                        (f) => ListTile(
                          dense: true,
                          title: Text(f.label),
                          subtitle: Text(
                            '${_number(f.value, f.unit)} / limit ${_number(f.limit, f.unit)}',
                          ),
                          trailing: Icon(
                            f.passes == true
                                ? Icons.check
                                : f.passes == false
                                ? Icons.close
                                : Icons.help_outline,
                            color: f.passes == true
                                ? Colors.green
                                : f.passes == false
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      context.localized(
                        "Airspace status: NOT CHECKED by this weather assessment. Consult current UAS zones, DABS and NOTAM separately.",
                        (l10n) => l10n.commonAirspaceStatusNotCheckedfcc694aa,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          showAirspaceSafetyPanel(context, widget.globe),
                      icon: const Icon(Icons.shield_outlined),
                      label: Text(
                        context.localized(
                          "Official airspace verification",
                          (l10n) =>
                              l10n.weatherOfficialAirspaceVerification1376fb67,
                        ),
                      ),
                    ),
                    const Divider(height: 30),
                    Text(
                      context.localized(
                        "Weather map (Open-Meteo sample grid)",
                        (l10n) => l10n.weatherWeatherMapOpenMeteodb0c967f,
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton.icon(
                      onPressed: () => _openStationObservations(),
                      icon: const Icon(Icons.sensors_outlined),
                      label: Text(
                        context.localized(
                          "Gemessene Wetter- und Gewässerstationen",
                          (l10n) => l10n
                              .weatherGemesseneWetterUndGewaesserstationen70b38f8d,
                        ),
                      ),
                    ),
                    Text(
                      context.localized(
                        "49 sampled model points around the selected spot. Display spacing does NOT indicate actual meteorological model accuracy; no spatial interpolation. This is NOT a MeteoSwiss layer, even if MeteoSwiss is selected above.",
                        (l10n) => l10n.commonSampledModelPointsArounda07ce918,
                      ),
                    ),
                    Text(
                      context.localized(
                        "Native model resolution: not supplied by this API response. The selected spacing only sets the display sample grid.",
                        (l10n) => l10n.weatherNativeModelResolutionNot32f4a5e7,
                      ),
                    ),
                    SegmentedButton<double>(
                      segments: [
                        ButtonSegment(
                          value: 1000.0,
                          label: Text(
                            context.localized(
                              "1 km local",
                              (l10n) => l10n.weatherKmLocal5e8c161b,
                            ),
                          ),
                        ),
                        ButtonSegment(
                          value: 5000.0,
                          label: Text('5 km regional'),
                        ),
                      ],
                      selected: {_gridSpacingMeters},
                      onSelectionChanged: (s) => setState(() {
                        _gridSpacingMeters = s.first;
                        _invalidateOverlay();
                      }),
                    ),
                    DropdownButtonFormField<WeatherOverlayKind>(
                      initialValue: _overlayKind,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.localized(
                          "Zusätzliches Prognoseraster",
                          (l10n) =>
                              l10n.weatherZusaetzlichesPrognoseraster279c3ee9,
                        ),
                      ),
                      items: [
                        for (final kind in WeatherOverlayKind.values)
                          DropdownMenuItem(
                            value: kind,
                            child: Text(kind.label),
                          ),
                      ],
                      onChanged: _overlayLoading
                          ? null
                          : (kind) => setState(() => _overlayKind = kind!),
                    ),
                    Text(
                      context.localized(
                        "Wind legend (m/s): green <3, yellow 3–7, orange 7–12, red ≥12.",
                        (l10n) => l10n.commonWindLegendMS1b571bdc,
                      ),
                    ),
                    Text(
                      context.localized(
                        "Niederschlag und großräumiger Regen sind Summen der vorangegangenen Stunde (mm), Neuschnee in cm, Schneehöhe in m. Eine Regenrate oder Niederschlagsart wird daraus nicht abgeleitet.",
                        (l10n) => l10n
                            .commonNiederschlagUndGrossraeumigerRegen09d9c44f,
                      ),
                    ),
                    Text(
                      context.localized(
                        "Bewölkung: 0–100 % Modellbedeckung, keine gemessenen 3D-Wolken. Temperatur: °C in 2 m Höhe. Alle sichtbaren Raster verwenden dieselbe Prognosezeit.",
                        (l10n) => l10n
                            .commonBewoelkungModellbedeckungKeineGemessenencfb37c6a,
                      ),
                    ),
                    ListenableBuilder(
                      listenable: widget.globe,
                      builder: (context, _) => Column(
                        children: [
                          for (final entry
                              in widget.globe.weatherOverlays.entries)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '${WeatherOverlayKind.values.byName(entry.key).label} · ${entry.value['units'] ?? WeatherOverlayKind.values.byName(entry.key).unit}',
                                    ),
                                    Text(
                                      context.localizedWithArgs(
                                        "Prognose: {0}\nAbgerufen: {1} · {2} fehlende Stichproben",
                                        [
                                          entry.value['timestampUtc'],
                                          entry.value['retrievedAtUtc'] ??
                                              "nicht bereitgestellt",
                                          entry.value['missingSamples'] ?? 0,
                                        ],
                                        (l10n, value) => l10n
                                            .weatherPrognoseAbgerufenFehlendeStichproben23fbbb89(
                                              value(0),
                                              value(1),
                                              value(2),
                                            ),
                                      ),
                                    ),
                                    if (DateTime.tryParse(
                                          '${entry.value['expiresAtUtc']}',
                                        )?.isBefore(DateTime.now().toUtc()) ==
                                        true)
                                      Text(
                                        context.localized(
                                          "Raster abgelaufen · auf der Karte ausgeblendet",
                                          (l10n) => l10n
                                              .weatherRasterAbgelaufenAufDer98608088,
                                        ),
                                      ),
                                    Slider(
                                      label: 'Deckkraft',
                                      value:
                                          (entry.value['opacity'] as num? ?? .4)
                                              .toDouble(),
                                      onChanged: (opacity) => _updateOverlay(
                                        () => widget.globe.setWeatherOpacity(
                                          entry.key,
                                          opacity,
                                        ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _updateOverlay(
                                        () => widget.globe.clearWeatherOverlay(
                                          kind: entry.key,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.visibility_off_outlined,
                                      ),
                                      label: Text(
                                        context.localized(
                                          "Dieses Raster ausblenden",
                                          (l10n) => l10n
                                              .weatherDiesesRasterAusblendenc09fe0a2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              _overlayLoading ||
                                  _selectedTime == null ||
                                  !widget.globe.isReady
                              ? null
                              : _showOverlay,
                          icon: const Icon(Icons.layers),
                          label: Text(
                            context.localized(
                              "Show on globe",
                              (l10n) => l10n.weatherShowOnGlobe8ee06550,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: widget.globe.weatherOverlayVisible
                              ? () async {
                                  _invalidateOverlay();
                                  await widget.globe.clearWeatherOverlay();
                                  if (mounted) {
                                    setState(() {});
                                  }
                                }
                              : null,
                          child: Text(
                            context.localized(
                              "Clear overlay",
                              (l10n) => l10n.commonClearOverlay89f8488e,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    Text(
                      context.localized(
                        "Compare saved spots",
                        (l10n) => l10n.weatherCompareSavedSpotsc7ce5e7e,
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      context.localized(
                        "All comparison results use the selected provider and identical flight time and criteria; missing data never yields a positive result.",
                        (l10n) => l10n.weatherAllComparisonResultsUse418051c7,
                      ),
                    ),
                    if (_providerId == WeatherProviderId.meteoSwiss)
                      Text(
                        context.localized(
                          "Official MeteoSwiss files are large; comparison is limited to 3 spots per request to reduce traffic.",
                          (l10n) =>
                              l10n.weatherOfficialMeteoswissFilesAre0450722a,
                        ),
                      ),
                    FilledButton.tonal(
                      onPressed:
                          _comparisonLoading ||
                              _selectedTime == null ||
                              _spots.isEmpty
                          ? null
                          : _compare,
                      child: Text(
                        context.localized(
                          "Evaluate saved spots",
                          (l10n) => l10n.weatherEvaluateSavedSpotsbdd72b2d,
                        ),
                      ),
                    ),
                    if (_comparisonLoading) const LinearProgressIndicator(),
                    if (_comparisonError != null) Text(_comparisonError!),
                    for (final item in _comparison)
                      ListTile(
                        title: Text(item.spot.name),
                        subtitle: Text(
                          item.error ??
                              context.localizedWithArgs(
                                "{0}\n{1}\n{2}\n{3} · Terrain and legal airspace not assessed.",
                                [
                                  _assessment(item.result!.assessment),
                                  item.result!.factors
                                      .map(
                                        (f) =>
                                            '${f.label}: ${_number(f.value, f.unit)} (limit ${_number(f.limit, f.unit)})',
                                      )
                                      .join(' · '),
                                  item.result!.explanation,
                                  item.result!.forecast.source,
                                ],
                                (l10n, value) =>
                                    l10n.weatherTerrainAndLegalAirspacedb03e335(
                                      value(0),
                                      value(1),
                                      value(2),
                                      value(3),
                                    ),
                              ),
                        ),
                        isThreeLine: true,
                      ),
                    const Divider(height: 30),
                    PollenSection(latitude: _latitude, longitude: _longitude),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _updateOverlay(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                "Kartenebene konnte nicht aktualisiert werden. Bitte erneut versuchen.",
                (l10n) =>
                    l10n.weatherKartenebeneKonnteNichtAktualisiertab47fc9e,
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openStationObservations() async {
    final lat = _latitude, lon = _longitude;
    if (lat != null && lon != null) {
      await widget.globe.observations.setContext([MobilityPoint(lat, lon)]);
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ObservationsScreen(controller: widget.globe.observations),
      ),
    );
  }
}
