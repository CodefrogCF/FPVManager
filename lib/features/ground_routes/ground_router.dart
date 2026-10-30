import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../mobility/road_routing.dart';
import 'ground_route.dart';

GroundRoutePlan parseGroundRouting(
  (String, GroundTravelMode, MobilityPoint, MobilityPoint, DateTime) input,
) {
  if (input.$1.length > 4 * 1024 * 1024) {
    throw const FormatException('Routenantwort ist zu groß');
  }
  final raw = jsonDecode(input.$1);
  if (raw is! Map ||
      raw['code'] != 'Ok' ||
      raw['routes'] is! List ||
      (raw['routes'] as List).isEmpty) {
    throw const FormatException('Keine passende Bodenroute verfügbar');
  }
  final r = raw['routes'][0];
  if (r is! Map ||
      r['geometry'] is! Map ||
      r['geometry']['type'] != 'LineString' ||
      r['geometry']['coordinates'] is! List) {
    throw const FormatException('Ungültige Bodenroutengeometrie');
  }
  final coordinates = r['geometry']['coordinates'] as List;
  if (coordinates.length < 2 || coordinates.length > 20000) {
    throw const FormatException('Bodenroute überschreitet das Punktelimit');
  }
  final points = <MobilityPoint>[], elevations = <double?>[];
  for (final p in coordinates) {
    if (p is! List || p.length < 2 || p.length > 3) {
      throw const FormatException('Nicht unterstützte Routenkoordinaten');
    }
    points.add(MobilityPoint.fromJson(p.take(2).toList()));
    final z = p.length == 3 ? p[2] : null;
    if (z != null && (z is! num || !z.isFinite || z.abs() > 20000)) {
      throw const FormatException('Ungültige Quellenhöhe');
    }
    elevations.add((z as num?)?.toDouble());
  }
  for (final key in ['distance', 'duration']) {
    if (r[key] is! num || !(r[key] as num).isFinite || r[key] < 0) {
      throw const FormatException('Ungültige Routenlänge oder Dauer');
    }
  }
  final result = GroundRoutePlan(
    name: '${input.$2.label}-Route',
    mode: input.$2,
    points: points,
    origin: input.$3,
    destination: input.$4,
    source:
        'OSRM / FOSSGIS · ${input.$2.profile} · © OpenStreetMap contributors (ODbL 1.0)',
    calculatedAtUtc: input.$5.toUtc(),
    distanceMeters: (r['distance'] as num).toDouble(),
    durationSeconds: (r['duration'] as num).toDouble(),
    elevations: elevations.any((e) => e != null) ? elevations : null,
    attributes: {
      'provider': 'https://routing.openstreetmap.de/',
      'profile': input.$2.profile,
      'weightName': r['weight_name'],
      'waypoints': raw['waypoints'],
      'surface': r['surface'],
      'access': r['access'],
      'elevationReference': elevations.any((e) => e != null)
          ? 'sourceUnverified'
          : null,
    },
  );
  GroundRoutePlan.decode(result.encode());
  return result;
}

class GroundRouter {
  GroundRouter({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _now = now ?? DateTime.now;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;
  MobilityHttp? _transport;
  Future<GroundRoutePlan>? _pending;
  String? _pendingKey;
  DateTime? _lastAttempt;
  bool _disposed = false;
  Future<GroundRoutePlan> calculate(
    MobilityPoint origin,
    MobilityPoint destination,
    GroundTravelMode mode,
  ) {
    if (_disposed) return Future.error(StateError('Routenplanung geschlossen'));
    final key = '${origin.toJson()}:${destination.toJson()}:${mode.name}';
    if (_pending != null) {
      if (_pendingKey == key) return _pending!;
      return Future.error(StateError('Eine Bodenroute wird bereits berechnet'));
    }
    final time = _now().toUtc();
    if (_lastAttempt != null &&
        time.difference(_lastAttempt!) < const Duration(seconds: 1)) {
      return Future.error(
        StateError('Bitte eine Sekunde zwischen Routenabfragen warten'),
      );
    }
    _lastAttempt = time;
    _pendingKey = key;
    final transport = _transport = MobilityHttp(client: _client);
    final future = (() async {
      try {
        final body = await transport.text(
          Uri.https(
            'routing.openstreetmap.de',
            '/${mode.servicePath}/route/v1/${mode.profile}/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
            {
              'overview': 'full',
              'geometries': 'geojson',
              'steps': 'false',
              'alternatives': 'false',
            },
          ),
          maxBytes: 4 * 1024 * 1024,
        );
        final input = (body, mode, origin, destination, time);
        return body.length < 65536
            ? parseGroundRouting(input)
            : await compute(parseGroundRouting, input);
      } finally {
        transport.dispose();
      }
    })();
    _pending = future;
    future.then(
      (_) {
        _pending = null;
      },
      onError: (Object _, StackTrace _) {
        _pending = null;
      },
    );
    return future;
  }

  void cancel() {
    _transport?.dispose();
  }

  void dispose() {
    _disposed = true;
    cancel();
    if (_ownsClient) _client.close();
  }
}
