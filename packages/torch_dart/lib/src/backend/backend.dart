import '../jit.dart';
import '../tensor.dart';

abstract interface class Torch {
  String get version;

  Jit get jit;

  Tensor tensor(Object data, {String? dtype, bool requiresGrad});
  Tensor zeros(List<int> shape, {String? dtype, bool requiresGrad});
  Tensor ones(List<int> shape, {String? dtype, bool requiresGrad});
  Tensor randn(List<int> shape, {String? dtype, bool requiresGrad});
  Tensor arange(
    num start,
    num end,
    num step, {
    String? dtype,
    bool requiresGrad,
  });
  void manualSeed(int seed);
  T inferenceMode<T>(T Function() action);
  ScriptModule loadScriptModule(String path, {String? mapLocation});
}
