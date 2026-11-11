import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/geo/altitude_service.dart';
import '../../core/geo/geo_coordinate_service.dart';
import '../../core/geo/reframe_wgs84_service.dart';
import 'globe_controller.dart';

typedef SwissHeightConverter = Future<SwissHeightResult> Function({
  required Wgs84Coordinate coordinate,
  required ReferencedElevation elevation,
});

class TerrainInformationDialog extends StatefulWidget {
  const TerrainInformationDialog({
    super.key,
    required this.terrain,
    this.convertHeight,
  });

  final TerrainElevation terrain;
  final SwissHeightConverter? convertHeight;

  @override
  State<TerrainInformationDialog> createState() =>
      _TerrainInformationDialogState();
}

class _TerrainInformationDialogState extends State<TerrainInformationDialog> {
  final _agl = TextEditingController();
  ReframeWgs84Service? _service;
  SwissHeightResult? _swissHeight;
  String? _conversionError;
  bool _converting = false;
  int _conversionRevision = 0;

  @override
  void initState() {
    super.initState();
    if (widget.convertHeight == null) _service = ReframeWgs84Service();
  }

  @override
  void dispose() {
    _conversionRevision++;
    _service?.dispose();
    _agl.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    if (_converting) return;
    final revision = ++_conversionRevision;
    setState(() {
      _converting = true;
      _conversionError = null;
    });
    try {
      final result = await (widget.convertHeight ?? _service!.toLn02)(
        coordinate: Wgs84Coordinate(
          latitude: widget.terrain.latitude,
          longitude: widget.terrain.longitude,
        ),
        elevation: widget.terrain.elevation,
      );
      if (!mounted || revision != _conversionRevision) return;
      setState(() => _swissHeight = result);
    } catch (_) {
      if (!mounted || revision != _conversionRevision) return;
      setState(() {
        _conversionError =
            'Swiss height conversion unavailable. The ellipsoidal height '
            'remains available. Check your connection and try again.';
      });
    } finally {
      if (mounted && revision == _conversionRevision) {
        setState(() => _converting = false);
      }
    }
  }

  double? get _aglMeters =>
      double.tryParse(_agl.text.trim().replaceAll(',', '.'));

  String? get _aglError {
    if (_agl.text.trim().isEmpty) return null;
    final value = _aglMeters;
    if (value == null || !value.isFinite || value < 0) {
      return 'Enter a finite height of 0 m or more.';
    }
    if (widget.terrain.elevation.reference == VerticalReference.unverified ||
        !(widget.terrain.heightMeters + value).isFinite) {
      return 'A height cannot be calculated with these values.';
    }
    return null;
  }

  String _height(ReferencedElevation elevation) =>
      '${elevation.meters.toStringAsFixed(1)} m · ${elevation.reference.label}';

  @override
  Widget build(BuildContext context) {
    const geo = GeoCoordinateService();
    const altitudes = AltitudeService();
    final terrain = widget.terrain;
    final coordinate = Wgs84Coordinate(
      latitude: terrain.latitude,
      longitude: terrain.longitude,
    );
    final supported = geo.supportsWgs84(coordinate);
    final position =
        _swissHeight?.position ??
        (supported ? geo.wgs84ToLv95(coordinate) : null);
    final agl = _aglMeters;
    final calculate = agl != null && _aglError == null;

    return AlertDialog(
      scrollable: true,
      title: Text(context.translate("Terrain Information")),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.translate("WGS84 latitude: {0}°", [
                terrain.latitude.toStringAsFixed(6),
              ]),
            ),
            Text(
              context.translate("WGS84 longitude: {0}°", [
                terrain.longitude.toStringAsFixed(6),
              ]),
            ),
            const SizedBox(height: 16),
            if (position != null) ...[
              Text(
                context.translate("Swiss coordinates (LV95)"),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                context.translate("Easting: {0} m", [
                  position.easting.toStringAsFixed(2),
                ]),
              ),
              Text(
                context.translate("Northing: {0} m", [
                  position.northing.toStringAsFixed(2),
                ]),
              ),
              Text(
                _swissHeight == null
                    ? context.translate(
                        "Approximate conversion (swisstopo formulas)",
                      )
                    : context.translate("Converted with swisstopo REFRAME"),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              Text(
                context.translate(
                  "LV95 conversion unavailable outside the supported Swiss region.",
                ),
              ),
            const SizedBox(height: 20),
            Text(
              context.translate("Ground elevation"),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              _height(terrain.elevation),
              key: const ValueKey('terrain-ellipsoid-height'),
            ),
            Text(
              context.translate("Sampling: {0}", [terrain.samplingMethod]),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_swissHeight != null)
              Text(
                _height(_swissHeight!.ln02Height),
                key: const ValueKey('terrain-ln02-height'),
              )
            else ...[
              Text(context.translate("AMSL (Swiss LN02): not converted")),
              const SizedBox(height: 8),
              if (supported &&
                  terrain.elevation.reference ==
                      VerticalReference.wgs84Ellipsoid) ...[
                FilledButton.tonal(
                  onPressed: _converting ? null : _convert,
                  child: Text(
                    _converting
                        ? context.translate("Converting…")
                        : context.translate("Convert to Swiss height (LN02)"),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.translate(
                    "Online conversion sends this position and ground elevation to swisstopo.",
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else
                Text(
                  context.translate(
                    "Swiss height conversion is unavailable at this position or for this reference.",
                  ),
                ),
            ],
            if (_conversionError != null) ...[
              const SizedBox(height: 8),
              Text(
                _conversionError!,
                key: const ValueKey('height-conversion-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              context.translate(
                "AMSL is height above mean sea level. Swiss national map heights use LN02; LHN95 is a separate height datum.",
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Text(
              context.translate("Height above local ground (AGL)"),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              context.translate(
                "AGL is a distance above this ground point, not a sea-level height.",
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _agl,
              key: const ValueKey('agl-height-input'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.translate("Height above terrain (AGL)"),
                suffixText: 'm',
                errorText: _aglError,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (calculate) ...[
              const SizedBox(height: 8),
              Text(context.translate("Height at this AGL:")),
              Text(
                _height(
                  altitudes.fromAboveGround(
                    height: AboveGroundHeight(agl),
                    ground: terrain.elevation,
                  ),
                ),
                key: const ValueKey('agl-ellipsoid-height'),
              ),
              if (_swissHeight != null)
                Text(
                  _height(
                    altitudes.fromAboveGround(
                      height: AboveGroundHeight(agl),
                      ground: _swissHeight!.ln02Height,
                    ),
                  ),
                  key: const ValueKey('agl-ln02-height'),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              context.translate(
                "Source: swisstopo terrain. Values use a digital terrain model, not measured aircraft height or verified obstacle clearance.",
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.translate("Close")),
        ),
      ],
    );
  }
}
