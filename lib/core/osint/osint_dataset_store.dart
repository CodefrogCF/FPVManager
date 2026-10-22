import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'osint_cache_database.dart';
import 'osint_dataset.dart';
import 'osint_source.dart';

/// Optional provider-specific persistence. Tiles and terrain never use this API.
abstract interface class OsintDatasetStore<T> {
  Future<OsintDataset<T>?> read(OsintSource source, DateTime now);
  Future<void> write(OsintDataset<T> dataset);
  Future<void> remove(String providerId);
  Future<void> cleanup(DateTime now);
}

/// JSON adapters must explicitly supply verified storage terms. This is not an
/// export/redistribution interface; source provenance remains in each envelope.
class JsonOsintDatasetStore implements OsintDatasetStore<Map<String, dynamic>> {
  JsonOsintDatasetStore({
    required this.database,
    required this.storageTerms,
    this.retention = const Duration(days: 30),
    this.maxBytes = 64 * 1024 * 1024,
  }) {
    if (storageTerms.scheme != 'https' ||
        retention <= Duration.zero ||
        maxBytes <= 0) {
      throw ArgumentError('Invalid persistent cache policy');
    }
  }
  final OsintCacheDatabase Function() database;
  final Uri storageTerms;
  final Duration retention;
  final int maxBytes;

  @override
  Future<OsintDataset<Map<String, dynamic>>?> read(
    OsintSource source,
    DateTime now,
  ) async {
    await cleanup(now);
    try {
      final record = await database().readSnapshot(source.id, maxBytes);
      if (record == null) return null;
      if (sha256.convert(utf8.encode(record.$1)).toString() != record.$2) {
        throw const FormatException('Cached dataset checksum mismatch');
      }
      final envelope = jsonDecode(record.$1) as Map<String, dynamic>;
      if (envelope['version'] != 1 ||
          envelope['storageTerms'] != storageTerms.toString()) {
        throw const FormatException(
          'Unsupported cache version or storage terms',
        );
      }
      final raw = envelope['source'] as Map<String, dynamic>;
      if (raw['id'] != source.id ||
          raw['dataUri'] != source.dataUri.toString() ||
          raw['coordinateReference'] != source.coordinateReference) {
        throw const FormatException(
          'Cached dataset source does not match adapter',
        );
      }
      DateTime date(String key) {
        final value = envelope[key];
        if (value is! String || !value.endsWith('Z')) {
          throw const FormatException('Invalid cached UTC timestamp');
        }
        return DateTime.parse(value);
      }

      final fetched = date('fetchedAt');
      final checked = date('checkedAt');
      final expires = date('expiresAt');
      if (checked.isBefore(fetched) || expires.isBefore(checked)) {
        throw const FormatException('Invalid cached timestamp ordering');
      }
      if (!now.toUtc().isBefore(checked.add(retention))) {
        await remove(source.id);
        return null;
      }
      final dataset = OsintDataset<Map<String, dynamic>>(
        source: OsintSource(
          id: raw['id'] as String,
          name: raw['name'] as String,
          publisher: raw['publisher'] as String,
          dataUri: Uri.parse(raw['dataUri'] as String),
          metadataUri: Uri.parse(raw['metadataUri'] as String),
          attribution: raw['attribution'] as String?,
          coordinateReference: raw['coordinateReference'] as String?,
          licenseName: raw['licenseName'] as String?,
          licenseUri: raw['licenseUri'] == null
              ? null
              : Uri.parse(raw['licenseUri'] as String),
        ),
        data: envelope['data'] as Map<String, dynamic>,
        fetchedAtUtc: fetched,
        lastCheckedAtUtc: checked,
        cacheExpiresAtUtc: expires,
        publishedAtUtc: envelope['publishedAt'] == null
            ? null
            : date('publishedAt'),
        validity:
            envelope['validFrom'] == null && envelope['validUntil'] == null
            ? null
            : OsintValidityPeriod(
                from: envelope['validFrom'] == null ? null : date('validFrom'),
                until: envelope['validUntil'] == null
                    ? null
                    : date('validUntil'),
              ),
        httpEtag: envelope['etag'] as String?,
        requiresRevalidation: envelope['requiresRevalidation'] == true,
        httpLastModified: envelope['lastModified'] as String?,
      );
      return dataset;
    } catch (error) {
      await remove(source.id);
      throw FormatException('Local OSINT cache rejected: $error');
    }
  }

  @override
  Future<void> write(OsintDataset<Map<String, dynamic>> dataset) async {
    if (!dataset.persistable) {
      await remove(dataset.providerId);
      return;
    }
    final s = dataset.source;
    final checked = dataset.lastCheckedAtUtc ?? dataset.fetchedAtUtc;
    final payload = jsonEncode({
      'version': 1,
      'storageTerms': storageTerms.toString(),
      'source': {
        'id': s.id,
        'name': s.name,
        'publisher': s.publisher,
        'dataUri': s.dataUri.toString(),
        'metadataUri': s.metadataUri.toString(),
        'attribution': s.attribution,
        'coordinateReference': s.coordinateReference,
        'licenseName': s.licenseName,
        'licenseUri': s.licenseUri?.toString(),
      },
      'data': dataset.data,
      'fetchedAt': dataset.fetchedAtUtc.toIso8601String(),
      'checkedAt': checked.toIso8601String(),
      'expiresAt': dataset.cacheExpiresAtUtc.toIso8601String(),
      'publishedAt': dataset.publishedAtUtc?.toIso8601String(),
      'validFrom': dataset.validity?.fromUtc?.toIso8601String(),
      'validUntil': dataset.validity?.untilUtc?.toIso8601String(),
      'etag': dataset.httpEtag,
      'requiresRevalidation': dataset.requiresRevalidation,
      'lastModified': dataset.httpLastModified,
    });
    final bytes = utf8.encode(payload);
    if (bytes.length > maxBytes) {
      throw const FormatException('Dataset exceeds local cache limit');
    }
    await database().writeSnapshot(
      s.id,
      payload,
      sha256.convert(bytes).toString(),
      checked.add(retention),
    );
  }

  @override
  Future<void> remove(String providerId) =>
      database().removeSnapshot(providerId);
  @override
  Future<void> cleanup(DateTime now) => database().cleanSnapshots(now);
}
