import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Only the overlay repaints when the bounded renderer snapshot arrives.
/// No gesture interception, coordinate telemetry or additional terrain requests.
class DeveloperPerformanceOverlay extends StatelessWidget {
  const DeveloperPerformanceOverlay({super.key, required this.samples});
  final ValueListenable<Map<String, dynamic>?> samples;

  static String _number(Object? value, [int decimals = 0]) =>
      value is num && value.isFinite ? value.toStringAsFixed(decimals) : '—';
  static Map _map(Object? value) => value is Map ? value : const {};
  static String _mib(Object? bytes) =>
      bytes is num ? _number(bytes / (1024 * 1024), 1) : '—';

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: samples,
      builder: (context, sample, _) {
        final german = Localizations.localeOf(context).languageCode == 'de';
        final s = sample ?? const <String, dynamic>{};
        final cpu = _map(s['cpuRenderMs']);
        final gpu = _map(s['gpuRenderMs']);
        final pacing = _map(s['framePacingMs']);
        final step = _map(s['physicsStep']);
        final flight = _map(s['flightPhysics']);
        final tiles = _map(s['tilesets']);
        final scenery = _map(s['scenery']);
        final rf = _map(s['rf']);
        final age = s['frameAgeMs'];
        final fps = age is num && age <= 1500
            ? _number(s['renderFps'], 1)
            : '—';
        final rows = <String>[
          if (sample == null)
            german ? 'Warte auf Renderer…' : 'Waiting for renderer…'
          else ...[
            'FPS $fps · P95 ${_number(pacing['p95'], 1)} ms',
            'CPU ${_number(cpu['p50'], 1)}/${_number(cpu['p95'], 1)} ms',
            'GPU ${_number(gpu['p50'], 1)}/${_number(gpu['p95'], 1)} ms',
            'Frames >33/100 ms: ${_number(s['over33Ms'])}/${_number(s['over100Ms'])}',
            'Physics ${flight['model'] ?? '—'} ${_number(flight['stepHz'])} Hz',
            'Step P95 ${_number(step['p95Ms'], 2)} ms · sub ${_number(flight['lastSubsteps'])}',
            'Queue ${_number(flight['queuedSeconds'], 3)} s · drop ${_number(flight['droppedSeconds'], 3)} s',
            'Terrain ${s['terrainState'] ?? '—'}${s['terrainWarning'] == true ? ' · !' : ''} · pending ${_number(s['pendingTerrainTiles'])}',
            '3D tiles ${_number(tiles['resident'])}/${_number(tiles['visible'])} · pending ${_number(tiles['pending'])}',
            '3D est. ${_mib(tiles['estimatedBytes'])} MiB',
            'Scenery ${_number(scenery['residentModels'])} · loading ${_number(scenery['loading'])}',
            'Scenery FPC ${_mib(scenery['collisionBytes'])} MiB · Δ ${_number(scenery['activeCollisionTriangles'])}',
            'RF ${rf['quality'] ?? '—'} · ${rf['provider'] ?? '—'}',
            'RF ${_number(rf['durationMs'])} ms · age ${_number(rf['ageMs'])} ms',
            'RF samples ${_number(rf['validSamples'])}/${_number(rf['samples'])}',
            if (rf['error'] != null) 'RF: ${rf['error']}',
          ],
        ];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .80),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.2,
              ),
              child: Text(
                '${german ? 'ENTWICKLER' : 'DEVELOPER'}\n${rows.join('\n')}',
                maxLines: 18,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    ),
  );
}
