import 'dart:typed_data';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import 'data/spot_photo.dart';
import 'data/spot_repository.dart';

Future<void> showSpotPhoto(
  BuildContext context, {
  Uint8List? bytes,
  SpotRepository? repository,
  SpotPhotoPreview? photo,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _PhotoDialog(bytes: bytes, repository: repository, photo: photo),
  );
}

class _PhotoDialog extends StatefulWidget {
  const _PhotoDialog({this.bytes, this.repository, this.photo});
  final Uint8List? bytes;
  final SpotRepository? repository;
  final SpotPhotoPreview? photo;
  @override
  State<_PhotoDialog> createState() => _PhotoDialogState();
}

class _PhotoDialogState extends State<_PhotoDialog> {
  late Future<Uint8List?> _bytes;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bytes = widget.bytes != null
        ? Future.value(widget.bytes)
        : widget.repository!.getPhotoBytes(
            spotId: widget.photo!.spotId,
            photoId: widget.photo!.id,
          );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      context.localized("Spot photo", (l10n) => l10n.spotsSpotPhoto590ebf66),
    ),
    content: SizedBox(
      width: 800,
      height: MediaQuery.sizeOf(context).height * .6,
      child: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.localized(
                      "Unable to load this photo.",
                      (l10n) => l10n.spotsUnableToLoadThisc9e4faa4,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(_load),
                    child: Text(
                      context.localized(
                        "Retry",
                        (l10n) => l10n.commonRetry9f5cd8a2,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data == null) {
            return Center(
              child: Text(
                context.localized(
                  "This photo is no longer available.",
                  (l10n) => l10n.spotsThisPhotoIsNo08b26948,
                ),
              ),
            );
          }
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              semanticLabel: context.localized(
                "Saved spot photo",
                (l10n) => l10n.spotsSavedSpotPhoto279ddf6a,
              ),
              errorBuilder: (context, error, stack) => Center(
                child: Text(
                  context.localized(
                    "Unable to display this photo.",
                    (l10n) => l10n.spotsUnableToDisplayThis38f897ec,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          context.localized("Close", (l10n) => l10n.commonClosebbfa773e),
        ),
      ),
    ],
  );
}

class SpotPhotosDialog extends StatefulWidget {
  const SpotPhotosDialog({
    super.key,
    required this.repository,
    required this.spotId,
    required this.spotName,
  });
  final SpotRepository repository;
  final int spotId;
  final String spotName;
  @override
  State<SpotPhotosDialog> createState() => _SpotPhotosDialogState();
}

class _SpotPhotosDialogState extends State<SpotPhotosDialog> {
  late final Stream<List<SpotPhotoPreview>> _photos = widget.repository
      .watchPhotos(widget.spotId);
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      context.localizedWithArgs("Photos: {0}", [
        widget.spotName,
      ], (l10n, value) => l10n.spotsPhotosa324a5d2(value(0))),
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: StreamBuilder<List<SpotPhotoPreview>>(
          stream: _photos,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                context.localized(
                  "Unable to load photos. Close this window and try again.",
                  (l10n) => l10n.spotsUnableToLoadPhotos634c2fc3,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return Text(
                context.localized(
                  "No photos yet. Edit this spot to add photos.",
                  (l10n) => l10n.spotsNoPhotosYetEdit1cb7ab6f,
                ),
              );
            }
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final photo in snapshot.data!)
                  InkWell(
                    onTap: () => showSpotPhoto(
                      context,
                      repository: widget.repository,
                      photo: photo,
                    ),
                    child: Image.memory(
                      photo.thumbnailBytes,
                      width: 120,
                      height: 100,
                      fit: BoxFit.cover,
                      semanticLabel: context.localized(
                        "Open spot photo",
                        (l10n) => l10n.spotsOpenSpotPhoto9410015a,
                      ),
                      errorBuilder: (context, error, stack) => const SizedBox(
                        width: 120,
                        height: 100,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          context.localized("Close", (l10n) => l10n.commonClosebbfa773e),
        ),
      ),
    ],
  );
}
