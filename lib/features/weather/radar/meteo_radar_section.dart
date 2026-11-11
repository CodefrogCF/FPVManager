import 'dart:async';

import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../globe/globe_controller.dart';
import 'meteo_radar_catalog.dart';

/// A deliberate, bounded discovery/animation UI for official observations.
/// It is not part of the Open-Meteo / MeteoSwiss forecast selection.
class MeteoRadarSection extends StatefulWidget {
  const MeteoRadarSection({super.key, required this.globe, this.catalog});

  final GlobeController globe;
  final MeteoRadarCatalog? catalog;

  @override
  State<MeteoRadarSection> createState() => _MeteoRadarSectionState();
}

class _MeteoRadarSectionState extends State<MeteoRadarSection> {
  late final MeteoRadarCatalog _catalog = widget.catalog ?? MeteoRadarCatalog();
  MeteoRadarProduct _product = MeteoRadarProduct.intensity;
  List<MeteoRadarFrame> _all = const [];
  bool _busy = false, _playing = false;
  int _index = 0, _generation = 0;
  String? _error;
  Timer? _timer;

  List<MeteoRadarFrame> get _frames =>
      _all.where((frame) => frame.product == _product).take(12).toList();

  @override
  void dispose() {
    _timer?.cancel();
    _catalog.dispose();
    _generation++;
    unawaited(widget.globe.clearMeteoSwissRadar().catchError((Object _) {}));
    super.dispose();
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    _playing = false;
  }

  Future<void> _discover() async {
    _pause();
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final generation = ++_generation;
    try {
      final results = await _catalog.discover(force: true);
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _all = results;
        _index = 0;
      });
      if (_frames.isEmpty) {
        setState(
          () => _error = 'No published frames for this product. This does not mean zero precipitation or complete coverage.',
        );
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _show(int index) async {
    final frames = _frames;
    if (_busy || index < 0 || index >= frames.length) {
      return;
    }
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _index = index;
    });
    try {
      await widget.globe.showMeteoSwissRadar(frames[index].toGlobeCommand());
    } catch (error) {
      if (mounted && generation == _generation) {
        _pause();
        setState(() => _error = 'Radar frame unavailable: $error');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  void _play() {
    if (_playing) {
      setState(_pause);
      return;
    }
    if (_busy || _frames.length < 2) {
      return;
    }
    if (_index == 0) {
      unawaited(_show(_frames.length - 1));
    }
    setState(() => _playing = true);
    // No speculative loading: one frame at a time; skip ticks while busy.
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !_playing) {
        return;
      }
      if (_busy) {
        return;
      }
      if (_index == 0) {
        setState(_pause);
        return;
      }
      unawaited(_show(_index - 1));
    });
  }

  String _format(DateTime value) {
    final time = value.toUtc();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(time.day)}.${pad(time.month)}.${time.year} ${pad(time.hour)}:${pad(time.minute)} UTC';
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    final selected = frames.isNotEmpty
        ? frames[_index >= 0 && _index < frames.length ? _index : 0]
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.translate("Official MeteoSwiss precipitation radar"),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              context.translate(
                "Observation, not forecast. Missing pixels and missing dates must not be interpreted as dry weather.",
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<MeteoRadarProduct>(
              initialValue: _product,
              decoration: InputDecoration(
                labelText: context.translate("Radar product"),
              ),
              items: [
                for (final product in MeteoRadarProduct.values)
                  DropdownMenuItem(
                    value: product,
                    child: Text('${product.label} (${product.unit})'),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (product) {
                      if (product == null) {
                        return;
                      }
                      setState(() {
                        _pause();
                        _product = product;
                        _index = 0;
                        _error = null;
                      });
                      unawaited(
                        widget.globe.clearMeteoSwissRadar().catchError(
                          (Object _) {},
                        ),
                      );
                    },
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _discover,
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(context.translate("Discover published radar times")),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (selected != null) ...[
              Text(
                context.translate("Observed: {0} · {1}", [
                  _format(selected.timestampUtc),
                  selected.product.unit,
                ]),
              ),
              if (selected.catalogueUpdatedUtc != null)
                Text(
                  context.translate("STAC updated: {0}", [
                    _format(selected.catalogueUpdatedUtc!),
                  ]),
                ),
              if (selected.quality != null)
                Text(
                  context.translate("Published CPC quality flag: {0}/9", [
                    selected.quality,
                  ]),
                ),
              if (selected.quality == null)
                Text(
                  context.translate(
                    "No published quality flag for this frame (quality unknown).",
                  ),
                ),
              Slider(
                value: _index
                    .toDouble()
                    .clamp(0, (frames.length - 1).toDouble())
                    .toDouble(),
                min: 0,
                max: (frames.length - 1).toDouble(),
                divisions: frames.length > 1 ? frames.length - 1 : null,
                label: _format(selected.timestampUtc),
                onChanged: _busy || frames.length == 1
                    ? null
                    : (value) {
                        setState(_pause);
                        unawaited(_show(value.round()));
                      },
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _show(_index),
                    icon: const Icon(Icons.radar),
                    label: Text(context.translate("Show selected frame")),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || _index >= frames.length - 1
                        ? null
                        : () {
                            setState(_pause);
                            unawaited(_show(_index + 1));
                          },
                    icon: const Icon(Icons.skip_previous),
                    label: const Text('Older'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _busy && !_playing ? null : _play,
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      _playing ? 'Pause' : context.translate("Play forward"),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy || _index == 0
                        ? null
                        : () {
                            setState(_pause);
                            unawaited(_show(_index - 1));
                          },
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Newer'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      setState(_pause);
                      await widget.globe.clearMeteoSwissRadar();
                    },
                    icon: const Icon(Icons.layers_clear),
                    label: Text(context.translate("Clear radar")),
                  ),
                ],
              ),
              Text(
                context.translate(
                  "{0} published frames (maximum 12). Irregular timestamp gaps are retained.",
                  [frames.length],
                ),
              ),
            ],
            Text(
              context.translate(
                "Source: MeteoSwiss · FSDI STAC · online HDF5/WASM · EPSG:2056. Radar can be unavailable on Web or Android if data or decoder access is blocked.",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
