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
  }) : super(
         source: defaultSource,
         conditionalRequests: !kIsWeb,
         // S22 cold downloads were still progressing at the former 45s cap.
         // Keep an independent 20s inactivity deadline in the streamed adapter.
         requestTimeout: const Duration(seconds: 120),
       );

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

  Map<String, dynamic>? _lastValidatedDocument;
  UasDatasetAssessment? _lastAssessment;

  /// Reuse the assessment performed by the provider at download/cache load.
  /// The document is not copied or mutated; only its identity is retained.
  /// A different document must always be validated again.
  UasDatasetAssessment assessDataset(Map<String, dynamic> document) {
    if (identical(_lastValidatedDocument, document) &&
        _lastAssessment != null) {
      return _lastAssessment!;
    }
    final assessment = UasDatasetAssessment.inspect(document);
    _lastValidatedDocument = document;
    _lastAssessment = assessment;
    return assessment;
  }

  @override
  void validateData(Map<String, dynamic> data) {
    super.validateData(data);
    assessDataset(data);
  }
}
