import 'package:xml/xml.dart';

/// DATEX II methods 2/4. Point roles and offsets must never be merged across parts.
Map<String, dynamic>? readTmcReference(XmlElement record) {
  Iterable<XmlElement> nodes(XmlElement p, String name) =>
      p.descendants.whereType<XmlElement>().where((e) => e.name.local == name);
  String? text(XmlElement p, String name) =>
      nodes(p, name).firstOrNull?.innerText.trim();
  final candidates = record.descendants
      .whereType<XmlElement>()
      .where((e) => {'alertCLinear', 'alertCPoint'}.contains(e.name.local))
      .toList();
  if (candidates.isEmpty) return null;
  if (candidates.length != 1) {
    return {'unsupported': 'Mehrere TMC-Ortsreferenzen in einer Teilmeldung'};
  }
  final node = candidates.single;
  final type =
      node.attributes
          .where((a) => a.name.local == 'type')
          .firstOrNull
          ?.value
          .split(':')
          .last ??
      '';
  final method = RegExp(r'^AlertCMethod([24])(Point|Linear)$').firstMatch(type);
  final number = method?.group(1);
  Map<String, dynamic>? point(String role) {
    final elements = nodes(
      node,
      'alertCMethod$number${role}PointLocation',
    ).toList();
    if (elements.length != 1) return null;
    final p = elements.single;
    final code = int.tryParse(text(p, 'specificLocation') ?? '');
    // OffsetDistance is a wrapper containing another offsetDistance element.
    final offset = number == '2'
        ? 0.0
        : double.tryParse(text(p, 'offsetDistance') ?? '');
    return {'code': code, 'offsetMeters': offset};
  }

  return {
    'country': text(node, 'alertCLocationCountryCode'),
    'table': text(node, 'alertCLocationTableNumber'),
    'version': text(node, 'alertCLocationTableVersion'),
    'direction': text(node, 'alertCDirectionCoded'),
    'method': number,
    'linear': method?.group(2) == 'Linear',
    'primary': point('Primary'),
    'secondary': point('Secondary'),
    if (method == null) 'unsupported': 'TMC-Methode $type nicht unterstützt',
  };
}
