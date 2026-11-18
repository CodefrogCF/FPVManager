import 'dart:typed_data';

import '../../core/localization/app_localizations.dart';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'situational_provider.dart';
import 'tmc_repository.dart';
import 'tmc_traffic_resolution.dart';

class TmcSection extends StatefulWidget {
  const TmcSection({
    super.key,
    required this.repository,
    required this.provider,
  });
  final TmcRepository repository;
  final SituationalProvider provider;
  @override
  State<TmcSection> createState() => _TmcSectionState();
}

class _TmcSectionState extends State<TmcSection> {
  String? _selected, _error;
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException ? error.message : 'TMC-Ortsdaten konnten nicht geladen werden. Vorhandene Tabellen bleiben erhalten.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(String version) => _run(() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'TMC LTEF ZIP', extensions: ['zip']),
      ],
    );
    if (file == null || !mounted) return;
    if (await file.length() > 8 * 1024 * 1024) {
      throw const FormatException('TMC-ZIP: maximal 8 MiB');
    }
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in file.openRead()) {
      length += chunk.length;
      if (length > 8 * 1024 * 1024) {
        throw const FormatException('TMC-ZIP: maximal 8 MiB');
      }
      bytes.add(chunk);
    }
    if (mounted) {
      await widget.repository.importZip(bytes.takeBytes(), version: version);
    }
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.repository, widget.provider]),
    builder: (context, _) {
      final repo = widget.repository,
          data = widget.provider.status.dataset?.data;
      final needed = data == null ? <String>{} : neededTmcVersions(data);
      final supported = TmcRepository.downloadableVersions;
      final options = {...supported, ...needed, ...repo.snapshots.keys}.toList()
        ..sort();
      final selected = options.contains(_selected)
          ? _selected!
          : needed.firstOrNull ?? supported.last;
      final disabled = _busy || repo.busy;
      return ExpansionTile(
        key: const ValueKey('tmcSection'),
        tilePadding: EdgeInsets.zero,
        title: Text(
          context.localized(
            "TMC-Ortsdaten",
            (l10n) => l10n.mobilityTmcOrtsdatene977fc3e,
          ),
        ),
        subtitle: Text(
          context.localizedWithArgs(
            "{0} Tabellen lokal{1}",
            [
              repo.snapshots.length,
              needed.isEmpty ? "" : " · benötigt: ${needed.join(", ")}",
            ],
            (l10n, value) =>
                l10n.mobilityTabellenLokal09ba7ffc(value(0), value(1)),
          ),
        ),
        children: [
          Text(
            context.localized(
              "Löst Schweizer Ortscodes und Tabellenrichtungen auf. Referenzdaten werden lokal gespeichert; die Aktualität der Verkehrsmeldungen bleibt unabhängig davon.",
              (l10n) => l10n.mobilityLoestSchweizerOrtscodesUnd47816372,
            ),
          ),
          if (data != null)
            Text(
              context.localizedWithArgs(
                "{0} Teilmeldungen aufgelöst · {1} noch offen",
                [data['tmcResolved'] ?? 0, data['tmcUnresolved'] ?? 0],
                (l10n, value) =>
                    l10n.mobilityTeilmeldungenAufgeloestNochOffenaa8196c8(
                      value(0),
                      value(1),
                    ),
              ),
            ),
          DropdownButtonFormField<String>(
            key: ValueKey('tmcVersion-$selected'),
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.localized(
                "Tabellenversion",
                (l10n) => l10n.mobilityTabellenversionb0986031,
              ),
            ),
            items: [
              for (final version in options)
                DropdownMenuItem(
                  value: version,
                  child: Text(
                    '$version${needed.contains(version) ? " · benötigt" : ""}',
                  ),
                ),
            ],
            onChanged: disabled ? null : (v) => setState(() => _selected = v),
          ),
          if (!supported.contains(selected))
            Text(
              context.localized(
                "Für diese Version ist kein LTEF-ZIP hinterlegt. Im offiziellen Katalog prüfen; GeoPackage wird noch nicht unterstützt.",
                (l10n) => l10n.mobilityFuerDieseVersionIst88b3c175,
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: disabled || kIsWeb || !supported.contains(selected)
                    ? null
                    : () => _run(() => repo.download(selected)),
                icon: const Icon(Icons.download_outlined),
                label: Text(
                  context.localizedWithArgs(
                    "Tabelle {0} laden",
                    [selected],
                    (l10n, value) =>
                        l10n.mobilityTabelleLaden750049fc(value(0)),
                  ),
                ),
              ),
              if (needed.any(
                (v) => !repo.snapshots.containsKey(v) && supported.contains(v),
              ))
                OutlinedButton(
                  onPressed: disabled || kIsWeb
                      ? null
                      : () => _run(() async {
                          for (final v in needed.where(
                            (v) =>
                                !repo.snapshots.containsKey(v) &&
                                supported.contains(v),
                          )) {
                            if (!mounted) return;
                            await repo.download(v);
                          }
                        }),
                  child: Text(
                    context.localized(
                      "Fehlende benötigte Tabellen laden",
                      (l10n) =>
                          l10n.mobilityFehlendeBenoetigteTabellenLaden3eb0f8e9,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: disabled ? null : () => _import(selected),
                icon: const Icon(Icons.file_open_outlined),
                label: Text(
                  context.localized(
                    "TMC-ZIP importieren",
                    (l10n) => l10n.mobilityTmcZipImportieren41204dbf,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(tmcCatalogUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(
                  context.localized(
                    "Offizieller Download und Quellen",
                    (l10n) =>
                        l10n.mobilityOffiziellerDownloadUndQuellen43d0f2a7,
                  ),
                ),
              ),
            ],
          ),
          if (kIsWeb)
            Text(
              context.localized(
                "Im Web das Original-ZIP über den offiziellen Download beziehen und lokal importieren. Kein zusätzlicher API-Schlüssel erforderlich.",
                (l10n) => l10n.mobilityImWebDasOriginal2ebbbc3c,
              ),
            ),
          if (disabled) const LinearProgressIndicator(),
          if (_error ?? repo.error case final String error)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (widget.provider.tmcError case final String error) Text(error),
          for (final entry in repo.snapshots.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.localizedWithArgs(
                  "TMC {0} · {1} Orte",
                  [entry.key, entry.value.table.nodes.length],
                  (l10n, value) =>
                      l10n.mobilityTmcOrted224adb9(value(0), value(1)),
                ),
              ),
              subtitle: Text(
                context.localizedWithArgs(
                  "ASTRA · Tabellenstand: {0}\nLokal bezogen: {1}{2}",
                  [
                    entry.value.table.publication?.isNotEmpty == true
                        ? entry.value.table.publication
                        : "nicht angegeben",
                    entry.value.retrievedUtc.toLocal(),
                    entry.value.imported
                        ? "\nDateiimport · nicht online bestätigt, nur Information"
                        : "\nDirekt von der offiziellen Downloadquelle",
                  ],
                  (l10n, value) =>
                      l10n.mobilityAstraTabellenstandLokalBezogenfdd31ddb(
                        value(0),
                        value(1),
                        value(2),
                      ),
                ),
              ),
              trailing: IconButton(
                tooltip: context.localizedWithArgs(
                  "Tabelle {0} entfernen",
                  [entry.key],
                  (l10n, value) =>
                      l10n.mobilityTabelleEntfernenad464a91(value(0)),
                ),
                onPressed: disabled
                    ? null
                    : () => _run(() => repo.remove(entry.key)),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          Text(
            context.localized(
              "TMC beschreibt vor allem Hauptverkehrsstraßen. Unbekannte Codes, Versionskonflikte und nicht eindeutige Abschnitte bleiben ohne Einfluss auf die Routenempfehlung.",
              (l10n) => l10n.commonTmcBeschreibtVorAllem56166f9f,
            ),
          ),
        ],
      );
    },
  );
}
