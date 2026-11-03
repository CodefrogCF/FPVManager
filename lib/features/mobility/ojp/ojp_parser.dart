import 'package:xml/xml.dart';

import 'ojp_models.dart';

/// Parse OJP 2.0 by local XML names (both the default and ojp: prefix occur
/// in official examples). No DTD/external entities or unbounded XML accepted.
class OjpTripParser {
  const OjpTripParser();

  List<OjpJourney> parse(String source) {
    if (source.length > 2 * 1024 * 1024 ||
        RegExp(
          r'<!\s*(?:DOCTYPE|ENTITY)',
          caseSensitive: false,
        ).hasMatch(source)) {
      throw const FormatException('Unsupported OJP XML');
    }
    final document = XmlDocument.parse(source);
    if (document.rootElement.name.local != 'OJP') {
      throw const FormatException('Not an OJP response');
    }
    final results = _all(document.rootElement, 'TripResult').toList();
    if (results.isEmpty) {
      final errors = _all(
        document.rootElement,
        'ErrorMessage',
      ).followedBy(_all(document.rootElement, 'ErrorCondition'));
      if (errors.isNotEmpty) {
        throw const FormatException('OJP service returned an error');
      }
      return const [];
    }
    final parsed = <OjpJourney>[];
    for (final result in results.take(8)) {
      final trip = _child(result, 'Trip');
      if (trip == null) continue;
      final start = _utc(_text(_child(trip, 'StartTime')));
      final end = _utc(_text(_child(trip, 'EndTime')));
      if (start == null || end == null || end.isBefore(start)) continue;
      final legs = <OjpLeg>[];
      for (final leg in _children(trip, 'Leg')) {
        final timed = _child(leg, 'TimedLeg');
        final continuous = _child(leg, 'ContinuousLeg');
        final transfer = _child(leg, 'TransferLeg');
        final section = timed ?? continuous ?? transfer;
        if (section == null) continue;
        final board =
            _child(section, 'LegBoard') ?? _child(section, 'LegStart');
        final alight =
            _child(section, 'LegAlight') ?? _child(section, 'LegEnd');
        final service = _child(section, 'Service');
        final transferMode = _text(_child(section, 'TransferType'))
            ?.toLowerCase();
        final personalMode = _text(_child(service, 'PersonalMode'))
            ?.toLowerCase();
        final kind = timed != null
            ? OjpLegKind.publicTransport
            : transfer != null
            ? (transferMode == 'walk' ? OjpLegKind.walk : OjpLegKind.transfer)
            : personalMode == 'foot' || personalMode == 'walk'
            ? OjpLegKind.walk
            : OjpLegKind.other;
        final label =
            _text(_child(_child(service, 'PublishedServiceName'), 'Text')) ??
            _text(_child(service, 'PublicCode')) ??
            _text(_child(_child(_child(service, 'Mode'), 'Name'), 'Text'));
        final length = double.tryParse(_text(_child(section, 'Length')) ?? '');
        legs.add(
          OjpLeg(
            kind: kind,
            from: _placeName(board) ?? 'Start',
            to: _placeName(alight) ?? 'Ziel',
            duration: _duration(
              _text(_child(leg, 'Duration')) ??
                  _text(_child(section, 'Duration')),
            ),
            line: label,
            mode:
                _text(_child(_child(service, 'Mode'), 'PtMode')) ??
                _text(_child(service, 'PersonalMode')),
            distanceMetres: length,
            departure: _serviceTime(_child(board, 'ServiceDeparture')),
            arrival: _serviceTime(_child(alight, 'ServiceArrival')),
          ),
        );
      }
      final count = int.tryParse(_text(_child(trip, 'Transfers')) ?? '');
      final publicTransportLegs = legs
          .where((l) => l.kind == OjpLegKind.publicTransport)
          .length;
      parsed.add(
        OjpJourney(
          id:
              _text(_child(trip, 'Id')) ??
              _text(_child(result, 'Id')) ??
              'unbekannt',
          startUtc: start,
          endUtc: end,
          transfers:
              count ?? (publicTransportLegs > 0 ? publicTransportLegs - 1 : 0),
          legs: legs,
        ),
      );
    }
    return parsed;
  }

  static OjpServiceTime _serviceTime(XmlElement? element) => OjpServiceTime(
    timetableUtc: _utc(_text(_child(element, 'TimetabledTime'))),
    estimatedUtc: _utc(_text(_child(element, 'EstimatedTime'))),
  );

  static DateTime? _utc(String? raw) {
    if (raw == null) return null;
    // No device-local interpretation of an OJP timestamp without an offset.
    if (!RegExp(r'(?:Z|[+-]\d\d:\d\d)$').hasMatch(raw)) {
      throw const FormatException('OJP time zone missing');
    }
    return DateTime.parse(raw).toUtc();
  }

  static Duration? _duration(String? text) {
    if (text == null) return null;
    final match = RegExp(
      r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
    ).firstMatch(text);
    if (match == null) return null;
    return Duration(
      seconds:
          ((int.parse(match.group(1) ?? '0') * 86400) +
                  (int.parse(match.group(2) ?? '0') * 3600) +
                  (int.parse(match.group(3) ?? '0') * 60) +
                  (double.tryParse(match.group(4) ?? '0') ?? 0))
              .round(),
    );
  }

  static String? _placeName(XmlElement? element) {
    final name = _child(element, 'StopPointName') ?? _child(element, 'Name');
    return _text(_child(name, 'Text')) ?? _text(name);
  }

  static XmlElement? _child(XmlElement? element, String name) {
    if (element == null) return null;
    for (final child in element.childElements) {
      if (child.name.local == name) return child;
    }
    return null;
  }

  static Iterable<XmlElement> _children(XmlElement element, String name) =>
      element.childElements.where((element) => element.name.local == name);

  static Iterable<XmlElement> _all(XmlElement element, String name) => element
      .descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == name);

  static String? _text(XmlElement? element) {
    final value = element?.innerText.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
