import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/osint/cached_osint_provider.dart';
import '../../core/osint/osint_dataset.dart';
import '../../core/osint/osint_source.dart';
import '../../core/osint/osint_provider_state.dart';
import '../mobility/road_routing.dart';
import 'avalanche_bulletin.dart';

class AvalancheRefreshCooldown implements Exception {
  const AvalancheRefreshCooldown(this.seconds);
  final int seconds;
  @override
  String toString() =>
      'SLF-Bulletin kann in $seconds s erneut abgefragt werden.';
}

class AvalancheProvider extends CachedOsintProvider<Map<String, dynamic>> {
  AvalancheProvider({http.Client? client, super.persistentCache, super.now})
    : _transport = MobilityHttp(client: client),
      super(cacheDuration: const Duration(minutes: 30));
  final MobilityHttp _transport;
  DateTime? _lastAttempt;
  int get retryAfterSeconds {
    final last = _lastAttempt;
    if (last == null) return 0;
    final elapsed = nowUtc.difference(last).inMilliseconds;
    // A corrected device clock must not lock the provider indefinitely.
    return elapsed < 0 ? 0 : math.max(0, (30000 - elapsed + 999) ~/ 1000);
  }

  @override
  Future<OsintDataset<Map<String, dynamic>>> fetch({
    bool forceRefresh = false,
  }) {
    final update = status.update;
    if (update != OsintUpdateState.loading &&
        update != OsintUpdateState.disposed &&
        !isClearing &&
        retryAfterSeconds > 0) {
      // Throttling is neither a network attempt nor evidence of invalid data.
      // Do not rewrite retrieval time, freshness, or an actual update failure.
      final data = cached;
      return data != null
          ? Future.value(data)
          : Future.error(AvalancheRefreshCooldown(retryAfterSeconds));
    }
    return super.fetch(forceRefresh: forceRefresh);
  }

  static final defaultSource = OsintSource(
    id: 'slf-avalanche',
    name: 'SLF-Lawinenbulletin',
    publisher: 'WSL-Institut für Schnee- und Lawinenforschung SLF',
    dataUri: Uri.parse('https://aws.slf.ch/api/bulletin/caaml/de/geojson'),
    metadataUri: Uri.parse(
      'https://www.slf.ch/de/services-und-produkte/slf-datenservice/',
    ),
    attribution: 'WSL-Institut für Schnee- und Lawinenforschung SLF · https://www.slf.ch · CC BY 4.0',
    licenseName: 'CC BY 4.0',
    licenseUri: Uri.parse('https://creativecommons.org/licenses/by/4.0/'),
    coordinateReference: 'EPSG:4326',
  );
  @override
  OsintSource get source => defaultSource;
  @override
  void validateData(Map<String, dynamic> data) {
    final areas = data['areas'];
    if (areas is! List || areas.length > 200) {
      throw const FormatException('Ungültiger SLF-Cache');
    }
    // Validate cached semantic data by exercising the exact bridge projection.
    avalancheFeatures(data, stale: true, period: 'all');
  }

  @override
  Future<OsintDataset<Map<String, dynamic>>> download() async {
    final now = nowUtc;
    _lastAttempt = now;
    final previous = cached;
    String? validator(String? value) =>
        value != null &&
            value.length <= 1024 &&
            !value.contains(RegExp(r'[\r\n]'))
        ? value
        : null;
    final etag = validator(previous?.httpEtag),
        modified = validator(previous?.httpLastModified);
    Map<String, String> headers = const {};
    var unchanged = false;
    final body = await _transport.read<String>(
      sourceUri,
      maxBytes: 4 * 1024 * 1024,
      headers: {
        'Accept': 'application/geo+json, application/json',
        'If-None-Match': ?etag,
        if (etag == null && modified != null) 'If-Modified-Since': modified,
      },
      onHeaders: (value) => headers = value,
      onNotModified: previous != null && (etag != null || modified != null)
          ? () {
              unchanged = true;
              return '';
            }
          : null,
      consume: (chunks) async {
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in chunks) {
          bytes.add(chunk);
        }
        return utf8.decode(bytes.takeBytes());
      },
    );
    final data = unchanged
        ? previous!.data
        : body.length < 65536
        ? parseAvalancheBulletin(body)
        : await compute(parseAvalancheBulletin, body);
    DateTime? published, from, until, nextUpdate;
    for (final a in data['areas']) {
      final p = avalancheDate(a['publishedUtc']),
          start = avalancheDate(a['fromUtc']),
          end = avalancheDate(a['untilUtc']);
      if (p.isAfter(now.add(const Duration(minutes: 2)))) {
        throw const FormatException(
          'SLF-Publikationszeit liegt in der Zukunft',
        );
      }
      published = published == null || p.isAfter(published) ? p : published;
      from = from == null || start.isBefore(from) ? start : from;
      until = until == null || end.isAfter(until) ? end : until;
      if (a['nextUpdateUtc'] != null) {
        final next = avalancheDate(a['nextUpdateUtc']);
        nextUpdate = nextUpdate == null || next.isBefore(nextUpdate)
            ? next
            : nextUpdate;
      }
    }
    var expires = DateTime.fromMillisecondsSinceEpoch(
      math.min(
        math.min(
          now.add(cacheDuration).millisecondsSinceEpoch,
          until?.millisecondsSinceEpoch ??
              now.add(cacheDuration).millisecondsSinceEpoch,
        ),
        nextUpdate?.millisecondsSinceEpoch ??
            now.add(cacheDuration).millisecondsSinceEpoch,
      ),
      isUtc: true,
    );
    // A live empty response is meaningful (no active bulletin), not level 1.
    final control = headers['cache-control'] ?? '';
    final noStore =
        RegExp(
          r'(^|,)\s*(no-store|private)\s*(=|,|$)',
          caseSensitive: false,
        ).hasMatch(control) ||
        unchanged &&
            !headers.containsKey('cache-control') &&
            !previous!.persistable;
    final checkAgain =
        noStore ||
        RegExp(
          r'(^|,)\s*no-cache\s*(,|$)',
          caseSensitive: false,
        ).hasMatch(control) ||
        unchanged &&
            !headers.containsKey('cache-control') &&
            previous!.requiresRevalidation;
    final maxAge = RegExp(
      r'(^|,)\s*max-age\s*=\s*"?(\d+)"?',
      caseSensitive: false,
    ).firstMatch(control);
    final seconds = maxAge == null ? null : int.tryParse(maxAge[2]!);
    final age = int.tryParse(headers['age'] ?? '') ?? 0;
    final lifetime = seconds != null
        ? Duration(
            seconds: math.max(0, math.min(1800, seconds - math.max(0, age))),
          )
        : unchanged && !headers.containsKey('cache-control')
        ? previous!.cacheExpiresAtUtc.difference(
            previous.lastCheckedAtUtc ?? previous.fetchedAtUtc,
          )
        : cacheDuration;
    final httpExpiry = now.add(lifetime.isNegative ? Duration.zero : lifetime);
    if (httpExpiry.isBefore(expires)) expires = httpExpiry;
    return OsintDataset(
      source: source,
      data: data,
      fetchedAtUtc: unchanged ? previous!.fetchedAtUtc : now,
      lastCheckedAtUtc: now,
      cacheExpiresAtUtc: checkAgain || expires.isBefore(now) ? now : expires,
      publishedAtUtc: published,
      validity: from == null
          ? null
          : OsintValidityPeriod(from: from, until: until),
      httpEtag:
          validator(headers['etag']) ?? (unchanged ? previous?.httpEtag : null),
      httpLastModified:
          validator(headers['last-modified']) ??
          (unchanged ? previous?.httpLastModified : null),
      persistable: !noStore,
      requiresRevalidation: checkAgain,
    );
  }

  @override
  void dispose() {
    _transport.dispose();
    super.dispose();
  }
}
