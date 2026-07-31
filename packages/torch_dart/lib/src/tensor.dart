import 'backend/backend.dart';

/// A PyTorch tensor owned by Dart.
///
/// Call [dispose] when the tensor is no longer needed. Operations return new
/// tensors and do not mutate their operands.
final class Tensor {
  final BackendTensor _handle;

  Tensor.fromHandle(this._handle);

  List<int> get shape => _handle.shape;
  int get ndim => _handle.ndim;
  int get numel => _handle.numel;
  String get dtype => _handle.dtype;
  String get device => _handle.device;
  bool get requiresGrad => _handle.requiresGrad;

  Tensor operator +(Tensor other) => _wrap(_handle.add(other._handle));
  Tensor operator -(Tensor other) => _wrap(_handle.subtract(other._handle));
  Tensor operator *(Tensor other) => _wrap(_handle.multiply(other._handle));
  Tensor operator /(Tensor other) => _wrap(_handle.divide(other._handle));

  Tensor matmul(Tensor other) => _wrap(_handle.matmul(other._handle));
  Tensor reshape(List<int> shape) => _wrap(_handle.reshape(shape));
  Tensor get transpose => _wrap(_handle.transpose());
  Tensor sum() => _wrap(_handle.sum());
  Tensor mean() => _wrap(_handle.mean());
  Tensor relu() => _wrap(_handle.relu());

  /// Converts the tensor to nested Dart lists, or a number for a scalar tensor.
  Object toList() => _handle.toList();

  /// Returns the value of a one-element tensor.
  num item() => _handle.item();

  void dispose() => _handle.dispose();

  Tensor _wrap(BackendTensor handle) => Tensor.fromHandle(handle);

  @override
  String toString() => _handle.toString();
}
