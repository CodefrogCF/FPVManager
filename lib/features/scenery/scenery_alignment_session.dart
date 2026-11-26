import 'scenery_catalog_controller.dart';
import 'scenery_manifest.dart';

/// One transient editor per renderer. Event tokens reject obsolete submissions.
class SceneryAlignmentSession {
  SceneryAlignmentSession({
    required this.catalog,
    required this.send,
    required this.canSend,
  });
  final SceneryCatalogController catalog;
  final SceneryCommand send;
  final bool Function() canSend;
  Map<String, SceneryManifest> _bases = {};
  int _revision = 0;
  String? _token;
  bool _saving = false;
  bool get active => _token != null;
  void invalidate() {
    _revision++;
    _token = null;
    _bases = {};
  }

  Future<void> begin({String? id, required bool german}) async {
    if (!canSend() || active || _saving) {
      throw StateError('Stop navigation or close the current scenery editor');
    }
    final revision = ++_revision;
    final definitions = await catalog.definitions();
    await catalog.synchronize();
    if (!canSend() || revision != _revision) {
      throw StateError('Renderer changed while opening scenery editor');
    }
    final bases = {for (final doc in definitions) doc.id: doc};
    if (id != null && !bases.containsKey(id)) {
      throw StateError('Scenery no longer exists');
    }
    final token = 'alignment-$revision';
    _token = token;
    _bases = bases;
    try {
      await send({
        'type': 'begin-scenery-alignment',
        'token': token,
        'id': id,
        'german': german,
        'definitions': definitions.map((m) => m.toJson()).toList(),
      });
    } catch (_) {
      if (_token == token) invalidate();
      rethrow;
    }
  }

  Future<void> event(Map<String, dynamic> data) async {
    final token = data['token'];
    if (token != _token || _token == null) return;
    if (data['type'] == 'scenery-alignment-cancel') {
      if (!_saving) invalidate();
      return;
    }
    if (data['type'] != 'scenery-alignment-submit' || _saving) return;
    final base = _bases[data['id']];
    if (base == null ||
        data['placement'] is! Map<String, dynamic> ||
        !canSend()) {
      return;
    }
    _saving = true;
    try {
      await catalog.saveAlignment(
        base,
        data['placement'] as Map<String, dynamic>,
        isCurrent: () => _token == token && canSend(),
        token: token as String,
      );
      if (_token == token && canSend()) {
        await send({'type': 'scenery-alignment-result', 'token': token});
        invalidate();
      }
    } catch (error) {
      if (_token == token && canSend()) {
        try {
          await send({
            'type': 'scenery-alignment-result',
            'token': token,
            'error': error.toString(),
          });
        } catch (_) {
          invalidate();
        }
      }
    } finally {
      _saving = false;
    }
  }
}
