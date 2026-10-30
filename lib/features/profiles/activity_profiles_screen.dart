import 'package:flutter/material.dart';

import '../../core/models/activity_profile.dart';
import '../help/guides_screen.dart';
import 'activity_profile_editor.dart';
import 'activity_profile_files.dart';
import 'activity_profiles_repository.dart';

enum _ProfileAction { edit, duplicate, export, delete }

class ActivityProfilesScreen extends StatefulWidget {
  const ActivityProfilesScreen({
    super.key,
    required this.controller,
    required this.onActivate,
    this.files = const ActivityProfileFiles(),
  });
  final ActivityProfilesController controller;
  final Future<void> Function(ActivityProfile?) onActivate;
  final ActivityProfileFiles files;
  @override
  State<ActivityProfilesScreen> createState() => _ActivityProfilesScreenState();
}

class _ActivityProfilesScreenState extends State<ActivityProfilesScreen> {
  bool _working = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_working || widget.controller.busy) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException
                  ? error.message
                  : 'Profilaktion fehlgeschlagen. Bitte erneut versuchen.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _edit(ActivityProfile initial) async {
    final result = await Navigator.push<ActivityProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityProfileEditor(
          initial: initial,
          onSave: widget.controller.put,
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (widget.controller.selected?.id == result.id) {
      await widget.onActivate(result);
    }
  }

  Future<void> _select(ActivityProfile? profile) async {
    await widget.controller.select(profile?.id);
    await widget.onActivate(profile);
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _confirm(String title, String detail, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _import() async {
    final profile = await widget.files.pick();
    if (profile == null || !mounted) return;
    if (await _confirm(
      '„${profile.name}“ importieren?',
      '${profile.tools.length} Werkzeuge · ${profile.actions.length} Schnellaktionen · ${profile.layers.length} Ebenenfavoriten. Wird als neues, inaktives Profil hinzugefügt.',
      'Importieren',
    )) {
      var imported = profile;
      while (widget.controller.catalog!.profiles.any(
        (p) => p.id == imported.id,
      )) {
        imported = imported.copyWith(id: newActivityProfileId());
      }
      await widget.controller.put(imported);
    }
  }

  Future<void> _template() async {
    final template = await showDialog<ActivityProfile>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Vorlage wählen'),
        children: [
          for (final p in activityProfileTemplates())
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p),
              child: Text(p.name),
            ),
        ],
      ),
    );
    if (template != null && mounted) {
      await _edit(template.copyWith(id: newActivityProfileId()));
    }
  }

  Future<void> _action(_ProfileAction action, ActivityProfile p) async {
    switch (action) {
      case _ProfileAction.edit:
        await _edit(p);
      case _ProfileAction.duplicate:
        await _edit(
          p.copyWith(
            id: newActivityProfileId(),
            name:
                '${p.name.length > 57 ? p.name.substring(0, 57) : p.name} Kopie',
          ),
        );
      case _ProfileAction.export:
        if (await widget.files.save(p) && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Profil exportiert')));
        }
      case _ProfileAction.delete:
        if (await _confirm(
          'Profil löschen?',
          '„${p.name}“ entfernen? Orte, Ausrüstung und Routen bleiben erhalten.',
          'Löschen',
        )) {
          final active = widget.controller.selected?.id == p.id;
          await widget.controller.remove(p.id);
          if (active) await widget.onActivate(null);
        }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller, catalog = c.catalog;
      final disabled = _working || c.busy;
      final full = (catalog?.profiles.length ?? 0) >= activityProfileMaxCount;
      return Scaffold(
        appBar: AppBar(title: const Text('Aktivitätsprofile')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (c.busy) const LinearProgressIndicator(),
                  if (c.error != null)
                    Text(
                      c.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (catalog == null && !c.busy)
                    TextButton(
                      onPressed: c.load,
                      child: const Text('Erneut versuchen'),
                    ),
                  if (catalog != null) ...[
                    Text(
                      catalog.firstUseDone
                          ? 'Werkzeuge passend zu deiner Aktivität'
                          : 'Womit möchtest du starten?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Vorlagen sind frei anpassbar. Alle Werkzeuge bleiben erreichbar.',
                    ),
                    ListTile(
                      leading: const Icon(Icons.apps),
                      title: Text(
                        catalog.firstUseDone
                            ? 'Ohne Profil · alle Werkzeuge'
                            : 'Überspringen · alle Werkzeuge',
                      ),
                      selected: catalog.selectedId == null,
                      onTap: disabled ? null : () => _run(() => _select(null)),
                    ),
                    for (final p in catalog.profiles)
                      ListTile(
                        key: ValueKey('profile-${p.id}'),
                        leading: Icon(
                          catalog.selectedId == p.id
                              ? Icons.check_circle
                              : Icons.person_outline,
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                          '${p.tools.length} Werkzeuge · ${p.actions.length} Schnellaktionen',
                        ),
                        selected: catalog.selectedId == p.id,
                        onTap: disabled ? null : () => _run(() => _select(p)),
                        trailing: PopupMenuButton<_ProfileAction>(
                          tooltip: '${p.name}: Profilaktionen',
                          enabled: !disabled,
                          onSelected: (action) =>
                              _run(() => _action(action, p)),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: _ProfileAction.edit,
                              child: Text('Bearbeiten'),
                            ),
                            PopupMenuItem(
                              value: _ProfileAction.duplicate,
                              enabled: !full,
                              child: const Text('Duplizieren'),
                            ),
                            const PopupMenuItem(
                              value: _ProfileAction.export,
                              child: Text('Exportieren'),
                            ),
                            const PopupMenuItem(
                              value: _ProfileAction.delete,
                              child: Text('Löschen'),
                            ),
                          ],
                        ),
                      ),
                    if (full)
                      const Text(
                        'Maximal 32 Profile. Zum Hinzufügen zuerst ein Profil löschen.',
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Aus Vorlage'),
                          onPressed: disabled || full
                              ? null
                              : () => _run(_template),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Eigenes Profil'),
                          onPressed: disabled || full
                              ? null
                              : () => _run(
                                  () => _edit(
                                    ActivityProfile(
                                      id: newActivityProfileId(),
                                      name: '',
                                    ),
                                  ),
                                ),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.file_open_outlined),
                          label: const Text('Importieren'),
                          onPressed: disabled || full
                              ? null
                              : () => _run(_import),
                        ),
                      ],
                    ),
                    const GuideLink(GuideTopic.profiles),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
