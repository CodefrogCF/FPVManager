import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import 'data/spot_repository.dart';
import 'spot_editor_dialog.dart';
import 'spot_photo_viewer.dart';

class SpotsScreen extends StatefulWidget {
  const SpotsScreen({
    super.key,
    required this.repository,
    this.initialLatitude,
    this.initialLongitude,
  });

  final SpotRepository repository;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<SpotsScreen> createState() => _SpotsScreenState();
}

enum _SpotAction { photos, edit, delete }

class _SpotsScreenState extends State<SpotsScreen> {
  late final Stream<List<Spot>> _spots;

  @override
  void initState() {
    super.initState();
    _spots = widget.repository.watchSpots();
  }

  Future<void> _editSpot([Spot? existing]) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SpotEditorDialog(
        repository: widget.repository,
        spot: existing,
        initialLatitude: widget.initialLatitude,
        initialLongitude: widget.initialLongitude,
      ),
    );
  }

  Future<void> _deleteSpot(Spot spot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete spot?'),
        content: Text('Permanently delete "${spot.name}"?'),
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

    try {
      await widget.repository.deleteSpot(spot.id);
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to delete spot: $error');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FPV Spots')),
      body: StreamBuilder<List<Spot>>(
        stream: _spots,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Unable to load spots: ${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final spots = snapshot.data!;

          if (spots.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place_outlined, size: 48),
                    SizedBox(height: 16),
                    Text('No spots saved yet.'),
                    SizedBox(height: 8),
                    Text(
                      'Add a spot to start building '
                      'your FPV location library.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: spots.length,
            itemBuilder: (context, index) {
              final spot = spots[index];

              return ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(spot.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${spot.latitude.toStringAsFixed(6)}, '
                      '${spot.longitude.toStringAsFixed(6)}',
                    ),
                    if (spot.notes != null && spot.notes!.isNotEmpty)
                      Text(
                        spot.notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                isThreeLine: spot.notes?.isNotEmpty ?? false,
                onTap: () => Navigator.pop(context, spot),
                trailing: PopupMenuButton<_SpotAction>(
                  tooltip: 'Spot options',
                  onSelected: (action) {
                    switch (action) {
                      case _SpotAction.photos:
                        showDialog<void>(
                          context: context,
                          builder: (context) => SpotPhotosDialog(
                            repository: widget.repository,
                            spotId: spot.id,
                            spotName: spot.name,
                          ),
                        );
                      case _SpotAction.edit:
                        _editSpot(spot);
                      case _SpotAction.delete:
                        _deleteSpot(spot);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _SpotAction.photos,
                      child: Text('View photos'),
                    ),
                    PopupMenuItem(value: _SpotAction.edit, child: Text('Edit')),
                    PopupMenuItem(
                      value: _SpotAction.delete,
                      child: Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _editSpot,
        icon: const Icon(Icons.add),
        label: const Text('Add Spot'),
      ),
    );
  }
}
