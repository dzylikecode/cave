abstract interface class TorchBackend {
  String get version;

  BackendTensor tensor(Object data, {String? dtype, bool requiresGrad});
  BackendTensor zeros(List<int> shape, {String? dtype, bool requiresGrad});
  BackendTensor ones(List<int> shape, {String? dtype, bool requiresGrad});
  BackendTensor randn(List<int> shape, {String? dtype, bool requiresGrad});
  BackendTensor arange(
    num start,
    num end,
    num step, {
    String? dtype,
    bool requiresGrad,
  });
  void manualSeed(int seed);
}

abstract interface class BackendTensor {
  List<int> get shape;
  int get ndim;
  int get numel;
  String get dtype;
  String get device;
  bool get requiresGrad;

  BackendTensor add(BackendTensor other);
  BackendTensor subtract(BackendTensor other);
  BackendTensor multiply(BackendTensor other);
  BackendTensor divide(BackendTensor other);
  BackendTensor matmul(BackendTensor other);
  BackendTensor reshape(List<int> shape);
  BackendTensor transpose();
  BackendTensor sum();
  BackendTensor mean();
  BackendTensor relu();
  Object toList();
  num item();
  void dispose();
}
