import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import '../../core/models/spot_classification.dart';
import 'data/spot_location_service.dart';
import 'data/spot_photo.dart';
import 'data/spot_photo_service.dart';
import 'data/spot_repository.dart';
import 'spot_photo_viewer.dart';
import 'spot_label_field.dart';

class SpotEditorDialog extends StatefulWidget {
  const SpotEditorDialog({
    super.key,
    required this.repository,
    this.spot,
    this.initialLatitude,
    this.initialLongitude,
    this.photoService = const SpotPhotoService(),
    this.locationService = const SpotLocationService(),
  });
  final SpotRepository repository;
  final Spot? spot;
  final double? initialLatitude;
  final double? initialLongitude;
  final SpotPhotoService photoService;
  final SpotLocationService locationService;
  @override
  State<SpotEditorDialog> createState() => _SpotEditorDialogState();
}

class _SpotEditorDialogState extends State<SpotEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _notes;
  late final TextEditingController _category;
  final _tags = TextEditingController();
  List<SpotPhotoPreview> _existingPhotos = [];
  final _newPhotos = <PreparedSpotPhoto>[];
  bool _loading = false;
  bool _loadFailed = false;
  bool _picking = false;
  bool _locating = false;
  bool _saving = false;
  int _coordinateRevision = 0;
  String? _error;
  String? _locationMessage;

  bool get _busy => _loading || _picking || _locating || _saving;
  int get _photoCount => _existingPhotos.length + _newPhotos.length;

  @override
  void initState() {
    super.initState();
    final spot = widget.spot;
    _name = TextEditingController(text: spot?.name ?? '');
    _latitude = TextEditingController(
      text:
          (spot?.latitude ?? widget.initialLatitude)?.toStringAsFixed(8) ?? '',
    );
    _longitude = TextEditingController(
      text:
          (spot?.longitude ?? widget.initialLongitude)?.toStringAsFixed(8) ??
          '',
    );
    _notes = TextEditingController(text: spot?.notes ?? '');
    _category = TextEditingController(text: spot?.category ?? '');
    _latitude.addListener(_coordinatesChanged);
    _longitude.addListener(_coordinatesChanged);
    if (spot != null) unawaited(_loadPhotos());
  }

  void _coordinatesChanged() {
    _coordinateRevision++;
    if (_locationMessage != null) setState(() => _locationMessage = null);
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _error = null;
    });
    try {
      final (photos, tags) = await (
        widget.repository.getPhotos(widget.spot!.id),
        widget.repository.getTags(widget.spot!.id),
      ).wait;
      if (mounted) {
        setState(() {
          _existingPhotos = photos;
          _tags.text = tags.join(', ');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _error =
              'Unable to load existing photos and tags. Retry before saving.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_busy || _photoCount >= SpotPhotoLimits.maxPhotos) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final photo = await widget.photoService.pickPhoto();
      if (mounted && photo != null) setState(() => _newPhotos.add(photo));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : 'Unable to open this photo. Try another JPEG, PNG or WebP.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _useLocation() async {
    if (_busy) return;
    final revision = _coordinateRevision;
    setState(() {
      _locating = true;
      _error = null;
      _locationMessage = null;
    });
    try {
      final location = await widget.locationService.currentLocation();
      if (!mounted) return;
      if (revision != _coordinateRevision) {
        setState(
          () => _locationMessage =
              'Coordinates were edited while locating. Your edits were kept.',
        );
        return;
      }
      _latitude.text = location.position.latitude.toStringAsFixed(8);
      _longitude.text = location.position.longitude.toStringAsFixed(8);
      setState(
        () => _locationMessage =
            'Device location · ${location.accuracyMeters == null ? 'accuracy unavailable' : 'accuracy ±${location.accuracyMeters!.ceil()} m'}. Check the coordinates before saving.',
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is SpotLocationException
              ? error.message
              : 'Unable to read location. Enter coordinates manually.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  double? _parseCoordinate(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String? _validateCoordinate(String? value, double minimum, double maximum) {
    final coordinate = _parseCoordinate(value ?? '');
    return coordinate == null ||
            !coordinate.isFinite ||
            coordinate < minimum ||
            coordinate > maximum
        ? 'Enter a value from $minimum to $maximum'
        : null;
  }

  Future<void> _save() async {
    if (_busy || _loadFailed || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final name = _name.text.trim();
      final latitude = _parseCoordinate(_latitude.text)!;
      final longitude = _parseCoordinate(_longitude.text)!;
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
      final classification = SpotClassification(
        category: _category.text,
        tags: SpotClassification.parseTags(_tags.text),
      );
      if (widget.spot == null) {
        await widget.repository.createSpot(
          name: name,
          latitude: latitude,
          longitude: longitude,
          notes: notes,
          photos: _newPhotos,
          classification: classification,
        );
      } else {
        final updated = await widget.repository.updateSpot(
          id: widget.spot!.id,
          name: name,
          latitude: latitude,
          longitude: longitude,
          notes: notes,
          retainedPhotoIds: _existingPhotos.map((photo) => photo.id).toList(),
          newPhotos: _newPhotos,
          classification: classification,
        );
        if (!updated) throw StateError('This spot no longer exists.');
      }
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to save this spot. Your edits are still here; retry or cancel.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _photoTile({
    required Widget image,
    required VoidCallback open,
    required VoidCallback remove,
    required int number,
  }) => SizedBox(
    width: 96,
    height: 100,
    child: Stack(
      children: [
        Positioned.fill(
          child: InkWell(
            onTap: open,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton.filledTonal(
            tooltip: 'Remove photo $number',
            visualDensity: VisualDensity.compact,
            onPressed: _busy ? null : remove,
            icon: const Icon(Icons.close, size: 18),
          ),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _latitude.removeListener(_coordinatesChanged);
    _longitude.removeListener(_coordinatesChanged);
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _notes.dispose();
    _category.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.spot == null ? 'Add Spot' : 'Edit Spot'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  enabled: !_saving,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Spot name'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Enter a spot name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _latitude,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude (WGS84)',
                  ),
                  validator: (value) => _validateCoordinate(value, -90, 90),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _longitude,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude (WGS84)',
                  ),
                  validator: (value) => _validateCoordinate(value, -180, 180),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _useLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      _locating ? 'Locating…' : 'Use current location',
                    ),
                  ),
                ),
                if (_locationMessage != null)
                  Text(
                    _locationMessage!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  enabled: !_saving,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description / notes (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                SpotLabelField(
                  controller: _category,
                  repository: widget.repository,
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),
                SpotLabelField(
                  controller: _tags,
                  repository: widget.repository,
                  tags: true,
                  enabled: !_loading && !_loadFailed && !_saving,
                ),
                const SizedBox(height: 16),
                Text(
                  'Photos ($_photoCount/${SpotPhotoLimits.maxPhotos})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (_loading || _picking || _saving)
                  const LinearProgressIndicator(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < _existingPhotos.length; i++)
                      _photoTile(
                        number: i + 1,
                        image: Image.memory(
                          _existingPhotos[i].thumbnailBytes,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                        open: () => showSpotPhoto(
                          context,
                          repository: widget.repository,
                          photo: _existingPhotos[i],
                        ),
                        remove: () =>
                            setState(() => _existingPhotos.removeAt(i)),
                      ),
                    for (var i = 0; i < _newPhotos.length; i++)
                      _photoTile(
                        number: _existingPhotos.length + i + 1,
                        image: Image.memory(
                          _newPhotos[i].thumbnailBytes,
                          fit: BoxFit.cover,
                        ),
                        open: () => showSpotPhoto(
                          context,
                          bytes: _newPhotos[i].imageBytes,
                        ),
                        remove: () => setState(() => _newPhotos.removeAt(i)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed:
                        _busy ||
                            _loadFailed ||
                            _photoCount >= SpotPhotoLimits.maxPhotos
                        ? null
                        : _pickPhoto,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add photo'),
                  ),
                ),
                const Text(
                  'JPEG, PNG or WebP · up to 12 MiB and 16 MP each. Photos are resized and stored locally.',
                  style: TextStyle(fontSize: 12),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    semanticsLabel: _error,
                  ),
                ],
                if (_loadFailed)
                  TextButton(
                    onPressed: _busy ? null : _loadPhotos,
                    child: const Text('Retry loading photos'),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || _loadFailed ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}
