/// User-defined classification. Category spelling is retained; tag keys are
/// lowercase and deduplicated so filters have one stable representation.
class SpotClassification {
  factory SpotClassification({
    String? category,
    Iterable<String> tags = const [],
  }) {
    final cleanCategory = _label(category ?? '', 40, 'Category');
    final cleanTags = <String>{};
    for (final tag in tags) {
      final clean = _label(tag, 32, 'Tag').toLowerCase();
      if (clean.contains(',')) throw ArgumentError('Separate tags with commas');
      if (clean.isNotEmpty) cleanTags.add(clean);
      if (cleanTags.length > 10) throw ArgumentError('Use at most 10 tags');
    }
    return SpotClassification._(
      cleanCategory.isEmpty ? null : cleanCategory,
      List.unmodifiable(cleanTags.toList()..sort()),
    );
  }

  const SpotClassification._(this.category, this.tags);
  final String? category;
  final List<String> tags;
  String get categoryKey => category?.toLowerCase() ?? '';

  static String _label(String value, int limit, String field) {
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      throw ArgumentError('$field cannot contain control characters');
    }
    final clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length > limit) {
      throw ArgumentError('$field must have at most $limit characters');
    }
    return clean;
  }

  static List<String> parseTags(String value) =>
      SpotClassification(tags: value.split(',')).tags;

  static String searchText({
    required String name,
    String? notes,
    String? category,
    Iterable<String> tags = const [],
  }) => [name, notes ?? '', category ?? '', ...tags].join(' ').toLowerCase();
}
