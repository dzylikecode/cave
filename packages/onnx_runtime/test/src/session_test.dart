import 'dart:async';
import 'dart:typed_data';

import 'package:onnx_runtime/onnx_runtime.dart';
import 'package:test/test.dart';

class _Backend implements OrtBackend {
  final handler = _Handler();
  @override
  Future<OrtSessionHandler> createSession(
    Uint8List model, {
    OrtSessionOptions options = const OrtSessionOptions(),
  }) async => handler;
}

class _Handler implements OrtSessionHandler {
  final pending = Completer<Map<String, OrtTensor>>();
  int disposals = 0;
  @override
  List<String> get inputNames => ['x'];
  @override
  List<String> get outputNames => ['y'];
  @override
  Future<Map<String, OrtTensor>> run(Map<String, OrtTensor> feeds) =>
      pending.future;
  @override
  Future<void> dispose() async {
    disposals++;
  }
}

void main() {
  test('session protects active runs and disposes exactly once', () async {
    final backend = _Backend();
    final session = await OrtInferenceSession.create(
      Uint8List(0),
      backend: backend,
    );
    final run = session.run({
      'x': OrtTensor([], Float32List.fromList([1])),
    });
    expect(session.dispose, throwsStateError);
    backend.handler.pending.completeError(StateError('inference failed'));
    await expectLater(run, throwsStateError);
    await session.dispose();
    await session.dispose();
    expect(backend.handler.disposals, 1);
    await expectLater(session.run({}), throwsStateError);
  });

  test('invalid options fail before backend creation', () async {
    await expectLater(
      OrtInferenceSession.create(
        Uint8List(0),
        backend: _Backend(),
        options: const OrtSessionOptions(intraOpNumThreads: 0),
      ),
      throwsArgumentError,
    );
  });
}
