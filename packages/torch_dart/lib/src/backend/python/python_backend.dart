import 'package:py_embed/py_embed.dart';

import '../backend.dart';
import 'python_helpers.dart';

final class PythonTorchBackend implements TorchBackend {
  final _module = PyModule('torch');

  late final _tensor = _module.get('tensor');
  late final _zeros = _module.get('zeros');
  late final _ones = _module.get('ones');
  late final _randn = _module.get('randn');
  late final _arange = _module.get('arange');
  late final _manualSeed = _module.get('manual_seed');
  late final _inferenceMode = _module.get('inference_mode');
  late final _jit = _module.get('jit');
  late final _jitLoad = _jit.get('load');

  @override
  late final version = _readString(_module, '__version__');

  @override
  BackendTensor tensor(
    Object data, {
    String? dtype,
    bool requiresGrad = false,
  }) {
    final pyData = dartToPython(data);
    try {
      return _create(_tensor, [pyData], dtype, requiresGrad);
    } finally {
      pyData.dispose();
    }
  }

  @override
  BackendTensor zeros(
    List<int> shape, {
    String? dtype,
    bool requiresGrad = false,
  }) => _shapeFactory(_zeros, shape, dtype, requiresGrad);

  @override
  BackendTensor ones(
    List<int> shape, {
    String? dtype,
    bool requiresGrad = false,
  }) => _shapeFactory(_ones, shape, dtype, requiresGrad);

  @override
  BackendTensor randn(
    List<int> shape, {
    String? dtype,
    bool requiresGrad = false,
  }) => _shapeFactory(_randn, shape, dtype, requiresGrad);

  BackendTensor _shapeFactory(
    PyObject factory,
    List<int> shape,
    String? dtype,
    bool requiresGrad,
  ) {
    final pyShape = intListToPython(shape);
    try {
      return _create(factory, [pyShape], dtype, requiresGrad);
    } finally {
      pyShape.dispose();
    }
  }

  @override
  BackendTensor arange(
    num start,
    num end,
    num step, {
    String? dtype,
    bool requiresGrad = false,
  }) {
    final args = <PyObject>[
      for (final value in [start, end, step]) _number(value),
    ];
    try {
      return _create(_arange, args, dtype, requiresGrad);
    } finally {
      for (final arg in args) {
        arg.dispose();
      }
    }
  }

  PythonBackendTensor _create(
    PyObject factory,
    List<PyObject> args,
    String? dtype,
    bool requiresGrad,
  ) {
    final kwargs = <String, PyObject>{'requires_grad': PyBool(requiresGrad)};
    if (dtype != null) {
      kwargs['dtype'] = _module.get(dtype);
    }
    try {
      return PythonBackendTensor(factory.callArgs(args, kwargs));
    } finally {
      for (final value in kwargs.values) {
        value.dispose();
      }
    }
  }

  @override
  void manualSeed(int seed) {
    final pySeed = PyInt(seed);
    try {
      _manualSeed.call1(pySeed).dispose();
    } finally {
      pySeed.dispose();
    }
  }

  @override
  T inferenceMode<T>(T Function() action) {
    final context = _inferenceMode.call0();
    try {
      _call(context, '__enter__').dispose();
      try {
        return action();
      } finally {
        final exit = context.get('__exit__');
        final sys = PyModule('sys');
        try {
          final excInfoObject = _call(sys, 'exc_info');
          try {
            final excInfo = excInfoObject.cast<PyTuple>();
            exit.callArgs([
              excInfo.getItem(0),
              excInfo.getItem(1),
              excInfo.getItem(2),
            ]).dispose();
          } finally {
            excInfoObject.dispose();
          }
        } finally {
          sys.dispose();
          exit.dispose();
        }
      }
    } finally {
      context.dispose();
    }
  }

  @override
  BackendScriptModule loadScriptModule(String path, {String? mapLocation}) {
    final pyPath = PyString(path);
    final kwargs = <String, PyObject>{};
    if (mapLocation != null) {
      kwargs['map_location'] = PyString(mapLocation);
    }
    try {
      return PythonBackendScriptModule(_jitLoad.callArgs([pyPath], kwargs));
    } finally {
      for (final value in kwargs.values) {
        value.dispose();
      }
      pyPath.dispose();
    }
  }
}

final class PythonBackendScriptModule implements BackendScriptModule {
  final PyObject object;

  PythonBackendScriptModule(this.object);

  @override
  BackendTensor forward(List<BackendTensor> inputs) {
    final pythonInputs = <PyObject>[];
    for (final input in inputs) {
      if (input is! PythonBackendTensor) {
        throw ArgumentError.value(input, 'inputs', 'Backend mismatch');
      }
      pythonInputs.add(input.object);
    }
    return PythonBackendTensor(object.callArgs(pythonInputs));
  }

  @override
  void eval() => _call(object, 'eval').dispose();

  @override
  void dispose() => object.dispose();
}

final class PythonBackendTensor implements BackendTensor {
  final PyObject object;

  PythonBackendTensor(this.object);

  @override
  late final int ndim = _readInt(object, 'ndim');

  @override
  late final List<int> shape = () {
    final value = object.get('shape');
    try {
      return List<int>.generate(ndim, (index) {
        final key = PyInt(index);
        try {
          final item = value[key];
          try {
            return item.toInt();
          } finally {
            item.dispose();
          }
        } finally {
          key.dispose();
        }
      }, growable: false);
    } finally {
      value.dispose();
    }
  }();

  @override
  late final int numel = _callInt(object, 'numel');

  @override
  late final String dtype = _readString(object, 'dtype');

  @override
  late final String device = _readString(object, 'device');

  @override
  late final bool requiresGrad = _readBool(object, 'requires_grad');

  PythonBackendTensor _binary(BackendTensor other, String method) {
    if (other is! PythonBackendTensor) {
      throw ArgumentError.value(other, 'other', 'Backend mismatch');
    }
    return PythonBackendTensor(_call1(object, method, other.object));
  }

  @override
  BackendTensor add(BackendTensor other) => _binary(other, 'add');
  @override
  BackendTensor subtract(BackendTensor other) => _binary(other, 'sub');
  @override
  BackendTensor multiply(BackendTensor other) => _binary(other, 'mul');
  @override
  BackendTensor divide(BackendTensor other) => _binary(other, 'div');
  @override
  BackendTensor matmul(BackendTensor other) => _binary(other, 'matmul');

  @override
  BackendTensor reshape(List<int> shape) {
    final pyShape = intListToPython(shape);
    try {
      return PythonBackendTensor(_call1(object, 'reshape', pyShape));
    } finally {
      pyShape.dispose();
    }
  }

  @override
  BackendTensor transpose() => PythonBackendTensor(object.get('T'));
  @override
  BackendTensor sum() => PythonBackendTensor(_call(object, 'sum'));
  @override
  BackendTensor mean() => PythonBackendTensor(_call(object, 'mean'));
  @override
  BackendTensor relu() => PythonBackendTensor(_call(object, 'relu'));

  @override
  Object toList() {
    final detached = _call(object, 'detach');
    try {
      final cpu = _call(detached, 'cpu');
      try {
        final result = _call(cpu, 'tolist');
        try {
          return pythonToDart(
            result,
            ndim,
            floatingPoint: _isFloatingPointDtype(dtype),
          );
        } finally {
          result.dispose();
        }
      } finally {
        cpu.dispose();
      }
    } finally {
      detached.dispose();
    }
  }

  @override
  num item() {
    final result = _call(object, 'item');
    try {
      return _isFloatingPointDtype(dtype) ? result.toDouble() : result.toInt();
    } finally {
      result.dispose();
    }
  }

  @override
  void dispose() => object.dispose();

  @override
  String toString() => object.str;
}

PyObject _call(PyObject object, String name) {
  final callable = object.get(name);
  try {
    return callable.call0();
  } finally {
    callable.dispose();
  }
}

PyObject _call1(PyObject object, String name, PyObject argument) {
  final callable = object.get(name);
  try {
    return callable.call1(argument);
  } finally {
    callable.dispose();
  }
}

int _callInt(PyObject object, String name) {
  final result = _call(object, name);
  try {
    return result.toInt();
  } finally {
    result.dispose();
  }
}

PyObject _number(num value) =>
    value is int ? PyInt(value) : PyDouble(value.toDouble());

bool _isFloatingPointDtype(String dtype) =>
    dtype.contains('float') || dtype.contains('bfloat');

int _readInt(PyObject object, String name) {
  final value = object.get(name);
  try {
    return value.toInt();
  } finally {
    value.dispose();
  }
}

bool _readBool(PyObject object, String name) {
  final value = object.get(name);
  try {
    return value.isTrue;
  } finally {
    value.dispose();
  }
}

String _readString(PyObject object, String name) {
  final value = object.get(name);
  try {
    return value.str;
  } finally {
    value.dispose();
  }
}
