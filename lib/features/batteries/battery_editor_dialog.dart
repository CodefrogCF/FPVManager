import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/battery_repository.dart';
import '../../core/models/battery_profile.dart';

class BatteryEditorDialog extends StatefulWidget {
  const BatteryEditorDialog({
    super.key,
    required this.repository,
    this.profile,
    this.asType = false,
    this.fromType,
  });
  final BatteryRepository repository;
  final BatteryProfile? profile;
  final bool asType;
  final Battery? fromType;
  @override
  State<BatteryEditorDialog> createState() => _BatteryEditorDialogState();
}

class _BatteryEditorDialogState extends State<BatteryEditorDialog> {
  final _form = GlobalKey<FormState>();
  Battery? get _seed => widget.profile?.battery ?? widget.fromType;
  bool get _isType => widget.profile?.battery.isType ?? widget.asType;
  late final _name = TextEditingController(text: widget.profile?.battery.name);
  late final _chemistry = TextEditingController(
    text: _seed?.chemistry ?? 'LiPo',
  );
  late final _numbers = <String, TextEditingController>{
    'Cell count': TextEditingController(text: _seed?.cellCount.toString()),
    'Capacity (mAh)': TextEditingController(
      text: _seed?.capacityMah.toString(),
    ),
    'Nominal voltage (V)': TextEditingController(
      text: _seed?.nominalVoltageVolts?.toString(),
    ),
    'Recorded energy (Wh)': TextEditingController(
      text: _seed?.energyWh?.toString(),
    ),
    'Weight (g)': TextEditingController(text: _seed?.weightGrams?.toString()),
    'Recorded charge (%)': TextEditingController(
      text: widget.profile?.battery.chargePercent?.toString(),
    ),
    'Cycle count': TextEditingController(
      text: widget.profile?.battery.cycleCount?.toString(),
    ),
  };
  late final _notes = TextEditingController(
    text: widget.profile?.battery.notes,
  );
  late final _condition = TextEditingController(
    text: widget.profile?.battery.conditionNotes,
  );
  late int? _typeId = widget.profile?.battery.typeId ?? widget.fromType?.id;
  late BatteryAvailability _availability = BatteryAvailability.parse(
    widget.profile?.battery.availability ?? 'unknown',
  );
  late final Set<int> _droneIds = {
    for (final item in widget.profile?.drones ?? <Drone>[]) item.id,
  };
  late final Set<int> _planIds = {
    for (final item in widget.profile?.flightPlans ?? <FlightPlan>[]) item.id,
  };
  late Future<BatteryAssignmentOptions> _options = widget.repository
      .getAssignmentOptions();
  bool _saving = false;
  String? _error;

  double? _number(String label) =>
      double.tryParse(_numbers[label]!.text.trim().replaceAll(',', '.'));
  String? _optional(TextEditingController controller) =>
      controller.text.trim().isEmpty ? null : controller.text.trim();

  Widget _text(
    TextEditingController controller,
    String label, {
    bool required = false,
    int limit = 120,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return 'Enter $label';
        if (text.length > limit) return 'Use at most $limit characters';
        return null;
      },
    ),
  );

  Widget _numeric(
    String label, {
    bool required = false,
    bool whole = false,
    bool zero = false,
    bool percent = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: _numbers[label],
      enabled: !_saving,
      keyboardType: TextInputType.numberWithOptions(decimal: !whole),
      decoration: InputDecoration(
        labelText: label,
        helperText: required ? null : 'Optional',
      ),
      onChanged: (_) => setState(() {}),
      validator: (text) {
        if (text == null || text.trim().isEmpty) {
          return required ? 'Enter $label' : null;
        }
        final value = _number(label);
        if (value == null ||
            !value.isFinite ||
            (zero || percent ? value < 0 : value <= 0) ||
            (percent && value > 100) ||
            (whole &&
                (value != value.truncateToDouble() ||
                    value > 9007199254740991))) {
          return percent
              ? 'Enter a number from 0 to 100'
              : whole
              ? 'Enter a ${zero ? 'nonnegative' : 'positive'} whole number'
              : 'Enter a finite number greater than zero';
        }
        return null;
      },
    ),
  );

  void _copyType(Battery type) {
    setState(() {
      _chemistry.text = type.chemistry;
      for (final entry in <String, num?>{
        'Cell count': type.cellCount,
        'Capacity (mAh)': type.capacityMah,
        'Nominal voltage (V)': type.nominalVoltageVolts,
        'Recorded energy (Wh)': type.energyWh,
        'Weight (g)': type.weightGrams,
      }.entries) {
        _numbers[entry.key]!.text = entry.value?.toString() ?? '';
      }
    });
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await widget.repository.saveProfile(
        BatteryInput(
          name: _name.text,
          chemistry: _chemistry.text,
          cellCount: _number('Cell count')!.toInt(),
          capacityMah: _number('Capacity (mAh)')!.toInt(),
          nominalVoltageVolts: _number('Nominal voltage (V)'),
          energyWh: _number('Recorded energy (Wh)'),
          weightGrams: _number('Weight (g)'),
          isType: _isType,
          typeId: _isType ? null : _typeId,
          chargePercent: _isType ? null : _number('Recorded charge (%)'),
          cycleCount: _isType ? null : _number('Cycle count')?.toInt(),
          availability: _isType ? BatteryAvailability.unknown : _availability,
          notes: _optional(_notes),
          conditionNotes: _isType ? null : _optional(_condition),
          droneIds: _isType ? {} : _droneIds,
          flightPlanIds: _isType ? {} : _planIds,
        ),
        id: widget.profile?.battery.id,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to save. Your entries are still here; check assignments and retry.',
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
      _chemistry,
      _notes,
      _condition,
      ..._numbers.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: FutureBuilder<BatteryAssignmentOptions>(
      future: _options,
      builder: (context, snapshot) {
        final options = snapshot.data;
        Battery? selectedType;
        if (options != null) {
          for (final type in options.types) {
            if (type.id == _typeId) selectedType = type;
          }
        }
        final voltage = _number('Nominal voltage (V)'),
            capacity = _number('Capacity (mAh)');
        final calculated = voltage == null || capacity == null
            ? null
            : voltage * (capacity / 1000);
        return AlertDialog(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.profile == null ? 'Add' : 'Edit'} battery${_isType ? ' type' : ''}',
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (snapshot.hasError) ...[
                      const Text('Unable to load types and assignments.'),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(
                                () => _options = widget.repository
                                    .getAssignmentOptions(),
                              ),
                        child: const Text('Retry loading options'),
                      ),
                    ] else if (options == null)
                      const LinearProgressIndicator(),
                    _text(
                      _name,
                      _isType ? 'Type name' : 'Battery name',
                      required: true,
                    ),
                    if (!_isType && options != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        key: ValueKey('type:$_typeId'),
                        initialValue: _typeId ?? 0,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Type template (optional)',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 0,
                            child: Text('No type template'),
                          ),
                          if (_typeId != null && selectedType == null)
                            DropdownMenuItem(
                              value: _typeId,
                              enabled: false,
                              child: const Text('Removed type'),
                            ),
                          for (final type in options.types)
                            DropdownMenuItem(
                              value: type.id,
                              child: Text(
                                type.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                () => _typeId = value == 0 ? null : value,
                              ),
                      ),
                      if (_typeId != null && selectedType == null)
                        const Text(
                          'The assigned type was removed. Select a type or no template.',
                        ),
                      TextButton(
                        onPressed: _saving || selectedType == null
                            ? null
                            : () => _copyType(selectedType!),
                        child: const Text('Copy type specifications'),
                      ),
                      const Text(
                        'Packs keep independent specification copies. Later type edits do not change them.',
                      ),
                    ],
                    _text(_chemistry, 'Chemistry', required: true),
                    _numeric('Cell count', required: true, whole: true),
                    _numeric('Capacity (mAh)', required: true, whole: true),
                    _numeric('Nominal voltage (V)'),
                    _numeric('Recorded energy (Wh)'),
                    if (calculated != null &&
                        calculated.isFinite &&
                        calculated > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Calculated nominal energy: ${calculated.toStringAsFixed(2)} Wh (capacity × nominal voltage)',
                        ),
                      ),
                    _numeric('Weight (g)'),
                    _text(_notes, 'Notes', limit: 4000, lines: 2),
                    if (!_isType) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Condition & availability',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'Charge, cycles and condition are recorded manually.',
                      ),
                      _numeric('Recorded charge (%)', percent: true),
                      _numeric('Cycle count', whole: true, zero: true),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<BatteryAvailability>(
                        initialValue: _availability,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Availability',
                        ),
                        items: [
                          for (final value in BatteryAvailability.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _availability = value!),
                      ),
                      _text(
                        _condition,
                        'Condition notes',
                        limit: 4000,
                        lines: 3,
                      ),
                      if (options != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Associated drones',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (options.drones.isEmpty)
                          const Text('No drone profiles yet.'),
                        for (final drone in options.drones)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(drone.name),
                            value: _droneIds.contains(drone.id),
                            onChanged: _saving
                                ? null
                                : (checked) => setState(() {
                                    if (checked!) {
                                      _droneIds.add(drone.id);
                                    } else {
                                      _droneIds.remove(drone.id);
                                    }
                                  }),
                          ),
                        Text(
                          'Associated flight plans',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (options.flightPlans.isEmpty)
                          const Text('No saved flight plans yet.'),
                        for (final plan in options.flightPlans)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(plan.name),
                            value: _planIds.contains(plan.id),
                            onChanged: _saving
                                ? null
                                : (checked) => setState(() {
                                    if (checked!) {
                                      _planIds.add(plan.id);
                                    } else {
                                      _planIds.remove(plan.id);
                                    }
                                  }),
                          ),
                      ],
                    ],
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
              onPressed: _saving || options == null ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save'),
            ),
          ],
        );
      },
    ),
  );
}
