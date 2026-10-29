import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/osint/osint_cache_database.dart';
import '../../core/osint/osint_dataset.dart';
import '../../core/osint/osint_dataset_store.dart';
import '../../core/osint/osint_source.dart';
import 'tmc_table.dart';

const tmcCatalogUrl = 'https://data.opentransportdata.swiss/dataset/rds-tmc';
const _resources = {
  '7.3': '37812015-c6dc-4c57-9417-20db15e703aa',
  '7.4': '4344eb97-060d-4199-82c5-aa68912428f4',
  '7.5': 'b1fb7993-6e2b-4825-b386-4e32d79405c1',
};
Uri tmcDownloadUri(String version) {
  final resource = _resources[version];
  if (resource == null) {
    throw const FormatException(
      'Für diese TMC-Version ist kein LTEF-ZIP hinterlegt. Offiziellen Katalog prüfen; GeoPackage-Dateien werden noch nicht unterstützt.',
    );
  }
  return Uri.parse(
    'https://data.opentransportdata.swiss/de/dataset/70c603be-92c8-4581-bab7-d97ab06bb490/resource/$resource/download/tmc_location_codes_v${version.replaceAll(".", "-")}.zip',
  );
}

OsintSource tmcSource(String version) => OsintSource(
  id: 'astra-tmc-4-9-$version',
  name: 'Schweizer TMC-Ortstabelle $version',
  publisher: 'ASTRA',
  dataUri: Uri.parse('$tmcCatalogUrl#table-$version'),
  metadataUri: Uri.parse(tmcCatalogUrl),
  attribution:
      'TMC-Ortsdaten: ASTRA / opentransportdata.swiss · Tabelle $version',
  licenseName: 'ASTRA / Open Data; siehe Ressource',
  licenseUri: Uri.parse('https://opentransportdata.swiss/de/tac-fedro/'),
  coordinateReference: 'EPSG:4326',
);

Map<String, dynamic> _import(Uint8List bytes) => importTmcTable(bytes).toJson();

class TmcSnapshot {
  const TmcSnapshot(this.table, this.retrievedUtc, this.imported);
  final TmcTable table;
  final DateTime retrievedUtc;
  final bool imported;
}

/// Reference tables persist independently of short-lived traffic snapshots.
/// Downloading requires an explicit user action; receiving codes only restores
/// matching local tables. No credentials or user coordinates enter these requests.
class TmcRepository extends ChangeNotifier {
  TmcRepository({this.storage, http.Client? client, DateTime Function()? now})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _now = now ?? DateTime.now;
  OsintDatasetStore<Map<String, dynamic>>? _store;
  final OsintDatasetStore<Map<String, dynamic>>? storage;
  OsintCacheDatabase? _ownedDatabase;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _now;
  final _snapshots = <String, TmcSnapshot>{}, _restored = <String>{};
  final _restoring = <String, Future<void>>{};
  final _aborts = <Completer<void>>{};
  Future<void>? _pending;
  bool _disposed = false, _clearing = false;
  int _epoch = 0;
  String? error, loadingVersion;
  bool get busy => _pending != null || _clearing;
  Map<String, TmcSnapshot> get snapshots => Map.unmodifiable(_snapshots);
  static List<String> get downloadableVersions => _resources.keys.toList();
  OsintDatasetStore<Map<String, dynamic>> get store => _store ??=
      storage ??
      JsonOsintDatasetStore(
        database: () => _ownedDatabase ??= OsintCacheDatabase.open(),
        storageTerms: Uri.parse(
          'https://opentransportdata.swiss/de/tac-fedro/',
        ),
        retention: const Duration(days: 3650),
        maxBytes: 12 * 1024 * 1024,
      );

  Future<void> restore(Iterable<String> versions) async {
    for (final version in versions.toSet().take(8)) {
      if (_disposed ||
          !RegExp(r'^7\.\d{1,2}$').hasMatch(version) ||
          _restored.contains(version)) {
        continue;
      }
      if (_snapshots.length >= 8 && !_snapshots.containsKey(version)) {
        error = 'Maximal acht TMC-Versionen gleichzeitig. Nicht benötigte Tabellen entfernen.';
        _restored.add(version);
        notifyListeners();
        continue;
      }
      await (_restoring[version] ??= _read(version).whenComplete(() {
        _restoring.remove(version);
      }));
    }
  }

  Future<void> _read(String version) async {
    final epoch = _epoch;
    try {
      final saved = await store.read(tmcSource(version), _now().toUtc());
      if (saved != null) {
        final table = await compute(_restoreTable, saved.data);
        if (table.version != version) {
          throw const FormatException('Gespeicherte TMC-Version stimmt nicht');
        }
        if (!_disposed &&
            !_clearing &&
            epoch == _epoch &&
            !_snapshots.containsKey(version)) {
          _snapshots[version] = TmcSnapshot(
            table,
            saved.fetchedAtUtc,
            saved.requiresRevalidation,
          );
        }
      }
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        error =
            'Gespeicherte TMC-Tabelle $version konnte nicht geladen werden. Erneut laden oder importieren.';
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        _restored.add(version);
        notifyListeners();
      }
    }
  }

  Future<void> download(String version) => _perform(version, () async {
    if (kIsWeb) {
      throw const FormatException(
        'Im Web das offizielle ZIP herunterladen und hier importieren. Der Dateispeicher verwendet Weiterleitungen, die nicht überall für Browser freigegeben sind.',
      );
    }
    final uri = tmcDownloadUri(version);
    return _download(uri).timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        _cancelTransfers();
        throw TimeoutException('TMC-Download hat zu lange gedauert');
      },
    );
  }, imported: false);

  Future<void> importZip(Uint8List bytes, {required String version}) =>
      _perform(version, () async => bytes, imported: true);

  Future<void> _perform(
    String version,
    Future<Uint8List> Function() read, {
    required bool imported,
  }) {
    if (_disposed || busy) {
      return Future.error(StateError('TMC-Vorgang bereits aktiv oder beendet'));
    }
    if (!RegExp(r'^7\.\d{1,2}$').hasMatch(version)) {
      return Future.error(const FormatException('Ungültige TMC-Version'));
    }
    if (_snapshots.length >= 8 && !_snapshots.containsKey(version)) {
      return Future.error(
        const FormatException(
          'Maximal acht TMC-Versionen gleichzeitig. Nicht benötigte Tabellen entfernen.',
        ),
      );
    }
    final completion = Completer<void>();
    _pending = completion.future;
    loadingVersion = version;
    error = null;
    final epoch = ++_epoch;
    notifyListeners();
    unawaited(() async {
      try {
        final bytes = await read();
        if (_disposed || epoch != _epoch) {
          throw StateError('TMC-Vorgang abgebrochen');
        }
        final data = await compute(_import, bytes);
        final table = TmcTable.fromJson(data);
        if (table.version != version) {
          throw FormatException(
            'Paket enthält TMC ${table.version}, angefordert wurde $version',
          );
        }
        if (_disposed || epoch != _epoch) {
          throw StateError('TMC-Vorgang abgebrochen');
        }
        final now = _now().toUtc();
        // Await cache restoration before publication to prevent an older read
        // overwriting a newer download, and write one atomic snapshot envelope.
        await _restoring[version];
        if (_disposed || epoch != _epoch) {
          throw StateError('TMC-Vorgang abgebrochen');
        }
        await store.write(
          OsintDataset(
            source: tmcSource(version),
            data: data,
            fetchedAtUtc: now,
            cacheExpiresAtUtc: now.add(const Duration(days: 3650)),
            requiresRevalidation: imported,
          ),
        );
        if (!_disposed && epoch == _epoch) {
          _snapshots[version] = TmcSnapshot(table, now, imported);
          _restored.add(version);
        }
        completion.complete();
      } catch (failure, stack) {
        if (!_disposed && epoch == _epoch) {
          error = failure is FormatException ? failure.message : 'TMC-Aktualisierung fehlgeschlagen. Letzte gültige Tabelle bleibt erhalten; Dateiimport oder erneuten Download versuchen.';
        }
        completion.completeError(failure, stack);
      } finally {
        _pending = null;
        loadingVersion = null;
        if (!_disposed) notifyListeners();
      }
    }());
    return completion.future;
  }

  Future<Uint8List> _download(Uri initial) async {
    var uri = initial;
    final abort = Completer<void>();
    _aborts.add(abort);
    try {
      for (var redirect = 0; redirect < 3; redirect++) {
        final request = http.AbortableRequest(
          'GET',
          uri,
          abortTrigger: abort.future,
        )..followRedirects = false;
        final response = await _client.send(request);
        if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
          final location = response.headers['location'];
          await response.stream.listen((_) {}).cancel();
          if (location == null) {
            throw const FormatException('TMC-Download ohne Weiterleitungsziel');
          }
          final target = uri.resolve(location);
          final allowed =
              target.host == 'data.opentransportdata.swiss' ||
              target.host ==
                      '83025b28472d6aa2bf5ae59f3724aa78.eu.r2.cloudflarestorage.com' &&
                  target.path.startsWith('/dx-omd-prod/resources/');
          if (target.scheme != 'https' ||
              target.userInfo.isNotEmpty ||
              target.hasFragment ||
              target.port != 443 ||
              !allowed) {
            throw const FormatException(
              'TMC-Download verweist auf eine unbekannte Quelle',
            );
          }
          uri = target;
          continue;
        }
        if (response.statusCode != 200 ||
            (response.contentLength ?? 0) > 8 * 1024 * 1024) {
          await response.stream.listen((_) {}).cancel();
          throw FormatException(
            'TMC-Download nicht verfügbar (HTTP ${response.statusCode}) oder zu groß',
          );
        }
        final bytes = BytesBuilder(copy: false);
        var received = 0;
        await for (final chunk in response.stream) {
          received += chunk.length;
          if (_disposed || abort.isCompleted || received > 8 * 1024 * 1024) {
            throw const FormatException(
              'TMC-Download abgebrochen / Größenlimit überschritten',
            );
          }
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      }
      throw const FormatException('Zu viele TMC-Weiterleitungen');
    } finally {
      if (!abort.isCompleted) abort.complete();
      _aborts.remove(abort);
    }
  }

  void _cancelTransfers() {
    for (final abort in _aborts) {
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<void> remove(String version) async {
    if (_disposed || _clearing) return;
    _clearing = true;
    ++_epoch;
    _cancelTransfers();
    notifyListeners();
    try {
      try {
        await _pending;
      } catch (_) {
        /* Drain the cancelled replacement. */
      }
      await Future.wait(_restoring.values.toList());
      await store.remove(tmcSource(version).id);
      _snapshots.remove(version);
      _restored.remove(version);
      error = null;
    } finally {
      _clearing = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_epoch;
    _cancelTransfers();
    if (_ownsClient) _client.close();
    unawaited(() async {
      try {
        await _pending;
      } catch (_) {
        /* Drain active imports. */
      }
      await Future.wait(_restoring.values.toList());
      await _ownedDatabase?.close();
    }());
    super.dispose();
  }
}

TmcTable _restoreTable(Map<String, dynamic> data) => TmcTable.fromJson(data);
