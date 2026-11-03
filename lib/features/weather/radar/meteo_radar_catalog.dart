import 'dart:convert';

import 'package:http/http.dart' as http;

/// Only ground precipitation estimates and one-hour accumulations are supported.
/// TZC side views and nowcasting products are deliberately excluded.
enum MeteoRadarProduct {
  intensity('RZC', 'Radar estimate', 'mm/h'),
  accumulation('CPC', 'CombiPrecip 60-minute total', 'mm');

  const MeteoRadarProduct(this.code, this.label, this.unit);
  final String code;
  final String label;
  final String unit;
}

class MeteoRadarFrame {
  const MeteoRadarFrame({
    required this.product,
    required this.timestampUtc,
    required this.assetUrl,
    required this.assetName,
    required this.catalogueUpdatedUtc,
    this.quality,
  });
  final MeteoRadarProduct product;
  final DateTime timestampUtc;
  final Uri assetUrl;
  final String assetName;
  final DateTime? catalogueUpdatedUtc;
  final int? quality;
  String get source => 'Source: MeteoSwiss · STAC FSDI';

  Map<String, dynamic> toGlobeCommand() => {
    'type': 'set-meteoswiss-radar',
    'product': product.code,
    'timestampUtc': timestampUtc.toUtc().toIso8601String(),
    'assetUrl': assetUrl.toString(),
    'assetName': assetName,
    'source': source,
    'units': product.unit,
    if (quality != null) 'qualityCode': quality,
    if (catalogueUpdatedUtc != null)
      'catalogueUpdatedUtc': catalogueUpdatedUtc!.toUtc().toIso8601String(),
  };
}

/// Bounded, user-triggered STAC discovery. Nothing is downloaded automatically.
class MeteoRadarCatalog {
  MeteoRadarCatalog({http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _now = now ?? DateTime.now;

  static final Uri collection = Uri.parse(
    'https://data.geo.admin.ch/api/stac/v1/collections/'
    'ch.meteoschweiz.ogd-radar-precip',
  );
  static const maxFrames = 12;
  static const maxItems = 3;
  static const cacheDuration = Duration(minutes: 2);
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;
  List<MeteoRadarFrame>? _cached;
  DateTime? _checkedUtc;
  Future<List<MeteoRadarFrame>>? _inFlight;
  bool _disposed = false;

  DateTime? get checkedUtc => _checkedUtc;

  Future<List<MeteoRadarFrame>> discover({bool force = false}) {
    if (_disposed) {
      return Future.error(StateError('Catalog closed'));
    }
    final cached = _cached;
    if (cached != null &&
        _checkedUtc != null &&
        _now().toUtc().difference(_checkedUtc!) <
            (force ? const Duration(seconds: 30) : cacheDuration)) {
      return Future.value(cached);
    }
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    // Clean up inside this Future instead of chaining an unobserved whenComplete.
    late final Future<List<MeteoRadarFrame>> request;
    request = _fetch().then(
      (result) {
        if (identical(_inFlight, request)) {
          _inFlight = null;
        }
        return result;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_inFlight, request)) {
          _inFlight = null;
        }
        Error.throwWithStackTrace(error, stack);
      },
    );
    _inFlight = request;
    return request;
  }

  Future<List<MeteoRadarFrame>> _fetch() async {
    // STAC collection items are calendar-day features. The server may include
    // the next day with no assets; do not mistake that for a coverage report.
    final uri = Uri.parse('${collection.toString()}/items?limit=$maxItems');
    final response = await _client
        .get(
          uri,
          headers: const {'Accept': 'application/geo+json, application/json'},
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('STAC HTTP ${response.statusCode}');
    }
    if (response.bodyBytes.length > 1200000) {
      throw const FormatException('STAC response exceeds limit');
    }
    final object = jsonDecode(utf8.decode(response.bodyBytes));
    if (object is! Map<String, dynamic> || object['features'] is! List) {
      throw const FormatException('Invalid STAC FeatureCollection');
    }
    final features = object['features'] as List;
    if (features.length > maxItems) {
      throw const FormatException('STAC returned too many day items');
    }
    final result = parseFeatures(features);
    if (!_disposed) {
      _cached = result;
      _checkedUtc = _now().toUtc();
    }
    return result;
  }

  /// Pure parser for STAC fixture testing, with strict asset host and format.
  static List<MeteoRadarFrame> parseFeatures(List<dynamic> features) {
    final frames = <String, MeteoRadarFrame>{};
    for (final raw in features.take(maxItems)) {
      if (raw is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(raw);
      final assets = map['assets'];
      if (assets is! Map) {
        continue;
      }
      final updated =
          DateTime.tryParse(
            '${map['properties'] is Map ? (map['properties'] as Map)['updated'] : null}',
          ) ??
          DateTime.tryParse('${map['updated']}');
      for (final entry in assets.entries) {
        if (frames.length >= 2000) {
          break;
        }
        if (entry.value is! Map) {
          continue;
        }
        final asset = entry.value as Map;
        final href = asset['href'];
        if (href is! String) {
          continue;
        }
        final url = Uri.tryParse(href);
        if (url == null ||
            url.scheme != 'https' ||
            url.host != 'data.geo.admin.ch' ||
            url.userInfo.isNotEmpty) {
          continue;
        }
        final name = url.pathSegments.last;
        final match = RegExp(
          r'^(RZC|CPC)(\d\d)(\d{3})(\d\d)(\d\d)([A-Za-z0-9]{0,2})(?:_00060)?\.[A-Za-z0-9]+\.h5$',
          caseSensitive: false,
        ).firstMatch(name);
        if (match == null) {
          continue;
        }
        final product = match.group(1)!.toUpperCase() == 'RZC'
            ? MeteoRadarProduct.intensity
            : MeteoRadarProduct.accumulation;
        if (product == MeteoRadarProduct.accumulation &&
            !name.contains('_00060.')) {
          continue;
        }
        try {
          final year = 2000 + int.parse(match.group(2)!);
          final day = int.parse(match.group(3)!);
          final hour = int.parse(match.group(4)!);
          final minute = int.parse(match.group(5)!);
          if (day < 1 ||
              day >
                  DateTime.utc(year + 1)
                      .difference(DateTime.utc(year))
                      .inDays ||
              hour > 23 ||
              minute > 59) {
            continue;
          }
          final time = DateTime.utc(year)
              .add(Duration(days: day - 1, hours: hour, minutes: minute));
          final quality =
              product == MeteoRadarProduct.accumulation &&
                  RegExp(r'^\d$').hasMatch(match.group(6)!)
              ? int.parse(match.group(6)!)
              : null;
          final candidate = MeteoRadarFrame(
            product: product,
            timestampUtc: time,
            assetUrl: url,
            assetName: name,
            quality: quality,
            catalogueUpdatedUtc: updated?.toUtc(),
          );
          final key = '${product.code}|${time.toIso8601String()}';
          final previous = frames[key];
          // CPC reanalysis can replace hourly data. Latest publication wins.
          if (previous == null ||
              (candidate.catalogueUpdatedUtc?.isAfter(
                    previous.catalogueUpdatedUtc ?? DateTime.utc(1970),
                  ) ??
                  false) ||
              ((candidate.catalogueUpdatedUtc ==
                      previous.catalogueUpdatedUtc) &&
                  (candidate.quality ?? -1) > (previous.quality ?? -1))) {
            frames[key] = candidate;
          }
        } on FormatException {
          continue;
        }
      }
    }
    final sorted = frames.values.toList()
      ..sort((a, b) => b.timestampUtc.compareTo(a.timestampUtc));
    final selected = <MeteoRadarFrame>[];
    for (final product in MeteoRadarProduct.values) {
      selected.addAll(
        sorted.where((f) => f.product == product).take(maxFrames),
      );
    }
    return List.unmodifiable(selected);
  }

  void dispose() {
    _disposed = true;
    if (_ownsClient) {
      _client.close();
    }
    _cached = null;
  }
}
