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
        if (response.statusCode != 200) {
          throw FormatException('Data source HTTP ${response.statusCode}');
        }
        if ((response.contentLength ?? 0) > maxBytes) {
          throw const FormatException('Response too large');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > maxBytes) {
            throw const FormatException('Response too large');
          }
          bytes.add(chunk);
        }
        return utf8.decode(bytes.takeBytes());
      })().timeout(const Duration(seconds: 25));
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

class RoadRoute {
  RoadRoute({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
    required this.retrievedUtc,
  });
  final double distanceMeters, durationSeconds;
  final List<MobilityPoint> points;
  final DateTime retrievedUtc;
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
  Future<RoadRoute> calculate(MobilityPoint origin, MobilityPoint destination) {
    final key = '${origin.toJson()}/${destination.toJson()}';
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
      {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
    );
    final future = _load(uri);
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

  Future<RoadRoute> _load(Uri uri) async {
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
        geometry is! Map ||
        geometry['type'] != 'LineString' ||
        geometry['coordinates'] is! List) {
      throw const FormatException('Invalid route response');
    }
    final coordinates = geometry['coordinates'] as List;
    if (coordinates.length < 2 || coordinates.length > 20000) {
      throw const FormatException('Unsupported route size');
    }
    return RoadRoute(
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.toDouble(),
      points: coordinates.map(MobilityPoint.fromJson).toList(growable: false),
      retrievedUtc: now().toUtc(),
    );
  }
}
