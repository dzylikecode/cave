import 'backend/backend.dart';
import 'backend/backend_factory.dart';
import 'tensor.dart';

/// Entry point for TorchScript operations.
const jit = Jit();

final class Jit {
  const Jit();

  /// Loads a module saved by `torch.jit.save`.
  ScriptModule load(String path, {String? mapLocation}) => .fromHandle(
    torchBackend.loadScriptModule(path, mapLocation: mapLocation),
  );
}

/// A loaded TorchScript module.
final class ScriptModule {
  final BackendScriptModule _handle;

  ScriptModule.fromHandle(this._handle);

  /// Runs a module with one tensor argument.
  Tensor call(Tensor input) => forward([input]);

  /// Runs the module with positional tensor arguments.
  Tensor forward(List<Tensor> inputs) => .fromHandle(
    _handle.forward(inputs.map(tensorHandle).toList(growable: false)),
  );

  ScriptModule eval() {
    _handle.eval();
    return this;
  }

  void dispose() => _handle.dispose();
}
