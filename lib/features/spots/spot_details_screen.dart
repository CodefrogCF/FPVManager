import 'package:flutter/material.dart';

import 'data/spot_query.dart';
import 'data/spot_repository.dart';
import 'spot_editor_dialog.dart';
import 'spot_photo_viewer.dart';

class SpotDetailsScreen extends StatefulWidget {
  const SpotDetailsScreen({
    super.key,
    required this.repository,
    required this.spotId,
    this.onRoadRoute,
  });
  final SpotRepository repository;
  final int spotId;
  final Future<void> Function()? onRoadRoute;
  @override
  State<SpotDetailsScreen> createState() => _SpotDetailsScreenState();
}

class _SpotDetailsScreenState extends State<SpotDetailsScreen> {
  late final _details = widget.repository.watchDetails(widget.spotId);
  bool _changing = false;
  String? _error;

  Future<void> _change(Future<void> Function() action) async {
    setState(() {
      _changing = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to update this spot. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _delete(SpotDetails details) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete spot?'),
        content: Text(
          'Permanently delete "${details.spot.name}" and its photos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _change(() async {
      await widget.repository.deleteSpot(widget.spotId);
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Spot details')),
    body: StreamBuilder<SpotDetails?>(
      stream: _details,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load spot details.'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final details = snapshot.data;
        if (details == null) {
          return const Center(child: Text('This spot no longer exists.'));
        }
        final spot = details.spot;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        spot.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: spot.isFavorite
                          ? 'Remove favorite'
                          : 'Add favorite',
                      onPressed: _changing
                          ? null
                          : () => _change(() async {
                              if (!await widget.repository.setFavorite(
                                id: spot.id,
                                isFavorite: !spot.isFavorite,
                              )) {
                                throw StateError('Missing spot');
                              }
                            }),
                      icon: Icon(
                        spot.isFavorite ? Icons.star : Icons.star_border,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  '${spot.latitude.toStringAsFixed(8)}, ${spot.longitude.toStringAsFixed(8)}',
                ),
                if (spot.category != null) ...[
                  const SizedBox(height: 16),
                  Text('Category: ${spot.category}'),
                ],
                if (details.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final tag in details.tags) Chip(label: Text(tag)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                SelectableText(
                  spot.notes?.isNotEmpty == true
                      ? spot.notes!
                      : 'No description added.',
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _changing
                          ? null
                          : () => Navigator.pop(context, spot),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Show on map'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => SpotPhotosDialog(
                          repository: widget.repository,
                          spotId: spot.id,
                          spotName: spot.name,
                        ),
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Photos'),
                    ),
                    if (widget.onRoadRoute != null)
                      OutlinedButton.icon(
                        onPressed: _changing ? null : widget.onRoadRoute,
                        icon: const Icon(Icons.directions_car_outlined),
                        label: const Text('Driving route'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _changing
                          ? null
                          : () => showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => SpotEditorDialog(
                                repository: widget.repository,
                                spot: spot,
                              ),
                            ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: _changing ? null : () => _delete(details),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
                if (_changing) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
