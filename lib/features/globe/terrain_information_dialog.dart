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
    this.developerMenusEnabled = false,
  });

  final TerrainElevation terrain;
  final bool developerMenusEnabled;
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
      title: Text(
        context.localized(
          "Terrain Information",
          (l10n) => l10n.globeTerrainInformation1a166cb2,
        ),
      ),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.localizedWithArgs("WGS84 latitude: {0}°", [
                terrain.latitude.toStringAsFixed(6),
              ], (l10n, value) => l10n.globeWgsLatituded60b5fd1(value(0))),
            ),
            Text(
              context.localizedWithArgs("WGS84 longitude: {0}°", [
                terrain.longitude.toStringAsFixed(6),
              ], (l10n, value) => l10n.globeWgsLongitudece917f86(value(0))),
            ),
            const SizedBox(height: 16),
            if (position != null) ...[
              Text(
                context.localized(
                  "Swiss coordinates (LV95)",
                  (l10n) => l10n.globeSwissCoordinatesLvb62ba2b6,
                ),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                context.localizedWithArgs("Easting: {0} m", [
                  position.easting.toStringAsFixed(2),
                ], (l10n, value) => l10n.globeEastingM080f8cea(value(0))),
              ),
              Text(
                context.localizedWithArgs("Northing: {0} m", [
                  position.northing.toStringAsFixed(2),
                ], (l10n, value) => l10n.globeNorthingMc882004d(value(0))),
              ),
              Text(
                _swissHeight == null
                    ? context.localized(
                        "Approximate conversion (swisstopo formulas)",
                        (l10n) => l10n
                            .globeApproximateConversionSwisstopoFormulase7bb7ac3,
                      )
                    : context.localized(
                        "Converted with swisstopo REFRAME",
                        (l10n) =>
                            l10n.globeConvertedWithSwisstopoReframe07d146f4,
                      ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              Text(
                context.localized(
                  "LV95 conversion unavailable outside the supported Swiss region.",
                  (l10n) => l10n.globeLvConversionUnavailableOutsidedecfa6d5,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              context.localized(
                "Ground elevation",
                (l10n) => l10n.globeGroundElevation5d588142,
              ),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              _height(terrain.elevation),
              key: const ValueKey('terrain-ellipsoid-height'),
            ),
            if (widget.developerMenusEnabled)
              Text(
                context.localizedWithArgs("Sampling: {0}", [
                  terrain.samplingMethod,
                ], (l10n, value) => l10n.globeSamplinga7cf9539(value(0))),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            if (_swissHeight != null)
              Text(
                _height(_swissHeight!.ln02Height),
                key: const ValueKey('terrain-ln02-height'),
              )
            else ...[
              Text(
                context.localized(
                  "AMSL (Swiss LN02): not converted",
                  (l10n) => l10n.globeAmslSwissLnNot9423d99b,
                ),
              ),
              const SizedBox(height: 8),
              if (supported &&
                  terrain.elevation.reference ==
                      VerticalReference.wgs84Ellipsoid) ...[
                FilledButton.tonal(
                  onPressed: _converting ? null : _convert,
                  child: Text(
                    _converting
                        ? context.localized(
                            "Converting…",
                            (l10n) => l10n.globeConverting3985de51,
                          )
                        : context.localized(
                            "Convert to Swiss height (LN02)",
                            (l10n) => l10n.globeConvertToSwissHeight5c83b28a,
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.localized(
                    "Online conversion sends this position and ground elevation to swisstopo.",
                    (l10n) => l10n.globeOnlineConversionSendsThis9f4e31f3,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else
                Text(
                  context.localized(
                    "Swiss height conversion is unavailable at this position or for this reference.",
                    (l10n) => l10n.globeSwissHeightConversionIsae058df0,
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
              context.localized(
                "AMSL is height above mean sea level. Swiss national map heights use LN02; LHN95 is a separate height datum.",
                (l10n) => l10n.globeAmslIsHeightAbove8e48a714,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Text(
              context.localized(
                "Height above local ground (AGL)",
                (l10n) => l10n.globeHeightAboveLocalGround8c1c0da0,
              ),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              context.localized(
                "AGL is a distance above this ground point, not a sea-level height.",
                (l10n) => l10n.commonAglIsADistance519675fb,
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
                labelText: context.localized(
                  "Height above terrain (AGL)",
                  (l10n) => l10n.globeHeightAboveTerrainAglcbf70384,
                ),
                suffixText: 'm',
                errorText: _aglError,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (calculate) ...[
              const SizedBox(height: 8),
              Text(
                context.localized(
                  "Height at this AGL:",
                  (l10n) => l10n.globeHeightAtThisAglfbdc9bdd,
                ),
              ),
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
              context.localized(
                "Source: swisstopo terrain. Values use a digital terrain model, not measured aircraft height or verified obstacle clearance.",
                (l10n) => l10n.commonSourceSwisstopoTerrainValues0aaf6e16,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            context.localized("Close", (l10n) => l10n.commonClosebbfa773e),
          ),
        ),
      ],
    );
  }
}
