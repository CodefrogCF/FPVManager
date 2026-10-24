import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import 'checklist.dart';
import 'preflight_repository.dart';

class ChecklistsTab extends StatefulWidget {
  const ChecklistsTab({super.key, required this.repository});
  final PreflightRepository repository;
  @override
  State<ChecklistsTab> createState() => _ChecklistsTabState();
}

class _ChecklistsTabState extends State<ChecklistsTab> {
  late final _rows = widget.repository.watch();
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checklist could not be saved: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit({
    PreflightChecklist? row,
    bool fromTemplate = false,
    bool template = false,
  }) async {
    final drones = await widget.repository.drones(),
        routes = await widget.repository.routes();
    if (!mounted) return;
    final result = await showDialog<_ChecklistDraft>(
      context: context,
      builder: (_) => _ChecklistEditor(
        row: row,
        drones: drones,
        routes: routes,
        fromTemplate: fromTemplate,
        template: template,
      ),
    );
    if (result == null) return;
    await widget.repository.save(
      id: fromTemplate ? null : row?.id,
      name: result.name,
      items: result.items,
      isTemplate: result.template,
      droneId: result.droneId,
      planId: result.planId,
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<PreflightChecklist>>(
    stream: _rows,
    builder: (context, snapshot) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Completion is saved on this device. Start a new checklist for each flight; completing it does not grant flight authorization.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : () => _run(() => _edit()),
              icon: const Icon(Icons.add_task),
              label: const Text('New checklist'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(() => _edit(template: true)),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('New template'),
            ),
          ],
        ),
        if (snapshot.hasError)
          const Text(
            'Local checklists unavailable. Reopen this screen to retry.',
          ),
        if (!snapshot.hasData && !snapshot.hasError)
          const LinearProgressIndicator(),
        for (final row in snapshot.data ?? <PreflightChecklist>[]) _card(row),
      ],
    ),
  );

  Widget _card(PreflightChecklist row) {
    List<ChecklistItem> items;
    try {
      items = decodeChecklist(row.itemsJson);
    } catch (_) {
      return ListTile(
        title: Text(row.name),
        subtitle: const Text('Unsupported checklist data'),
      );
    }
    final done = items.where((i) => i.checked).length;
    return Card(
      key: ValueKey(row.id),
      child: ExpansionTile(
        title: Text(row.name),
        subtitle: Text(
          row.isTemplate
              ? 'Reusable template · ${items.length} items'
              : '$done / ${items.length} checked · ${row.updatedAt.toLocal()}',
        ),
        trailing: PopupMenuButton<String>(
          enabled: !_busy,
          onSelected: (value) => _run(() async {
            if (value == 'start') {
              await _edit(row: row, fromTemplate: true);
            }
            if (value == 'edit') {
              await _edit(row: row);
            }
            if (value == 'delete') {
              if (!mounted) return;
              final yes = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Delete ${row.isTemplate ? "template" : "checklist"}?',
                  ),
                  content: Text(row.name),
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
              if (yes == true) await widget.repository.delete(row.id);
            }
          }),
          itemBuilder: (_) => [
            if (row.isTemplate)
              const PopupMenuItem(
                value: 'start',
                child: Text('Start checklist'),
              ),
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit items & associations'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        children: [
          if (row.droneId != null || row.planId != null)
            FutureBuilder<(List<Drone>, List<FlightPlan>)>(
              future: Future.wait<Object>([
                widget.repository.drones(),
                widget.repository.routes(),
              ]).then((v) => (v[0] as List<Drone>, v[1] as List<FlightPlan>)),
              builder: (_, s) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  [
                    if (row.droneId != null)
                      s.data?.$1
                              .where((d) => d.id == row.droneId)
                              .firstOrNull
                              ?.name ??
                          'Drone #${row.droneId}',
                    if (row.planId != null)
                      s.data?.$2
                              .where((p) => p.id == row.planId)
                              .firstOrNull
                              ?.name ??
                          'Route #${row.planId}',
                  ].join(' · '),
                ),
              ),
            ),
          for (var i = 0; i < items.length; i++)
            if (row.isTemplate)
              ListTile(dense: true, title: Text(items[i].label))
            else
              CheckboxListTile(
                title: Text(items[i].label),
                value: items[i].checked,
                onChanged: _busy
                    ? null
                    : (v) => _run(() => widget.repository.check(row.id, i, v!)),
              ),
        ],
      ),
    );
  }
}

class _ChecklistDraft {
  const _ChecklistDraft(
    this.name,
    this.items,
    this.template,
    this.droneId,
    this.planId,
  );
  final String name;
  final List<ChecklistItem> items;
  final bool template;
  final int? droneId, planId;
}

class _ChecklistEditor extends StatefulWidget {
  const _ChecklistEditor({
    this.row,
    required this.drones,
    required this.routes,
    required this.fromTemplate,
    required this.template,
  });
  final PreflightChecklist? row;
  final List<Drone> drones;
  final List<FlightPlan> routes;
  final bool fromTemplate, template;
  @override
  State<_ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<_ChecklistEditor> {
  late final _old = widget.row == null
      ? <ChecklistItem>[]
      : decodeChecklist(widget.row!.itemsJson);
  late final _name = TextEditingController(
    text: widget.row?.name ?? (widget.template ? 'My template' : 'Preflight'),
  );
  late final _items = TextEditingController(
    text: (_old.isEmpty ? defaultPreflightItems : _old.map((i) => i.label))
        .join('\n'),
  );
  late final _template =
      !widget.fromTemplate && (widget.row?.isTemplate ?? widget.template);
  late int? _drone = widget.row?.droneId, _route = widget.row?.planId;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _items.dispose();
    super.dispose();
  }

  void _save() {
    try {
      final labels = _items.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final items = [
        for (var i = 0; i < labels.length; i++)
          ChecklistItem(
            labels[i],
            checked:
                !widget.fromTemplate &&
                !_template &&
                i < _old.length &&
                _old[i].label == labels[i] &&
                _old[i].checked,
          ),
      ];
      encodeChecklist(items);
      if (_name.text.trim().isEmpty || _name.text.trim().length > 120) {
        throw ArgumentError('Enter a name up to 120 characters');
      }
      Navigator.pop(
        context,
        _ChecklistDraft(_name.text.trim(), items, _template, _drone, _route),
      );
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_template ? 'Checklist template' : 'Preflight checklist'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _items,
              minLines: 5,
              maxLines: 12,
              maxLength: 30100,
              decoration: const InputDecoration(
                labelText: 'Items · one per line',
                helperText: 'Up to 100 items. Changed items or associations must be checked again.',
              ),
            ),
            DropdownButtonFormField<int>(
              initialValue: _drone,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Drone'),
              items: [
                const DropdownMenuItem<int>(child: Text('Any drone')),
                for (final d in widget.drones)
                  DropdownMenuItem(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) => _drone = v,
            ),
            DropdownButtonFormField<int>(
              initialValue: _route,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Flight plan'),
              items: [
                const DropdownMenuItem<int>(child: Text('Any flight plan')),
                for (final p in widget.routes)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => _route = v,
            ),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _save,
        child: Text(
          widget.fromTemplate
              ? 'Start with all items unchecked'
              : 'Save locally',
        ),
      ),
    ],
  );
}
