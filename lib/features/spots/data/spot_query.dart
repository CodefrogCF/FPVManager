import '../../../core/database/fpv_database.dart' show Spot;
import '../../../core/models/spot_classification.dart';

class SpotFilter {
  SpotFilter({
    String query = '',
    this.favoritesOnly = false,
    String? category,
    Iterable<String> tags = const [],
  }) : query = query.trim().toLowerCase(),
       classification = SpotClassification(category: category, tags: tags) {
    if (query.length > 160 || query.contains('\u0000')) {
      throw ArgumentError('Search is limited to 160 characters');
    }
  }
  final String query;
  final bool favoritesOnly;
  final SpotClassification classification;
  List<String> get terms =>
      query.split(RegExp(r'\s+')).where((term) => term.isNotEmpty).toList();
}

class SpotSummary {
  SpotSummary({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.isFavorite,
    required this.category,
    required this.notesPreview,
    required Iterable<String> tags,
  }) : tags = List.unmodifiable(tags);
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final bool isFavorite;
  final String? category;
  final String notesPreview;
  final List<String> tags;
}

class SpotPage {
  SpotPage({required Iterable<SpotSummary> items, required this.hasNext})
    : items = List.unmodifiable(items);
  final List<SpotSummary> items;
  final bool hasNext;
  int? get nextBeforeId => hasNext && items.isNotEmpty ? items.last.id : null;
}

class SpotDetails {
  SpotDetails({required this.spot, required Iterable<String> tags})
    : tags = List.unmodifiable(tags);
  final Spot spot;
  final List<String> tags;
}

/// Only fields used by the renderer and the compact map selection panel.
class SpotMapEntry {
  const SpotMapEntry({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });
  final int id;
  final String name;
  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is SpotMapEntry &&
      id == other.id &&
      name == other.name &&
      latitude == other.latitude &&
      longitude == other.longitude;
  @override
  int get hashCode => Object.hash(id, name, latitude, longitude);
}
