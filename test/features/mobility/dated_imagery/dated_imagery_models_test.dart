import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/dated_imagery/dated_imagery_models.dart';

const swissCollection = '{"id":"ch.swisstopo.swisseo_s2-sr_v200"}';
const rapidCollection = '{"id":"ch.swisstopo.spezialbefliegungen"}';
const swissItems = '''{"features":[
  {"id":"s2-2026-10-30", "collection":"ch.swisstopo.swisseo_s2-sr_v200",
    "bbox":[7.1,46.5,8.1,47.4],
    "properties":{"datetime":"2026-10-30T10:32:15Z","created":"2026-10-31T14:00:00Z",
    "eo:cloud_cover":73,"title":"Sentinel 2 WGS84","proj:epsg":2056},
    "assets":{"TCI-10M":{"type":"image/tiff; application=geotiff",
      "href":"https://data.geo.admin.ch/swiss-eo-tci.tif"},
      "CLOUDMASK":{"type":"image/tiff","href":"https://data.geo.admin.ch/cloud.tif"}}},
  {"id":"s2-2026-10-29", "collection":"ch.swisstopo.swisseo_s2-sr_v200",
    "bbox":[7.1,46.5,8.1,47.4],"properties":{"datetime":"2026-10-29T10:30:00Z"}},
  {"id":"s2-2026-10-29", "collection":"ch.swisstopo.swisseo_s2-sr_v200",
    "bbox":[7.1,46.5,8.1,47.4],"properties":{"datetime":"2026-10-29T10:30:00Z"}}
]}''';
const rapidItems = '''{"features":[
 {"id":"not-rapid","collection":"ch.swisstopo.spezialbefliegungen",
  "bbox":[7,46,8,48],"properties":{"datetime":"2025-05-30T10:00:00Z"}},
 {"id":"ram-2025-05-30t12000000","collection":"ch.swisstopo.spezialbefliegungen",
  "bbox":[7.1,46.5,8.0,47.0],
  "properties":{"datetime":"2025-05-30T12:00:00Z",
  "title":"Blatten orthophoto","description":"Blatten 2025 landslide / Rapid Mapping",
  "proj:epsg":2056},
  "assets":{"QDOP-RGB":{"href":"https://data.geo.admin.ch/rapid-ortho.tif",
     "type":"image/tiff; application=geotiff"},
    "DSM":{"href":"https://data.geo.admin.ch/dsm.tif","type":"image/tiff"}}},
 {"id":"ram-2024-06-28t10000000","collection":"ch.swisstopo.spezialbefliegungen",
  "bbox":[7.1,46.5,8.0,47.0],
  "properties":{"datetime":"2024-06-28T10:00:00Z"},
  "assets":{"oblique":{"href":"https://data.geo.admin.ch/photo.jpg",
    "type":"image/jpeg"}}}
]}''';

void main() {
  final now = DateTime.utc(2026, 11, 3);
  final bbox = [7.4, 46.8, 7.6, 47.0];
  test('swissEO preserves satellite acquisition, publication, bounds, clouds and masks', () {
    final snapshot = parseDatedImageryStac(
      swissCollection,
      swissItems,
      product: DatedImageryProduct.swissEo,
      fetchedUtc: now,
      requestedBounds: bbox,
    );
    expect(snapshot.items.length, 2); // Duplicate ids are not displayed twice.
    expect(
      snapshot.items.first.acquiredUtc,
      DateTime.utc(2026, 10, 30, 10, 32, 15),
    );
    expect(snapshot.items.first.publishedUtc, DateTime.utc(2026, 10, 31, 14));
    expect(snapshot.items.first.cloudCoverPercent, 73);
    expect(snapshot.items.first.qualityAssetAvailable, true);
    expect(
      snapshot.items.first.displayAsset!.renderKind,
      DatedImageryRenderKind.swissEoWms,
    );
    expect(
      swissEoWmsTime(snapshot.items.first.acquiredUtc),
      '2026-10-30t103215',
    );
    expect(snapshot.items.first.covers(46.8, 7.5), true);
    expect(snapshot.items.first.covers(48, 7.5), false);
    final decoded = DatedImagerySnapshot.decode(snapshot.encode());
    expect(decoded.items.first.publishedUtc, snapshot.items.first.publishedUtc);
    expect(decoded.items.first.bbox, snapshot.items.first.bbox);
    expect(decoded.isOld(now.add(const Duration(days: 2))), true);
  });

  test('Rapid Mapping is event-specific; missing mission metadata and unsupported assets remain explicit', () {
    final snapshot = parseDatedImageryStac(
      rapidCollection,
      rapidItems,
      product: DatedImageryProduct.rapidMapping,
      fetchedUtc: now,
      requestedBounds: bbox,
    );
    expect(snapshot.items.length, 2);
    expect(snapshot.items.first.title, 'Blatten orthophoto');
    expect(snapshot.items.first.missionContext, contains('landslide'));
    expect(
      snapshot.items.first.displayAsset!.renderKind,
      DatedImageryRenderKind.rapidCog,
    );
    expect(snapshot.items.first.displayAsset!.projection, 2056);
    expect(snapshot.items.last.missionContext, 'Ereignis nicht angegeben');
    expect(snapshot.items.last.displayAsset, isNull);
    expect(snapshot.items.last.publishedUtc, isNull);
  });

  test('out-of-area, missing acquisition, unknown coordinates and truncated pages are not coverage', () {
    final empty = parseDatedImageryStac(
      swissCollection,
      '{"features":[{"id":"unknown","collection":"ch.swisstopo.swisseo_s2-sr_v200",'
      '"bbox":[7.0,46.0,8.0,47.5],"properties":{}}]}',
      product: DatedImageryProduct.swissEo,
      fetchedUtc: now,
      requestedBounds: bbox,
    );
    expect(empty.items, isEmpty);
    expect(empty.isEmpty, true);
    expect(
      () => parseDatedImageryStac(
        rapidCollection,
        rapidItems,
        product: DatedImageryProduct.swissEo,
        fetchedUtc: now,
        requestedBounds: bbox,
      ),
      throwsFormatException,
    );
    expect(
      () => parseDatedImageryStac(
        swissCollection,
        swissItems,
        product: DatedImageryProduct.swissEo,
        fetchedUtc: now,
        requestedBounds: [0, 0, 0, 0],
      ),
      throwsFormatException,
    );
    final incomplete = parseDatedImageryStac(
      swissCollection,
      '{"features":[],"links":[{"rel":"next","href":"https://data.geo.admin.ch/x"}]}',
      product: DatedImageryProduct.swissEo,
      fetchedUtc: now,
      requestedBounds: bbox,
    );
    expect(incomplete.incomplete, true);
    expect(incomplete.items, isEmpty);
  });

  test('6D STAC boxes retain WGS84 horizontal extent, no invented height', () {
    final item =
        '{"features":[{"id":"scene-1",'
        '"collection":"ch.swisstopo.swisseo_s2-sr_v200",'
        '"bbox":[7.1,46.5,500,8.1,47.4,700],'
        '"properties":{"datetime":"2026-10-30T10:00:00Z"}}]}';
    final snapshot = parseDatedImageryStac(
      swissCollection,
      item,
      product: DatedImageryProduct.swissEo,
      fetchedUtc: now,
      requestedBounds: bbox,
    );
    expect(snapshot.items.single.bbox, [7.1, 46.5, 8.1, 47.4]);
  });
}
