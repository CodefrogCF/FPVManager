/// An optional lighting preview; null time follows the device clock.
class SceneTime {
  const SceneTime({this.enabled = false, this.fixedUtc});
  final bool enabled;
  final DateTime? fixedUtc;

  void validate() {
    if (fixedUtc != null &&
        (fixedUtc!.toUtc().year < 1900 || fixedUtc!.toUtc().year > 2100)) {
      throw ArgumentError('Scene date must be within 1900–2100');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {'enabled': enabled, 'timeUtc': fixedUtc?.toUtc().toIso8601String()};
  }

  factory SceneTime.fromJson(Map<String, dynamic> json) {
    final raw = json['timeUtc'];
    if (json['enabled'] is! bool ||
        (raw != null &&
            (raw is! String ||
                !RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?Z$')
                    .hasMatch(raw)))) {
      throw const FormatException('Invalid lighting preview');
    }
    final value = SceneTime(
      enabled: json['enabled'] as bool,
      fixedUtc: raw == null ? null : DateTime.parse(raw as String).toUtc(),
    );
    value.validate();
    if (raw != null &&
        value.fixedUtc!.toIso8601String().substring(0, 19) !=
            (raw as String).substring(0, 19)) {
      throw const FormatException('Invalid calendar date');
    }
    return value;
  }
}
