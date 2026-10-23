import 'dart:async';

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
  });
  final SpotRepository spots;
  final DroneRepository drones;
  final GlobeController globe;
  final WeatherPreferencesRepository preferences;
  final double? initialLatitude, initialLongitude;
  final Map<WeatherProviderId, WeatherProvider>? availableProviders;

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
  final WeatherOverlayService _overlays = WeatherOverlayService();
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
          const SnackBar(
            content: Text('Weather preferences could not be saved'),
          ),
        );
      }
    }
  }

  Future<void> _load() async {
    final lat = _latitude, lon = _longitude;
    final token = ++_requestToken;
    setState(() {
      _terrain = null;
      _terrainError = null;
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
      final result = await _provider.forecast(lat, lon);
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
      );
      if (mounted) {
        setState(() => _terrain = terrain);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _terrainError = 'Terrain analysis unavailable: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _terrainLoading = false);
      }
    }
  }

  Future<void> _showOverlay() async {
    final lat = _latitude, lon = _longitude;
    if (lat == null || lon == null || !widget.globe.isReady) {
      return;
    }
    setState(() => _overlayLoading = true);
    try {
      final overlay = await _overlays.load(
        latitude: lat,
        longitude: lon,
        timeUtc: _time,
        kind: _overlayKind,
        spacingMeters: _gridSpacingMeters,
      );
      if (!mounted) {
        return;
      }
      await widget.globe.showWeatherOverlay(overlay.toGlobeCommand());
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${overlay.cells.length} independent Open-Meteo samples shown on globe.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Weather overlay unavailable: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _overlayLoading = false);
      }
    }
  }

  Future<void> _compare() async {
    if (_selectedTime == null || _spots.isEmpty) {
      return;
    }
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
      if (!mounted) {
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
    if (mounted) {
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
      appBar: AppBar(title: const Text('Weather & FPV suitability')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const Text(
                      'Weather forecasts are planning aids, not real-time flight safety or legal authorisation.',
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<WeatherProviderId>(
                      initialValue: _providerId,
                      decoration: const InputDecoration(
                        labelText: 'Active forecast provider',
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
                          label: const Text('Provider terms / data source'),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    if (_spots.isNotEmpty)
                      DropdownButtonFormField<int>(
                        initialValue: _spotId,
                        decoration: const InputDecoration(
                          labelText: 'Saved flying spot',
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
                            ? 'Selected globe location (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})'
                            : 'No saved spot selected. Select a point on the globe or save a spot.',
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
                          onPressed: _loading ? null : _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh forecast'),
                        ),
                      ),
                    if (forecast != null) ...[
                      Text(
                        forecast.source,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Location: ${forecast.locationDescription}${forecast.distanceToSourceKm == null ? '' : ' (${forecast.distanceToSourceKm!.toStringAsFixed(1)} km away)'}',
                      ),
                      Text('Resolution: ${forecast.modelResolution}'),
                      Text(
                        'Downloaded: ${forecast.retrievedUtc.toUtc().toIso8601String()} UTC',
                      ),
                      if (forecast.sourceIssuedUtc != null)
                        Text(
                          'Forecast issued: ${forecast.sourceIssuedUtc!.toIso8601String()}',
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<DateTime>(
                        initialValue: _selectedTime,
                        decoration: const InputDecoration(
                          labelText: 'Planned flight time (local)',
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
                          _comparison = [];
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
                              'Direction ${_number(reading?.directionDegrees, '°')}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Gusts ${_number(reading?.gustMs, 'm/s')}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Rain ${_number(reading?.precipitationMm, 'mm/h')}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Temp ${_number(reading?.temperatureC, '°C')}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Visibility ${_number(reading?.visibilityMeters, 'm')}',
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
                      const Text(
                        'Model wind at 10 m and 80 m is not a prediction of local rotor turbulence. Valleys, ridges, obstacles and thermals may cause major deviations.',
                      ),
                    ],
                    const Divider(height: 30),
                    Text(
                      'Local terrain exposure',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text(
                      'Optional Cesium relief check within 300 m (centre and four neighbours). Not an aerodynamic turbulence model.',
                    ),
                    TextButton.icon(
                      onPressed:
                          _terrainLoading ||
                              !widget.globe.isReady ||
                              _latitude == null
                          ? null
                          : _checkTerrain,
                      icon: const Icon(Icons.terrain),
                      label: const Text('Inspect local terrain'),
                    ),
                    if (_terrainLoading) const LinearProgressIndicator(),
                    if (_terrainError != null) Text(_terrainError!),
                    if (_terrain != null)
                      Text(
                        'Nearby relief ${_terrain!.localReliefMeters.toStringAsFixed(0)} m from ${_terrain!.samples} terrain samples. ${_terrain!.warning}',
                      ),
                    const Divider(height: 30),
                    Text(
                      'FPV suitability thresholds',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_drones.isNotEmpty)
                      DropdownButtonFormField<int>(
                        initialValue: _droneId,
                        decoration: const InputDecoration(
                          labelText: 'Drone profile (user thresholds)',
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
                          _comparison = [];
                        }),
                      )
                    else
                      const Text(
                        'No drone profiles saved; configure generic thresholds below.',
                      ),
                    const Text(
                      'These are personal limits, not manufacturer-approved wind tolerances.',
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
                      title: const Text('Require visibility forecast'),
                      subtitle: const Text(
                        'MeteoSwiss E4 does not provide this parameter.',
                      ),
                      value: _criteria.minimumVisibilityMeters != null,
                      onChanged: (v) {
                        setState(() {
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
                    const Text(
                      'Airspace status: NOT CHECKED by this weather assessment. Consult current UAS zones, DABS and NOTAM separately.',
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          showAirspaceSafetyPanel(context, widget.globe),
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('Official airspace verification'),
                    ),
                    const Divider(height: 30),
                    Text(
                      'Weather map (Open-Meteo sample grid)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      '49 sampled model points around the selected spot. Display spacing does NOT indicate actual meteorological model accuracy; no spatial interpolation. This is NOT a MeteoSwiss layer, even if MeteoSwiss is selected above.',
                    ),
                    SegmentedButton<double>(
                      segments: const [
                        ButtonSegment(value: 1000.0, label: Text('1 km local')),
                        ButtonSegment(
                          value: 5000.0,
                          label: Text('5 km regional'),
                        ),
                      ],
                      selected: {_gridSpacingMeters},
                      onSelectionChanged: (s) =>
                          setState(() => _gridSpacingMeters = s.first),
                    ),
                    SegmentedButton<WeatherOverlayKind>(
                      segments: const [
                        ButtonSegment(
                          value: WeatherOverlayKind.wind,
                          label: Text('Wind'),
                        ),
                        ButtonSegment(
                          value: WeatherOverlayKind.precipitation,
                          label: Text('Precipitation'),
                        ),
                      ],
                      selected: {_overlayKind},
                      onSelectionChanged: (s) =>
                          setState(() => _overlayKind = s.first),
                    ),
                    const Text(
                      'Wind legend (m/s): green <3, yellow 3–7, orange 7–12, red ≥12.',
                    ),
                    const Text(
                      'Precipitation legend (mm/h): cyan <0.2, blue 0.2–1, violet 1–3, purple ≥3.',
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
                          label: const Text('Show on globe'),
                        ),
                        OutlinedButton(
                          onPressed: widget.globe.weatherOverlayVisible
                              ? () async {
                                  await widget.globe.clearWeatherOverlay();
                                  if (mounted) {
                                    setState(() {});
                                  }
                                }
                              : null,
                          child: const Text('Clear overlay'),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    Text(
                      'Compare saved spots',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'All comparison results use the selected provider and identical flight time and criteria; missing data never yields a positive result.',
                    ),
                    if (_providerId == WeatherProviderId.meteoSwiss)
                      const Text(
                        'Official MeteoSwiss files are large; comparison is limited to 3 spots per request to reduce traffic.',
                      ),
                    FilledButton.tonal(
                      onPressed:
                          _comparisonLoading ||
                              _selectedTime == null ||
                              _spots.isEmpty
                          ? null
                          : _compare,
                      child: const Text('Evaluate saved spots'),
                    ),
                    if (_comparisonLoading) const LinearProgressIndicator(),
                    if (_comparisonError != null) Text(_comparisonError!),
                    for (final item in _comparison)
                      ListTile(
                        title: Text(item.spot.name),
                        subtitle: Text(
                          item.error ??
                              '''${_assessment(item.result!.assessment)}\n${item.result!.factors.map((f) => '${f.label}: ${_number(f.value, f.unit)} (limit ${_number(f.limit, f.unit)})').join(' · ')}\n${item.result!.explanation}\n${item.result!.forecast.source} · Terrain and legal airspace not assessed.''',
                        ),
                        isThreeLine: true,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
