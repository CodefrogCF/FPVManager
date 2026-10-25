import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xml/xml.dart';
import 'package:fpvmanager/core/osint/osint_provider_state.dart';
import 'package:fpvmanager/features/mobility/road_routing.dart';
import 'package:fpvmanager/features/mobility/traffic_counters_provider.dart';

String counterTable({String version = '1', String siteVersion = '1'}) =>
    '''
<d2LogicalModel xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><payloadPublication xsi:type="MeasurementSiteTablePublication"><publicationTime>2026-10-25T09:00:00Z</publicationTime>
<measurementSiteTable id="OTD:TrafficData" version="$version"><measurementSiteRecord id="CH:001.01" version="$siteVersion"><measurementSpecificCharacteristics index="custom-flow"><measurementSpecificCharacteristics><period>60</period><specificMeasurementValueType>trafficFlow</specificMeasurementValueType><specificVehicleCharacteristics><vehicleType>car</vehicleType></specificVehicleCharacteristics></measurementSpecificCharacteristics></measurementSpecificCharacteristics>
<measurementSpecificCharacteristics index="custom-speed"><measurementSpecificCharacteristics><period>60</period><specificMeasurementValueType>trafficSpeed</specificMeasurementValueType><specificVehicleCharacteristics><vehicleType>car</vehicleType></specificVehicleCharacteristics></measurementSpecificCharacteristics></measurementSpecificCharacteristics>
<measurementSiteLocation><pointCoordinates><latitude>47</latitude><longitude>8</longitude></pointCoordinates><lane>lane 1</lane></measurementSiteLocation></measurementSiteRecord>
<measurementSiteRecord id="far" version="1"><pointCoordinates><latitude>45.8</latitude><longitude>10.5</longitude></pointCoordinates></measurementSiteRecord></measurementSiteTable></payloadPublication></d2LogicalModel>''';
String counterValues({
  String tableVersion = '1',
  String siteVersion = '1',
  bool error = false,
}) =>
    '''
<d2LogicalModel xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><payloadPublication xsi:type="MeasuredDataPublication"><publicationTime>2026-10-25T10:00:20Z</publicationTime><measurementSiteTableReference id="OTD:TrafficData" version="$tableVersion"/>
<siteMeasurements><measurementSiteReference id="CH:001.01" version="$siteVersion"/><measurementTimeDefault>2026-10-25T10:00:00Z</measurementTimeDefault>
<measuredValue index="custom-flow"><measuredValue><basicData xsi:type="TrafficFlow"><vehicleFlow><vehicleFlowRate xsi:type="VehiclesPerHour">1200</vehicleFlowRate></vehicleFlow></basicData></measuredValue></measuredValue>
<measuredValue index="custom-speed"><measuredValue><basicData xsi:type="TrafficSpeed">${error ? '<dataError>true</dataError>' : ''}<averageVehicleSpeed><speed xsi:type="KilometresPerHour">76.5</speed></averageVehicleSpeed></basicData></measuredValue></measuredValue>
<measuredValue index="unknown"><measuredValue><basicData xsi:type="TrafficSpeed"><speed>99</speed></basicData></measuredValue></measuredValue>
</siteMeasurements></payloadPublication></d2LogicalModel>''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('counter metadata and filtered measurements use the separate key and exact endpoint; source definitions control units/classification', () async {
    var now = DateTime.utc(2026, 10, 25, 10, 0, 30), requests = 0, fail = false;
    final provider = TrafficCountersProvider(
      center: MobilityPoint(47, 8),
      readKey: () async => 'counter-test-key',
      now: () => now,
      client: MockClient((request) async {
        requests++;
        expect(request.url.toString(), TrafficCountersProvider.endpoint);
        expect(request.followRedirects, false);
        expect(request.headers['Authorization'], 'Bearer counter-test-key');
        expect(request.body, isNot(contains('counter-test-key')));
        final xml = XmlDocument.parse(request.body),
            op = request.headers['SOAPAction']!;
        if (op.endsWith('pullMeasurementSiteTable')) {
          return http.Response(counterTable(), 200);
        }
        final references = xml.descendants
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'siteRequestReference')
            .toList();
        expect(references, hasLength(1));
        expect(references.single.getAttribute('id'), r'CH:001\.01');
        return http.Response(fail ? '<d2LogicalModel>' : counterValues(), 200);
      }),
    );
    addTearDown(provider.dispose);
    final first = await provider.fetch();
    expect(requests, 2);
    expect(first.persistable, false);
    expect(first.data['features'], hasLength(1));
    final record = first.data['features'].single;
    expect(record['geometry']['coordinates'], [8.0, 47.0]);
    expect(record['values'][0]['value'], 1200);
    expect(record['values'][0]['vehicle'], 'car');
    expect(record['values'][1]['value'], 76.5);
    expect(record['values'][2]['value'], isNull);
    expect(first.data.toString(), isNot(contains('counter-test-key')));
    await expectLater(provider.fetch(forceRefresh: true), throwsException);
    expect(requests, 2);
    now = now.add(const Duration(minutes: 1));
    fail = true;
    await expectLater(provider.fetch(forceRefresh: true), throwsException);
    expect(identical(provider.cached, first), true);
    expect(provider.status.dataState, OsintDataState.refreshFailed);
    now = now.add(const Duration(minutes: 1));
    fail = false;
    await provider.fetch(forceRefresh: true);
    expect(requests, 4);
  });
  test('table changes trigger metadata reload; incompatible detector versions are not guessed', () async {
    var tableRequests = 0;
    final provider = TrafficCountersProvider(
      center: MobilityPoint(47, 8),
      readKey: () async => 'fixture',
      client: MockClient((request) async {
        if (request.headers['SOAPAction']!.endsWith(
          'pullMeasurementSiteTable',
        )) {
          tableRequests++;
          return http.Response(
            counterTable(version: tableRequests == 1 ? '1' : '2'),
            200,
          );
        }
        return http.Response(
          counterValues(tableVersion: '2', siteVersion: 'new-unknown'),
          200,
        );
      }),
    );
    addTearDown(provider.dispose);
    await expectLater(provider.fetch(), throwsException);
    expect(tableRequests, 2);
    expect(provider.cached, isNull);
  });
  test(
    'failed sensor values and unsupported XML never become valid measurements',
    () async {
      final parsed = await parseCounterPublication(
        Stream.value(utf8.encode(counterValues(error: true))),
        table: false,
      );
      expect(parsed['records'].single['values'][1]['error'], true);
      expect(parsed['records'].single['values'][1]['value'], isNull);
      for (final xml in [
        '<!DOCTYPE x SYSTEM "https://example.invalid"><d2LogicalModel/>',
        '<soap><Fault>private error</Fault></soap>',
        counterTable().substring(0, 500),
      ]) {
        await expectLater(
          parseCounterPublication(Stream.value(utf8.encode(xml)), table: true),
          throwsFormatException,
        );
      }
    },
  );
}
