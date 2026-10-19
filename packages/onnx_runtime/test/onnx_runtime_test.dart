import 'dart:io';
import 'dart:typed_data';
import 'package:onnx_runtime/onnx_runtime.dart';
import 'package:test/test.dart';

void main() {
  test('tensor validates shape and owns its data', () {
    final source = Float32List.fromList([1, 2]);
    final tensor = OrtTensor([1, 2], source);
    source[0] = 9;
    expect(tensor.data, [1, 2]);
    expect(() => OrtTensor([3], source), throwsArgumentError);
    expect(() => OrtTensor([-2], source), throwsArgumentError);
    expect(OrtTensor([], Float32List.fromList([4])).shape, isEmpty);
  });
  group('native runtime', () {
    late OrtRuntime runtime;
    setUp(() {
      runtime = OrtRuntime();
    });
    tearDown(() {
      runtime.dispose();
    });
    test('named inputs, dynamic batches, owned outputs and native errors', () {
      final session = OrtSession.fromFile(runtime, 'test/fixtures/add.onnx');
      try {
        expect(session.inputNames, ['a', 'b']);
        expect(session.outputNames, ['sum']);
        expect(() => runtime.dispose(), throwsStateError);
        final first = session.run({
          'a': OrtTensor([1, 2], Float32List.fromList([1, 2])),
          'b': OrtTensor([1, 2], Float32List.fromList([3, 4])),
        })['sum']!;
        expect(first.shape, [1, 2]);
        expect(first.data, [4, 6]);
        final second = session.run({
          'a': OrtTensor([2, 2], Float32List.fromList([1, 2, 3, 4])),
          'b': OrtTensor([2, 2], Float32List.fromList([4, 3, 2, 1])),
        })['sum']!;
        expect(second.shape, [2, 2]);
        expect(second.data, [5, 5, 5, 5]);
        expect(first.data, [4, 6]);
        expect(() => session.run({}), throwsArgumentError);
        expect(
          () => session.run({
            'a': OrtTensor([1, 3], Float32List(3)),
            'b': OrtTensor([1, 3], Float32List(3)),
          }),
          throwsA(isA<OrtException>()),
        );
      } finally {
        session.dispose();
      }
      session.dispose();
      expect(() => session.run({}), throwsStateError);
    });
    test('invalid model releases resources', () {
      final directory = Directory.systemTemp.createTempSync('ort_test_');
      try {
        final file = File('${directory.path}/bad.onnx')
          ..writeAsStringSync('bad model');
        expect(
          () => OrtSession.fromFile(runtime, file.path),
          throwsA(isA<OrtException>()),
        );
      } finally {
        directory.deleteSync(recursive: true);
      }
    });
  });
}
