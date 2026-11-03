import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/features/mobility/drought/drought_metadata.dart';

const collectionFixture =
    '{"id":"ch.swisstopo.swisseo_vhi_v100",'
    '"updated":"2026-11-03T09:00:00Z"}';
const itemsFixture =
    '{"type":"FeatureCollection","features":['
    '{"collection":"ch.swisstopo.swisseo_vhi_v100","properties":{'
    '"datetime":"2026-11-01T00:00:00Z",'
    '"start_datetime":"2026-10-26T00:00:00Z",'
    '"end_datetime":"2026-11-01T00:00:00Z",'
    '"updated":"2026-11-02T12:00:00Z"}},'
    '{"collection":"ch.swisstopo.swisseo_vhi_v100","properties":{'
    '"datetime":"2026-10-30T00:00:00Z"}}]}';

void main() {
  final now = DateTime.utc(2026, 11, 3, 12);
  test('STAC preserves source observation, period, publication and fetch separately', () {
    final data = parseDroughtVhiStac(
      collectionFixture,
      itemsFixture,
      fetchedUtc: now,
    );
    expect(data.observedUtc, DateTime.utc(2026, 11, 1));
    expect(data.periodStartUtc, DateTime.utc(2026, 10, 26));
    expect(data.periodEndUtc, DateTime.utc(2026, 11, 1));
    expect(data.publishedUtc, DateTime.utc(2026, 11, 2, 12));
    expect(data.fetchedUtc, now);
    expect(data.state(now), OsintDataState.fresh);
    expect(
      DroughtVhiMetadata.decode(data.encode()).observedUtc,
      data.observedUtc,
    );
  });

  test(
    'a collection updated date is never substituted for missing observation',
    () {
      final data = parseDroughtVhiStac(
        collectionFixture,
        '{"features":[{"collection":"ch.swisstopo.swisseo_vhi_v100",'
        '"properties":{"datetime":null}}]}',
        fetchedUtc: now,
      );
      expect(data.observedUtc, isNull);
      expect(data.publishedUtc, isNull);
      expect(data.state(now), OsintDataState.unavailable);
    },
  );

  test(
    'stale observations, clock skew and refresh failures remain explicit',
    () {
      final data = parseDroughtVhiStac(
        collectionFixture,
        itemsFixture,
        fetchedUtc: now,
      );
      expect(
        data.state(now.add(const Duration(days: 11))),
        OsintDataState.stale,
      );
      expect(
        data.state(now.subtract(const Duration(minutes: 1))),
        OsintDataState.clockSkew,
      );
      expect(
        data.asCached(failed: true).state(now),
        OsintDataState.refreshFailed,
      );
      expect(data.asCached(failed: true).fromCache, true);
    },
  );

  test(
    'only documented CDI steps exist and future steps are labelled forecasts',
    () {
      expect(DroughtTimeStep.values.map((e) => e.value), [0, 1, 2, 3, 4]);
      expect(DroughtTimeStep.current.isForecast, false);
      expect(DroughtTimeStep.inTwoWeeks.isForecast, true);
      expect(DroughtTimeStep.next.label, contains('Prognose'));
    },
  );

  test('rejects wrong collection and excessive JSON', () {
    expect(
      () =>
          parseDroughtVhiStac('{"id":"other"}', itemsFixture, fetchedUtc: now),
      throwsFormatException,
    );
    expect(
      () => parseDroughtVhiStac(
        collectionFixture,
        List.filled(600001, 'x').join(),
        fetchedUtc: now,
      ),
      throwsFormatException,
    );
  });

  test(
    'unsupported data and missing values are not assigned an index value',
    () {
      final data = parseDroughtVhiStac(
        collectionFixture,
        '{"features":[]}',
        fetchedUtc: now,
      );
      expect(data.observedUtc, null);
      expect(data.state(now), OsintDataState.unavailable);
      // No numeric VHI data are parsed from STAC, nor interpreted as zero.
    },
  );
}
