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
    void Function(Map<String, String>)? onHeaders,
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
        onHeaders?.call(Map.unmodifiable(response.headers));
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
    this.sections = const [],
    this.alternatives = const [],
    this.omittedAlternatives = 0,
  });
  final double distanceMeters, durationSeconds;
  final List<MobilityPoint> points;
  final DateTime retrievedUtc;
  final List<RoadManeuver> maneuvers;
  final MobilityPoint? destination;
  final List<RoadSection> sections;
  final List<RoadRoute> alternatives;
  final int omittedAlternatives;
  List<RoadRoute> get choices => [this, ...alternatives];
  RoadRoute withAlternatives(List<RoadRoute> others, int omitted) => RoadRoute(
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
    points: points,
    retrievedUtc: retrievedUtc,
    maneuvers: maneuvers,
    destination: destination,
    sections: sections,
    alternatives: List.unmodifiable(others),
    omittedAlternatives: omitted,
  );
  Map<String, dynamic> get overlay => {
    'id': 'road',
    'visible': true,
    'features': [
      {
        'id': 'road-route',
        'name': 'Driving route · OSRM / © OpenStreetMap contributors (ODbL)',
        'detail':
            '${(distanceMeters / 1000).toStringAsFixed(1)} km · ${(durationSeconds / 60).ceil()} min OSRM base estimate without traffic delays; verify access and the final approach.',
        'geometry': {
          'type': 'LineString',
          'coordinates': points.map((p) => p.toJson()).toList(),
        },
      },
    ],
  };
}

/// Explicit OSRM step geometry and road references; never inferred from turn names.
class RoadSection {
  const RoadSection({
    required this.points,
    required this.references,
    required this.durationSeconds,
    required this.distanceMeters,
    this.link = false,
  });
  final List<MobilityPoint> points;
  final Set<String> references;
  final double durationSeconds, distanceMeters;
  final bool link;
}

Set<String> roadReferences(String value) => value
    .toUpperCase()
    .split(RegExp(r'[;,]'))
    .map((s) => s.replaceAll(RegExp(r'\s+'), ''))
    .where((s) => RegExp(r'^[A-Z]{0,3}[0-9]{1,5}[A-Z]?$').hasMatch(s))
    .take(8)
    .toSet();

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
        'alternatives': 'true',
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
    final body = await transport.text(uri, maxBytes: 6 * 1024 * 1024);
    final input = (body, destination, now().toUtc());
    // Tiny responses do not benefit from worker startup and message copying.
    return body.length < 64 * 1024
        ? _decodeAlternatives(input)
        : compute(_decodeAlternatives, input);
  }
}

RoadRoute _decodeAlternatives((String, MobilityPoint, DateTime) request) {
  final decoded = jsonDecode(request.$1);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid routing response');
  }
  final json = decoded;
  if (json['code'] != 'Ok' ||
      json['routes'] is! List ||
      (json['routes'] as List).isEmpty) {
    throw const FormatException('No driving route available');
  }
  final routes = json['routes'] as List;
  if (routes.length > 8) {
    throw const FormatException('Unsupported alternative count');
  }
  RoadRoute read(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid route');
    return _decodeRoadRoute(raw, request.$2, request.$3);
  }

  final first = read(routes.first), others = <RoadRoute>[];
  var omitted = routes.length > 3 ? routes.length - 3 : 0;
  for (final raw in routes.skip(1).take(2)) {
    try {
      final alternative = read(raw);
      if (alternative.distanceMeters < 1 ||
          !alternative.points.any(
            (p) =>
                p.latitude != alternative.points.first.latitude ||
                p.longitude != alternative.points.first.longitude,
          )) {
        throw const FormatException('Empty alternative');
      }
      others.add(alternative);
    } on FormatException {
      omitted++;
    }
  }
  return first.withAlternatives(others, omitted);
}

RoadRoute _decodeRoadRoute(
  Map route,
  MobilityPoint destination,
  DateTime time,
) {
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
  final sections = <RoadSection>[];
  var sectionVertices = 0;
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
        final section = step['geometry'];
        if (section is Map &&
            section['type'] == 'LineString' &&
            section['coordinates'] is List) {
          final raw = section['coordinates'] as List;
          sectionVertices += raw.length;
          if (raw.length < 2 || sectionVertices > 40000) {
            throw const FormatException('Unsupported road section size');
          }
          final points = raw
              .map(MobilityPoint.fromJson)
              .toList(growable: false);
          sections.add(
            RoadSection(
              points: points,
              references: Set.unmodifiable(roadReferences(label(step['ref']))),
              durationSeconds: t.toDouble(),
              distanceMeters: d.toDouble(),
              link: {'on ramp', 'off ramp'}.contains(maneuver['type']),
            ),
          );
        }
        at += d;
      }
    }
  }
  return RoadRoute(
    distanceMeters: distance.toDouble(),
    durationSeconds: duration.toDouble(),
    points: coordinates.map(MobilityPoint.fromJson).toList(growable: false),
    retrievedUtc: time,
    maneuvers: List.unmodifiable(maneuvers),
    destination: destination,
    sections: List.unmodifiable(sections),
  );
}
