import 'dart:math' as math;

import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import 'route_analysis.dart';

class RouteProfileChart extends StatefulWidget {
  const RouteProfileChart({super.key, required this.analysis});
  final RouteAnalysis analysis;
  @override
  State<RouteProfileChart> createState() => _RouteProfileChartState();
}

class _RouteProfileChartState extends State<RouteProfileChart> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final data = widget.analysis.profile;
    final selected = data[_index.clamp(0, data.length - 1)];
    final scheme = Theme.of(context).colorScheme;
    String meters(double? n) =>
        n == null ? 'unknown' : '${n.toStringAsFixed(1)} m';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.translate("Terrain and planned altitude · WGS84 ellipsoid"),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (event) {
                final fraction = (event.localPosition.dx / constraints.maxWidth)
                    .clamp(0.0, 1.0);
                final target = data.last.sample.distance * fraction;
                var nearest = 0;
                for (var i = 1; i < data.length; i++) {
                  if ((data[i].sample.distance - target).abs() <
                      (data[nearest].sample.distance - target).abs()) {
                    nearest = i;
                  }
                }
                setState(() => _index = nearest);
              },
              child: CustomPaint(
                painter: _ProfilePainter(
                  data,
                  _index,
                  scheme.primary,
                  scheme.outline,
                  scheme.error,
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0 m'),
            Text('${data.last.sample.distance.toStringAsFixed(0)} m'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.translate(
            "Tap the profile to inspect a sample. Planned altitude uses the primary colour; terrain uses grey.",
          ),
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            context.translate("At {0} m: ground {1}, altitude {2}, AGL {3}.", [
              selected.sample.distance.toStringAsFixed(0),
              meters(selected.ground),
              meters(selected.altitude),
              meters(selected.clearance),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter(
    this.points,
    this.selected,
    this.routeColor,
    this.groundColor,
    this.errorColor,
  );
  final List<RouteProfilePoint> points;
  final int selected;
  final Color routeColor, groundColor, errorColor;
  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (final p in points) ...[p.ground, p.altitude],
    ].nonNulls.toList();
    if (values.isEmpty) return;
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final span = math.max(20.0, high - low);
    double x(int i) => points.last.sample.distance > 0
        ? size.width * points[i].sample.distance / points.last.sample.distance
        : size.width * i / (points.length - 1);
    double y(double height) =>
        size.height -
        12 -
        (height - low + span * .05) / (span * 1.1) * (size.height - 24);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (a.ground != null && b.ground != null) {
        canvas.drawLine(
          Offset(x(i - 1), y(a.ground!)),
          Offset(x(i), y(b.ground!)),
          Paint()
            ..color = groundColor
            ..strokeWidth = 2,
        );
      }
      if (a.altitude != null && b.altitude != null) {
        canvas.drawLine(
          Offset(x(i - 1), y(a.altitude!)),
          Offset(x(i), y(b.altitude!)),
          Paint()
            ..color =
                (a.clearance != null && a.clearance! < 0) ||
                    (b.clearance != null && b.clearance! < 0)
                ? errorColor
                : routeColor
            ..strokeWidth = 3,
        );
      }
    }
    final sx = x(selected.clamp(0, points.length - 1));
    canvas.drawLine(
      Offset(sx, 0),
      Offset(sx, size.height),
      Paint()
        ..color = routeColor.withValues(alpha: .4)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProfilePainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.routeColor != routeColor ||
      old.groundColor != groundColor ||
      old.errorColor != errorColor;
}
