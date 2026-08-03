/// A PyTorch tensor owned by Dart.
///
/// Call [dispose] when the tensor is no longer needed. Operations return new
/// tensors and do not mutate their operands.
abstract interface class Tensor {
  List<int> get shape;
  int get ndim;
  int get numel;
  String get dtype;
  String get device;
  bool get requiresGrad;

  Tensor operator +(Tensor other);
  Tensor operator -(Tensor other);
  Tensor operator *(Tensor other);
  Tensor operator /(Tensor other);

  Tensor matmul(Tensor other);
  Tensor reshape(List<int> shape);
  Tensor get transpose;
  Tensor sum();
  Tensor mean();
  Tensor relu();

  /// Converts the tensor to nested Dart lists, or a number for a scalar tensor.
  Object toList();

  /// Returns the value of a one-element tensor.
  num item();

  void dispose();
}
