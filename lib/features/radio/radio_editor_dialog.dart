import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/radio_equipment_repository.dart';
import '../../core/models/radio_profile.dart';

class RadioEditorDialog extends StatefulWidget {
  const RadioEditorDialog({super.key, required this.repository, this.profile});
  final RadioEquipmentRepository repository;
  final RadioProfile? profile;
  @override
  State<RadioEditorDialog> createState() => _RadioEditorDialogState();
}

class _RadioEditorDialogState extends State<RadioEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.profile?.equipment.name,
  );
  late String _category = widget.profile?.equipment.category ?? 'control';
  late final _parameters = {
    for (final field in RadioParameter.values)
      field: TextEditingController(
        text: widget.profile == null
            ? ''
            : field.read(widget.profile!.equipment)?.toString() ?? '',
      ),
  };
  late final _descriptions = {
    for (final field in RadioTextField.values)
      field: TextEditingController(
        text: widget.profile == null
            ? ''
            : field.read(widget.profile!.equipment),
      ),
  };
  late final _droneIds =
      widget.profile?.drones.map((row) => row.id).toSet() ?? <int>{};
  late Future<List<Drone>> _drones = widget.repository.getDrones();
  bool _saving = false;
  String? _error;

  double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Widget _text(
    TextEditingController controller,
    String label, {
    int limit = 120,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      maxLines: limit > 120 ? 2 : 1,
      decoration: InputDecoration(labelText: label),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Enter $label';
        }
        if ((value?.length ?? 0) > limit) {
          return 'Use at most $limit characters';
        }
        return null;
      },
    ),
  );

  Widget _numeric(RadioParameter field) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: _parameters[field],
      enabled: !_saving,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: field.signed,
      ),
      decoration: InputDecoration(labelText: field.fieldLabel),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (text) {
        if (text == null || text.trim().isEmpty) return null;
        final number = _number(text);
        if (number == null) return 'Enter a number';
        try {
          field.validate(number);
        } on ArgumentError {
          return field.signed
              ? 'Enter a finite number'
              : field.zero
              ? 'Enter zero or a positive finite number'
              : 'Enter a positive finite number';
        }
        return null;
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
      final id = await widget.repository.saveProfile(
        RadioProfileInput(
          name: _name.text.trim(),
          category: _category,
          parameters: {
            for (final field in RadioParameter.values)
              if (_parameters[field]!.text.trim().isNotEmpty)
                field: _number(_parameters[field]!.text)!,
          },
          descriptions: {
            for (final field in RadioTextField.values)
              if (_descriptions[field]!.text.trim().isNotEmpty)
                field: _descriptions[field]!.text.trim(),
          },
          droneIds: _droneIds,
        ),
        id: widget.profile?.equipment.id,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context, id);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to save this profile. Your entries are still here; refresh drones if an assignment was removed, then retry or cancel.',
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
      ..._parameters.values,
      ..._descriptions.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: FutureBuilder<List<Drone>>(
      future: _drones,
      builder: (context, snapshot) {
        final drones = snapshot.data;
        final missing = drones == null
            ? <int>[]
            : _droneIds
                  .where((id) => !drones.any((row) => row.id == id))
                  .toList();
        return AlertDialog(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.profile == null
                    ? context.translate("Add equipment profile")
                    : context.translate("Edit equipment profile"),
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
            width: 640,
            child: SingleChildScrollView(
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(_name, 'Profile name', required: true),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.translate("System category"),
                      ),
                      items: [
                        for (final entry in radioCategories.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        if (!radioCategories.containsKey(_category))
                          DropdownMenuItem(
                            value: _category,
                            child: Text(
                              _category,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _category = value!),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.translate(
                        "Create independent control and video configurations. Leave unknown values empty. Maximum power is the transmitter output before antenna gain and cable loss; record the applicable mode and source below.",
                      ),
                    ),
                    for (final group in RadioProfileSection.values) ...[
                      const SizedBox(height: 24),
                      Text(
                        group.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final field in RadioTextField.values.where(
                        (field) => field.group == group,
                      ))
                        _text(
                          _descriptions[field]!,
                          field.label,
                          limit: field.limit,
                        ),
                      for (final field in RadioParameter.values.where(
                        (field) => field.group == group,
                      ))
                        _numeric(field),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      context.translate("Associated drones"),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      context.translate(
                        "A drone can use several independent configurations.",
                      ),
                    ),
                    if (snapshot.hasError)
                      Text(context.translate("Unable to load drone profiles.")),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const LinearProgressIndicator(),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _drones = widget.repository.getDrones();
                            }),
                      child: Text(context.translate("Refresh drones")),
                    ),
                    if (drones != null && drones.isEmpty && missing.isEmpty)
                      Text(
                        context.translate(
                          "No drone profiles yet. You can assign this equipment later.",
                        ),
                      ),
                    for (final row in drones ?? <Drone>[])
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(row.name),
                        value: _droneIds.contains(row.id),
                        onChanged: _saving
                            ? null
                            : (checked) => setState(() {
                                if (checked!) {
                                  _droneIds.add(row.id);
                                } else {
                                  _droneIds.remove(row.id);
                                }
                              }),
                      ),
                    for (final id in missing)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          context.translate(
                            "Removed drone (#{0}) — uncheck to continue",
                            [id],
                          ),
                        ),
                        value: true,
                        onChanged: _saving
                            ? null
                            : (_) => setState(() => _droneIds.remove(id)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(context.translate("Cancel")),
            ),
            FilledButton(
              onPressed:
                  _saving ||
                      drones == null ||
                      snapshot.hasError ||
                      snapshot.connectionState == ConnectionState.waiting ||
                      missing.isNotEmpty
                  ? null
                  : _save,
              child: Text(
                _saving
                    ? context.translate("Saving...")
                    : context.translate("Save"),
              ),
            ),
          ],
        );
      },
    ),
  );
}
