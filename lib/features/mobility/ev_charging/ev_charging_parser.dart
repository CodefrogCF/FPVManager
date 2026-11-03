import 'dart:convert';

import 'ev_charging_models.dart';

Map<String, dynamic> _object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
List<dynamic> _array(Object? value) => value is List ? value : const [];

/// Older GeoAdmin/OICP records sometimes publish plugs as comma-delimited tags,
/// while OCPI uses connector objects. Do not manufacture unreported attributes.
List<dynamic> _components(Object? value) {
  if (value is List) return value;
  if (value is Map) return [value];
  if (value is String && value.length < 1000) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded;
      if (decoded is Map) return [decoded];
    } on FormatException {
      // It is a plain OICP plug description, not embedded JSON.
    }
    return value
        .split(RegExp(r'[,;|]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(24)
        .toList();
  }
  return const [];
}

String? _text(Object? value) {
  if (value == null) return null;
  if (value is Map) {
    return _text(value['value'] ?? value['name'] ?? value['en'] ?? value['de']);
  }
  if (value is List) return value.isEmpty ? null : _text(value.first);
  final v = value.toString().trim();
  return v.isEmpty ? null : v;
}

double? _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(_text(value) ?? '');
Object? _value(Map<String, dynamic> data, List<String> names) {
  for (final name in names) {
    final matching = data.keys
        .where(
          (key) =>
              key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '') ==
              name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), ''),
        )
        .firstOrNull;
    if (matching != null && data[matching] != null) return data[matching];
  }
  return null;
}

DateTime? _date(Object? value) =>
    DateTime.tryParse(_text(value) ?? '')?.toUtc();

/// Normalizes GeoAdmin Identify features (current HTTPS, geographically bounded),
/// and OCPI Location records for the announced replacement source.
EvChargingSnapshot parseEvChargingResponse(
  String payload,
  EvChargingArea area,
  DateTime fetchedUtc,
) {
  final document = _object(jsonDecode(payload));
  if (document['status_code'] != null && document['status_code'] != 1000) {
    throw const FormatException('BFE source returned an error.');
  }
  final rawEntries =
      document['results'] ?? document['features'] ?? document['data'];
  if (rawEntries is! List) {
    throw const FormatException('Missing BFE station array.');
  }
  final entries = _array(rawEntries);
  if (entries.length > 200) {
    throw const FormatException(
      'EV charging response exceeded the 200-feature safety limit.',
    );
  }
  final bySite = <String, _MutableStation>{};
  final statusMap = <String, EvChargingAvailability>{};
  var seen = 0;
  for (final item in entries) {
    final source = _object(item);
    final properties = _object(source['properties'] ?? source['attributes']);
    final location = properties.isEmpty && source.containsKey('coordinates')
        ? source
        : properties;
    if (location.isEmpty) continue;
    final geometry = _object(source['geometry']);
    final coordinates = _array(geometry['coordinates']);
    final locationCoords = _object(location['coordinates']);
    final lat = coordinates.length >= 2
        ? _number(coordinates[1])
        : _number(
            _value(locationCoords.isNotEmpty ? locationCoords : location, [
              'latitude',
              'lat',
              'y',
            ]),
          );
    final lon = coordinates.length >= 2
        ? _number(coordinates[0])
        : _number(
            _value(locationCoords.isNotEmpty ? locationCoords : location, [
              'longitude',
              'lon',
              'lng',
              'x',
            ]),
          );
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        !area.contains(lat, lon)) {
      continue;
    }
    final rawFeatureId = _text(
      source['featureId'] ?? source['id'] ?? location['id'],
    );
    if (rawFeatureId == null || rawFeatureId.length > 150) continue;
    final siteId =
        _text(
          _value(location, ['ChargingStationId', 'station_id', 'location_id']),
        ) ??
        rawFeatureId;
    final country = _text(_value(location, ['country_code'])) ?? '';
    final party = _text(_value(location, ['party_id', 'operator_id'])) ?? '';
    final key = 'bfe:${country.isEmpty ? 'CH' : country}:$party:$siteId';
    final name =
        _text(
          _value(location, [
            'ChargingStationNames',
            'name',
            'label',
            'StationName',
          ]),
        ) ??
        'Ladestation';
    final address =
        _text(_value(location, ['Address', 'address', 'street', 'Street'])) ??
        _text(_value(location, ['city', 'City']));
    final station = bySite.putIfAbsent(
      key,
      () => _MutableStation(key, name, lat, lon, address),
    );
    final evseList = _array(_value(location, ['evses', 'chargingPoints']));
    final evses = evseList.isEmpty ? [location] : evseList;
    for (final evseRaw in evses.take(80)) {
      final evse = _object(evseRaw);
      final evseId =
          _text(_value(evse, ['evse_id', 'uid', 'EvseID', 'EVSEID', 'id'])) ??
          rawFeatureId;
      final fullId = '$key/$evseId';
      if (!station.evseIds.contains(fullId)) station.evseIds.add(fullId);
      final connectors = _components(
        _value(evse, [
          'connectors',
          'ChargingFacilities',
          'chargingFacilities',
        ]),
      );
      final plugs = _components(_value(evse, ['Plugs', 'plugs']));
      final all = <Object?>[...connectors.take(48), ...plugs.take(48)];
      if (all.isEmpty &&
          _value(evse, ['PlugType', 'ConnectorType', 'standard']) != null) {
        all.add(evse);
      }
      for (final raw in all) {
        final connector = _object(raw);
        final type =
            _text(
              _value(connector, [
                'standard',
                'PlugType',
                'type',
                'Plug',
                'ConnectorType',
                'Plugs',
              ]),
            ) ??
            _text(raw);
        if (type == null || type.length > 100) continue;
        // Older OICP charging facilities report power in kW; OCPI max_electric_power is Watts.
        final watts = _number(_value(connector, ['max_electric_power']));
        final kw = watts != null
            ? watts / 1000
            : _number(
                    _value(connector, [
                      'Power',
                      'power_kw',
                      'PowerKW',
                      'maxPower',
                    ]),
                  ) ??
                  _number(_value(evse, ['Power', 'power_kw', 'PowerKW']));
        final power = kw != null && kw > 0 && kw <= 1000 ? kw : null;
        final connectorId =
            _text(_value(connector, ['id', 'ConnectorID'])) ?? type;
        final dedupe = '$fullId:$connectorId:$type';
        station.connectors.putIfAbsent(
          dedupe,
          () =>
              EvChargingConnector(id: connectorId, type: type, powerKw: power),
        );
      }
      final status = _text(
        _value(evse, ['status', 'Availability', 'availability', 'EVSEStatus']),
      );
      final updated = _date(
        _value(evse, [
          'status_updated',
          'status_last_updated',
          'StatusLastUpdated',
          'last_updated',
          'LastUpdate',
          'LastUpdated',
        ]),
      );
      if (status != null) {
        final existing = statusMap[fullId];
        if (existing == null ||
            (updated != null &&
                (existing.updatedUtc == null ||
                    updated.isAfter(existing.updatedUtc!)))) {
          statusMap[fullId] = EvChargingAvailability(
            evseId: fullId,
            rawStatus: status,
            updatedUtc: updated,
          );
        }
      }
    }
    seen++;
  }
  final stations = bySite.values.map((m) => m.finish()).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return EvChargingSnapshot(
    area: area,
    fetchedUtc: fetchedUtc.toUtc(),
    stations: stations,
    statuses: statusMap,
    truncated: entries.length >= 200 || seen >= 200,
  );
}

class _MutableStation {
  _MutableStation(this.id, this.name, this.lat, this.lon, this.address);
  final String id, name;
  final double lat, lon;
  final String? address;
  final List<String> evseIds = [];
  final Map<String, EvChargingConnector> connectors = {};
  EvChargingStation finish() => EvChargingStation(
    id: id,
    name: name,
    latitude: lat,
    longitude: lon,
    address: address,
    evseIds: List.unmodifiable(evseIds),
    connectors: List.unmodifiable(connectors.values),
  );
}
