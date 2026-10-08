// ignore_for_file: non_constant_identifier_names

import 'package:py_embed/py_embed.dart';

import '../base.dart';

final class PythonApi() implements BaseApi {
  // Import PyTorch only when the backend is first used.
  late final _torch = PyModule('torch');

  @override
  late final String version = _torch.getAttrString('__version__');

  late final _zeros = _torch.getAttr('zeros');

  @override
  TensorPython zeros(List<int> shape, {DType? dtype, Device? device}) {
    for (var i = 0; i < shape.length; i++) {
      if (shape[i] < 0) {
        throw ArgumentError.value(shape, 'shape', 'Dimension $i is negative');
      }
    }
    return Py.using((scope) {
      final kwargs = <String, Object?>{};
      if (dtype != null) kwargs['dtype'] = scope(_torch.getAttr(dtype.name));
      if (device != null) kwargs['device'] = device.toString();
      return TensorPython(_zeros.forward([shape], kwargs: kwargs));
    });
  }

  late final _inference_mode = _torch.getAttr('inference_mode');

  @override
  T inference_mode<T>(T Function() action) => Py.using((scope) {
    final context = scope(_inference_mode.call0());
    return context.withContext((_) => action());
  });

  late final _jit_load = Py.using((scope) {
    final module = scope(_torch.getAttr('jit'));
    return module.getAttr('load');
  });

  @override
  ScriptModulePython jit_load(String path, {Device? map_location}) =>
      ScriptModulePython(
        _jit_load.forward(
          [path],
          kwargs: {
            if (map_location != null) 'map_location': map_location.toString(),
          },
        ),
      );
}

final class ScriptModulePython(final PyObject handle) implements ScriptModule {
  @override
  ScriptModulePython eval() => Py.using((scope) {
    final method = scope(handle.getAttr('eval'));
    scope(method.call0());
    return this;
  });

  @override
  TensorPython call(Tensor input) => forward([input]);

  @override
  TensorPython forward(List<Tensor> inputs) => Py.using((scope) {
    final args = <PyObject>[];
    for (final input in inputs) {
      if (input is! TensorPython) {
        throw ArgumentError.value(input, 'inputs', 'Expected a Python tensor');
      }
      args.add(input.handle);
    }
    final method = scope(handle.getAttr('forward'));
    final result = scope(method.forward(args));
    final module = scope(PyModule('torch'));
    final check = scope(module.getAttr('is_tensor'));
    if (!scope(check.forward([result])).asBool()) {
      throw UnsupportedError('Only a single Tensor output is supported');
    }
    return TensorPython(scope.escape(result));
  });

  @override
  void dispose() => handle.ref.discrement();
}

final class TensorPython(final PyObject handle) implements Tensor {
  @override
  List<int> get shape => Py.using((scope) {
    final shape = scope(handle.getAttr('shape'));
    return List<int>.unmodifiable(
      List<int>.generate(
        handle.getAttrInt('ndim'),
        (i) => scope(shape.getItem(scope(PyInt(i)))).asInt(),
      ),
    );
  });

  @override
  DType get dtype => Py.using((scope) {
    final dtype = scope(handle.getAttr('dtype'));
    final method = scope(dtype.getAttr('__str__'));
    final name = scope(method.call0()).asString();
    for (final dtype in DType.values) {
      if (name == 'torch.${dtype.name}') return dtype;
    }
    throw UnsupportedError('Unsupported dtype: $name');
  });

  @override
  Device get device => Py.using((scope) {
    final device = scope(handle.getAttr('device'));
    final name = device.getAttrString('type');
    final type = DeviceType.values
        .where((type) => type.name == name)
        .firstOrNull;
    if (type == null) throw UnsupportedError('Unsupported device: $name');
    final index = scope(device.getAttr('index'));
    return Device(
      type,
      index: index.ptr == PyObject.borrowedConst(.none).ptr
          ? null
          : index.asInt(),
    );
  });

  @override
  void dispose() => handle.ref.discrement();
}
