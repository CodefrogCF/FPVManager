import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/database/repositories/battery_repository.dart';
import '../../core/models/battery_profile.dart';
import 'battery_editor_dialog.dart';

class BatteryDetailsScreen extends StatefulWidget {
  const BatteryDetailsScreen({
    super.key,
    required this.repository,
    required this.batteryId,
  });
  final BatteryRepository repository;
  final int batteryId;
  @override
  State<BatteryDetailsScreen> createState() => _BatteryDetailsScreenState();
}

class _BatteryDetailsScreenState extends State<BatteryDetailsScreen> {
  late Stream<BatteryProfile?> _profile = widget.repository.watchProfile(
    widget.batteryId,
  );
  bool _deleting = false;
  String? _error;

  Future<void> _delete(BatteryProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.translate("Delete battery{0}?", [
            profile.battery.isType ? ' type' : '',
          ]),
        ),
        content: Text(
          'Permanently delete "${profile.battery.name}"? '
          '${profile.battery.isType ? 'Existing packs keep their specifications and lose this type link.' : 'Drones and flight plans are kept; only this battery and its assignments are removed.'}',
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
      await widget.repository.deleteBattery(widget.batteryId);
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
      appBar: AppBar(title: Text(context.translate("Battery details"))),
      body: StreamBuilder<BatteryProfile?>(
        stream: _profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.translate("Unable to load this battery.")),
                  TextButton(
                    onPressed: () => setState(
                      () => _profile = widget.repository.watchProfile(
                        widget.batteryId,
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
              child: Text(context.translate("This battery no longer exists.")),
            );
          }
          final battery = profile.battery;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    battery.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    battery.isType
                        ? context.translate("Battery type · reusable template")
                        : context.translate("Individual battery"),
                  ),
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
                                builder: (context) => BatteryEditorDialog(
                                  repository: widget.repository,
                                  profile: profile,
                                ),
                              ),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(context.translate("Edit battery")),
                      ),
                      if (battery.isType)
                        OutlinedButton.icon(
                          onPressed: _deleting
                              ? null
                              : () async {
                                  final id = await showDialog<int>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => BatteryEditorDialog(
                                      repository: widget.repository,
                                      fromType: battery,
                                    ),
                                  );
                                  if (id != null && context.mounted) {
                                    await Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            BatteryDetailsScreen(
                                              repository: widget.repository,
                                              batteryId: id,
                                            ),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.add),
                          label: Text(context.translate("Add pack from type")),
                        ),
                      TextButton.icon(
                        onPressed: _deleting ? null : () => _delete(profile),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete battery'),
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
                  if (!battery.isType)
                    _field('Type template', profile.type?.name),
                  _field('Chemistry', battery.chemistry),
                  _field('Cell count', battery.cellCount, 'S'),
                  _field('Capacity', battery.capacityMah, 'mAh'),
                  _field('Nominal voltage', battery.nominalVoltageVolts, 'V'),
                  _field('Recorded energy', battery.energyWh, 'Wh'),
                  if (profile.calculatedNominalEnergyWh != null)
                    _field(
                      'Calculated nominal energy (capacity × voltage)',
                      profile.calculatedNominalEnergyWh!.toStringAsFixed(2),
                      'Wh',
                    ),
                  _field('Weight', battery.weightGrams, 'g'),
                  _field('Notes', battery.notes),
                  if (!battery.isType) ...[
                    const SizedBox(height: 24),
                    Text(
                      context.translate("Condition & availability"),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      context.translate(
                        "Charge, cycles and condition are recorded manually.",
                      ),
                    ),
                    _field('Recorded charge', battery.chargePercent, '%'),
                    _field('Cycle count', battery.cycleCount),
                    _field(
                      'Availability',
                      BatteryAvailability.parse(battery.availability).label,
                    ),
                    _field('Condition notes', battery.conditionNotes),
                    _field(
                      'Associated drones',
                      profile.drones.isEmpty
                          ? null
                          : profile.drones.map((d) => d.name).join('\n'),
                    ),
                    _field(
                      'Associated flight plans',
                      profile.flightPlans.isEmpty
                          ? null
                          : profile.flightPlans.map((p) => p.name).join('\n'),
                    ),
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
