import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import 'data/spot_repository.dart';

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

enum _SpotAction { edit, delete }

class _SpotsScreenState extends State<SpotsScreen> {
  late final Stream<List<Spot>> _spots;

  @override
  void initState() {
    super.initState();
    _spots = widget.repository.watchSpots();
  }

  Future<void> _editSpot([Spot? existing]) async {
    final input = await showDialog<_SpotInput>(
      context: context,
      builder: (context) => _SpotEditorDialog(
        spot: existing,
        initialLatitude: widget.initialLatitude,
        initialLongitude: widget.initialLongitude,
      ),
    );

    if (!mounted || input == null) return;

    try {
      if (existing == null) {
        await widget.repository.createSpot(
          name: input.name,
          latitude: input.latitude,
          longitude: input.longitude,
          notes: input.notes,
        );
      } else {
        await widget.repository.updateSpot(
          id: existing.id,
          name: input.name,
          latitude: input.latitude,
          longitude: input.longitude,
          notes: input.notes,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to save spot: $error');
    }
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
                      case _SpotAction.edit:
                        _editSpot(spot);
                      case _SpotAction.delete:
                        _deleteSpot(spot);
                    }
                  },
                  itemBuilder: (context) => const [
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

class _SpotInput {
  const _SpotInput({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.notes,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? notes;
}

class _SpotEditorDialog extends StatefulWidget {
  const _SpotEditorDialog({
    this.spot,
    this.initialLatitude,
    this.initialLongitude,
  });

  final Spot? spot;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<_SpotEditorDialog> createState() => _SpotEditorDialogState();
}

class _SpotEditorDialogState extends State<_SpotEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();

    final spot = widget.spot;

    _name = TextEditingController(text: spot?.name ?? '');

    _latitude = TextEditingController(
      text:
          (spot?.latitude ?? widget.initialLatitude)?.toStringAsFixed(6) ?? '',
    );

    _longitude = TextEditingController(
      text:
          (spot?.longitude ?? widget.initialLongitude)?.toStringAsFixed(6) ??
          '',
    );

    _notes = TextEditingController(text: spot?.notes ?? '');
  }

  double? _parseCoordinate(String text) {
    return double.tryParse(text.trim().replaceAll(',', '.'));
  }

  String? _validateCoordinate(String? value, double minimum, double maximum) {
    final coordinate = _parseCoordinate(value ?? '');

    if (coordinate == null ||
        !coordinate.isFinite ||
        coordinate < minimum ||
        coordinate > maximum) {
      return 'Enter a value from $minimum to $maximum';
    }

    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final notes = _notes.text.trim();

    Navigator.pop(
      context,
      _SpotInput(
        name: _name.text.trim(),
        latitude: _parseCoordinate(_latitude.text)!,
        longitude: _parseCoordinate(_longitude.text)!,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.spot == null ? 'Add Spot' : 'Edit Spot'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Spot name'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Enter a spot name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _latitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude (WGS84)',
                  ),
                  validator: (value) => _validateCoordinate(value, -90, 90),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _longitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude (WGS84)',
                  ),
                  validator: (value) => _validateCoordinate(value, -180, 180),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
