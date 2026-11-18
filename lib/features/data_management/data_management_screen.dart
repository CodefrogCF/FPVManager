import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/database/fpv_database.dart';
import 'backup_codec.dart';
import 'backup_file_service.dart';
import 'backup_repository.dart';
import '../offline/base_map_cache_preference.dart';
import '../offline/offline_regions_section.dart';
import '../offline/offline_region.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({
    super.key,
    required this.database,
    this.beforeRestore,
    this.onRestored,
    this.files = const BackupFileService(),
    this.latitude = 46.8,
    this.longitude = 8.3,
    this.cachedMaps = false,
    this.onCachedMaps,
    this.onRegionsChanged,
    this.offlineStorage,
    this.prepareOfflineSnapshots,
  });
  final FpvDatabase database;
  final Future<void> Function()? beforeRestore, onRestored;
  final BackupFileService files;
  final double latitude, longitude;
  final bool cachedMaps;
  final ValueChanged<bool>? onCachedMaps;
  final ValueChanged<OfflineRegion?>? onRegionsChanged;
  final OfflineMapStorage? offlineStorage;
  final Future<String> Function(Set<String>)? prepareOfflineSnapshots;
  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _busy = false, _encrypt = true;
  bool _savingCacheMode = false;
  late bool _cachedMaps = widget.cachedMaps;
  String? _status;
  final _password = TextEditingController(),
      _confirmation = TextEditingController();

  Future<void> _setCachedMaps(bool value) async {
    if (_savingCacheMode || _cachedMaps == value) return;
    setState(() => _savingCacheMode = true);
    try {
      await BaseMapCachePreference(widget.database).write(value);
      widget.onCachedMaps?.call(value);
      if (mounted) setState(() => _cachedMaps = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                "The map cache preference could not be saved.",
                (l10n) => l10n.datamanagementTheMapCachePreference010bed10,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCacheMode = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await work();
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Operation failed. The file may be invalid, too large, or the password may be incorrect. Existing data was retained.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run(() async {
    if (_encrypt &&
        (_password.text.length < 12 || _password.text != _confirmation.text)) {
      setState(
        () => _status =
            'Use at least 12 characters and enter the same password twice.',
      );
      return;
    }
    final bytes = await BackupRepository(widget.database)
        .create(password: _encrypt ? _password.text : null);
    _password.clear();
    _confirmation.clear();
    final saved = await widget.files.save(bytes);
    if (mounted) {
      setState(
        () => _status = saved
            ? 'Backup exported. Keep it in a safe location.'
            : 'Export cancelled.',
      );
    }
  });
  Future<void> _import() => _run(() async {
    final bytes = await widget.files.pick();
    if (bytes == null) return;
    String? password;
    if (isEncryptedBackup(bytes)) {
      if (!mounted) return;
      var input = "";
      {
        password = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              context.localized(
                "Backup password",
                (l10n) => l10n.datamanagementBackupPasswordd96a6076,
              ),
            ),
            content: TextField(
              onChanged: (value) => input = value,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.localized(
                  "Password",
                  (l10n) => l10n.datamanagementPassword8be3c943,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  context.localized(
                    "Cancel",
                    (l10n) => l10n.commonCancel77dfd213,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, input),
                child: const Text('Open backup'),
              ),
            ],
          ),
        );
      }
      if (password == null) return;
    }
    final repository = BackupRepository(widget.database),
        document = await repository.preview(bytes, password: password);
    password = null;
    if (!mounted) return;
    final tables = document['tables'] as Map;
    final counts = {
      for (final e in {
        'spots': 'Spots',
        'drones': 'Drones',
        'batteries': 'Batteries',
        'radio_equipment': 'Radio profiles',
        'flight_plans': 'Flight routes',
        'ground_routes': 'Bodenrouten',
        'spot_photos': 'Images',
        'preflight_checklists': 'Checklists',
        'telemetry_flights': 'Telemetry flights',
      }.entries)
        e.value: (tables[e.key] as List? ?? []).length,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.localized(
            "Replace personal data?",
            (l10n) => l10n.datamanagementReplacePersonalData946d9c54,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.localizedWithArgs(
                  "Backup from {0}",
                  [document['createdAt']],
                  (l10n, value) =>
                      l10n.datamanagementBackupFrome163c3fa(value(0)),
                ),
              ),
              const SizedBox(height: 12),
              for (final e in counts.entries) Text('${e.value}: ${e.key}'),
              const SizedBox(height: 12),
              Text(
                context.localized(
                  "This replaces your current spots, equipment, routes, images, checklists, telemetry and backed-up preferences. Restored map preferences can reconnect enabled layers. API keys and downloaded maps/data remain on this device. Create a backup of your current data first.",
                  (l10n) => l10n.commonThisReplacesYourCurrentf961d89e,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.localized("Cancel", (l10n) => l10n.commonCancel77dfd213),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.localized(
                "Replace and restore",
                (l10n) => l10n.datamanagementReplaceAndRestoreee68c046,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.beforeRestore?.call();
    await repository.restore(document);
    try {
      await widget.onRestored?.call();
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'Backup restored. Reopen the map to reload its preferences.',
        );
      }
      return;
    }
    if (mounted) setState(() => _status = 'Backup restored successfully.');
  });
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          context.localized(
            "Offline & personal data",
            (l10n) => l10n.datamanagementOfflinePersonalDatae0f55e89,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OfflineRegionsSection(
            storage: widget.offlineStorage,
            latitude: widget.latitude,
            longitude: widget.longitude,
            cachedMaps: _cachedMaps,
            enabled: !_busy && !_savingCacheMode,
            onChanged: widget.onRegionsChanged,
            prepareSnapshots: widget.prepareOfflineSnapshots,
            onCachedMaps: _setCachedMaps,
          ),
          const Divider(height: 32),
          Text(
            context.localized(
              "Portable backups",
              (l10n) => l10n.datamanagementPortableBackups13832bb9,
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            context.localized(
              "Save spots, images, equipment, routes, checklists, telemetry and planning preferences in one local file (up to 64 MiB). Public map/OSINT caches and API keys are excluded.",
              (l10n) => l10n.commonSaveSpotsImagesEquipmentdd4221ef,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.localized(
                "Protect backup with a password",
                (l10n) => l10n.datamanagementProtectBackupWithAf8add733,
              ),
            ),
            value: _encrypt,
            onChanged: _busy ? null : (v) => setState(() => _encrypt = v),
          ),
          if (_encrypt) ...[
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.localized(
                  "Password (at least 12 characters)",
                  (l10n) =>
                      l10n.datamanagementPasswordAtLeastCharacters518d1ae0,
                ),
              ),
            ),
            TextField(
              controller: _confirmation,
              enabled: !_busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.localized(
                  "Repeat password",
                  (l10n) => l10n.datamanagementRepeatPassword366c2415,
                ),
              ),
            ),
            Text(
              context.localized(
                "A forgotten password cannot be recovered.",
                (l10n) => l10n.datamanagementAForgottenPasswordCannot76d00a6a,
              ),
            ),
          ] else
            Text(
              context.localized(
                "Unprotected backups contain readable personal data, including coordinates, notes and images.",
                (l10n) => l10n.commonUnprotectedBackupsContainReadableec1db6d0,
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.save_alt),
            label: Text(
              context.localized(
                "Create backup",
                (l10n) => l10n.datamanagementCreateBackup60e77f3b,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.restore),
            label: Text(
              context.localized(
                "Restore backup",
                (l10n) => l10n.datamanagementRestoreBackupa65eaa88,
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_status!),
            ),
        ],
      ),
    ),
  );
}
