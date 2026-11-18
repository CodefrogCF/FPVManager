import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

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
                  : context.localized(
                      "Profilaktion fehlgeschlagen. Bitte erneut versuchen.",
                      (l10n) => l10n
                          .profilesProfilaktionFehlgeschlagenBitteErneutfc851528,
                    ),
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
              child: Text(
                context.localized(
                  "Abbrechen",
                  (l10n) => l10n.commonAbbrechen07af7cb3,
                ),
              ),
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
        title: Text(
          context.localized(
            "Vorlage wählen",
            (l10n) => l10n.profilesVorlageWaehlen7df6eb54,
          ),
        ),
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
        appBar: AppBar(
          title: Text(
            context.localized(
              "Aktivitätsprofile",
              (l10n) => l10n.commonAktivitaetsprofilee88c0015,
            ),
          ),
        ),
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
                      child: Text(
                        context.localized(
                          "Erneut versuchen",
                          (l10n) => l10n.commonErneutVersuchen3234b7ec,
                        ),
                      ),
                    ),
                  if (catalog != null) ...[
                    Text(
                      catalog.firstUseDone
                          ? context.localized(
                              "Werkzeuge passend zu deiner Aktivität",
                              (l10n) =>
                                  l10n.profilesWerkzeugePassendZuDeiner8e101852,
                            )
                          : context.localized(
                              "Womit möchtest du starten?",
                              (l10n) =>
                                  l10n.profilesWomitMoechtestDuStartenee1d09d8,
                            ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      context.localized(
                        "Vorlagen sind frei anpassbar. Alle Werkzeuge bleiben erreichbar.",
                        (l10n) =>
                            l10n.profilesVorlagenSindFreiAnpassbarff309b1d,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.apps),
                      title: Text(
                        catalog.firstUseDone
                            ? context.localized(
                                "Ohne Profil · alle Werkzeuge",
                                (l10n) => l10n
                                    .profilesOhneProfilAlleWerkzeuge5ab1fd0c,
                              )
                            : context.localized(
                                "Überspringen · alle Werkzeuge",
                                (l10n) => l10n
                                    .profilesUberspringenAlleWerkzeuge95410f7f,
                              ),
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
                          context.localizedWithArgs(
                            "{0} Werkzeuge · {1} Schnellaktionen",
                            [p.tools.length, p.actions.length],
                            (l10n, value) =>
                                l10n.profilesWerkzeugeSchnellaktionenc271b295(
                                  value(0),
                                  value(1),
                                ),
                          ),
                        ),
                        selected: catalog.selectedId == p.id,
                        onTap: disabled ? null : () => _run(() => _select(p)),
                        trailing: PopupMenuButton<_ProfileAction>(
                          tooltip: '${p.name}: Profilaktionen',
                          enabled: !disabled,
                          onSelected: (action) =>
                              _run(() => _action(action, p)),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: _ProfileAction.edit,
                              child: Text(
                                context.localized(
                                  "Bearbeiten",
                                  (l10n) => l10n.profilesBearbeiten104f3bfd,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: _ProfileAction.duplicate,
                              enabled: !full,
                              child: Text(
                                context.localized(
                                  "Duplizieren",
                                  (l10n) => l10n.profilesDuplizieren8524c5cd,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: _ProfileAction.export,
                              child: Text(
                                context.localized(
                                  "Exportieren",
                                  (l10n) => l10n.profilesExportieren4e4a0d71,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: _ProfileAction.delete,
                              child: Text(
                                context.localized(
                                  "Löschen",
                                  (l10n) => l10n.commonLoeschenffa5a8a7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (full)
                      Text(
                        context.localized(
                          "Maximal 32 Profile. Zum Hinzufügen zuerst ein Profil löschen.",
                          (l10n) =>
                              l10n.profilesMaximalProfileZumHinzufuegene6d6ba7e,
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy_outlined),
                          label: Text(
                            context.localized(
                              "Aus Vorlage",
                              (l10n) => l10n.profilesAusVorlage7a27bf2c,
                            ),
                          ),
                          onPressed: disabled || full
                              ? null
                              : () => _run(_template),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: Text(
                            context.localized(
                              "Eigenes Profil",
                              (l10n) => l10n.profilesEigenesProfila1a7ad19,
                            ),
                          ),
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
                          label: Text(
                            context.localized(
                              "Importieren",
                              (l10n) => l10n.commonImportieren7d4a3f2a,
                            ),
                          ),
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
