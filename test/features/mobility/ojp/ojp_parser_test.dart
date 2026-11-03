import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/features/mobility/ojp/ojp_models.dart';
import 'package:fpvmanager/features/mobility/ojp/ojp_parser.dart';

const ojpFixture = '''<?xml version="1.0" encoding="UTF-8"?>
<siri:OJP xmlns:siri="http://www.siri.org.uk/siri" xmlns:ojp="http://www.vdv.de/ojp" version="2.0">
  <ojp:OJPResponse><siri:ServiceDelivery><ojp:OJPTripDelivery>
    <ojp:TripResult><ojp:Id>trip-1</ojp:Id><ojp:Trip>
      <ojp:Id>trip-1</ojp:Id>
      <ojp:StartTime>2026-11-03T12:55:00Z</ojp:StartTime>
      <ojp:EndTime>2026-11-03T14:00:00Z</ojp:EndTime>
      <ojp:Transfers>1</ojp:Transfers>
      <ojp:Leg><ojp:Duration>PT5M</ojp:Duration><ojp:ContinuousLeg>
        <ojp:LegStart><ojp:Name><ojp:Text>Spot</ojp:Text></ojp:Name></ojp:LegStart>
        <ojp:LegEnd><ojp:Name><ojp:Text>Station</ojp:Text></ojp:Name></ojp:LegEnd>
        <ojp:Service><ojp:PersonalMode>foot</ojp:PersonalMode></ojp:Service>
        <ojp:Length>350</ojp:Length>
      </ojp:ContinuousLeg></ojp:Leg>
      <ojp:Leg><ojp:TimedLeg>
        <ojp:LegBoard><ojp:StopPointName><ojp:Text>Bern</ojp:Text></ojp:StopPointName>
          <ojp:ServiceDeparture><ojp:TimetabledTime>2026-11-03T13:00:00Z</ojp:TimetabledTime>
          <ojp:EstimatedTime>2026-11-03T13:02:00Z</ojp:EstimatedTime></ojp:ServiceDeparture>
        </ojp:LegBoard>
        <ojp:LegAlight><ojp:StopPointName><ojp:Text>Olten</ojp:Text></ojp:StopPointName>
          <ojp:ServiceArrival><ojp:TimetabledTime>2026-11-03T13:26:00Z</ojp:TimetabledTime></ojp:ServiceArrival>
        </ojp:LegAlight>
        <ojp:Service><ojp:Mode><ojp:PtMode>rail</ojp:PtMode></ojp:Mode>
          <ojp:PublishedServiceName><ojp:Text>IC 8</ojp:Text></ojp:PublishedServiceName></ojp:Service>
      </ojp:TimedLeg></ojp:Leg>
      <ojp:Leg><ojp:TransferLeg><ojp:TransferType>walk</ojp:TransferType>
        <ojp:LegStart><ojp:Name><ojp:Text>Olten 1</ojp:Text></ojp:Name></ojp:LegStart>
        <ojp:LegEnd><ojp:Name><ojp:Text>Olten 4</ojp:Text></ojp:Name></ojp:LegEnd>
        <ojp:Duration>PT4M</ojp:Duration>
      </ojp:TransferLeg></ojp:Leg>
      <ojp:Leg><ojp:TimedLeg>
        <ojp:LegBoard><ojp:StopPointName><ojp:Text>Olten</ojp:Text></ojp:StopPointName>
          <ojp:ServiceDeparture><ojp:TimetabledTime>2026-11-03T13:35:00Z</ojp:TimetabledTime></ojp:ServiceDeparture></ojp:LegBoard>
        <ojp:LegAlight><ojp:StopPointName><ojp:Text>Zürich</ojp:Text></ojp:StopPointName>
          <ojp:ServiceArrival><ojp:TimetabledTime>2026-11-03T14:00:00Z</ojp:TimetabledTime></ojp:ServiceArrival></ojp:LegAlight>
      </ojp:TimedLeg></ojp:Leg>
    </ojp:Trip></ojp:TripResult>
  </ojp:OJPTripDelivery></siri:ServiceDelivery></ojp:OJPResponse>
</siri:OJP>''';

void main() {
  test('parses prefixed OJP 2.0, walk, transfer and independent realtime', () {
    final result = const OjpTripParser().parse(ojpFixture);
    expect(result, hasLength(1));
    final trip = result.single;
    expect(trip.transfers, 1);
    expect(trip.startUtc, DateTime.utc(2026, 11, 3, 12, 55));
    expect(trip.legs.map((l) => l.kind), [
      OjpLegKind.walk,
      OjpLegKind.publicTransport,
      OjpLegKind.walk,
      OjpLegKind.publicTransport,
    ]);
    expect(trip.legs.first.distanceMetres, 350);
    expect(trip.legs[1].line, 'IC 8');
    expect(trip.legs[1].departure.hasRealtimeChange, true);
    expect(trip.legs[1].departure.timetableUtc, DateTime.utc(2026, 11, 3, 13));
    expect(
      trip.legs[1].departure.estimatedUtc,
      DateTime.utc(2026, 11, 3, 13, 2),
    );
    expect(trip.legs[2].duration, const Duration(minutes: 4));
  });

  test('accepts offset timestamps and normalizes to UTC', () {
    final text = ojpFixture.replaceAll(
      '2026-11-03T13:00:00Z',
      '2026-11-03T14:00:00+01:00',
    );
    final leg = const OjpTripParser().parse(text).single.legs[1];
    expect(leg.departure.timetableUtc, DateTime.utc(2026, 11, 3, 13));
  });

  test('handles empty journeys and service errors', () {
    expect(const OjpTripParser().parse('<OJP><OJPResponse/></OJP>'), isEmpty);
    expect(
      () => const OjpTripParser().parse(
        '<OJP><ErrorMessage>oops</ErrorMessage></OJP>',
      ),
      throwsFormatException,
    );
  });

  test('rejects missing timezone and DTD XML', () {
    expect(
      () => const OjpTripParser().parse(
        ojpFixture.replaceFirst('2026-11-03T12:55:00Z', '2026-11-03T12:55:00'),
      ),
      throwsFormatException,
    );
    expect(
      () => const OjpTripParser().parse('<!DOCTYPE OJP><OJP/>'),
      throwsFormatException,
    );
  });
}
