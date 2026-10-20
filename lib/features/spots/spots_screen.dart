import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/fpv_database.dart';
import '../../core/models/spot_classification.dart';
import 'data/spot_query.dart';
import 'data/spot_repository.dart';
import 'spot_details_screen.dart';
import 'spot_editor_dialog.dart';
import 'spot_label_field.dart';

class SpotsScreen extends StatefulWidget {
  const SpotsScreen({
    super.key,
    required this.repository,
    this.initialLatitude,
    this.initialLongitude,
  });
  final SpotRepository repository;
  final double? initialLatitude;
  final double? initialLongitude;
  @override
  State<SpotsScreen> createState() => _SpotsScreenState();
}

class _SpotsScreenState extends State<SpotsScreen> {
  final _search = TextEditingController();
  final _cursors = <int?>[null];
  Timer? _debounce;
  String _query = '';
  bool _favorites = false;
  SpotClassification _labels = SpotClassification();
  late Stream<SpotPage> _page;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _refresh(reset: true);
  }

  void _refresh({bool reset = false}) {
    if (reset) {
      _cursors
        ..clear()
        ..add(null);
    }
    _revision++;
    _page = widget.repository.watchSpotPage(
      beforeId: _cursors.last,
      filter: SpotFilter(
        query: _query,
        favoritesOnly: _favorites,
        category: _labels.category,
        tags: _labels.tags,
      ),
    );
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _query = value;
          _refresh(reset: true);
        });
      }
    });
  }

  void _clear() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _query = '';
      _favorites = false;
      _labels = SpotClassification();
      _refresh(reset: true);
    });
  }

  Future<void> _filters() async {
    final result = await showDialog<SpotClassification>(
      context: context,
      builder: (context) =>
          _SpotFiltersDialog(repository: widget.repository, labels: _labels),
    );
    if (result != null && mounted) {
      setState(() {
        _labels = result;
        _refresh(reset: true);
      });
    }
  }

  Future<void> _details(int id) async {
    final spot = await Navigator.of(context).push<Spot>(
      MaterialPageRoute(
        builder: (context) =>
            SpotDetailsScreen(repository: widget.repository, spotId: id),
      ),
    );
    if (spot != null && mounted) Navigator.pop(context, spot);
  }

  final _favoriteChanges = <int>{};
  Future<void> _favorite(SpotSummary spot) async {
    setState(() => _favoriteChanges.add(spot.id));
    try {
      if (!await widget.repository.setFavorite(
        id: spot.id,
        isFavorite: !spot.isFavorite,
      )) {
        throw StateError('Missing spot');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update favorite. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _favoriteChanges.remove(spot.id));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('FPV Spots')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp('\u0000')),
              ],
              maxLength: 160,
              onChanged: _searchChanged,
              decoration: InputDecoration(
                labelText: 'Search spots',
                hintText: 'Name, description, category or tags',
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _search.clear();
                    _searchChanged('');
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .20,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('Favorites'),
                    selected: _favorites,
                    avatar: const Icon(Icons.star_border, size: 18),
                    onSelected: (value) => setState(() {
                      _favorites = value;
                      _refresh(reset: true);
                    }),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.filter_list, size: 18),
                    label: Text(
                      'Categories / tags${_labels.category != null || _labels.tags.isNotEmpty ? ' •' : ''}',
                    ),
                    onPressed: _filters,
                  ),
                  if (_labels.category != null)
                    InputChip(
                      label: Text(_labels.category!),
                      onDeleted: () => setState(() {
                        _labels = SpotClassification(tags: _labels.tags);
                        _refresh(reset: true);
                      }),
                    ),
                  for (final tag in _labels.tags)
                    InputChip(
                      label: Text(tag),
                      onDeleted: () => setState(() {
                        _labels = SpotClassification(
                          category: _labels.category,
                          tags: _labels.tags.where((value) => value != tag),
                        );
                        _refresh(reset: true);
                      }),
                    ),
                  if (_query.isNotEmpty ||
                      _favorites ||
                      _labels.category != null ||
                      _labels.tags.isNotEmpty)
                    TextButton(
                      onPressed: _clear,
                      child: const Text('Clear filters'),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<SpotPage>(
              key: ValueKey(_revision),
              stream: _page,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Unable to load spots.'),
                        TextButton(
                          onPressed: () => setState(() => _refresh()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final page = snapshot.data!;
                return Column(
                  children: [
                    Expanded(
                      child: page.items.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No spots found. Add a spot or adjust your filters.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: page.items.length,
                              itemBuilder: (context, index) {
                                final spot = page.items[index];
                                return ListTile(
                                  leading: const Icon(Icons.place_outlined),
                                  title: Text(
                                    spot.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${spot.latitude.toStringAsFixed(6)}, ${spot.longitude.toStringAsFixed(6)}',
                                      ),
                                      if (spot.category != null ||
                                          spot.tags.isNotEmpty)
                                        Text(
                                          [
                                            if (spot.category != null)
                                              spot.category!,
                                            ...spot.tags.map((tag) => '#$tag'),
                                          ].join(' · '),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (spot.notesPreview.isNotEmpty)
                                        Text(
                                          spot.notesPreview,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                  onTap: () => _details(spot.id),
                                  trailing: IconButton(
                                    tooltip: spot.isFavorite
                                        ? 'Remove favorite'
                                        : 'Add favorite',
                                    onPressed:
                                        _favoriteChanges.contains(spot.id)
                                        ? null
                                        : () => _favorite(spot),
                                    icon: Icon(
                                      spot.isFavorite
                                          ? Icons.star
                                          : Icons.star_border,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          8,
                          4,
                          8,
                          keyboardVisible ? 4 : 88,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _cursors.length == 1
                                  ? null
                                  : () => setState(() {
                                      _cursors.removeLast();
                                      _refresh();
                                    }),
                              child: const Text('Previous'),
                            ),
                            Expanded(
                              child: Text(
                                'Page ${_cursors.length} · ${page.items.length} spots',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: page.hasNext
                                  ? () => setState(() {
                                      _cursors.add(page.nextBeforeId);
                                      _refresh();
                                    })
                                  : null,
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: keyboardVisible
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => SpotEditorDialog(
                  repository: widget.repository,
                  initialLatitude: widget.initialLatitude,
                  initialLongitude: widget.initialLongitude,
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Spot'),
            ),
    );
  }
}

class _SpotFiltersDialog extends StatefulWidget {
  const _SpotFiltersDialog({required this.repository, required this.labels});
  final SpotRepository repository;
  final SpotClassification labels;
  @override
  State<_SpotFiltersDialog> createState() => _SpotFiltersDialogState();
}

class _SpotFiltersDialogState extends State<_SpotFiltersDialog> {
  final _form = GlobalKey<FormState>();
  late final _category = TextEditingController(text: widget.labels.category);
  late final _tags = TextEditingController(text: widget.labels.tags.join(', '));
  @override
  void dispose() {
    _category.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Filter spots'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpotLabelField(
                controller: _category,
                repository: widget.repository,
              ),
              const SizedBox(height: 12),
              SpotLabelField(
                controller: _tags,
                repository: widget.repository,
                tags: true,
              ),
              const SizedBox(height: 12),
              const Text(
                'Matches the category and every selected tag. Search and favorites also apply.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              SpotClassification(
                category: _category.text,
                tags: SpotClassification.parseTags(_tags.text),
              ),
            );
          }
        },
        child: const Text('Apply'),
      ),
    ],
  );
}
