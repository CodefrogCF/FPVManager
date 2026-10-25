import 'package:flutter/material.dart';

class CachedMapNotice extends StatelessWidget {
  const CachedMapNotice({super.key});
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: const Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        'Cached base map & terrain · coverage may be incomplete or outdated. Live overlays and API actions require separate verification.',
      ),
    ),
  );
}
