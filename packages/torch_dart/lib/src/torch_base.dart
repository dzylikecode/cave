import 'backend/backend_factory.dart';
import 'tensor.dart';

/// Version of the PyTorch package used by the active backend.
String get torchVersion => torchBackend.version;

Tensor tensor(Object data, {String? dtype, bool requiresGrad = false}) =>
    Tensor.fromHandle(
      torchBackend.tensor(data, dtype: dtype, requiresGrad: requiresGrad),
    );

Tensor zeros(List<int> shape, {String? dtype, bool requiresGrad = false}) =>
    Tensor.fromHandle(
      torchBackend.zeros(shape, dtype: dtype, requiresGrad: requiresGrad),
    );

Tensor ones(List<int> shape, {String? dtype, bool requiresGrad = false}) =>
    Tensor.fromHandle(
      torchBackend.ones(shape, dtype: dtype, requiresGrad: requiresGrad),
    );

Tensor randn(List<int> shape, {String? dtype, bool requiresGrad = false}) =>
    Tensor.fromHandle(
      torchBackend.randn(shape, dtype: dtype, requiresGrad: requiresGrad),
    );

Tensor arange(
  num end, {
  num start = 0,
  num step = 1,
  String? dtype,
  bool requiresGrad = false,
}) => Tensor.fromHandle(
  torchBackend.arange(
    start,
    end,
    step,
    dtype: dtype,
    requiresGrad: requiresGrad,
  ),
);

void manualSeed(int seed) => torchBackend.manualSeed(seed);
