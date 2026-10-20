import 'package:flutter/material.dart';

import '../../core/database/repositories/drone_repository.dart';
import '../../core/models/drone_profile.dart';

class DroneEditorDialog extends StatefulWidget {
  const DroneEditorDialog({super.key, required this.repository, this.profile});
  final DroneRepository repository;
  final DroneProfile? profile;
  @override
  State<DroneEditorDialog> createState() => _DroneEditorDialogState();
}

class _DroneEditorDialogState extends State<DroneEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile?.drone.name);
  late final _type = TextEditingController(
    text: widget.profile?.drone.type ?? 'quadcopter',
  );
  late final _notes = TextEditingController(text: widget.profile?.drone.notes);
  late final _configuration = TextEditingController(
    text: widget.profile?.drone.configuration,
  );
  late final _propellers = TextEditingController(
    text: widget.profile?.drone.propellerDescription,
  );
  late final _motors = TextEditingController(
    text: widget.profile?.drone.motorDescription,
  );
  late final _esc = TextEditingController(
    text: widget.profile?.drone.escDescription,
  );
  late final _context = TextEditingController(
    text: widget.profile?.drone.measurementContext,
  );
  late final _values = {
    for (final parameter in DroneParameter.values)
      parameter: TextEditingController(text: _initialValue(parameter)),
  };
  late final _sources = {
    for (final parameter in DroneParameter.values)
      parameter:
          widget.profile?.measurements[parameter]?.source ??
          DroneValueSource.unspecified,
  };
  bool _saving = false;
  String? _error;

  String _initialValue(DroneParameter parameter) {
    return widget.profile?.measurements[parameter]?.valueLabel ?? '';
  }

  double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));
  String? _validateNumber(DroneParameter parameter, String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = _number(text);
    if (value == null) return 'Enter a number';
    try {
      parameter.validate(value);
      return null;
    } on ArgumentError {
      return parameter.wholeNumber
          ? 'Enter a positive whole number'
          : 'Enter a finite number greater than zero';
    }
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    bool required = false,
    int? limit,
    int lines = 1,
    String? helper,
  }) => TextFormField(
    controller: controller,
    enabled: !_saving,
    maxLines: lines,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
    ),
    validator: (value) {
      final text = value?.trim() ?? '';
      if (required && text.isEmpty) return 'Enter $label';
      if (limit != null && text.length > limit) {
        return 'Use at most $limit characters';
      }
      return null;
    },
  );

  Widget _measurement(DroneParameter parameter) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final value = TextFormField(
          controller: _values[parameter],
          enabled: !_saving,
          keyboardType: TextInputType.numberWithOptions(
            decimal: !parameter.wholeNumber,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(labelText: parameter.fieldLabel),
          validator: (text) => _validateNumber(parameter, text),
          onChanged: (_) {
            if (_sources[parameter] != DroneValueSource.unspecified) {
              setState(
                () => _sources[parameter] = DroneValueSource.unspecified,
              );
            }
          },
        );
        // The key also updates a field's internal selection when a number edit
        // clears its old provenance. There is no inherited measured/estimated flag.
        final source = DropdownButtonFormField<DroneValueSource>(
          key: ValueKey('${parameter.name}:${_sources[parameter]!.name}'),
          initialValue: _sources[parameter],
          isExpanded: true,
          decoration: InputDecoration(labelText: '${parameter.label} source'),
          items: [
            for (final option in DroneValueSource.values)
              DropdownMenuItem(
                value: option,
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _saving
              ? null
              : (value) => setState(() => _sources[parameter] = value!),
        );
        return constraints.maxWidth < 440
            ? Column(children: [value, const SizedBox(height: 8), source])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: value),
                  const SizedBox(width: 16),
                  Expanded(child: source),
                ],
              );
      },
    ),
  );

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) {
      setState(() => _error = 'Check the highlighted fields before saving.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final input = DroneProfileInput(
        name: _name.text.trim(),
        type: _type.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        configuration: _configuration.text,
        propellerDescription: _propellers.text,
        motorDescription: _motors.text,
        escDescription: _esc.text,
        measurementContext: _context.text,
        measurements: {
          for (final parameter in DroneParameter.values)
            if (_values[parameter]!.text.trim().isNotEmpty)
              parameter: DroneMeasurement(
                _number(_values[parameter]!.text)!,
                source: _sources[parameter]!,
              ),
        },
      );
      if (widget.profile == null) {
        await widget.repository.createProfile(input);
      } else if (!await widget.repository.updateProfile(
        id: widget.profile!.drone.id,
        input: input,
      )) {
        throw StateError('Profile no longer exists');
      }
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to save this profile. Your entries are still here; retry or cancel.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _type,
      _notes,
      _configuration,
      _propellers,
      _motors,
      _esc,
      _context,
      ..._values.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.profile == null ? 'Add drone profile' : 'Edit drone profile',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _text(_name, 'Profile name', required: true, limit: 120),
                const SizedBox(height: 12),
                _text(
                  _type,
                  'Drone type',
                  required: true,
                  limit: 120,
                  helper: 'For example: quadcopter, fixed-wing or hexacopter',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Leave unknown values empty. Identify each entered value as measured, estimated or source not specified. Editing a number resets its previous source.',
                ),
                for (final group in DroneParameterGroup.values) ...[
                  const SizedBox(height: 24),
                  Text(
                    group.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (group == DroneParameterGroup.airframe)
                    _text(
                      _configuration,
                      'Configuration',
                      limit: 4000,
                      lines: 2,
                      helper: 'Frame layout, payload or build configuration',
                    ),
                  if (group == DroneParameterGroup.propellers)
                    _text(
                      _propellers,
                      'Propeller description',
                      limit: 120,
                      helper: 'Model, blade count or material',
                    ),
                  if (group == DroneParameterGroup.propulsion) ...[
                    _text(_motors, 'Motor description', limit: 120),
                    const SizedBox(height: 12),
                    _text(_esc, 'ESC description', limit: 120),
                  ],
                  for (final parameter in DroneParameter.values.where(
                    (parameter) => parameter.group == group,
                  ))
                    _measurement(parameter),
                ],
                const SizedBox(height: 20),
                _text(
                  _context,
                  'Measurement context / sources',
                  limit: 4000,
                  lines: 3,
                  helper: 'Battery voltage, payload, conditions, measurement method or estimate basis',
                ),
                const SizedBox(height: 16),
                _text(_notes, 'Notes', lines: 3),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}
