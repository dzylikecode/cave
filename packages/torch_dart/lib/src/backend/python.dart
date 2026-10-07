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
    return PyTuple(shape.length).using((object) {
      final dimensions = object as PyTuple;
      for (var i = 0; i < shape.length; i++) {
        dimensions.setElementAt(i, PyInt(shape[i]));
      }
      return PyDict().using((object) {
        final kwargs = object as PyDict;
        if (dtype != null) {
          _torch
              .getAttr(dtype.name)
              .using((value) => kwargs.setElementAtStr('dtype', value));
        }
        if (device != null) {
          PyString(device.toString())
              .using((value) => kwargs.setElementAtStr('device', value));
        }
        // The argument tuple takes ownership of an additional reference.
        dimensions.ref.increment();
        return PyTuple.fromList([
          dimensions,
        ]).using((args) => TensorPython(_zeros.call(args as PyTuple, kwargs)));
      });
    });
  }

  late final _inference_mode = _torch.getAttr('inference_mode');

  @override
  T inference_mode<T>(T Function() action) => _inference_mode.call0().using(
    (context) => context.withContext((_) => action()),
  );

  late final _jit_load = _torch
      .getAttr('jit')
      .using((module) => module.getAttr('load'));

  @override
  ScriptModulePython jit_load(String path, {Device? map_location}) =>
      PyTuple.fromList([PyString(path)]).using((args) {
        if (map_location == null) {
          return ScriptModulePython(_jit_load.call(args as PyTuple));
        }
        return PyDict().using((object) {
          final kwargs = object as PyDict;
          PyString(
            map_location.toString(),
          ).using((device) => kwargs.setElementAtStr('map_location', device));
          return ScriptModulePython(_jit_load.call(args as PyTuple, kwargs));
        });
      });
}

final class ScriptModulePython(final PyObject handle) implements ScriptModule {
  @override
  ScriptModulePython eval() {
    handle.getAttr('eval').using((method) => method.call0().ref.discrement());
    return this;
  }

  @override
  TensorPython call(Tensor input) => forward([input]);

  @override
  TensorPython forward(List<Tensor> inputs) {
    final pythonInputs = <TensorPython>[];
    for (final input in inputs) {
      if (input is! TensorPython) {
        throw ArgumentError.value(input, 'inputs', 'Expected a Python tensor');
      }
      pythonInputs.add(input);
    }
    // callN consumes argument references. Retain each caller-owned tensor.
    final args = <PyObject>[];
    for (final input in pythonInputs) {
      input.handle.ref.increment();
      args.add(input.handle);
    }
    final result = handle
        .getAttr('forward')
        .using((method) => method.callN(args));
    try {
      final isTensor = PyModule('torch').using(
        (module) => module.getAttr('is_tensor').using((check) {
          result.ref.increment();
          return check.callN([result]).using((value) => value.asBool());
        }),
      );
      if (!isTensor) {
        throw UnsupportedError('Only a single Tensor output is supported');
      }
      return TensorPython(result);
    } catch (_) {
      result.ref.discrement();
      rethrow;
    }
  }

  @override
  void dispose() => handle.ref.discrement();
}

final class TensorPython(final PyObject handle) implements Tensor {
  @override
  List<int> get shape => handle
      .getAttr('shape')
      .using(
        (shape) => List<int>.unmodifiable(
          List<int>.generate(
            handle.getAttrInt('ndim'),
            (i) => PyInt(i).using(
              (index) => shape.getItem(index).using((value) => value.asInt()),
            ),
          ),
        ),
      );

  @override
  DType get dtype {
    final name = handle
        .getAttr('dtype')
        .using(
          (dtype) => dtype
              .getAttr('__str__')
              .using(
                (method) => method.call0().using((value) => value.asString()),
              ),
        );
    for (final dtype in DType.values) {
      if (name == 'torch.${dtype.name}') return dtype;
    }
    throw UnsupportedError('Unsupported dtype: $name');
  }

  @override
  Device get device => handle.getAttr('device').using((device) {
    final name = device.getAttrString('type');
    final type = DeviceType.values
        .where((type) => type.name == name)
        .firstOrNull;
    if (type == null) throw UnsupportedError('Unsupported device: $name');
    final index = device
        .getAttr('index')
        .using((value) => value.equals(PyNone()) ? null : value.asInt());
    return Device(type, index: index);
  });

  @override
  void dispose() => handle.ref.discrement();
}
