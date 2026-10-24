import 'dart:convert';

const defaultPreflightItems = [
  'Batteries: charge, condition, secure mounting and reserve',
  'Propellers: damage, fastening and rotation',
  'GPS: fix, home position and recovery settings where fitted',
  'Radio: antennas, control link, failsafe and range check',
  'Video: antennas, goggles, recording and video link',
  'Weather: wind, gusts, precipitation and visibility',
  'Airspace: current official restrictions, permissions and temporary notices',
];

class ChecklistItem {
  const ChecklistItem(this.label, {this.checked = false});
  final String label;
  final bool checked;
}

String encodeChecklist(List<ChecklistItem> items) {
  if (items.isEmpty ||
      items.length > 100 ||
      items.any((i) => i.label.trim().isEmpty || i.label.length > 300)) {
    throw ArgumentError('Use 1–100 checklist items, up to 300 characters each');
  }
  final encoded = jsonEncode({
    'version': 1,
    'items': [
      for (final i in items) {'label': i.label.trim(), 'checked': i.checked},
    ],
  });
  if (encoded.length > 60000) {
    throw ArgumentError('Checklist text is too large');
  }
  return encoded;
}

List<ChecklistItem> decodeChecklist(String value) {
  if (value.length > 60000) throw const FormatException('Checklist too large');
  final j = jsonDecode(value) as Map<String, dynamic>;
  if (j['version'] != 1) throw const FormatException('Unsupported checklist');
  final items = [
    for (final i in j['items'] as List)
      ChecklistItem(i['label'] as String, checked: i['checked'] as bool),
  ];
  encodeChecklist(items);
  return List.unmodifiable(items);
}
