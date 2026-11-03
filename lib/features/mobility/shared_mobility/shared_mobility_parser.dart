import 'dart:convert';

import 'shared_mobility_models.dart';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
String? _string(Object? value) =>
    value is String && value.trim().isNotEmpty && value.length <= 300
    ? value.trim()
    : null;
int? _integer(Object? value) => value is int
    ? value
    : value is num && value.isFinite
    ? value.toInt()
    : null;
num? _number(Object? value) => value is num && value.isFinite ? value : null;
bool? _bool(Object? value) => value is bool ? value : null;
DateTime? _time(Object? value) {
  if (value is num && value.isFinite && value > 1000000000) {
    return DateTime.fromMillisecondsSinceEpoch(
      value > 1000000000000 ? value.toInt() : value.toInt() * 1000,
      isUtc: true,
    );
  }
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

String? _httpsLink(Object? raw) {
  final text = _string(raw);
  if (text == null || text.length > 500) {
    return null;
  }
  final uri = Uri.tryParse(text);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri.toString()
      : null;
}

List<String> _types(Object? raw) {
  final candidates = raw is List ? raw : [raw];
  final distinct = <String>{};
  for (final value in candidates) {
    final type = _string(value);
    if (type != null && type.length <= 60 && distinct.length < 12) {
      distinct.add(type);
    }
  }
  return List.unmodifiable(distinct);
}

/// Parses documented REST `identify` EsriJSON array, or a locally composed
/// GBFS 2.0/2.3 feed set. We do not fetch all GBFS systems on a nearby query.
SharedMobilitySnapshot parseSharedMobilityResponse(
  String body,
  SharedMobilityArea area,
  DateTime fetchedUtc, {
  Map<String, String> headers = const {},
}) {
  if (body.length > 1100000) {
    throw const FormatException('Shared mobility response too large.');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw const FormatException('Shared mobility returned invalid JSON.');
  }
  if (decoded is List) {
    return _parseRest(decoded, area, fetchedUtc, headers);
  }
  if (decoded is Map &&
      decoded['version'] is String &&
      decoded['data'] is Map) {
    return _parseGbfs(_map(decoded), area, fetchedUtc);
  }
  throw const FormatException('Unsupported shared mobility response.');
}

SharedMobilitySnapshot _parseRest(
  List<dynamic> rows,
  SharedMobilityArea area,
  DateTime fetched,
  Map<String, String> headers,
) {
  final items = <String, SharedMobilityOffer>{};
  final modified =
      _time(headers['x-data-last-updated']) ?? _time(headers['last-modified']);
  // No documented REST TTL: server HTTP Date is not data publication time.
  // As such, reported availability is never presented as verified fresh.
  for (final raw in rows.take(201)) {
    final row = _map(raw);
    final attrs = _map(row['attributes']);
    final geom = _map(row['geometry']);
    if (geom['spatialReference'] is Map &&
        _map(geom['spatialReference'])['wkid'] != 4326) {
      continue;
    }
    final lat = _number(geom['y'])?.toDouble();
    final lon = _number(geom['x'])?.toDouble();
    final id =
        _string(attrs['id']) ?? _string(row['featureId']) ?? _string(row['id']);
    final providerId = _string(attrs['provider_id']);
    if (lat == null ||
        lon == null ||
        id == null ||
        providerId == null ||
        id.length > 150 ||
        !area.contains(lat, lon)) {
      continue;
    }
    final pickup = switch (_string(attrs['pickup_type'])) {
      'station_based' => SharedMobilityPickup.stationBased,
      'free_floating' => SharedMobilityPickup.freeFloating,
      _ => SharedMobilityPickup.unknown,
    };
    final offer = SharedMobilityOffer(
      id: id,
      providerId: providerId,
      providerName: _string(attrs['provider_name']) ?? providerId,
      latitude: lat,
      longitude: lon,
      pickup: pickup,
      vehicleTypes: _types(attrs['vehicle_type']),
      name: _string(attrs['station_name']),
      operatorUrl:
          _httpsLink(attrs['provider_website']) ??
          _httpsLink(attrs['provider_url']) ??
          _httpsLink(attrs['provider_apps_android_store_uri']) ??
          _httpsLink(attrs['provider_apps_ios_store_uri']),
      reportedAvailable: _bool(attrs['available']),
      reserved: _bool(attrs['vehicle_status_reserved']),
      disabled: _bool(attrs['vehicle_status_disabled']),
      installed: _bool(attrs['station_status_installed']),
      renting: _bool(attrs['station_status_renting']),
      availableCount: _integer(attrs['station_status_num_vehicle_available']),
      updatedUtc: _time(attrs['last_updated']) ?? _time(attrs['last_reported']),
    );
    items.putIfAbsent('$providerId/$id', () => offer);
    if (items.length >= 200) {
      break;
    }
  }
  return SharedMobilitySnapshot(
    area: area,
    fetchedUtc: fetched.toUtc(),
    offers: List.unmodifiable(items.values),
    truncated: rows.length >= 200 || items.length >= 200,
    feedUpdatedUtc: modified,
    sourceVersion: 'REST v1',
  );
}

/// Supports local snapshots composed of the standard GBFS 2.x feed bodies.
/// Provider-specific GBFS feeds are intentionally not downloaded nationwide.
SharedMobilitySnapshot _parseGbfs(
  Map<String, dynamic> root,
  SharedMobilityArea area,
  DateTime fetched,
) {
  final version = _string(root['version']) ?? '';
  if (!version.startsWith('2.0') && !version.startsWith('2.3')) {
    throw const FormatException('Only GBFS 2.0/2.3 is supported.');
  }
  final data = _map(root['data']);
  final system = _map(data['system_information']);
  final providerId =
      _string(system['system_id']) ?? _string(root['provider_id']) ?? 'gbfs';
  final providerName = _string(system['name']) ?? providerId;
  final stations = _map(data['station_information']);
  final statuses = _map(data['station_status']);
  final floating = _map(data['free_bike_status']);
  final byStation = <String, Map<String, dynamic>>{};
  for (final row in (statuses['stations'] as List? ?? const []).take(300)) {
    final map = _map(row), id = _string(map['station_id']);
    if (id != null) {
      byStation[id] = map;
    }
  }
  final types = <String, String>{};
  for (final row
      in (_map(data['vehicle_types'])['vehicle_types'] as List? ?? const [])
          .take(100)) {
    final map = _map(row), id = _string(map['vehicle_type_id']);
    if (id != null) {
      types[id] = _string(map['form_factor']) ?? id;
    }
  }
  final found = <String, SharedMobilityOffer>{};
  for (final row in (stations['stations'] as List? ?? const []).take(201)) {
    final station = _map(row);
    final id = _string(station['station_id']);
    final lat = _number(station['lat'])?.toDouble(),
        lon = _number(station['lon'])?.toDouble();
    if (id == null || lat == null || lon == null || !area.contains(lat, lon)) {
      continue;
    }
    final status = byStation[id] ?? const <String, dynamic>{};
    final count =
        _integer(status['num_bikes_available']) ??
        _integer(status['num_cars_available']);
    final uris = _map(station['rental_uris']);
    found.putIfAbsent(
      '$providerId/$id',
      () => SharedMobilityOffer(
        id: id,
        providerId: providerId,
        providerName: providerName,
        latitude: lat,
        longitude: lon,
        pickup: SharedMobilityPickup.stationBased,
        name: _string(station['name']),
        vehicleTypes: _types(station['vehicle_types_available']),
        availableCount: count,
        installed: _bool(status['is_installed']),
        renting: _bool(status['is_renting']),
        operatorUrl: _httpsLink(uris['android']) ?? _httpsLink(uris['ios']),
        updatedUtc: _time(status['last_reported']),
      ),
    );
    if (found.length >= 200) {
      break;
    }
  }
  for (final row in (floating['bikes'] as List? ?? const []).take(201)) {
    if (found.length >= 200) {
      break;
    }
    final bike = _map(row);
    final id = _string(bike['bike_id']);
    final lat = _number(bike['lat'])?.toDouble(),
        lon = _number(bike['lon'])?.toDouble();
    if (id == null || lat == null || lon == null || !area.contains(lat, lon)) {
      continue;
    }
    final uris = _map(bike['rental_uris']);
    final vehicleType = _string(bike['vehicle_type_id']);
    found.putIfAbsent(
      '$providerId/$id',
      () => SharedMobilityOffer(
        id: id,
        providerId: providerId,
        providerName: providerName,
        latitude: lat,
        longitude: lon,
        pickup: SharedMobilityPickup.freeFloating,
        vehicleTypes: _types(
          vehicleType == null ? null : types[vehicleType] ?? vehicleType,
        ),
        reportedAvailable:
            _bool(bike['is_reserved']) == true ||
                _bool(bike['is_disabled']) == true
            ? false
            : _bool(bike['is_reserved']) == false &&
                  _bool(bike['is_disabled']) == false,
        reserved: _bool(bike['is_reserved']),
        disabled: _bool(bike['is_disabled']),
        operatorUrl: _httpsLink(uris['android']) ?? _httpsLink(uris['ios']),
        updatedUtc: _time(bike['last_reported']),
      ),
    );
  }
  final time =
      _time(root['last_updated']) ??
      _time(statuses['last_updated']) ??
      _time(floating['last_updated']);
  final ttlSeconds =
      _integer(root['ttl']) ??
      _integer(statuses['ttl']) ??
      _integer(floating['ttl']);
  final ttl = ttlSeconds == null || ttlSeconds <= 0
      ? null
      : Duration(seconds: ttlSeconds.clamp(10, 3600).toInt());
  return SharedMobilitySnapshot(
    area: area,
    fetchedUtc: fetched.toUtc(),
    offers: List.unmodifiable(found.values),
    truncated:
        found.length >= 200 ||
        (stations['stations'] as List? ?? const []).length >= 201 ||
        (floating['bikes'] as List? ?? const []).length >= 201,
    feedUpdatedUtc: time,
    maxAge: ttl,
    sourceVersion: 'GBFS $version',
  );
}
