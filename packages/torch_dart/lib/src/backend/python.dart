// ignore_for_file: non_constant_identifier_names

import 'dart:async' show Zone;

import 'package:py_embed/py_embed.dart';

import '../base.dart';

final class PythonApi() implements BaseApi {
  @override
  ModulePython module_from_source(
    String source, {
    String class_name = 'Model',
    String? name,
    List<Object?> args = const [],
    Map<String, Object?> kwargs = const {},
  }) => ResourceScope.scope(() {
    final module = PyModule.fromSource(source, name: name);
    final constructor = module.getAttr(class_name);
    return ModulePython(constructor.forward(args, kwargs: kwargs))
        .detachToParentScope();
  });

  @override
  ModulePython conv2d(
    int in_channels,
    int out_channels,
    Object kernel_size, {
    Object stride = 1,
    Object padding = 0,
    Object dilation = 1,
    int groups = 1,
    bool bias = true,
    String padding_mode = 'zeros',
    Device? device,
    DType? dtype,
  }) => ResourceScope.scope(() {
    final nn = PyModule('torch.nn');
    final constructor = nn.getAttr('Conv2d');
    return ModulePython(
      constructor.forward(
        [in_channels, out_channels, kernel_size],
        kwargs: {
          'stride': stride,
          'padding': padding,
          'dilation': dilation,
          'groups': groups,
          'bias': bias,
          'padding_mode': padding_mode,
          if (device != null) 'device': device.toString(),
          if (dtype != null) 'dtype': _torch.getAttr(dtype.name),
        },
      ),
    ).detachToParentScope();
  });

  @override
  ModulePython module(
    Tensor Function(List<Tensor>, Map<String, Tensor>) forward,
  ) {
    final callback = ResourceScope.unmanaged(
      () => PyFunction((args, kwargs) {
        final inputs = [
          for (var i = 0; i < args.length; i++) TensorPython(args[i]),
        ];
        final keywords = <String, Tensor>{};
        if (kwargs != null) {
          final keys = kwargs.keys;
          for (var i = 0; i < keys.length; i++) {
            final key = keys[i].asString();
            keywords[key] = TensorPython(kwargs.elementAtStr(key)!);
          }
        }
        final output = forward(inputs, keywords) as TensorPython;
        return output.handle;
      }, name: 'forward'),
    );
    try {
      return ResourceScope.scope(() {
        final nn = PyModule('torch.nn');
        final base = nn.getAttr('Module');
        final modelClass = newType('DartModule', [base], {'forward': callback});
        return ModulePython(modelClass.call0(), callback).detachToParentScope();
      });
    } catch (_) {
      callback.dispose();
      rethrow;
    }
  }

  @override
  ModulePython linear(int in_features, int out_features, {bool bias = true}) =>
      ResourceScope.scope(() {
        final nn = PyModule('torch.nn');
        final constructor = nn.getAttr('Linear');
        return ModulePython(
          constructor.forward(
            [in_features, out_features],
            kwargs: {'bias': bias},
          ),
        ).detachToParentScope();
      });

  @override
  AdamPython adam(
    List<Tensor> params, {
    double lr = 0.001,
    List<double> betas = const [0.9, 0.999],
    double eps = 1e-8,
    double weight_decay = 0,
    bool amsgrad = false,
  }) => ResourceScope.scope(() {
    final constructor = _optim.getAttr('Adam');
    return AdamPython(
      constructor
          .forward(
            [params],
            kwargs: {
              'lr': lr,
              'betas': betas,
              'eps': eps,
              'weight_decay': weight_decay,
              'amsgrad': amsgrad,
            },
          )
          .detachToParentScope(),
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
  }) => ResourceScope.scope(() {
    final constructor = _optim.getAttr('SGD');
    return SGDPython(
      constructor
          .forward(
            [params],
            kwargs: {
              'lr': lr,
              'momentum': momentum,
              'dampening': dampening,
              'weight_decay': weight_decay,
              'nesterov': nesterov,
            },
          )
          .detachToParentScope(),
    );
  });

  // Import PyTorch only when the backend is first used.
  late final _torch = ResourceScope.unmanaged(() => PyModule('torch'));
  late final _optim = ResourceScope.unmanaged(() => PyModule('torch.optim'));

  @override
  late final String version = _torch.getAttrString('__version__');

  @override
  void manual_seed(int seed) => ResourceScope.scope(() {
    final method = _torch.getAttr('manual_seed');
    method.forward([seed]);
  });

  TensorPython _create(
    String name,
    Object data, {
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  }) => ResourceScope.scope(() {
    final method = _torch.getAttr(name);
    return TensorPython(
      method
          .forward(
            [data],
            kwargs: {
              if (dtype != null) 'dtype': _torch.getAttr(dtype.name),
              if (device != null) 'device': device.toString(),
              'requires_grad': requires_grad,
            },
          )
          .detachToParentScope(),
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

  late final _arange = ResourceScope.unmanaged(() => _torch.getAttr('arange'));

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

    return TensorPython(
      ResourceScope.returning(
        () => _arange.forward(
          [start, end, step],
          kwargs: {
            if (dtype != null) 'dtype': _torch.getAttr(dtype.name),
            if (device != null) 'device': device.toString(),
            if (requires_grad) 'requires_grad': true,
          },
        ),
      ),
    );
  }

  @override
  T no_grad<T>(T Function() action) {
    final context = ResourceScope.returning(
      () => _torch.getAttr('no_grad').call0(),
    );
    try {
      final callerZone = Zone.current;
      return context.withContext((_) => callerZone.run(action));
    } finally {
      context.dispose();
    }
  }

  late final _inference_mode = ResourceScope.unmanaged(
    () => _torch.getAttr('inference_mode'),
  );

  @override
  T inference_mode<T>(T Function() action) {
    final context = ResourceScope.returning(() => _inference_mode.call0());
    try {
      final callerZone = Zone.current;
      return context.withContext((_) => callerZone.run(action));
    } finally {
      context.dispose();
    }
  }

  late final _jit_load = ResourceScope.unmanaged(
    () => ResourceScope.returning(() {
      final module = _torch.getAttr('jit');
      return module.getAttr('load');
    }),
  );

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
  ScriptModulePython eval() => ResourceScope.scope(() {
    final method = handle.getAttr('eval');
    method.call0();
    return this;
  });

  @override
  TensorPython call(covariant TensorPython input) => forward([input]);

  @override
  TensorPython forward(List<Tensor> inputs) => ResourceScope.scope(() {
    final args = <PyObject>[];
    for (final input in inputs) {
      args.add((input as TensorPython).handle);
    }
    final method = handle.getAttr('forward');
    final result = method.forward(args);
    final module = PyModule('torch');
    final check = module.getAttr('is_tensor');
    if (!check.forward([result]).asBool()) {
      throw UnsupportedError('Only a single Tensor output is supported');
    }
    return TensorPython(result.detachToParentScope());
  });

  @override
  void dispose() => handle.dispose();
}

final class TensorPython(@override final PyObject handle)
    implements Tensor, PyObjectWrapper {
  TensorPython _promote() {
    handle.detachToParentScope();
    return this;
  }

  TensorPython _apply(
    String name, [
    List<Object?> args = const [],
    Map<String, Object?>? kwargs,
  ]) => ResourceScope.scope(() {
    final method = handle.getAttr(name);
    return TensorPython(
      method.forward(args, kwargs: kwargs).detachToParentScope(),
    );
  });

  void _invoke(
    String name, [
    List<Object?> args = const [],
    Map<String, Object?>? kwargs,
  ]) => ResourceScope.scope(() {
    final method = handle.getAttr(name);
    method.forward(args, kwargs: kwargs);
  });

  @override
  int get ndim => handle.getAttrInt('ndim');
  @override
  int get numel =>
      ResourceScope.scope(() => handle.getAttr('numel').call0().asInt());
  @override
  bool get requires_grad => handle.getAttrBool('requires_grad');
  @override
  set requires_grad(bool value) => _invoke('requires_grad_', [value]);
  @override
  bool get is_leaf => handle.getAttrBool('is_leaf');
  @override
  TensorPython? get grad => ResourceScope.scope(() {
    final value = handle.getAttr('grad');
    return value == PyObject.borrowedConst(.none)
        ? null
        : TensorPython(value.detachToParentScope());
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
  void zero_grad({bool set_to_none = true}) => ResourceScope.scope(() {
    if (set_to_none) {
      handle.setAttr('grad', .borrowedConst(.none));
    } else {
      final value = handle.getAttr('grad');
      if (value != PyObject.borrowedConst(.none)) {
        value.getAttr('detach_').call0();
        value.getAttr('zero_').call0();
      }
    }
  });

  @override
  TensorPython operator +(Object other) => ResourceScope.scope(() {
    final operand = PyConverter().toPyObject(other);
    return TensorPython((handle + operand).detachToParentScope());
  });
  @override
  TensorPython operator -(Object other) => ResourceScope.scope(() {
    final operand = PyConverter().toPyObject(other);
    return TensorPython((handle - operand).detachToParentScope());
  });
  @override
  TensorPython operator *(Object other) => ResourceScope.scope(() {
    final operand = PyConverter().toPyObject(other);
    return TensorPython((handle * operand).detachToParentScope());
  });
  @override
  TensorPython operator /(Object other) => ResourceScope.scope(() {
    final operand = PyConverter().toPyObject(other);
    return TensorPython((handle / operand).detachToParentScope());
  });
  @override
  TensorPython operator -() => TensorPython(-handle);
  @override
  TensorPython matmul(Tensor other) => ResourceScope.scope(() {
    final operand = PyConverter().toPyObject(other);
    return TensorPython(handle.matrixMultiply(operand).detachToParentScope());
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
  TensorPython to({Device? device, DType? dtype}) => ResourceScope.scope(() {
    final torch = PyModule('torch');
    return _apply('to', [], {
      if (device != null) 'device': device.toString(),
      if (dtype != null) 'dtype': torch.getAttr(dtype.name),
    })._promote();
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
  Object item() =>
      ResourceScope.scope(() => _scalar(handle.getAttr('item').call0(), dtype));
  @override
  Object toList() => ResourceScope.scope(() {
    final type = dtype;
    if (type == .complex64 || type == .complex128) {
      throw UnsupportedError('Complex tensor data conversion is not supported');
    }
    final dimensions = shape;
    final values = handle.getAttr('tolist').call0();
    Object read(PyObject value, int depth) {
      if (depth == dimensions.length) return _scalar(value, type);
      return List<Object>.generate(
        dimensions[depth],
        (i) => read(value.getItem(PyInt(i)), depth + 1),
      );
    }

    return read(values, 0);
  });

  @override
  List<int> get shape => ResourceScope.scope(() {
    final shape = handle.getAttr('shape');
    return .unmodifiableOf(
      List<int>.generate(
        handle.getAttrInt('ndim'),
        (i) => shape.getItem(PyInt(i)).asInt(),
      ),
    );
  });

  @override
  DType get dtype => ResourceScope.scope(() {
    final dtype = handle.getAttr('dtype');
    final name = dtype.toString();
    return .fromString(name.substring(6));
  });

  @override
  Device get device => ResourceScope.scope(() {
    final device = handle.getAttr('device');
    final index = device.getAttr('index');
    return Device(
      .fromString(device.getAttrString('type')),
      index: index.ptr == PyObject.borrowedConst(.none).ptr
          ? null
          : index.asInt(),
    );
  });

  @override
  TensorPython reshape(List<int> shape) => ResourceScope.scope(() {
    final method = handle.getAttr('reshape');
    return TensorPython(method.forward(shape).detachToParentScope());
  });

  @override
  TensorPython unsqueeze(int dim) => ResourceScope.scope(() {
    final method = handle.getAttr('unsqueeze');
    return TensorPython(method.forward([dim]).detachToParentScope());
  });

  @override
  TensorPython squeeze([int? dim]) => ResourceScope.scope(() {
    final method = handle.getAttr('squeeze');
    return TensorPython(method.forward([dim]).detachToParentScope());
  });

  @override
  TensorPython view(List<int> shape) => ResourceScope.scope(() {
    final method = handle.getAttr('view');
    return TensorPython(method.forward(shape).detachToParentScope());
  });

  @override
  Tensor detach() => ResourceScope.scope(() {
    final method = handle.getAttr('detach');
    return TensorPython(method.call0().detachToParentScope());
  });

  @override
  Tensor clone() => ResourceScope.scope(() {
    final method = handle.getAttr('clone');
    return TensorPython(method.call0().detachToParentScope());
  });

  @override
  String toString() => handle.toString();

  @override
  void dispose() => handle.dispose();
}

final class SGDPython(final PyObject handle) implements SGD {
  @override
  void zero_grad({bool set_to_none = true}) => ResourceScope.scope(() {
    final method = handle.getAttr('zero_grad');
    method.forward([], kwargs: {'set_to_none': set_to_none});
  });

  @override
  void step() => ResourceScope.scope(() {
    final method = handle.getAttr('step');
    method.call0();
  });

  @override
  void dispose() => handle.dispose();
}

final class AdamPython(final PyObject handle) implements Adam {
  @override
  void zero_grad({bool set_to_none = true}) => ResourceScope.scope(() {
    final method = handle.getAttr('zero_grad');
    method.forward([], kwargs: {'set_to_none': set_to_none});
  });

  @override
  void step() => ResourceScope.scope(() {
    final method = handle.getAttr('step');
    method.call0();
  });

  @override
  void dispose() => handle.dispose();
}

final class ModulePython implements ModuleBackend, ScopedResource {
  final PyObject handle;
  final PyFunction? callback;

  ModulePython(this.handle, [this.callback]) {
    handle.detachFromScope();
    callback?.detachFromScope();
    ResourceScope.track(this);
  }

  @override
  bool get isDisposed => handle.isDisposed;

  @override
  ModulePython detachFromScope() {
    ResourceScope.untrack(this);
    return this;
  }

  @override
  ModulePython detachToParentScope() {
    ResourceScope.promoteToParent(this);
    return this;
  }

  @override
  void save(String path) => ResourceScope.scope(() {
    final method = PyModule('torch').getAttr('save');
    method.forward([handle, path]);
  });

  @override
  void save_pt(String path, {required List<Tensor> inputs}) {
    if (inputs.length != 1) {
      throw UnsupportedError('save_pt currently requires one tensor input');
    }
    ResourceScope.scope(() => _savePt.forward([handle, path, inputs.single]));
  }

  @override
  TensorPython call(
    List<Tensor> inputs, {
    Map<String, Tensor> kwargs = const {},
  }) => TensorPython(handle.forward(inputs, kwargs: kwargs));

  @override
  void register_module(String name, ModuleBackend module) =>
      ResourceScope.scope(() {
        final method = handle.getAttr('add_module');
        method.forward([name, (module as ModulePython).handle]);
      });

  @override
  List<Tensor> parameters() => ResourceScope.scope(() {
    final method = handle.getAttr('parameters');
    final iterator = method.call0();
    final list = PyModule('builtins').getAttr('list');
    final values = PyList.fromRef(list.forward([iterator]).ref);
    return .generate(values.length, (i) {
      final value = values[i];
      return TensorPython(value.detachToParentScope());
    });
  });

  @override
  bool get training => handle.getAttrBool('training');
  @override
  void train(bool mode) => ResourceScope.scope(() {
    final method = handle.getAttr('train');
    method.forward([mode]);
  });
  @override
  void zero_grad({bool set_to_none = true}) => ResourceScope.scope(() {
    final method = handle.getAttr('zero_grad');
    method.forward([], kwargs: {'set_to_none': set_to_none});
  });
  @override
  void dispose() {
    if (isDisposed) return;
    ResourceScope.untrack(this);
    handle.dispose();
    callback?.dispose();
  }
}

// A Python function supplies the inspectable signature FX requires. Keep this
// export adapter local to the backend; restore original methods even on failure.
final _savePt = ResourceScope.unmanaged(
  () => ResourceScope.returning(() {
    final namespace = PyDict();
    final exec = PyModule('builtins').getAttr('exec');
    exec.forward([_savePtSource, namespace]);
    final function = namespace.elementAtStr('_save_pt')!;
    return function;
  }),
);

const _savePtSource = r'''
import inspect
import torch
import torch.fx

def _make_forward(callback):
    def forward(self, x):
        return callback(x)
    return forward

def _save_pt(model, path, example_input):
    training = [(module, module.training) for module in model.modules()]
    originals = {}
    try:
        model.eval()
        for module, _ in training:
            cls = type(module)
            if inspect.isbuiltin(module.forward) and cls not in originals:
                originals[cls] = cls.forward
                cls.forward = _make_forward(module.forward)
        graph = torch.fx.symbolic_trace(model)
        traced = torch.jit.trace(graph, (example_input,))
        traced.save(path)
    finally:
        for cls, forward in originals.items():
            cls.forward = forward
        for module, flag in training:
            module.training = flag
''';
