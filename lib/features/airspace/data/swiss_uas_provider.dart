import 'package:flutter/foundation.dart';

import '../../../core/osint/geojson_osint_provider.dart';
import '../../../core/osint/osint_source.dart';
import '../uas_dataset_assessment.dart';

class SwissUasProvider extends GeoJsonOsintProvider {
  SwissUasProvider({
    super.client,
    super.cacheDuration,
    super.now,
    super.persistentCache,
  }) : super(source: defaultSource, conditionalRequests: !kIsWeb);

  static final Uri datasetUri = Uri.parse(
    'https://data.geo.admin.ch/ch.bazl.einschraenkungen-drohnen/'
    'einschraenkungen-drohnen/einschraenkungen-drohnen_4326.geojson',
  );

  static final defaultSource = OsintSource(
    id: 'ch.bazl.uas-zones',
    name: 'Swiss UAS Geographical Zones',
    publisher: 'FOCA / BAZL',
    dataUri: datasetUri,
    metadataUri: Uri.parse(
      'https://opendata.swiss/en/dataset/geografische-uas-gebiete-der-schweiz',
    ),
    // The STAC collection's rel=license links explicitly to terms_by.
    // CKAN's missing licence is not a Creative Commons declaration.
    licenseName: 'Open use. Must provide the source (STAC terms)',
    licenseUri: Uri.parse('https://opendata.swiss/en/terms-of-use/#terms_by'),
    attribution: '© FOCA / BAZL',
    coordinateReference: 'EPSG:4326',
  );

  @override
  void validateData(Map<String, dynamic> data) {
    super.validateData(data);
    UasDatasetAssessment.inspect(data);
  }
}
