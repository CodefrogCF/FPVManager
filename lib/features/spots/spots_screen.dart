import 'dart:async';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/fpv_database.dart';
import '../../core/models/spot_classification.dart';
import 'data/spot_query.dart';
import 'data/spot_repository.dart';
import 'spot_details_screen.dart';
import 'spot_editor_dialog.dart';
import 'spot_label_field.dart';
import 'spot_list_controller.dart';

class SpotsScreen extends StatefulWidget {
  const SpotsScreen({
    super.key,
    required this.repository,
    this.initialLatitude,
    this.initialLongitude,
    this.onRoadRoute,
    this.title = 'FPV Spots',
  });
  final SpotRepository repository;
  final String title;
  final double? initialLatitude;
  final double? initialLongitude;
  final Future<void> Function(int)? onRoadRoute;
  @override
  State<SpotsScreen> createState() => _SpotsScreenState();
}

class _SpotsScreenState extends State<SpotsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  late SpotListController _list;
  Timer? _debounce;
  String _query = '';
  bool _favorites = false;
  SpotClassification _labels = SpotClassification();

  @override
  void initState() {
    super.initState();
    _list = SpotListController(widget.repository)..addListener(_listChanged);
    _scroll.addListener(_nearEnd);
  }

  void _listChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nearEnd();
    });
  }

  void _nearEnd() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
      unawaited(_list.loadMore());
    }
  }

  void _refresh({bool reset = false}) {
    _list.setFilter(
      SpotFilter(
        query: _query,
        favoritesOnly: _favorites,
        category: _labels.category,
        tags: _labels.tags,
      ),
    );
    if (reset && _scroll.hasClients) _scroll.jumpTo(0);
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
        builder: (context) => SpotDetailsScreen(
          repository: widget.repository,
          spotId: id,
          onRoadRoute: widget.onRoadRoute == null
              ? null
              : () => widget.onRoadRoute!(id),
        ),
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
          SnackBar(
            content: Text(
              context.translate("Unable to update favorite. Please retry."),
            ),
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
    _scroll.dispose();
    _list.removeListener(_listChanged);
    _list.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
                labelText: context.translate("Search spots"),
                hintText: context.translate(
                  "Name, description, category or tags",
                ),
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: context.translate("Clear search"),
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
                      context.translate("Categories / tags{0}", [
                        _labels.category != null || _labels.tags.isNotEmpty
                            ? ' •'
                            : '',
                      ]),
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
                      child: Text(context.translate("Clear filters")),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: _spotList(keyboardVisible)),
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
              label: Text(context.translate("Add Spot")),
            ),
    );
  }

  Widget _spotList(bool keyboardVisible) {
    if (_list.items.isEmpty) {
      if (_list.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _list.error ??
                    context.translate(
                      "No spots found. Add a spot or adjust your filters.",
                    ),
                textAlign: TextAlign.center,
              ),
              if (_list.error != null)
                TextButton(
                  onPressed: _list.retry,
                  child: Text(context.translate("Retry")),
                ),
            ],
          ),
        ),
      );
    }
    final indices = {
      for (var i = 0; i < _list.items.length; i++) _list.items[i].id: i,
    };
    return Column(
      children: [
        if (_list.refreshing) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            key: const PageStorageKey('continuous-spot-list'),
            controller: _scroll,
            padding: EdgeInsets.only(bottom: keyboardVisible ? 8 : 96),
            itemCount: _list.items.length + 1,
            findChildIndexCallback: (key) =>
                key is ValueKey<int> ? indices[key.value] : null,
            itemBuilder: (context, index) {
              if (index == _list.items.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: _list.loading
                        ? const CircularProgressIndicator()
                        : _list.error != null
                        ? Column(
                            children: [
                              Text(_list.error!),
                              TextButton(
                                onPressed: _list.retry,
                                child: Text(context.translate("Retry")),
                              ),
                            ],
                          )
                        : Text(
                            _list.hasMore
                                ? context.translate(
                                    "Weitere Spots werden beim Scrollen geladen.",
                                  )
                                : context.translate("Alle {0} Spots geladen.", [
                                    _list.items.length,
                                  ]),
                          ),
                  ),
                );
              }
              final spot = _list.items[index];
              return ListTile(
                key: ValueKey(spot.id),
                leading: const Icon(Icons.place_outlined),
                title: Text(
                  spot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${spot.latitude.toStringAsFixed(6)}, ${spot.longitude.toStringAsFixed(6)}',
                    ),
                    if (spot.category != null || spot.tags.isNotEmpty)
                      Text(
                        [
                          if (spot.category != null) spot.category!,
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
                      ? context.translate("Remove favorite")
                      : context.translate("Add favorite"),
                  onPressed: _favoriteChanges.contains(spot.id)
                      ? null
                      : () => _favorite(spot),
                  icon: Icon(spot.isFavorite ? Icons.star : Icons.star_border),
                ),
              );
            },
          ),
        ),
      ],
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
              Text(
                context.translate(
                  "Matches the category and every selected tag. Search and favorites also apply.",
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.translate("Cancel")),
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
        child: Text(context.translate("Apply")),
      ),
    ],
  );
}
