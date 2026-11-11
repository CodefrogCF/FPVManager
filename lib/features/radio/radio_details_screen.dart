import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/database/repositories/radio_equipment_repository.dart';
import '../../core/models/radio_profile.dart';
import 'radio_editor_dialog.dart';

class RadioDetailsScreen extends StatefulWidget {
  const RadioDetailsScreen({
    super.key,
    required this.repository,
    required this.equipmentId,
  });
  final RadioEquipmentRepository repository;
  final int equipmentId;
  @override
  State<RadioDetailsScreen> createState() => _RadioDetailsScreenState();
}

class _RadioDetailsScreenState extends State<RadioDetailsScreen> {
  late Stream<RadioProfile?> _profile = widget.repository.watchProfile(
    widget.equipmentId,
  );
  bool _deleting = false;
  String? _error;

  Future<void> _delete(RadioProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate("Delete equipment profile?")),
        content: Text(
          context.translate(
            "Permanently delete \"{0}\" and its assignments? Drone profiles and other equipment configurations are kept.",
            [profile.equipment.name],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.translate("Cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.translate("Delete")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.repository.deleteEquipment(widget.equipmentId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to delete. Please retry.');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _field(String label, Object? value, [String unit = '']) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        SelectableText(
          value == null
              ? context.translate("Not recorded")
              : '$value${unit.isEmpty ? '' : ' $unit'}',
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: Scaffold(
      appBar: AppBar(title: Text(context.translate("Equipment details"))),
      body: StreamBuilder<RadioProfile?>(
        stream: _profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.translate("Unable to load this equipment profile."),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _profile = widget.repository.watchProfile(
                        widget.equipmentId,
                      ),
                    ),
                    child: Text(context.translate("Retry")),
                  ),
                ],
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data;
          if (profile == null) {
            return Center(
              child: Text(
                context.translate("This equipment profile no longer exists."),
              ),
            );
          }
          final row = profile.equipment;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    row.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(radioCategoryLabel(row.category)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _deleting
                            ? null
                            : () => showDialog<int>(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => RadioEditorDialog(
                                  repository: widget.repository,
                                  profile: profile,
                                ),
                              ),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(context.translate("Edit equipment")),
                      ),
                      TextButton.icon(
                        onPressed: _deleting ? null : () => _delete(profile),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete equipment'),
                      ),
                    ],
                  ),
                  if (_deleting) const LinearProgressIndicator(),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    context.translate(
                      "Recorded specifications. Unknown values remain unrecorded. Maximum transmitter power is before antenna gain and cable loss; the operating setting may be lower.",
                    ),
                  ),
                  _field(
                    'Associated drones',
                    profile.drones.isEmpty
                        ? null
                        : profile.drones.map((d) => d.name).join('\n'),
                  ),
                  for (final group in RadioProfileSection.values) ...[
                    const SizedBox(height: 24),
                    Text(
                      group.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final field in RadioTextField.values.where(
                      (f) => f.group == group,
                    ))
                      _field(field.label, field.read(row)),
                    for (final field in RadioParameter.values.where(
                      (f) => f.group == group,
                    ))
                      _field(field.label, field.read(row), field.unit),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
