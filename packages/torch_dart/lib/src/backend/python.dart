// ignore_for_file: non_constant_identifier_names

import 'package:py_embed/py_embed.dart';

import '../base.dart';

final class PythonApi() implements BaseApi {
  @override
  AdamPython adam(
    List<Tensor> params, {
    double lr = 0.001,
    List<double> betas = const [0.9, 0.999],
    double eps = 1e-8,
    double weight_decay = 0,
    bool amsgrad = false,
  }) => using((scope) {
    final constructor = scope(_optim.getAttr('Adam'));
    return AdamPython(
      constructor.forward(
        [params],
        kwargs: {
          'lr': lr,
          'betas': betas,
          'eps': eps,
          'weight_decay': weight_decay,
          'amsgrad': amsgrad,
        },
      ),
    );
  });

  @override
  SGDPython sgd(
    List<Tensor> params, {
    double lr = 0.001,
    double momentum = 0,
    double dampening = 0,
    double weight_decay = 0,
    bool nesterov = false,
  }) => using((scope) {
    final constructor = scope(_optim.getAttr('SGD'));
    return SGDPython(
      constructor.forward(
        [params],
        kwargs: {
          'lr': lr,
          'momentum': momentum,
          'dampening': dampening,
          'weight_decay': weight_decay,
          'nesterov': nesterov,
        },
      ),
    );
  });

  // Import PyTorch only when the backend is first used.
  late final _torch = PyModule('torch');
  late final _optim = PyModule('torch.optim');

  @override
  late final String version = _torch.getAttrString('__version__');

  @override
  void manual_seed(int seed) => using((scope) {
    final method = scope(_torch.getAttr('manual_seed'));
    scope(method.forward([seed]));
  });

  TensorPython _create(
    String name,
    Object data, {
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  }) => using((scope) {
    final method = scope(_torch.getAttr(name));
    return TensorPython(
      method.forward(
        [data],
        kwargs: {
          if (dtype != null) 'dtype': scope(_torch.getAttr(dtype.name)),
          if (device != null) 'device': device.toString(),
          'requires_grad': requires_grad,
        },
      ),
    );
  });

  @override
  TensorPython tensor(
    Object data, {
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  }) {
    final active = Set<List>.identity();
    void validate(Object? value) {
      if (value is List) {
        if (!active.add(value)) {
          throw ArgumentError('Cyclic tensor data is not supported');
        }
        try {
          for (final element in value) {
            validate(element);
          }
        } finally {
          active.remove(value);
        }
      } else if (value is! num && value is! bool) {
        throw ArgumentError.value(
          value,
          'data',
          'Expected numeric/bool scalar or nested list',
        );
      }
    }

    validate(data);
    return _create(
      'tensor',
      data,
      dtype: dtype,
      device: device,
      requires_grad: requires_grad,
    );
  }

  @override
  TensorPython zeros(
    List<int> shape, {
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  }) => _create(
    'zeros',
    shape,
    dtype: dtype,
    device: device,
    requires_grad: requires_grad,
  );

  @override
  TensorPython ones(
    List<int> shape, {
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  }) => _create(
    'ones',
    shape,
    dtype: dtype,
    device: device,
    requires_grad: requires_grad,
  );

  @override
  TensorPython randn(
    List<int> shape, {
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  }) => _create(
    'randn',
    shape,
    dtype: dtype,
    device: device,
    requires_grad: requires_grad,
  );

  late final _arange = _torch.getAttr('arange');

  @override
  TensorPython arange(
    num end, {
    num start = 0,
    num step = 1,
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  }) {
    if (step == 0) {
      throw ArgumentError.value(step, 'step', 'Step cannot be zero');
    }
    if (step > 0 && start >= end || step < 0 && start <= end) {
      throw ArgumentError(
        'Step must be positive when start < end '
        'and negative when start > end.',
      );
    }

    return using(
      (scope) => TensorPython(
        _arange.forward(
          [start, end, step],
          kwargs: {
            if (dtype != null) 'dtype': scope(_torch.getAttr(dtype.name)),
            if (device != null) 'device': device.toString(),
            if (requires_grad) 'requires_grad': true,
          },
        ),
      ),
    );
  }

  @override
  T no_grad<T>(T Function() action) => using((scope) {
    final method = scope(_torch.getAttr('no_grad'));
    final context = scope(method.call0());
    return context.withContext((_) => action());
  });

  late final _inference_mode = _torch.getAttr('inference_mode');

  @override
  T inference_mode<T>(T Function() action) => using((scope) {
    final context = scope(_inference_mode.call0());
    return context.withContext((_) => action());
  });

  late final _jit_load = using((scope) {
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
  ScriptModulePython eval() => using((scope) {
    final method = scope(handle.getAttr('eval'));
    scope(method.call0());
    return this;
  });

  @override
  TensorPython call(covariant TensorPython input) => forward([input]);

  @override
  TensorPython forward(List<Tensor> inputs) => using((scope) {
    final args = <PyObject>[];
    for (final input in inputs) {
      args.add((input as TensorPython).handle);
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

final class TensorPython(@override final PyObject handle)
    implements Tensor, PyObjectWrapper {
  TensorPython _apply(
    String name, [
    List<Object?> args = const [],
    Map<String, Object?>? kwargs,
  ]) => using((scope) {
    final method = scope(handle.getAttr(name));
    return TensorPython(method.forward(args, kwargs: kwargs));
  });

  void _invoke(
    String name, [
    List<Object?> args = const [],
    Map<String, Object?>? kwargs,
  ]) => using((scope) {
    final method = scope(handle.getAttr(name));
    scope(method.forward(args, kwargs: kwargs));
  });

  @override
  int get ndim => handle.getAttrInt('ndim');
  @override
  int get numel =>
      using((scope) => scope(scope(handle.getAttr('numel')).call0()).asInt());
  @override
  bool get requires_grad => handle.getAttrBool('requires_grad');
  @override
  set requires_grad(bool value) => _invoke('requires_grad_', [value]);
  @override
  bool get is_leaf => handle.getAttrBool('is_leaf');
  @override
  TensorPython? get grad => using((scope) {
    final value = scope(handle.getAttr('grad'));
    return value == PyObject.borrowedConst(.none)
        ? null
        : TensorPython(scope.escape(value));
  });
  @override
  void retain_grad() => _invoke('retain_grad');
  @override
  void backward({
    Tensor? gradient,
    bool? retain_graph,
    bool create_graph = false,
  }) => _invoke('backward', [], {
    'gradient': ?gradient,
    'retain_graph': ?retain_graph,
    'create_graph': create_graph,
  });
  @override
  void zero_grad({bool set_to_none = true}) => using((scope) {
    if (set_to_none) {
      handle.setAttr('grad', .borrowedConst(.none));
    } else {
      final value = scope(handle.getAttr('grad'));
      if (value != PyObject.borrowedConst(.none)) {
        scope(scope(value.getAttr('detach_')).call0());
        scope(scope(value.getAttr('zero_')).call0());
      }
    }
  });

  @override
  TensorPython operator +(Object other) => using((scope) {
    final operand = scope(PyConverter().toPyObject(other));
    return TensorPython(handle + operand);
  });
  @override
  TensorPython operator -(Object other) => using((scope) {
    final operand = scope(PyConverter().toPyObject(other));
    return TensorPython(handle - operand);
  });
  @override
  TensorPython operator *(Object other) => using((scope) {
    final operand = scope(PyConverter().toPyObject(other));
    return TensorPython(handle * operand);
  });
  @override
  TensorPython operator /(Object other) => using((scope) {
    final operand = scope(PyConverter().toPyObject(other));
    return TensorPython(handle / operand);
  });
  @override
  TensorPython operator -() => TensorPython(-handle);
  @override
  TensorPython matmul(Tensor other) => using((scope) {
    final operand = scope(PyConverter().toPyObject(other));
    return TensorPython(handle.matrixMultiply(operand));
  });
  @override
  TensorPython add_(Object other, {num alpha = 1}) {
    _invoke('add_', [other], {'alpha': alpha});
    return this;
  }

  @override
  TensorPython mul_(Object other) {
    _invoke('mul_', [other]);
    return this;
  }

  @override
  TensorPython copy_(Tensor source) {
    _invoke('copy_', [source]);
    return this;
  }

  @override
  TensorPython pow(num exponent) => _apply('pow', [exponent]);
  @override
  TensorPython relu() => _apply('relu');
  @override
  TensorPython sigmoid() => _apply('sigmoid');
  @override
  TensorPython tanh() => _apply('tanh');
  @override
  TensorPython exp() => _apply('exp');
  @override
  TensorPython log() => _apply('log');
  @override
  TensorPython contiguous() => _apply('contiguous');
  @override
  TensorPython sum({int? dim, bool keepdim = false}) =>
      _reduce('sum', dim: dim, keepdim: keepdim);
  @override
  TensorPython mean({int? dim, bool keepdim = false}) =>
      _reduce('mean', dim: dim, keepdim: keepdim);

  TensorPython _reduce(String name, {int? dim, required bool keepdim}) {
    // Older PyTorch versions resolve dim=None to the named-dimension overload.
    // A global reduction uses the no-argument overload; keeping dimensions
    // requires explicitly selecting all numerical axes.
    if (dim == null && !keepdim) return _apply(name);
    return _apply(name, [], {
      'dim': dim ?? List<int>.generate(ndim, (i) => i),
      'keepdim': keepdim,
    });
  }

  @override
  TensorPython transpose(int dim0, int dim1) =>
      _apply('transpose', [dim0, dim1]);
  @override
  TensorPython to({Device? device, DType? dtype}) => using((scope) {
    final torch = scope(PyModule('torch'));
    return _apply('to', [], {
      if (device != null) 'device': device.toString(),
      if (dtype != null) 'dtype': scope(torch.getAttr(dtype.name)),
    });
  });

  Object _scalar(PyObject value, DType type) => switch (type) {
    .bool => value.asBool(),
    .uint8 || .int8 || .int16 || .int32 || .int64 => value.asInt(),
    .float16 || .bfloat16 || .float32 || .float64 => value.asDouble(),
    _ => throw UnsupportedError(
      'Complex tensor data conversion is not supported',
    ),
  };
  @override
  Object item() => using(
    (scope) => _scalar(scope(scope(handle.getAttr('item')).call0()), dtype),
  );
  @override
  Object toList() => using((scope) {
    final type = dtype;
    if (type == .complex64 || type == .complex128) {
      throw UnsupportedError('Complex tensor data conversion is not supported');
    }
    final dimensions = shape;
    final values = scope(scope(handle.getAttr('tolist')).call0());
    Object read(PyObject value, int depth) {
      if (depth == dimensions.length) return _scalar(value, type);
      return List<Object>.generate(
        dimensions[depth],
        (i) => read(scope(value.getItem(scope(PyInt(i)))), depth + 1),
      );
    }

    return read(values, 0);
  });

  @override
  List<int> get shape => using((scope) {
    final shape = scope(handle.getAttr('shape'));
    return .unmodifiableOf(
      List<int>.generate(
        handle.getAttrInt('ndim'),
        (i) => scope(shape.getItem(scope(PyInt(i)))).asInt(),
      ),
    );
  });

  @override
  DType get dtype => using((scope) {
    final dtype = scope(handle.getAttr('dtype'));
    final name = dtype.toString();
    return .fromString(name.substring(6));
  });

  @override
  Device get device => using((scope) {
    final device = scope(handle.getAttr('device'));
    final index = scope(device.getAttr('index'));
    return Device(
      .fromString(device.getAttrString('type')),
      index: index.ptr == PyObject.borrowedConst(.none).ptr
          ? null
          : index.asInt(),
    );
  });

  @override
  TensorPython reshape(List<int> shape) => using((scope) {
    final method = scope(handle.getAttr('reshape'));
    return TensorPython(method.forward(shape));
  });

  @override
  TensorPython unsqueeze(int dim) => using((scope) {
    final method = scope(handle.getAttr('unsqueeze'));
    return TensorPython(method.forward([dim]));
  });

  @override
  TensorPython squeeze([int? dim]) => using((scope) {
    final method = scope(handle.getAttr('squeeze'));
    return TensorPython(method.forward([dim]));
  });

  @override
  TensorPython view(List<int> shape) => using((scope) {
    final method = scope(handle.getAttr('view'));
    return TensorPython(method.forward(shape));
  });

  @override
  Tensor detach() => using((scope) {
    final method = scope(handle.getAttr('detach'));
    return TensorPython(method.call0());
  });

  @override
  Tensor clone() => using((scope) {
    final method = scope(handle.getAttr('clone'));
    return TensorPython(method.call0());
  });

  @override
  String toString() => handle.toString();

  @override
  void dispose() => handle.ref.discrement();
}

final class SGDPython(final PyObject handle) implements SGD {
  @override
  void zero_grad({bool set_to_none = true}) => using((scope) {
    final method = scope(handle.getAttr('zero_grad'));
    scope(method.forward([], kwargs: {'set_to_none': set_to_none}));
  });

  @override
  void step() => using((scope) {
    final method = scope(handle.getAttr('step'));
    scope(method.call0());
  });

  @override
  void dispose() => handle.ref.discrement();
}

final class AdamPython(final PyObject handle) implements Adam {
  @override
  void zero_grad({bool set_to_none = true}) => using((scope) {
    final method = scope(handle.getAttr('zero_grad'));
    scope(method.forward([], kwargs: {'set_to_none': set_to_none}));
  });

  @override
  void step() => using((scope) {
    final method = scope(handle.getAttr('step'));
    scope(method.call0());
  });

  @override
  void dispose() => handle.ref.discrement();
}
