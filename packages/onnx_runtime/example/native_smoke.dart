import 'dart:convert';
import 'dart:typed_data';

import 'package:onnx_runtime/onnx_runtime.dart';

void main() {
  // The same tiny two-input Add model as test/fixtures/add.onnx, embedded so
  // the compiled smoke executable can run independently of the source tree.
  final model = base64Decode(
    'CAg6ZwoQCgFhCgFiEgNzdW0iA0FkZBIDYWRkWhgKAWESEwoRCAESDQoHEgViYXRjaAoCCAJaGAoBYhITChEIARINCgcSBWJhdGNoCgIIAmIaCgNzdW0SEwoRCAESDQoHEgViYXRjaAoCCAJCAhAN',
  );
  final runtime = OrtRuntime();
  try {
    final session = OrtSession.fromBytes(runtime, model);
    try {
      final outputs = session.run({
        'a': OrtTensor([1, 2], Float32List.fromList([1, 2])),
        'b': OrtTensor([1, 2], Float32List.fromList([3, 4])),
      });
      final result = outputs['sum']!.data;
      if (result.length != 2 || result[0] != 4 || result[1] != 6) {
        throw StateError('Unexpected ONNX inference result: $result');
      }
      print('ONNX Runtime native inference passed: $result');
    } finally {
      session.dispose();
    }
  } finally {
    runtime.dispose();
  }
}
