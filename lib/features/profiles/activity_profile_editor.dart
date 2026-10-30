import 'package:flutter/material.dart';

import '../../core/models/activity_profile.dart';
import '../../core/models/user_preferences.dart';
import '../help/guides_screen.dart';

class ActivityProfileEditor extends StatefulWidget {
  const ActivityProfileEditor({super.key, required this.initial, this.onSave});
  final ActivityProfile initial;
  final Future<void> Function(ActivityProfile)? onSave;
  @override
  State<ActivityProfileEditor> createState() => _ActivityProfileEditorState();
}

class _ActivityProfileEditorState extends State<ActivityProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial.name);
  late GlobeMapStyle? _style = widget.initial.map.style;
  late bool? _places = widget.initial.map.savedPlaces;
  late bool? _lighting = widget.initial.map.lighting;
  late final _tools = widget.initial.tools.toSet();
  late final _actions = widget.initial.actions.toSet();
  late final _layers = widget.initial.layers.toSet();
  bool _changed = false;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final result = ActivityProfile(
      id: widget.initial.id,
      name: _name.text.trim(),
      map: ActivityMapDefaults(
        style: _style,
        savedPlaces: _places,
        lighting: _lighting,
      ),
      tools: ActivityTool.values.where(_tools.contains),
      actions: ActivityAction.values.where(_actions.contains),
      layers: ActivityLayer.values.where(_layers.contains),
    );
    setState(() => _saving = true);
    try {
      await widget.onSave?.call(result);
      if (!mounted) return;
      setState(() {
        _changed = false;
        _saving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, result);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profil wurde nicht gespeichert. Dein Entwurf bleibt erhalten; bitte erneut versuchen.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Widget _options<T extends Enum>(
    String title,
    List<T> values,
    Set<T> selected,
    String Function(T) label,
  ) => ExpansionTile(
    title: Text(title),
    children: [
      for (final value in values)
        CheckboxListTile(
          title: Text(label(value)),
          value: selected.contains(value),
          onChanged: (on) => setState(() {
            _changed = true;
            on! ? selected.add(value) : selected.remove(value);
          }),
        ),
    ],
  );

  Widget _bool(String label, bool? value, ValueChanged<bool?> onChanged) =>
      DropdownButtonFormField<int>(
        initialValue: value == null
            ? -1
            : value
            ? 1
            : 0,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: const [
          DropdownMenuItem(value: -1, child: Text('Beibehalten')),
          DropdownMenuItem(value: 1, child: Text('Ein')),
          DropdownMenuItem(value: 0, child: Text('Aus')),
        ],
        onChanged: (v) => setState(() {
          _changed = true;
          onChanged(v == -1 ? null : v == 1);
        }),
      );

  Future<bool> _mayLeave() async =>
      !_changed ||
      await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Änderungen verwerfen?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Weiter bearbeiten'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Verwerfen'),
                ),
              ],
            ),
          ) ==
          true;

  @override
  Widget build(BuildContext context) => PopScope<ActivityProfile>(
    canPop: !_changed && !_saving,
    onPopInvokedWithResult: (didPop, result) async {
      if (_saving) return;
      if (!didPop && await _mayLeave() && mounted) {
        setState(() => _changed = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Profil bearbeiten')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: AbsorbPointer(
                absorbing: _saving,
                child: ExcludeFocus(
                  excluding: _saving,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _name,
                        autofocus: false,
                        maxLength: 64,
                        decoration: const InputDecoration(
                          labelText: 'Profilname',
                        ),
                        onChanged: (_) => setState(() => _changed = true),
                        validator: (v) =>
                            v == null ||
                                v.trim().isEmpty ||
                                RegExp(r'[\x00-\x1f\x7f]').hasMatch(v)
                            ? 'Bitte einen gültigen Namen eingeben'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      const Text('Kartenstartwerte beim Aktivieren'),
                      DropdownButtonFormField<String>(
                        initialValue: _style?.name ?? 'keep',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Hintergrundkarte',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'keep',
                            child: Text('Beibehalten'),
                          ),
                          DropdownMenuItem(
                            value: 'satellite',
                            child: Text('Satellit'),
                          ),
                          DropdownMenuItem(
                            value: 'topographic',
                            child: Text('Topografisch'),
                          ),
                          DropdownMenuItem(
                            value: 'relief',
                            child: Text('Relief'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          _changed = true;
                          _style = value == 'keep'
                              ? null
                              : GlobeMapStyle.values.byName(value!);
                        }),
                      ),
                      _bool('Gespeicherte Orte', _places, (v) => _places = v),
                      _bool(
                        'Reale Tag-/Nachtbeleuchtung',
                        _lighting,
                        (v) => _lighting = v,
                      ),
                      const SizedBox(height: 16),
                      _options(
                        'Bevorzugte Werkzeuge',
                        ActivityTool.values,
                        _tools,
                        (v) => v.label,
                      ),
                      _options(
                        'Schnellaktionen auf der Karte',
                        ActivityAction.values,
                        _actions,
                        (v) => v.label,
                      ),
                      _options(
                        'Bevorzugte Ebenen · Schnellzugriffe',
                        ActivityLayer.values,
                        _layers,
                        (v) => v.label,
                      ),
                      const GuideLink(GuideTopic.profiles),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _saving ? 'Wird gespeichert…' : 'Profil speichern',
                        ),
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
