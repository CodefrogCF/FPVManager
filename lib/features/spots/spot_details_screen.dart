import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import 'package:url_launcher/url_launcher.dart';

import 'data/spot_query.dart';
import 'data/spot_repository.dart';
import 'spot_editor_dialog.dart';
import 'spot_photo_viewer.dart';

class SpotDetailsScreen extends StatefulWidget {
  const SpotDetailsScreen({
    super.key,
    required this.repository,
    required this.spotId,
    this.onRoadRoute,
  });
  final SpotRepository repository;
  final int spotId;
  final Future<void> Function()? onRoadRoute;
  @override
  State<SpotDetailsScreen> createState() => _SpotDetailsScreenState();
}

class _SpotDetailsScreenState extends State<SpotDetailsScreen> {
  late final _details = widget.repository.watchDetails(widget.spotId);
  late final Future<Map<String, dynamic>?>? _osmProvenance =
      widget.repository is DriftSpotRepository
      ? (widget.repository as DriftSpotRepository).osmProvenance(widget.spotId)
      : null;
  bool _changing = false;
  String? _error;

  Future<void> _change(Future<void> Function() action) async {
    setState(() {
      _changing = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to update this spot. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  Future<void> _delete(SpotDetails details) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate("Delete spot?")),
        content: Text(
          context.translate("Permanently delete \"{0}\" and its photos?", [
            details.spot.name,
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.translate("Cancel")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.translate("Delete")),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _change(() async {
      await widget.repository.deleteSpot(widget.spotId);
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.translate("Spot details"))),
    body: StreamBuilder<SpotDetails?>(
      stream: _details,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(context.translate("Unable to load spot details.")),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final details = snapshot.data;
        if (details == null) {
          return Center(
            child: Text(context.translate("This spot no longer exists.")),
          );
        }
        final spot = details.spot;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        spot.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: spot.isFavorite
                          ? context.translate("Remove favorite")
                          : context.translate("Add favorite"),
                      onPressed: _changing
                          ? null
                          : () => _change(() async {
                              if (!await widget.repository.setFavorite(
                                id: spot.id,
                                isFavorite: !spot.isFavorite,
                              )) {
                                throw StateError('Missing spot');
                              }
                            }),
                      icon: Icon(
                        spot.isFavorite ? Icons.star : Icons.star_border,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  '${spot.latitude.toStringAsFixed(8)}, ${spot.longitude.toStringAsFixed(8)}',
                ),
                if (spot.category != null) ...[
                  const SizedBox(height: 16),
                  Text(context.translate("Category: {0}", [spot.category])),
                ],
                if (details.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final tag in details.tags) Chip(label: Text(tag)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                SelectableText(
                  spot.notes?.isNotEmpty == true
                      ? spot.notes!
                      : context.translate("No description added."),
                ),
                if (_osmProvenance != null)
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _osmProvenance,
                    builder: (context, source) {
                      final reference = source.data?['reference'];
                      if (reference is! String ||
                          !RegExp(r'^(node|way|relation)/[1-9][0-9]*$')
                              .hasMatch(reference)) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            context.translate("OpenStreetMap source: {0}", [
                              reference,
                            ]),
                          ),
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse(
                                'https://www.openstreetmap.org/$reference',
                              ),
                            ),
                            child: const Text(
                              'View original OSM element · © OpenStreetMap contributors · ODbL',
                            ),
                          ),
                          Text(
                            context.translate(
                              "Original OSM source reference is kept separately from personal edits.",
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _changing
                          ? null
                          : () => Navigator.pop(context, spot),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(context.translate("Show on map")),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => SpotPhotosDialog(
                          repository: widget.repository,
                          spotId: spot.id,
                          spotName: spot.name,
                        ),
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(context.translate("Photos")),
                    ),
                    if (widget.onRoadRoute != null)
                      OutlinedButton.icon(
                        onPressed: _changing ? null : widget.onRoadRoute,
                        icon: const Icon(Icons.directions_car_outlined),
                        label: Text(context.translate("Driving route")),
                      ),
                    OutlinedButton.icon(
                      onPressed: _changing
                          ? null
                          : () => showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => SpotEditorDialog(
                                repository: widget.repository,
                                spot: spot,
                              ),
                            ),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(context.translate("Edit")),
                    ),
                    TextButton.icon(
                      onPressed: _changing ? null : () => _delete(details),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.translate("Delete")),
                    ),
                  ],
                ),
                if (_changing) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
