import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import 'backup_codec.dart';
import 'backup_file_service.dart';
import 'backup_repository.dart';
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
  late bool _cachedMaps = widget.cachedMaps;
  String? _status;
  final _password = TextEditingController(),
      _confirmation = TextEditingController();
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
            title: const Text('Backup password'),
            content: TextField(
              onChanged: (value) => input = value,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
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
        title: const Text('Replace personal data?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Backup from ${document['createdAt']}'),
              const SizedBox(height: 12),
              for (final e in counts.entries) Text('${e.value}: ${e.key}'),
              const SizedBox(height: 12),
              const Text(
                'This replaces your current spots, equipment, routes, images, checklists, telemetry and backed-up preferences. Restored map preferences can reconnect enabled layers. API keys and downloaded maps/data remain on this device. Create a backup of your current data first.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace and restore'),
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
      appBar: AppBar(title: const Text('Offline & personal data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OfflineRegionsSection(
            storage: widget.offlineStorage,
            latitude: widget.latitude,
            longitude: widget.longitude,
            cachedMaps: _cachedMaps,
            enabled: !_busy,
            onChanged: widget.onRegionsChanged,
            prepareSnapshots: widget.prepareOfflineSnapshots,
            onCachedMaps: (value) {
              setState(() => _cachedMaps = value);
              widget.onCachedMaps?.call(value);
            },
          ),
          const Divider(height: 32),
          Text(
            'Portable backups',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Save spots, images, equipment, routes, checklists, telemetry and planning preferences in one local file (up to 64 MiB). Public map/OSINT caches and API keys are excluded.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Protect backup with a password'),
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
              decoration: const InputDecoration(
                labelText: 'Password (at least 12 characters)',
              ),
            ),
            TextField(
              controller: _confirmation,
              enabled: !_busy,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Repeat password'),
            ),
            const Text('A forgotten password cannot be recovered.'),
          ] else
            const Text(
              'Unprotected backups contain readable personal data, including coordinates, notes and images.',
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.save_alt),
            label: const Text('Create backup'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.restore),
            label: const Text('Restore backup'),
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
