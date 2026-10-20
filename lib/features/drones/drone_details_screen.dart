import 'package:flutter/material.dart';

import '../../core/database/repositories/drone_repository.dart';
import '../../core/models/drone_profile.dart';
import 'drone_editor_dialog.dart';

class DroneDetailsScreen extends StatefulWidget {
  const DroneDetailsScreen({
    super.key,
    required this.repository,
    required this.droneId,
  });
  final DroneRepository repository;
  final int droneId;
  @override
  State<DroneDetailsScreen> createState() => _DroneDetailsScreenState();
}

class _DroneDetailsScreenState extends State<DroneDetailsScreen> {
  late Stream<DroneProfile?> _profile = widget.repository.watchProfile(
    widget.droneId,
  );
  bool _deleting = false;
  String? _error;

  Future<void> _delete(DroneProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete drone profile?'),
        content: Text(
          'Permanently delete "${profile.drone.name}"? Flight plans will be kept without this drone assignment.',
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
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.repository.deleteDrone(widget.droneId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to delete this profile. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _text(String label, String? value) => value == null || value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              SelectableText(value),
            ],
          ),
        );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Drone profile')),
    body: StreamBuilder<DroneProfile?>(
      stream: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load this drone profile.'),
                TextButton(
                  onPressed: () => setState(
                    () => _profile = widget.repository.watchProfile(
                      widget.droneId,
                    ),
                  ),
                  child: const Text('Retry'),
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
          return const Center(
            child: Text('This drone profile no longer exists.'),
          );
        }
        final drone = profile.drone;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  drone.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(drone.type),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _deleting
                          ? null
                          : () => showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => DroneEditorDialog(
                                repository: widget.repository,
                                profile: profile,
                              ),
                            ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                    TextButton.icon(
                      onPressed: _deleting ? null : () => _delete(profile),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete profile'),
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
                for (final group in DroneParameterGroup.values) ...[
                  const SizedBox(height: 24),
                  Text(
                    group.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (group == DroneParameterGroup.airframe)
                    _text('Configuration', drone.configuration),
                  if (group == DroneParameterGroup.propellers)
                    _text('Propeller description', drone.propellerDescription),
                  if (group == DroneParameterGroup.propulsion) ...[
                    _text('Motor description', drone.motorDescription),
                    _text('ESC description', drone.escDescription),
                  ],
                  for (final parameter in DroneParameter.values.where(
                    (parameter) => parameter.group == group,
                  ))
                    if (profile.measurements[parameter] case final measurement?)
                      _ParameterRow(
                        parameter: parameter,
                        measurement: measurement,
                      ),
                  if (!profile.measurements.keys.any(
                    (parameter) => parameter.group == group,
                  ))
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('No numeric parameters recorded.'),
                    ),
                ],
                _text(
                  'Measurement context / sources',
                  drone.measurementContext,
                ),
                _text('Notes', drone.notes),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ParameterRow extends StatelessWidget {
  const _ParameterRow({required this.parameter, required this.measurement});
  final DroneParameter parameter;
  final DroneMeasurement measurement;
  @override
  Widget build(BuildContext context) {
    final value = measurement.valueLabel;
    final source = measurement.source;
    final color = switch (source) {
      DroneValueSource.measured => Colors.lightGreenAccent,
      DroneValueSource.estimated => Colors.amberAccent,
      DroneValueSource.unspecified => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${parameter.label}: $value${parameter.unit.isEmpty ? '' : ' ${parameter.unit}'}',
          ),
          Text(
            source.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
