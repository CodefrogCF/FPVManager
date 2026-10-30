import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/osint/cached_osint_provider.dart';
import '../../core/osint/osint_cache_database.dart';
import '../../core/osint/osint_dataset_store.dart';
import '../mobility/road_routing.dart';
import 'hydro_station_provider.dart';
import 'meteo_station_provider.dart';
import 'station_observation.dart';

enum StationKind { meteo, hydro }

class ObservationController extends ChangeNotifier {
  ObservationController({
    required this.cacheFactory,
    required this.send,
    MeteoStationProvider? meteoProvider,
    this.hydroFactory,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _ownsMeteo = meteoProvider == null {
    meteo =
        meteoProvider ??
        MeteoStationProvider(
          persistentCache: JsonOsintDatasetStore(
            database: cacheFactory,
            storageTerms: MeteoStationProvider.defaultSource.licenseUri!,
            maxBytes: 2 * 1024 * 1024,
          ),
        );
    meteo.addListener(_changed);
  }
  final OsintCacheDatabase Function() cacheFactory;
  final Future<void> Function(Map<String, dynamic>) send;
  final HydroStationProvider Function(List<MobilityPoint>)? hydroFactory;
  final DateTime Function() _now;
  final bool _ownsMeteo;
  late final MeteoStationProvider meteo;
  HydroStationProvider? hydro;
  List<MobilityPoint> path = [];
  final visible = <StationKind>{};
  final Map<StationKind, String> renderErrors = {};
  final _retired = <Future<void>>[];
  Timer? _clock;
  bool _disposed = false;
  String? _pathKey;
  int _revision = 0;

  CachedOsintProvider<Map<String, dynamic>>? provider(StationKind kind) =>
      kind == StationKind.meteo ? meteo : hydro;
  List<ObservationStation> stations(StationKind kind) {
    final data = provider(kind)?.status.dataset?.data;
    return data == null || path.isEmpty
        ? []
        : nearbyStations(readStations(data), path);
  }

  Duration maxAge(StationKind kind) => kind == StationKind.meteo
      ? const Duration(minutes: 30)
      : const Duration(minutes: 60);
  Future<void> setContext(List<MobilityPoint> points) async {
    if (points.isEmpty || points.length > 20000) {
      throw const FormatException(
        'Messstationen benötigen einen Kartenpunkt oder eine begrenzte Route',
      );
    }
    final key = points.map((p) => '${p.latitude},${p.longitude}').join(';');
    if (key == _pathKey) return;
    _pathKey = key;
    path = List.unmodifiable(points);
    _revision++;
    final previous = hydro;
    previous?.removeListener(_changed);
    if (previous != null) {
      previous.dispose();
      final pending = previous.settled;
      _retired.add(pending);
      unawaited(pending.then((_) => _retired.remove(pending)));
    }
    hydro =
        hydroFactory?.call(path) ??
        HydroStationProvider(
          path: path,
          persistentCache: JsonOsintDatasetStore(
            database: cacheFactory,
            storageTerms: HydroStationProvider.termsUri,
            maxBytes: 2 * 1024 * 1024,
          ),
        );
    hydro!.addListener(_changed);
    await meteo.loadCached();
    await hydro!.loadCached();
    for (final kind in visible.toList()) {
      await _push(kind);
    }
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> setVisible(StationKind kind, bool enabled) async {
    if (enabled) {
      visible.add(kind);
      await provider(kind)?.loadCached();
    } else {
      visible.remove(kind);
    }
    await _push(kind);
    if (visible.isEmpty) {
      _clock?.cancel();
      _clock = null;
    } else {
      _clock ??= Timer.periodic(const Duration(minutes: 1), (_) {
        for (final k in visible.toList()) {
          unawaited(_push(k));
        }
        _changed();
      });
    }
    _changed();
  }

  Future<void> refresh(StationKind kind) async {
    final p = provider(kind);
    if (p == null) throw StateError('Bitte zuerst einen Kartenpunkt wählen');
    try {
      await p.fetch(forceRefresh: true);
    } finally {
      if (!_disposed) {
        await _push(kind);
        _changed();
      }
    }
  }

  Future<void> _push(StationKind kind) async {
    if (_disposed) return;
    final revision = _revision;
    final p = provider(kind), entries = stations(kind);
    final command = <String, dynamic>{
      'id': kind == StationKind.meteo ? 'meteo-stations' : 'hydro-stations',
      'visible': visible.contains(kind),
      if (visible.contains(kind))
        ...stationFeatures(
          entries,
          now: _now().toUtc(),
          maxAge: maxAge(kind),
          attribution: p?.source.attribution ?? 'Quelle unbekannt',
        ),
    };
    try {
      await send(command);
      if (revision == _revision) renderErrors.remove(kind);
    } catch (_) {
      if (revision == _revision) {
        renderErrors[kind] =
            'Messstationen konnten nicht auf der Karte dargestellt werden.';
      }
    }
  }

  Future<void> restoreRenderer() async {
    for (final kind in visible.toList()) {
      await _push(kind);
    }
  }

  Future<void> get settled => Future.wait([
    meteo.settled,
    if (hydro != null) hydro!.settled,
    ..._retired,
  ]);
  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _clock?.cancel();
    meteo.removeListener(_changed);
    if (_ownsMeteo) meteo.dispose();
    hydro?.removeListener(_changed);
    hydro?.dispose();
    super.dispose();
  }
}
