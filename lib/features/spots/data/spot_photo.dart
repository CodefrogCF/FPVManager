import 'dart:typed_data';

/// Storage limits shared by processing, persistence and the editor.
abstract final class SpotPhotoLimits {
  static const maxPhotos = 6;
  static const maxSourceBytes = 12 * 1024 * 1024;
  static const maxSourcePixels = 16 * 1000 * 1000;
  static const maxImageEdge = 1600;
  static const maxImageBytes = 1024 * 1024;
  static const thumbnailEdge = 256;
  static const maxThumbnailBytes = 64 * 1024;
}

/// Only normalized data produced by the photo processor is persisted.
class PreparedSpotPhoto {
  PreparedSpotPhoto({
    required Uint8List imageBytes,
    required Uint8List thumbnailBytes,
    required this.width,
    required this.height,
  }) : imageBytes = Uint8List.fromList(imageBytes).asUnmodifiableView(),
       thumbnailBytes = Uint8List.fromList(thumbnailBytes).asUnmodifiableView();

  final Uint8List imageBytes;
  final Uint8List thumbnailBytes;
  final int width;
  final int height;
}

/// Lightweight database projection; never includes the full photo BLOB.
class SpotPhotoPreview {
  const SpotPhotoPreview({
    required this.id,
    required this.spotId,
    required this.thumbnailBytes,
    required this.width,
    required this.height,
  });
  final int id;
  final int spotId;
  final Uint8List thumbnailBytes;
  final int width;
  final int height;
}
