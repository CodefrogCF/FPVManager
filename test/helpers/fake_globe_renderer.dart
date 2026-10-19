import 'dart:convert';

import 'package:fpvmanager/features/globe/globe_controller.dart';

/// In-memory renderer peer using the same envelopes as the actual JS bridge.
class FakeGlobeRenderer {
  FakeGlobeRenderer(this.controller, {List<Map<String, dynamic>>? commands})
    : commands = commands ?? [];

  final GlobeController controller;
  final List<Map<String, dynamic>> commands;
  final Map<String, StringBuffer> _transfers = {};
  String sessionId = 'renderer-1';
  int sequence = 0;
  bool autoAcknowledge = true;

  void attach() => controller.attach(receive);

  String encode(Map<String, dynamic> event) => jsonEncode({
    'source': 'fpvmanager-globe',
    'version': 1,
    'sessionId': sessionId,
    'eventSequence': ++sequence,
    ...event,
  });

  void emit(Map<String, dynamic> event) =>
      controller.handleEvent(encode(event));
  void ready() => emit({'type': 'globe-ready', 'terrainAvailable': true});

  void acknowledge(
    Map<String, dynamic> command, {
    Map<String, dynamic> result = const {},
    String? error,
  }) => emit({
    'type': 'command-result',
    'commandType': command['type'],
    'requestId': command['requestId'],
    'ok': error == null,
    if (error == null) 'result': result else 'error': error,
  });

  Future<void> receive(String message) async {
    final data = jsonDecode(message) as Map<String, dynamic>;
    final id = data['requestId'] as String;
    switch (data['type']) {
      case 'transfer-start':
        _transfers[id] = StringBuffer();
        return;
      case 'transfer-chunk':
        _transfers[id]?.write(data['data']);
        return;
      case 'transfer-complete':
        await receive(_transfers.remove(id)!.toString());
        return;
      case 'cancel-command':
        _transfers.remove(id);
        return;
    }
    commands.add(data);
    if (autoAcknowledge && data['type'] != 'query-terrain-elevation') {
      acknowledge(data);
    }
  }
}
