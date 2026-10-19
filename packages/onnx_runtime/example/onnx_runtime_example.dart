import 'dart:typed_data';
import 'package:onnx_runtime/onnx_runtime.dart';

void main(List<String> args) {
  if (args.length != 1) {
    throw ArgumentError(
      'Usage: dart run example/onnx_runtime_example.dart <AMP model>',
    );
  }
  final runtime = OrtRuntime();
  try {
    final session = OrtSession.fromFile(runtime, args[0]);
    try {
      final result = session.run({
        session.inputNames.single: OrtTensor([1, 760], Float32List(760)),
      });
      for (final entry in result.entries) {
        print(
          '${entry.key}: shape=${entry.value.shape}, data=${entry.value.data}',
        );
      }
    } finally {
      session.dispose();
    }
  } finally {
    runtime.dispose();
  }
}
