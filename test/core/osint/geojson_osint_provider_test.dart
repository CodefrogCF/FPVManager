import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fpvmanager/core/osint/geojson_osint_provider.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/core/osint/osint_source.dart';

void main() {
  final source = OsintSource(
    id: 'alternative',
    name: 'Alternative airspace',
    publisher: 'Fixture publisher',
    dataUri: Uri.parse('https://example.invalid/data'),
    metadataUri: Uri.parse('https://example.invalid/metadata'),
    licenseName: 'Fixture terms',
    licenseUri: Uri.parse('https://example.invalid/terms'),
    coordinateReference: 'EPSG:4326',
  );

  test('replacement adapter keeps provenance and raw HTTP date without inventing validity', () async {
    final client = MockClient((request) async {
      expect(request.url, source.dataUri);
      return http.Response(
        '{"type":"FeatureCollection","features":[]}',
        200,
        headers: {'last-modified': 'Tue, 20 Oct 2026 06:00:00 GMT'},
      );
    });
    final provider = GeoJsonOsintProvider(source: source, client: client);
    addTearDown(provider.dispose);
    addTearDown(client.close);
    final result = await provider.fetch();
    expect(result.source, same(source));
    expect(result.httpLastModified, 'Tue, 20 Oct 2026 06:00:00 GMT');
    expect(result.validity, isNull);
    expect(
      result.cacheExpiresAtUtc.difference(result.fetchedAtUtc),
      const Duration(hours: 1),
    );
  });

  test(
    'network, timeout and incompatible CRS failures have typed categories',
    () async {
      for (final kind in [
        OsintFailureKind.network,
        OsintFailureKind.timeout,
        OsintFailureKind.invalidData,
      ]) {
        final client = MockClient((_) async {
          if (kind == OsintFailureKind.network) {
            throw http.ClientException('Fixture');
          }
          if (kind == OsintFailureKind.timeout) {
            return Completer<http.Response>().future;
          }
          return http.Response(
            jsonEncode({
              'type': 'FeatureCollection',
              'features': [],
              'crs': {
                'type': 'name',
                'properties': {'name': 'EPSG:2056'},
              },
            }),
            200,
          );
        });
        final provider = GeoJsonOsintProvider(
          source: source,
          client: client,
          requestTimeout: const Duration(milliseconds: 10),
        );
        try {
          await expectLater(
            provider.fetch(),
            throwsA(
              isA<OsintProviderException>().having((e) => e.kind, 'kind', kind),
            ),
          );
          expect(provider.status.error?.kind, kind);
          expect(provider.cached, isNull);
        } finally {
          provider.dispose();
          client.close();
        }
      }
    },
  );
}
