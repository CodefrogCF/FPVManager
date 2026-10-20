import '../../../core/osint/geojson_osint_provider.dart';
import '../../../core/osint/osint_source.dart';

class SwissUasProvider extends GeoJsonOsintProvider {
  SwissUasProvider({super.client, super.cacheDuration, super.now})
    : super(source: defaultSource);

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
    // The inspected catalogue declares no licence. Do not infer CC/OGD rights
    // from public access, swisstopo's separate terms or HTTP headers.
    attribution: '© FOCA / BAZL',
    coordinateReference: 'EPSG:4326',
  );
}
