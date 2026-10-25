import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'road_routing.dart';

class RoadDestination {
  const RoadDestination(this.name, this.point);
  final String name;
  final MobilityPoint point;
}

/// Searches official Swiss place/address data only on explicit submission.
class DestinationSearch {
  DestinationSearch({http.Client? client})
    : _http = MobilityHttp(client: client);
  final MobilityHttp _http;
  void dispose() => _http.dispose();
  Future<List<RoadDestination>> search(String input) async {
    final query = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query.length < 3 ||
        query.length > 200 ||
        query.split(' ').length > 10) {
      throw const FormatException(
        'Bitte 3–200 Zeichen und höchstens 10 Wörter eingeben.',
      );
    }
    final raw = jsonDecode(
      await _http.text(
        Uri.https('api3.geo.admin.ch', '/rest/services/ech/SearchServer', {
          'type': 'locations',
          'searchText': query,
          'origins': 'address,zipcode,gg25,gazetteer',
          'limit': '10',
          'sr': '4326',
          'lang': 'de',
        }),
        maxBytes: 256 * 1024,
      ),
    );
    if (raw is! Map ||
        raw['results'] is! List ||
        (raw['results'] as List).length > 50) {
      throw const FormatException('Ungültige Antwort der Zielsuche.');
    }
    final results = <RoadDestination>[];
    for (final result in raw['results'] as List) {
      if (result is! Map || result['attrs'] is! Map) continue;
      final attrs = result['attrs'] as Map;
      final lat = attrs['lat'], lon = attrs['lon'], label = attrs['label'];
      if (lat is! num ||
          lon is! num ||
          label is! String ||
          label.length > 2000) {
        continue;
      }
      final point = MobilityPoint(lat.toDouble(), lon.toDouble());
      // Labels contain bold/italic HTML from the search service. Display text only.
      final name = label
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .trim();
      if (name.isNotEmpty) results.add(RoadDestination(name, point));
    }
    return results;
  }
}

class RoadDestinationSearch extends StatefulWidget {
  const RoadDestinationSearch({
    super.key,
    required this.onSelected,
    this.search,
  });
  final ValueChanged<RoadDestination> onSelected;
  final DestinationSearch? search;
  @override
  State<RoadDestinationSearch> createState() => _RoadDestinationSearchState();
}

class _RoadDestinationSearchState extends State<RoadDestinationSearch> {
  final _query = TextEditingController();
  late final _search = widget.search ?? DestinationSearch();
  bool _busy = false;
  String? _message;
  List<RoadDestination> _results = [];
  int _revision = 0;
  Future<void> _submit() async {
    if (_busy) return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _message = null;
      _results = [];
    });
    try {
      final results = await _search.search(_query.text);
      if (mounted && revision == _revision) {
        setState(() {
          _results = results;
          if (results.isEmpty) _message = 'Keine passenden Ziele gefunden.';
        });
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(
          () => _message = 'Zielsuche fehlgeschlagen. Eingabe und Verbindung prüfen oder Koordinaten verwenden.',
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('destinationSearch'),
        controller: _query,
        maxLength: 200,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() {
          _revision++;
          _busy = false;
          _results = [];
          _message = null;
        }),
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Adresse oder Ort in der Schweiz',
          counterText: '',
        ),
      ),
      OutlinedButton.icon(
        onPressed: _busy ? null : _submit,
        icon: const Icon(Icons.search),
        label: const Text('Ziel suchen'),
      ),
      const Text(
        'Erst „Ziel suchen“ sendet die Eingabe an geo.admin.ch / swisstopo. © swisstopo',
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_message != null) Text(_message!),
      for (final result in _results)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.place_outlined),
          title: Text(result.name),
          subtitle: Text(
            '${result.point.latitude.toStringAsFixed(5)}, ${result.point.longitude.toStringAsFixed(5)}',
          ),
          onTap: () {
            widget.onSelected(result);
            setState(() => _results = []);
          },
        ),
    ],
  );
}
