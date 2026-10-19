/// Validation shared by local repositories, before they modify the database.
abstract final class RepositoryValidation {
  static String text(String value, String field) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 120) {
      throw ArgumentError('$field must contain 1–120 characters');
    }
    return trimmed;
  }

  static void id(int value) {
    if (value <= 0) throw ArgumentError('ID must be positive');
  }

  static void optionalId(int? value) {
    if (value != null) id(value);
  }

  static void positive(num? value, String field, {bool allowZero = false}) {
    if (value != null &&
        (!value.isFinite || (allowZero ? value < 0 : value <= 0))) {
      throw ArgumentError(
        '$field must be finite and ${allowZero ? 'nonnegative' : 'positive'}',
      );
    }
  }

  static void coordinates(double latitude, double longitude) {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('Invalid WGS84 coordinates');
    }
  }
}
