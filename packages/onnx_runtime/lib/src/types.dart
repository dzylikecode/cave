import 'dart:typed_data';

/// A failure reported by the runtime.
class OrtException implements Exception {
  final String message;
  OrtException(this.message);
  @override
  String toString() => 'OrtException: $message';
}

/// An owned Dart copy of a float32 tensor. Scalar tensors use an empty shape.
class OrtTensor {
  final List<int> shape;
  final Float32List data;
  OrtTensor(List<int> shape, Float32List data)
    : shape = List.unmodifiable(shape),
      data = Float32List.fromList(data) {
    if (shape.any((d) => d < 0) ||
        shape.fold(1, (a, b) => a * b) != data.length) {
      throw ArgumentError('Tensor shape does not match data length');
    }
  }
}
