import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import 'offline_preparation_surface_native.dart'
    if (dart.library.js_interop) 'offline_preparation_surface_web.dart';
import 'offline_region.dart';

class OfflinePreparationScreen extends StatelessWidget {
  const OfflinePreparationScreen({super.key, required this.config});
  final Map<String, dynamic> config;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.translate("Offline-Bereich vorbereiten")),
    ),
    body: SafeArea(
      child: OfflinePreparationSurface(
        config: config,
        onComplete: (region) => Navigator.pop<OfflineRegion>(context, region),
      ),
    ),
  );
}
