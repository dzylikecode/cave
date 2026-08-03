import 'backend/backend.dart';
import 'backend/backend_factory.dart' as backend;
import 'tensor.dart';

/// Namespaced access mirroring Python's `torch` module.
Torch get torch => backend.torch;

/// Version of the PyTorch package used by the active backend.
String get torchVersion => torch.version;

Tensor tensor(Object data, {String? dtype, bool requiresGrad = false}) =>
    torch.tensor(data, dtype: dtype, requiresGrad: requiresGrad);

Tensor zeros(List<int> shape, {String? dtype, bool requiresGrad = false}) =>
    torch.zeros(shape, dtype: dtype, requiresGrad: requiresGrad);

Tensor ones(List<int> shape, {String? dtype, bool requiresGrad = false}) =>
    torch.ones(shape, dtype: dtype, requiresGrad: requiresGrad);

Tensor randn(List<int> shape, {String? dtype, bool requiresGrad = false}) =>
    torch.randn(shape, dtype: dtype, requiresGrad: requiresGrad);

Tensor arange(
  num end, {
  num start = 0,
  num step = 1,
  String? dtype,
  bool requiresGrad = false,
}) => torch.arange(start, end, step, dtype: dtype, requiresGrad: requiresGrad);

void manualSeed(int seed) => torch.manualSeed(seed);

T inferenceMode<T>(T Function() action) => torch.inferenceMode(action);
