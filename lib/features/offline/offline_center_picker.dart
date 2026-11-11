import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../globe/globe_controller.dart';
import '../globe/globe_view.dart';

class OfflineCenterPicker extends StatefulWidget {
  const OfflineCenterPicker({
    super.key,
    required this.latitude,
    required this.longitude,
  });
  final double latitude, longitude;
  @override
  State<OfflineCenterPicker> createState() => _OfflineCenterPickerState();
}

class _OfflineCenterPickerState extends State<OfflineCenterPicker> {
  late final _controller = GlobeController();
  bool _positioned = false;
  @override
  void initState() {
    super.initState();
    _controller.addListener(_change);
  }

  void _change() {
    if (_controller.isReady && !_positioned) {
      _positioned = true;
      _controller
          .flyTo(
            latitude: widget.latitude,
            longitude: widget.longitude,
            altitude: 15000,
          )
          .catchError((Object _) {});
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_change);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = _controller.selectedPoint;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.translate("Mittelpunkt auf Karte wählen")),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: GlobeView(controller: _controller)),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        point == null
                            ? context.translate(
                                "Gewünschten Mittelpunkt auf dem Globe antippen.",
                              )
                            : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                      ),
                      FilledButton.icon(
                        onPressed: point == null
                            ? null
                            : () => Navigator.pop(context, (
                                latitude: point.latitude,
                                longitude: point.longitude,
                              )),
                        icon: const Icon(Icons.check),
                        label: Text(
                          context.translate("Mittelpunkt übernehmen"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
