import 'dart:typed_data';

import 'package:flutter/services.dart';

/// CHGeo2004 + HTRANS, ETRS89 ellipsoid -> LN02; inverse by adding the
/// bilinearly interpolated offset. ETRS89 is used as the WGS84 visualization
/// approximation. No conversion/extrapolation outside the supplied grid.
class SwissObstacleHeights {
  SwissObstacleHeights(ByteData data) : _data = data {
    if (data.lengthInBytes < 40 ||
        data.getUint32(0, Endian.little) != 0x4e4c4843 ||
        data.getUint32(4, Endian.little) != 0x01003230) {
      throw const FormatException('Invalid Swiss height grid');
    }
    width = data.getUint32(8, Endian.little);
    height = data.getUint32(12, Endian.little);
    west = data.getFloat64(16, Endian.little);
    north = data.getFloat64(24, Endian.little);
    step = data.getFloat64(32, Endian.little);
    if (width != 559 ||
        height != 253 ||
        data.lengthInBytes != 40 + width * height * 4 ||
        !west.isFinite ||
        !north.isFinite ||
        !step.isFinite ||
        step <= 0) {
      throw const FormatException('Invalid Swiss height grid dimensions');
    }
  }
  final ByteData _data;
  late final int width, height;
  late final double west, north, step;
  static Future<SwissObstacleHeights> load() async => SwissObstacleHeights(
    await rootBundle.load('assets/geo/chgeo2004_ln02.bin'),
  );

  double? ellipsoidHeight(double lon, double lat, double ln02) {
    if (!lon.isFinite || !lat.isFinite || !ln02.isFinite) return null;
    final x = (lon - west) / step, y = (north - lat) / step;
    if (x < 0 || y < 0 || x > width - 1 || y > height - 1) return null;
    final col = x.floor().clamp(0, width - 2),
        row = y.floor().clamp(0, height - 2);
    final dx = x - col, dy = y - row;
    double value(int c, int r) =>
        _data.getFloat32(40 + (r * width + c) * 4, Endian.little);
    final offset =
        value(col, row) * (1 - dx) * (1 - dy) +
        value(col + 1, row) * dx * (1 - dy) +
        value(col, row + 1) * (1 - dx) * dy +
        value(col + 1, row + 1) * dx * dy;
    return offset.isFinite && offset > 40 && offset < 60 ? ln02 + offset : null;
  }
}
