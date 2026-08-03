import 'backend/backend_factory.dart' as backend;
import 'tensor.dart';

/// Entry point for TorchScript operations.
const jit = Jit();

final class Jit {
  const Jit();

  /// Loads a module saved by `torch.jit.save`.
  ScriptModule load(String path, {String? mapLocation}) =>
      backend.torch.loadScriptModule(path, mapLocation: mapLocation);
}

/// A loaded TorchScript module.
abstract interface class ScriptModule {
  /// Runs a module with one tensor argument.
  Tensor call(Tensor input);

  /// Runs the module with positional tensor arguments.
  Tensor forward(List<Tensor> inputs);

  ScriptModule eval();

  void dispose();
}
