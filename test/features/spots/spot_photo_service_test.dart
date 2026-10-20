import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:fpvmanager/features/spots/data/spot_photo.dart';
import 'package:fpvmanager/features/spots/data/spot_photo_service.dart';

void main() {
  test('normalizes a large PNG into bounded JPEG and thumbnail', () {
    final source = img.Image(width: 2000, height: 1000, numChannels: 4);
    img.fill(source, color: img.ColorRgba8(255, 0, 0, 0));
    final photo = prepareSpotPhoto(img.encodePng(source));
    expect(photo.width, 1600);
    expect(photo.height, 800);
    expect(
      photo.imageBytes.length,
      lessThanOrEqualTo(SpotPhotoLimits.maxImageBytes),
    );
    final full = img.decodeJpg(photo.imageBytes)!;
    expect(full.width, 1600);
    // Transparent source pixels are composited onto white.
    expect(full.getPixel(0, 0).r, greaterThan(245));
    expect(full.getPixel(0, 0).g, greaterThan(245));
    final thumbnail = img.decodeJpg(photo.thumbnailBytes)!;
    expect(thumbnail.width, 256);
    expect(thumbnail.height, 128);
    expect(
      photo.thumbnailBytes.length,
      lessThanOrEqualTo(SpotPhotoLimits.maxThumbnailBytes),
    );
    expect(() => photo.imageBytes[0] = 0, throwsUnsupportedError);
  });

  test('applies camera orientation and strips EXIF including GPS', () {
    final source = img.Image(width: 80, height: 40);
    source.exif.imageIfd.orientation = 6;
    source.exif.imageIfd.make = 'Private camera';
    source.exif.gpsIfd.gpsLatitude = 47;
    source.exif.gpsIfd.gpsLatitudeRef = 'N';
    final encoded = img.encodeJpg(source);
    expect(img.decodeJpg(encoded)!.exif.gpsIfd.gpsLatitude, isNotNull);
    final photo = prepareSpotPhoto(encoded);
    expect(photo.width, 40);
    expect(photo.height, 80);
    final decoded = img.decodeJpg(photo.imageBytes)!;
    expect(decoded.exif.imageIfd.make, isNull);
    expect(decoded.exif.gpsIfd.gpsLatitude, isNull);
    expect(decoded.exif.imageIfd.orientation, isNull);
    final thumbnail = img.decodeJpg(photo.thumbnailBytes)!;
    expect(thumbnail.exif.gpsIfd.gpsLatitude, isNull);
  });

  test(
    'small photos keep their size and unsupported or malformed data fails',
    () {
      final photo = prepareSpotPhoto(
        img.encodeJpg(img.Image(width: 12, height: 6)),
      );
      expect(photo.width, 12);
      expect(photo.height, 6);
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([0xff, 0xd8, 0xff]),
        img.encodeGif(img.Image(width: 2, height: 2)),
      ]) {
        expect(() => prepareSpotPhoto(bytes), throwsFormatException);
      }
      expect(
        () => prepareSpotPhoto(Uint8List(SpotPhotoLimits.maxSourceBytes + 1)),
        throwsFormatException,
      );
    },
  );

  test('rejects oversized image dimensions before pixel decoding', () {
    final png = img.encodePng(img.Image(width: 4, height: 4));
    // The PNG header claims 25 MP; pixel payload remains tiny.
    final header = ByteData.sublistView(png);
    header.setUint32(16, 5000);
    header.setUint32(20, 5000);
    expect(() => prepareSpotPhoto(png), throwsFormatException);
  });
}
