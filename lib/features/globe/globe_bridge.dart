import 'dart:async';
import 'dart:convert';

typedef GlobeCommandSender = Future<void> Function(String command);

class GlobeBridgeOptions {
  const GlobeBridgeOptions({
    this.commandTimeout = const Duration(seconds: 15),
    this.terrainTimeout = const Duration(seconds: 30),
    this.datasetTimeout = const Duration(minutes: 2),
    this.transportTimeout = const Duration(seconds: 10),
    // Fewer native WebView2 / Android JS calls; dynamically shrink frames
    // whose escaped JSON would exceed the protocol limit.
    this.chunkCharacters = 96 * 1024,
    this.maxCommandCharacters = 64 * 1024 * 1024,
    this.maxFrameCharacters = 128 * 1024,
    this.maxPendingRequests = 32,
  });

  final Duration commandTimeout;
  final Duration terrainTimeout;
  final Duration datasetTimeout;
  final Duration transportTimeout;
  final int chunkCharacters;
  final int maxCommandCharacters;
  final int maxFrameCharacters;
  final int maxPendingRequests;
}

class GlobeTransferMetrics {
  const GlobeTransferMetrics({
    required this.type,
    required this.characters,
    required this.encodeTime,
    required this.acknowledgementTime,
    this.dispatchTime = Duration.zero,
    this.frameCount = 0,
  });
  final String type;
  final int characters;
  final Duration encodeTime;

  /// Includes send/chunk transfer + JavaScript handling + reply, not pure
  /// Cesium render time. Only a renderer-side measurement can separate them.
  final Duration acknowledgementTime;

  /// Time to send all frames; excludes renderer processing and acknowledgement.
  final Duration dispatchTime;
  final int frameCount;
}

class _PendingCommand {
  _PendingCommand(this.type, this.session);

  final String type;
  final String session;
  final completer = Completer<Map<String, dynamic>>();
  Timer? timer;
  Duration dispatchTime = Duration.zero;
  int frameCount = 0;
}

/// Protocol v1 transport shared by the Web iframe and native WebView.
class GlobeBridge {
  GlobeBridge({this.options = const GlobeBridgeOptions()}) {
    if (options.chunkCharacters <= 0 ||
        options.maxCommandCharacters < options.chunkCharacters ||
        options.maxFrameCharacters < options.chunkCharacters + 1024 ||
        options.maxPendingRequests <= 0 ||
        [
          options.commandTimeout,
          options.terrainTimeout,
          options.datasetTimeout,
          options.transportTimeout,
        ].any((value) => value <= Duration.zero)) {
      throw ArgumentError('Invalid globe bridge limits');
    }
  }

  static const version = 1;
  final GlobeBridgeOptions options;
  final Map<String, _PendingCommand> _pending = {};
  final Set<String> _retiredSessions = {};
  GlobeCommandSender? _sender;
  String? _session;
  int _nextRequest = 0;
  int _lastEventSequence = 0;

  String? get session => _session;
  GlobeTransferMetrics? lastTransferMetrics;

  void attach(GlobeCommandSender sender) {
    endSession();
    _sender = sender;
  }

  void endSession() {
    cancelPending();
    final previous = _session;
    if (previous != null) {
      _retiredSessions.add(previous);
      if (_retiredSessions.length > 64) {
        _retiredSessions.remove(_retiredSessions.first);
      }
    }
    _session = null;
    _lastEventSequence = 0;
  }

  void detach() {
    endSession();
    _sender = null;
  }

  void cancelPending() {
    for (final requestId in _pending.keys.toList()) {
      final sender = _sender;
      final session = _session;
      if (sender != null && session != null) {
        unawaited(_control(sender, session, 'cancel-command', requestId));
      }
      _fail(requestId, StateError('Globe connection closed'));
    }
  }

  /// Rejects invalid, duplicated and obsolete envelopes before state changes.
  Map<String, dynamic>? receive(String message) {
    if (_sender == null || message.length > options.maxFrameCharacters) {
      return null;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['source'] != 'fpvmanager-globe' ||
        decoded['version'] != version ||
        decoded['type'] is! String) {
      return null;
    }
    final session = decoded['sessionId'];
    final sequence = decoded['eventSequence'];
    if (session is! String ||
        session.isEmpty ||
        session.length > 120 ||
        sequence is! int ||
        sequence <= 0 ||
        _retiredSessions.contains(session)) {
      return null;
    }
    if (decoded['type'] == 'globe-ready' ||
        decoded['type'] == 'renderer-loading') {
      if (_session != session) {
        endSession();
        _session = session;
      }
    } else if (_session != session &&
        !(_session == null && decoded['type'] == 'globe-error')) {
      return null;
    }
    if (sequence <= _lastEventSequence) return null;
    _lastEventSequence = sequence;
    if (decoded['type'] == 'command-result') {
      final id = decoded['requestId'];
      final request = _pending[id];
      if (request == null ||
          request.session != session ||
          decoded['commandType'] != request.type ||
          decoded['ok'] is! bool) {
        return null;
      }
      if (decoded['ok'] == true && decoded['result'] is Map<String, dynamic>) {
        _pending.remove(id);
        request.timer?.cancel();
        request.completer.complete(decoded['result'] as Map<String, dynamic>);
      } else if (decoded['ok'] == false && decoded['error'] is String) {
        _fail(id as String, StateError(decoded['error'] as String));
      }
      return null;
    }
    return decoded;
  }

  Future<Map<String, dynamic>> send(
    Map<String, dynamic> command, {
    Duration? timeout,
  }) {
    final session = _session;
    final sender = _sender;
    final type = command['type'];
    if (session == null || sender == null) {
      return Future.error(StateError('Globe is not ready'));
    }
    if (type is! String || _pending.length >= options.maxPendingRequests) {
      return Future.error(StateError('Globe command queue is full or invalid'));
    }
    final id = (++_nextRequest).toString();
    final encoding = Stopwatch()..start();
    final encoded = jsonEncode({
      ...command,
      'version': version,
      'sessionId': session,
      'requestId': id,
    });
    encoding.stop();
    if (encoded.length > options.maxCommandCharacters) {
      return Future.error(
        ArgumentError('Globe command exceeds transfer limit'),
      );
    }
    final pending = _PendingCommand(type, session);
    _pending[id] = pending;
    pending.timer = Timer(timeout ?? options.commandTimeout, () {
      _fail(id, TimeoutException('Globe command timed out: $type'));
      unawaited(_control(sender, session, 'cancel-command', id));
    });
    final acknowledgement = Stopwatch()..start();
    final dispatched = _dispatch(sender, session, id, type, encoded);
    return pending.completer.future.then((result) async {
      // The acknowledgement can arrive synchronously while send() is still
      // completing. Finish transport measurement before publishing metrics.
      await dispatched;
      acknowledgement.stop();
      lastTransferMetrics = GlobeTransferMetrics(
        type: type,
        characters: encoded.length,
        encodeTime: encoding.elapsed,
        acknowledgementTime: acknowledgement.elapsed,
        dispatchTime: pending.dispatchTime,
        frameCount: pending.frameCount,
      );
      return result;
    });
  }

  Future<void> _control(
    GlobeCommandSender sender,
    String session,
    String type,
    String id,
  ) async {
    try {
      await sender(
        jsonEncode({
          'version': version,
          'sessionId': session,
          'type': type,
          'requestId': id,
        }),
      ).timeout(options.transportTimeout);
    } catch (_) {
      // The page or transport may already be gone.
    }
  }

  Future<void> _dispatch(
    GlobeCommandSender sender,
    String session,
    String id,
    String type,
    String encoded,
  ) async {
    final request = _pending[id];
    final dispatch = Stopwatch()..start();

    Future<void> transmit(String value) async {
      if (!_pending.containsKey(id) || _session != session) return;
      if (value.length > options.maxFrameCharacters) {
        throw ArgumentError('Globe frame exceeds transfer limit');
      }
      await sender(value).timeout(options.transportTimeout);
      if (request != null) request.frameCount++;
    }

    Future<void> frame(Map<String, dynamic> payload) => transmit(
      jsonEncode({
        'version': version,
        'sessionId': session,
        'requestId': id,
        ...payload,
      }),
    );

    try {
      if (encoded.length <= options.chunkCharacters) {
        await sender(encoded).timeout(options.transportTimeout);
        if (request != null) request.frameCount++;
        return;
      }
      await frame({
        'type': 'transfer-start',
        'commandType': type,
        'length': encoded.length,
      });
      var index = 0;
      var offset = 0;
      while (offset < encoded.length) {
        if (!_pending.containsKey(id) || _session != session) return;
        final maximum = offset + options.chunkCharacters < encoded.length
            ? offset + options.chunkCharacters
            : encoded.length;
        // Escaping the transferred JSON as a second JSON string increases
        // frame size. Check the actual frame, not just raw substring length.
        // Most geometry fits the optimistic bound without a binary search.
        var end = maximum;
        final header = {
          'version': version,
          'sessionId': session,
          'requestId': id,
          'type': 'transfer-chunk',
          'index': index,
        };
        String encodeChunk(int until) =>
            jsonEncode({...header, 'data': encoded.substring(offset, until)});
        var encodedChunk = encodeChunk(end);
        if (encodedChunk.length > options.maxFrameCharacters) {
          var low = offset;
          var high = end;
          while (low + 1 < high) {
            final middle = low + ((high - low) ~/ 2);
            final candidate = encodeChunk(middle);
            if (candidate.length <= options.maxFrameCharacters) {
              low = middle;
              encodedChunk = candidate;
            } else {
              high = middle;
            }
          }
          end = low;
        }
        if (end <= offset) {
          throw ArgumentError('Globe frame cannot fit payload');
        }
        // Send the frame we already encoded instead of serializing it again.
        await transmit(encodedChunk);
        index++;
        offset = end;
        // Allow cancellation, renderer errors and input between frames.
        await Future<void>.delayed(Duration.zero);
      }
      await frame({'type': 'transfer-complete'});
    } catch (error, stack) {
      _fail(id, error, stack);
      await _control(sender, session, 'cancel-command', id);
    } finally {
      dispatch.stop();
      if (request != null) request.dispatchTime = dispatch.elapsed;
    }
  }

  void _fail(String id, Object error, [StackTrace? stack]) {
    final pending = _pending.remove(id);
    if (pending == null) return;
    pending.timer?.cancel();
    pending.completer.completeError(error, stack);
  }
}
