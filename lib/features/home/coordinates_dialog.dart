import 'package:flutter/material.dart';

import '../mobility/destination_search.dart';
import 'globe_search.dart';

class CoordinatesDialog extends StatefulWidget {
  const CoordinatesDialog({super.key, this.search});
  final GlobeSearch? search;
  @override
  State<CoordinatesDialog> createState() => CoordinatesDialogState();
}

class CoordinatesDialogState extends State<CoordinatesDialog> {
  final _query = TextEditingController();
  late final _search = widget.search ?? GlobeSearch();
  List<RoadDestination> _results = [];
  String? _message;
  bool _busy = false;
  int _revision = 0;

  Future<void> _submit() async {
    if (_busy || _query.text.trim().isEmpty) return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _results = [];
      _message = null;
    });
    try {
      final results = await _search.search(_query.text);
      if (!mounted || revision != _revision) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _message = 'Keine passenden Orte gefunden.';
      });
    } on FormatException catch (error) {
      if (mounted && revision == _revision) {
        setState(() => _message = error.message);
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(
          () => _message = 'Onlinesuche nicht verfügbar. Verbindung prüfen oder Koordinaten eingeben.',
        );
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _revision++;
    _query.dispose();
    if (widget.search == null) _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ort oder Koordinaten suchen'),
    scrollable: true,
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('globeSearch'),
            controller: _query,
            autofocus: true,
            maxLength: 200,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Koordinaten, Ort oder Straße',
              counterText: '',
              hintText: '46.7, 8.4 · LV95: 2600000 / 1200000',
            ),
            onChanged: (_) => setState(() {
              _revision++;
              _busy = false;
              _results = [];
              _message = null;
            }),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            'WGS84: Breite, Länge · LV95: Ost / Nord\nOrts- und Adresssuche erst beim Absenden: geo.admin.ch / © swisstopo',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message!),
            ),
          for (final result in _results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(result.name),
              subtitle: Text(
                'WGS84 · ${result.point.latitude.toStringAsFixed(5)}, ${result.point.longitude.toStringAsFixed(5)}',
              ),
              onTap: () => Navigator.pop(context, result),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _busy ? null : _submit,
        icon: const Icon(Icons.search),
        label: const Text('Suchen'),
      ),
    ],
  );
}
