import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'spot_photo.dart';

abstract interface class SpotPhotoService {
  const factory SpotPhotoService() = LocalSpotPhotoService;
  Future<PreparedSpotPhoto?> pickPhoto();
}

final class LocalSpotPhotoService implements SpotPhotoService {
  const LocalSpotPhotoService();

  @override
  Future<PreparedSpotPhoto?> pickPhoto() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Spot photos',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
          uniformTypeIdentifiers: [
            'public.jpeg',
            'public.png',
            'org.webmproject.webp',
          ],
        ),
      ],
    );
    if (file == null) return null;
    final length = await file.length();
    if (length > SpotPhotoLimits.maxSourceBytes) {
      throw const FormatException('Choose a photo smaller than 12 MiB.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, length)) {
      if (bytes.length + chunk.length > SpotPhotoLimits.maxSourceBytes) {
        throw const FormatException('Choose a photo smaller than 12 MiB.');
      }
      bytes.add(chunk);
    }
    return compute(prepareSpotPhoto, bytes.takeBytes());
  }
}

/// Bounded, platform-independent normalization. Native calls use an isolate;
/// Flutter Web's compute runs on the browser event loop.
PreparedSpotPhoto prepareSpotPhoto(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > SpotPhotoLimits.maxSourceBytes) {
    throw const FormatException('Choose a photo smaller than 12 MiB.');
  }
  try {
    final decoders = <img.Decoder>[
      img.JpegDecoder(),
      img.PngDecoder(),
      img.WebPDecoder(),
    ];
    final decoder = decoders
        .where((candidate) => candidate.isValidFile(bytes))
        .firstOrNull;
    if (decoder == null) {
      throw const FormatException('Choose a JPEG, PNG or WebP photo.');
    }
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width > 16384 ||
        info.height > 16384 ||
        info.width * info.height > SpotPhotoLimits.maxSourcePixels) {
      throw const FormatException('Choose a photo with at most 16 megapixels.');
    }
    if (decoder.numFrames() != 1) {
      throw const FormatException('Choose a still photo, not an animation.');
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) {
      throw const FormatException('This photo could not be decoded.');
    }
    final orientation = decoded.exif.imageIfd.orientation ?? 1;
    final rotated = orientation >= 5 && orientation <= 8;
    final width = rotated ? decoded.height : decoded.width;
    final height = rotated ? decoded.width : decoded.height;
    final scale = math.min(
      1.0,
      SpotPhotoLimits.maxImageEdge / math.max(width, height),
    );
    final resized = img.copyResize(
      decoded,
      width: math.max(1, (width * scale).round()),
      height: math.max(1, (height * scale).round()),
      interpolation: img.Interpolation.linear,
    );
    // A fresh canvas deliberately drops EXIF/GPS, text and other source metadata.
    final normalized = img.Image(
      width: resized.width,
      height: resized.height,
      numChannels: 3,
    );
    img.fill(normalized, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(normalized, resized);
    final thumbScale = math.min(
      1.0,
      SpotPhotoLimits.thumbnailEdge /
          math.max(normalized.width, normalized.height),
    );
    final thumbnail = img.copyResize(
      normalized,
      width: math.max(1, (normalized.width * thumbScale).round()),
      height: math.max(1, (normalized.height * thumbScale).round()),
      interpolation: img.Interpolation.linear,
    );
    final imageBytes = img.encodeJpg(normalized, quality: 82);
    final thumbnailBytes = img.encodeJpg(thumbnail, quality: 70);
    if (imageBytes.length > SpotPhotoLimits.maxImageBytes ||
        thumbnailBytes.length > SpotPhotoLimits.maxThumbnailBytes) {
      throw const FormatException(
        'This photo is too detailed to store. Choose a smaller photo.',
      );
    }
    return PreparedSpotPhoto(
      imageBytes: imageBytes,
      thumbnailBytes: thumbnailBytes,
      width: normalized.width,
      height: normalized.height,
    );
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'This photo could not be decoded. Choose another JPEG, PNG or WebP.',
    );
  }
}
