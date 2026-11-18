import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../help/guides_screen.dart';

class CachedMapNotice extends StatelessWidget {
  const CachedMapNotice({super.key});
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Padding(
      padding: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.localized(
              "Cached base map & terrain · coverage may be incomplete or outdated. Live overlays and API actions require separate verification.",
              (l10n) => l10n.offlineCachedBaseMapTerrainecfb9aaf,
            ),
          ),
          GuideLink(GuideTopic.offline),
        ],
      ),
    ),
  );
}
