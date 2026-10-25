import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MobilityPoint {
  MobilityPoint(this.latitude, this.longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw const FormatException('Invalid coordinates');
    }
  }
  final double latitude, longitude;
  List<double> toJson() => [longitude, latitude];
  factory MobilityPoint.fromJson(Object? json) {
    if (json is! List || json.length != 2 || json.any((v) => v is! num)) {
      throw const FormatException('Invalid coordinate pair');
    }
    return MobilityPoint(
      (json[1] as num).toDouble(),
      (json[0] as num).toDouble(),
    );
  }
}

/// Exposes only the HTTP status, never response bodies or credentials.
class MobilityHttpException extends FormatException {
  MobilityHttpException(this.statusCode)
    : super('Data source HTTP $statusCode');
  final int statusCode;
}

/// Bounds transport before decoding; aborts timed out/disposed requests.
class MobilityHttp {
  MobilityHttp({http.Client? client})
    : client = client ?? http.Client(),
      ownsClient = client == null;
  final http.Client client;
  final bool ownsClient;
  final Set<Completer<void>> _requests = {};
  bool _disposed = false;
  Future<String> text(
    Uri uri, {
    Map<String, String> headers = const {},
    String? body,
    int maxBytes = 4 * 1024 * 1024,
  }) => read(
    uri,
    headers: headers,
    body: body,
    maxBytes: maxBytes,
    consume: (stream) async {
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in stream) {
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    },
  );

  Future<T> read<T>(
    Uri uri, {
    required Future<T> Function(Stream<List<int>>) consume,
    Map<String, String> headers = const {},
    String? body,
    int maxBytes = 4 * 1024 * 1024,
    Duration timeout = const Duration(seconds: 25),
    T Function()? onNotModified,
  }) async {
    if (_disposed) throw StateError('Data source closed');
    final abort = Completer<void>();
    _requests.add(abort);
    try {
      return await (() async {
        final request = http.AbortableRequest(
          body == null ? 'GET' : 'POST',
          uri,
          abortTrigger: abort.future,
        )..followRedirects = false;
        request.headers.addAll(headers);
        if (!kIsWeb) {
          request.headers['User-Agent'] =
              'FPVManager (https://github.com/CodefrogCF/FPVManager)';
        }
        if (body != null) request.body = body;
        final response = await client.send(request);
        if (response.statusCode == 304 && onNotModified != null) {
          return onNotModified();
        }
        if (response.statusCode != 200) {
          throw MobilityHttpException(response.statusCode);
        }
        if ((response.contentLength ?? 0) > maxBytes) {
          throw FormatException(
            'Response too large (maximum ${maxBytes ~/ 1024} KiB)',
          );
        }
        Stream<List<int>> bounded() async* {
          var received = 0;
          await for (final chunk in response.stream) {
            if (abort.isCompleted) throw StateError('Data request cancelled');
            received += chunk.length;
            if (received > maxBytes) {
              throw FormatException(
                'Response too large (maximum ${maxBytes ~/ 1024} KiB)',
              );
            }
            yield chunk;
          }
        }

        return consume(bounded());
      })().timeout(timeout);
    } finally {
      if (!abort.isCompleted) abort.complete();
      _requests.remove(abort);
    }
  }

  void dispose() {
    _disposed = true;
    for (final request in _requests) {
      if (!request.isCompleted) request.complete();
    }
    if (ownsClient) client.close();
  }
}

class RoadManeuver {
  const RoadManeuver({
    required this.type,
    required this.modifier,
    required this.road,
    required this.atMeters,
    required this.durationSeconds,
    required this.distanceMeters,
    this.exit,
  });
  final String type, modifier, road;
  final double atMeters, durationSeconds, distanceMeters;
  final int? exit;
  String get instruction {
    if (!{
      'arrive',
      'depart',
      'roundabout',
      'rotary',
      'roundabout turn',
      'exit roundabout',
      'exit rotary',
      'on ramp',
      'off ramp',
      'merge',
      'fork',
      'turn',
      'continue',
      'new name',
      'end of road',
      'notification',
      'use lane',
    }.contains(type)) {
      return 'Der Route folgen · Fahrhinweis nicht unterstützt';
    }
    if (type == 'arrive') return 'Ziel voraus';
    if (type == 'depart') return 'Der Route folgen';
    if (type.contains('roundabout') || type == 'rotary') {
      return exit == null
          ? 'In den Kreisverkehr fahren'
          : 'Im Kreisverkehr Ausfahrt $exit nehmen';
    }
    final direction = switch (modifier) {
      'left' => 'links',
      'right' => 'rechts',
      'slight left' => 'leicht links',
      'slight right' => 'leicht rechts',
      'sharp left' => 'scharf links',
      'sharp right' => 'scharf rechts',
      'uturn' => 'wenden',
      _ => 'geradeaus',
    };
    if (modifier == 'uturn') return 'Wenn möglich wenden';
    if (type == 'on ramp') return 'Auffahrt $direction nehmen';
    if (type == 'off ramp') return 'Ausfahrt $direction nehmen';
    if (type == 'merge') return '$direction einfädeln';
    if (type == 'fork') return '$direction halten';
    if (modifier == 'straight' || modifier.isEmpty) {
      return 'Geradeaus weiterfahren';
    }
    return '$direction abbiegen';
  }
}

class RoadRoute {
  RoadRoute({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
    required this.retrievedUtc,
    this.maneuvers = const [],
    this.destination,
  });
  final double distanceMeters, durationSeconds;
  final List<MobilityPoint> points;
  final DateTime retrievedUtc;
  final List<RoadManeuver> maneuvers;
  final MobilityPoint? destination;
  Map<String, dynamic> get overlay => {
    'id': 'road',
    'visible': true,
    'features': [
      {
        'id': 'road-route',
        'name': 'Driving route · OSRM / © OpenStreetMap contributors (ODbL)',
        'detail':
            '${(distanceMeters / 1000).toStringAsFixed(1)} km · ${(durationSeconds / 60).ceil()} min estimate; no live traffic, access permission or last-mile guarantee.',
        'geometry': {
          'type': 'LineString',
          'coordinates': points.map((p) => p.toJson()).toList(),
        },
      },
    ],
  };
}

class RoadRouter {
  RoadRouter({http.Client? client, DateTime Function()? now})
    : transport = MobilityHttp(client: client),
      now = now ?? DateTime.now;
  final MobilityHttp transport;
  final DateTime Function() now;
  Future<RoadRoute>? _pending;
  String? _pendingKey;
  DateTime? _lastRequest;
  void dispose() => transport.dispose();
  Future<RoadRoute> calculate(
    MobilityPoint origin,
    MobilityPoint destination, {
    double? headingDegrees,
  }) {
    if (headingDegrees != null &&
        (!headingDegrees.isFinite ||
            headingDegrees < 0 ||
            headingDegrees >= 360)) {
      return Future.error(ArgumentError('Invalid travel direction'));
    }
    final key = '${origin.toJson()}/${destination.toJson()}/$headingDegrees';
    if (_pending != null) {
      if (_pendingKey == key) return _pending!;
      return Future.error(StateError('A route request is already running'));
    }
    final time = now().toUtc();
    if (_lastRequest != null &&
        time.difference(_lastRequest!) < const Duration(seconds: 1)) {
      return Future.error(
        StateError('Please wait one second before requesting another route'),
      );
    }
    _lastRequest = time;
    _pendingKey = key;
    final uri = Uri.https(
      'routing.openstreetmap.de',
      '/routed-car/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
      {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'true',
        if (headingDegrees != null)
          'bearings': '${headingDegrees.round() % 360},60;',
      },
    );
    final future = _load(uri, destination);
    _pending = future;
    // Observe both outcomes without creating an unhandled error future.
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

  Future<RoadRoute> _load(Uri uri, MobilityPoint destination) async {
    final json = jsonDecode(
      await transport.text(uri, maxBytes: 2 * 1024 * 1024),
    ) as Map<String, dynamic>;
    if (json['code'] != 'Ok' ||
        json['routes'] is! List ||
        (json['routes'] as List).isEmpty) {
      throw const FormatException('No driving route available');
    }
    final route = (json['routes'] as List).first as Map;
    final distance = route['distance'],
        duration = route['duration'],
        geometry = route['geometry'];
    if (distance is! num ||
        duration is! num ||
        !distance.isFinite ||
        !duration.isFinite ||
        distance < 0 ||
        duration < 0 ||
        distance > 100000000 ||
        duration > 2592000 ||
        geometry is! Map ||
        geometry['type'] != 'LineString' ||
        geometry['coordinates'] is! List) {
      throw const FormatException('Invalid route response');
    }
    final coordinates = geometry['coordinates'] as List;
    if (coordinates.length < 2 || coordinates.length > 20000) {
      throw const FormatException('Unsupported route size');
    }
    final maneuvers = <RoadManeuver>[];
    var at = 0.0;
    if (route['legs'] != null) {
      final legs = route['legs'];
      if (legs is! List || legs.length > 100) {
        throw const FormatException('Invalid route legs');
      }
      for (final leg in legs) {
        if (leg is! Map || leg['steps'] is! List) {
          throw const FormatException('Missing route instructions');
        }
        for (final step in leg['steps'] as List) {
          if (maneuvers.length >= 2000 ||
              step is! Map ||
              step['maneuver'] is! Map) {
            throw const FormatException('Invalid route instructions');
          }
          final maneuver = step['maneuver'] as Map,
              d = step['distance'],
              t = step['duration'];
          if (d is! num ||
              t is! num ||
              !d.isFinite ||
              !t.isFinite ||
              d < 0 ||
              t < 0 ||
              maneuver['type'] is! String) {
            throw const FormatException('Invalid route instruction');
          }
          if (d > distance + 1000 || t > duration + 600) {
            throw const FormatException('Inconsistent route instruction');
          }
          MobilityPoint.fromJson(maneuver['location']);
          String label(Object? value) => value is String
              ? value.substring(0, value.length.clamp(0, 160))
              : '';
          final exit = maneuver['exit'];
          if (exit != null && (exit is! int || exit < 1 || exit > 100)) {
            throw const FormatException('Invalid roundabout exit');
          }
          maneuvers.add(
            RoadManeuver(
              type: label(maneuver['type']),
              modifier: label(maneuver['modifier']),
              road: label(step['name']),
              atMeters: at,
              distanceMeters: d.toDouble(),
              durationSeconds: t.toDouble(),
              exit: exit as int?,
            ),
          );
          at += d;
        }
      }
    }
    return RoadRoute(
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toDouble(),
      points: coordinates.map(MobilityPoint.fromJson).toList(growable: false),
      retrievedUtc: now().toUtc(),
      maneuvers: List.unmodifiable(maneuvers),
      destination: destination,
    );
  }
}
