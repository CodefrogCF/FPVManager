import '../../core/geo/geo_coordinate_service.dart';
import 'globe_controller.dart';

/// Only state actually painted by native GlobeView chrome. Keeping this
/// separate avoids rebuilding the platform WebView on unrelated globe events.
class GlobeViewStatus {
  const GlobeViewStatus({this.coordinates, this.error});

  final String? coordinates;
  final String? error;

  factory GlobeViewStatus.fromController(GlobeController controller) {
    final point = controller.selectedPoint;
    return GlobeViewStatus(
      coordinates: point == null
          ? null
          : '${point.latitude.toStringAsFixed(5)}, '
                '${point.longitude.toStringAsFixed(5)} | '
                '${point.altitude.toStringAsFixed(1)} m '
                '(${point.heightReference.label})',
      error: controller.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlobeViewStatus &&
      other.coordinates == coordinates &&
      other.error == error;

  @override
  int get hashCode => Object.hash(coordinates, error);
}
