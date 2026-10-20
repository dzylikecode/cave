import 'dart:typed_data';

import 'backend.dart';
import 'types.dart';

/// Portable asynchronous session backed by a platform implementation.
///
/// Asynchronous methods do not guarantee execution on a background isolate.
class OrtInferenceSession {
  final OrtSessionHandler _handler;
  bool _closed = false;
  Future<void>? _disposal;
  int _runs = 0;
  OrtInferenceSession._(this._handler);

  static Future<OrtInferenceSession> create(
    Uint8List model, {
    required OrtBackend backend,
    OrtSessionOptions options = const OrtSessionOptions(),
  }) async {
    if (options.intraOpNumThreads < 1) {
      throw ArgumentError.value(options.intraOpNumThreads, 'intraOpNumThreads');
    }
    return OrtInferenceSession._(
      await backend.createSession(model, options: options),
    );
  }

  List<String> get inputNames => List.unmodifiable(_handler.inputNames);
  List<String> get outputNames => List.unmodifiable(_handler.outputNames);

  Future<Map<String, OrtTensor>> run(Map<String, OrtTensor> feeds) async {
    if (_closed) throw StateError('Session is disposed');
    if (feeds.length != inputNames.length ||
        inputNames.any((name) => !feeds.containsKey(name))) {
      throw ArgumentError('Expected inputs: $inputNames');
    }
    _runs++;
    try {
      return await _handler.run(Map.unmodifiable(feeds));
    } finally {
      _runs--;
    }
  }

  /// Releases the session. Await active runs before disposing.
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    if (_runs != 0) throw StateError('Await active runs before disposal');
    _closed = true;
    return _disposal = Future.sync(_handler.dispose);
  }
}
