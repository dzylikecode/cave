// ignore_for_file: non_constant_identifier_names

import 'package:meta/meta.dart';

import 'backend/python.dart';

@internal
final pythonApi = PythonApi();

@internal
BaseApi get api => pythonApi;

/// Entry point for the active PyTorch backend.
abstract final class Torch {
  static String get version => api.version;
}

/// Seeds PyTorch's random number generators on all devices.
///
/// Resetting the same [seed] reproduces random sequences in the same environment.
/// The backend's returned generator is discarded.
void manual_seed(int seed) => api.manual_seed(seed);

/// Runs [action] synchronously with inference mode enabled.
///
/// Restores the previous mode when [action] returns or throws. The return value
/// is forwarded unchanged. Do not pass an async callback: the scope does not
/// extend across await points.
T inference_mode<T>(T Function() action) => api.inference_mode(action);

/// Creates a zero-filled tensor with [shape]. Dimensions must be nonnegative.
/// An empty shape creates a scalar; zero-sized dimensions are allowed.
/// Omitted [dtype] and [device] use the backend defaults.
/// The caller owns the returned tensor and must dispose it.
Tensor zeros(
  List<int> shape, {
  DType? dtype,
  Device? device,
  bool requires_grad = false,
}) => api.zeros(
  shape,
  dtype: dtype,
  device: device,
  requires_grad: requires_grad,
);

/// Copies a numeric/bool scalar or nested Dart list into a new leaf tensor.
///
/// The caller owns the result. Tensor inputs are not accepted; use [Tensor.clone] instead.
Tensor tensor(
  Object data, {
  DType? dtype,
  Device? device,
  bool requires_grad = false,
}) => api.tensor(
  data,
  dtype: dtype,
  device: device,
  requires_grad: requires_grad,
);

/// Creates a tensor filled with ones.
///
/// The caller owns the result.
Tensor ones(
  List<int> shape, {
  DType? dtype,
  Device? device,
  bool requires_grad = false,
}) =>
    api.ones(shape, dtype: dtype, device: device, requires_grad: requires_grad);

/// Creates standard normal samples.
///
/// The caller owns the result.
Tensor randn(
  List<int> shape, {
  DType? dtype,
  Device? device,
  bool requires_grad = false,
}) => api.randn(
  shape,
  dtype: dtype,
  device: device,
  requires_grad: requires_grad,
);

/// Disables gradient recording for a synchronous callback, restoring on error.
///
/// Factory requires_grad arguments still apply. Do not pass an async callback.
T no_grad<T>(T Function() action) => api.no_grad(action);

Tensor arange(
  num end, {
  num start = 0,
  num step = 1,
  DType? dtype,
  Device? device,
  bool requires_grad = false,
}) => api.arange(
  end,
  start: start,
  step: step,
  dtype: dtype,
  device: device,
  requires_grad: requires_grad,
);

const jit = Jit();

/// Loading operations for TorchScript models.
final class const Jit() {
  /// Loads a model, optionally remapping its tensors to [map_location].
  ///
  /// When omitted, the saved devices are preserved. Loading does not change
  /// the model's evaluation mode or enable inference mode.
  ScriptModule load(String path, {Device? map_location}) =>
      api.jit_load(path, map_location: map_location);
}

/// A loaded TorchScript model owning resources until [dispose] is called.
abstract interface class ScriptModule {
  /// Switches this model to evaluation mode and returns the same model.
  /// This does not enable inference mode.
  ScriptModule eval();

  /// Calls a model accepting one tensor and returning one tensor.
  Tensor call(Tensor input);

  /// Calls forward with positional tensor inputs and a single tensor output.
  /// Inputs remain owned by the caller; the caller owns the returned tensor.
  Tensor forward(List<Tensor> inputs);

  /// Releases this model's resources. Do not use the model afterward.
  void dispose();
}

/// Backend contract. Extend this as the public API takes shape.
@internal
abstract interface class BaseApi {
  ModuleBackend module_from_source(
    String source, {
    String class_name = 'Model',
    String? name,
    List<Object?> args = const [],
    Map<String, Object?> kwargs = const {},
  });
  ModuleBackend conv2d(
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
  });
  ModuleBackend module(
    Tensor Function(List<Tensor>, Map<String, Tensor>) forward,
  );
  ModuleBackend linear(int in_features, int out_features, {bool bias = true});
  Adam adam(
    List<Tensor> params, {
    double lr = 0.001,
    List<double> betas = const [0.9, 0.999],
    double eps = 1e-8,
    double weight_decay = 0,
    bool amsgrad = false,
  });
  SGD sgd(
    List<Tensor> params, {
    double lr = 0.001,
    double momentum = 0,
    double dampening = 0,
    double weight_decay = 0,
    bool nesterov = false,
  });
  String get version;
  void manual_seed(int seed);
  T inference_mode<T>(T Function() action);
  ScriptModule jit_load(String path, {Device? map_location});
  T no_grad<T>(T Function() action);
  Tensor tensor(
    Object data, {
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  });
  Tensor zeros(
    List<int> shape, {
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  });
  Tensor ones(
    List<int> shape, {
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  });
  Tensor randn(
    List<int> shape, {
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  });

  Tensor arange(
    num end, {
    num start = 0,
    num step = 1,
    DType? dtype,
    Device? device,
    bool requires_grad = false,
  });
}

/// Scalar element types supported by the initial Tensor API.
enum DType {
  bool,
  uint8,
  int8,
  int16,
  int32,
  int64,
  float16,
  bfloat16,
  float32,
  float64,
  complex64,
  complex128;

  factory fromString(String s) => values.firstWhere(
    (v) => v.name == s,
    orElse: () => throw FormatException('unknown dtype', s),
  );
}

enum DeviceType {
  cpu,
  cuda,
  mps;

  factory fromString(String v) => switch (v) {
    'cpu' => .cpu,
    'cuda' => .cuda,
    'mps' => .mps,
    _ => throw FormatException('Unknown device type', v),
  };
}

/// A device type and optional index. A null index leaves selection to the backend.
final class const Device(final DeviceType type, {final int? index}) {
  this : assert(index == null || index >= 0);

  /// Parses `type` or `type:index`, with a nonnegative decimal index.
  factory parse(String value) {
    final parts = value.split(':');
    if (parts.length > 2) {
      throw FormatException('Expected type or type:index', value);
    }

    final DeviceType type = .fromString(parts[0]);

    final index = parts.length == 2 ? int.parse(parts[1]) : null;

    return .new(type, index: index);
  }

  @override
  bool operator ==(Object other) =>
      other is Device && type == other.type && index == other.index;

  @override
  int get hashCode => Object.hash(type, index);

  @override
  String toString() => index == null ? type.name : '${type.name}:$index';
}

/// A backend-independent tensor owning resources until [dispose] is called.
///
/// Each returned wrapper owns its reference, including views and gradients.
/// Views may share storage. Dispose each wrapper once and do not use it afterward.
/// In-place methods ending in `_` return this wrapper.
abstract interface class Tensor {
  List<int> get shape;
  DType get dtype;
  Device get device;

  int get ndim;
  int get numel;

  /// Whether operations involving this tensor record gradients.
  ///
  /// Changes follow PyTorch's gradient flag validation, including leaf checks.
  bool get requires_grad;
  set requires_grad(bool value);
  bool get is_leaf;

  /// Returns an independently owned wrapper, or null if no gradient is stored.
  Tensor? get grad;

  /// Retains gradients on a non-leaf tensor during backward.
  void retain_grad();

  /// Accumulates gradients into leaf tensors participating in this graph.
  ///
  /// Non-scalar outputs require [gradient]. Omitted [retain_graph] defaults to
  /// [create_graph]. With [create_graph], reset leaf gradients using [zero_grad]
  /// afterward to break possible reference cycles.
  void backward({
    Tensor? gradient,
    bool? retain_graph,
    bool create_graph = false,
  });

  /// Clears the stored gradient, leaving it absent when [set_to_none] is true.
  ///
  /// This is a Dart binding convenience, not a native PyTorch Tensor method.
  ///
  /// Otherwise detaches and zeros an existing gradient without creating one.
  void zero_grad({bool set_to_none = true});

  /// Adds a tensor or number using broadcasting.
  ///
  /// Non-mutating operation results are caller-owned and must be disposed.
  Tensor operator +(Object other);
  Tensor operator -(Object other);
  Tensor operator *(Object other);
  Tensor operator /(Object other);
  Tensor operator -();
  Tensor matmul(Tensor other);

  /// Adds [other] scaled by [alpha] in place and returns this wrapper.
  ///
  /// Use [no_grad] when updating leaf tensors that require gradients.
  Tensor add_(Object other, {num alpha = 1});

  /// Multiplies by [other] in place and returns this wrapper.
  Tensor mul_(Object other);

  /// Copies values from [source] in place and returns this wrapper.
  Tensor copy_(Tensor source);
  Tensor pow(num exponent);
  Tensor relu();
  Tensor sigmoid();
  Tensor tanh();
  Tensor exp();
  Tensor log();
  Tensor sum({int? dim, bool keepdim = false});
  Tensor mean({int? dim, bool keepdim = false});
  Tensor transpose(int dim0, int dim1);
  Tensor contiguous();

  /// Converts the device or element type.
  ///
  /// Even a no-op returns a separately owned wrapper.
  Tensor to({Device? device, DType? dtype});

  /// Reads a one-element bool, integer, or real tensor.
  ///
  /// Complex values are unsupported.
  Object item();

  /// Copies values into nested Dart lists matching the shape.
  ///
  /// A scalar returns a scalar.
  /// Reading may synchronize an accelerator. Complex values are unsupported.
  Object toList();

  Tensor reshape(List<int> shape);
  Tensor view(List<int> shape);
  Tensor unsqueeze(int dim);
  Tensor squeeze([int? dim]);
  Tensor detach();
  Tensor clone();

  /// Releases this tensor's resources. Do not use the tensor afterward.
  void dispose();
}

/// A PyTorch optimizer owning a backend reference until disposed.
abstract interface class Optimizer {
  /// Clears gradients on the optimizer's parameters.
  void zero_grad({bool set_to_none = true});

  /// Updates parameters using their current gradients.
  void step();

  /// Releases this wrapper; dispose once and do not use it afterward.
  void dispose();
}

/// Stochastic gradient descent with optional momentum and weight decay.
///
/// Parameters remain owned by the caller. The optimizer retains its own
/// references. Parameter and option validation is delegated to PyTorch.
abstract interface class SGD implements Optimizer {
  factory SGD(
    List<Tensor> params, {
    double lr = 0.001,
    double momentum = 0,
    double dampening = 0,
    double weight_decay = 0,
    bool nesterov = false,
  }) => api.sgd(
    params,
    lr: lr,
    momentum: momentum,
    dampening: dampening,
    weight_decay: weight_decay,
    nesterov: nesterov,
  );
}

/// Adaptive moment estimation backed by PyTorch.
///
/// Parameters remain owned by the caller; the optimizer retains its own
/// references. Option validation is delegated to PyTorch.
abstract interface class Adam implements Optimizer {
  factory Adam(
    List<Tensor> params, {
    double lr = 0.001,
    List<double> betas = const [0.9, 0.999],
    double eps = 1e-8,
    double weight_decay = 0,
    bool amsgrad = false,
  }) => api.adam(
    params,
    lr: lr,
    betas: betas,
    eps: eps,
    weight_decay: weight_decay,
    amsgrad: amsgrad,
  );
}

/// A model with Python-managed state and a Dart-defined forward computation.
abstract class Module {
  Module() {
    _backend = api.module((inputs, kwargs) => forward(inputs, kwargs: kwargs));
  }

  /// Creates a Python model class from source and calls its constructor.
  ///
  /// [class_name] selects the class; [args] and [kwargs] are constructor arguments.
  /// Supplying [name] registers a Python module, allowing whole-model pickle
  /// saving. Recreate the same named module before loading in a new process.
  factory Module.fromSource(
    String source, {
    String class_name = 'Model',
    String? name,
    List<Object?> args = const [],
    Map<String, Object?> kwargs = const {},
  }) => _SourceModule(
    api.module_from_source(
      source,
      class_name: class_name,
      name: name,
      args: args,
      kwargs: kwargs,
    ),
  );

  @internal
  Module.fromBackend(ModuleBackend backend) : _backend = backend;

  late final ModuleBackend _backend;

  /// Computes one tensor output from tensor inputs and keyword arguments.
  ///
  /// Callback inputs are borrowed for this call; do not dispose or keep them.
  /// Return an owned output, or an input unchanged. Output ownership transfers
  /// to the caller. Non-tensor arguments and outputs are not supported yet.
  Tensor forward(List<Tensor> inputs, {Map<String, Tensor> kwargs = const {}});

  /// Calls through Python's Module machinery, including forward hooks.
  Tensor call(List<Tensor> inputs, {Map<String, Tensor> kwargs = const {}}) =>
      _backend.call(inputs, kwargs: kwargs);

  /// Registers a child with PyTorch and returns the supplied Dart wrapper.
  T register_module<T extends Module>(String name, T module) {
    _backend.register_module(name, module._backend);
    return module;
  }

  /// Returns independently owned parameter wrappers; dispose each once.
  List<Tensor> parameters() => _backend.parameters();
  bool get training => _backend.training;
  Module train([bool mode = true]) {
    _backend.train(mode);
    return this;
  }

  Module eval() => train(false);
  void zero_grad({bool set_to_none = true}) =>
      _backend.zero_grad(set_to_none: set_to_none);

  /// Exports an FX-traceable model to a TorchScript file for inference.
  ///
  /// Currently accepts one positional tensor input and one tensor output.
  /// Tracing runs in evaluation mode and restores each module's training flag
  /// afterward. Data-dependent Dart control flow is not supported.
  void save_pt(String path, {required List<Tensor> inputs}) =>
      _backend.save_pt(path, inputs: inputs);

  /// Releases this wrapper once, after its Python owners have been released.
  ///
  /// Child wrappers remain caller-owned. Dispose parent models before children.
  void dispose() => _backend.dispose();
}

final class _SourceModule(super.backend) extends Module {
  this : super.fromBackend();

  @override
  Tensor forward(
    List<Tensor> inputs, {
    Map<String, Tensor> kwargs = const {},
  }) => _backend.call(inputs, kwargs: kwargs);
}

/// Pickles a complete Python model without requiring example inputs.
///
/// This is torch.save, not TorchScript export. The model class must be importable
/// by module name; Dart callback models are not supported. Loading requires the
/// same class definition and torch.load, not jit.load.
void save(Module model, String path) => model._backend.save(path);

/// A linear layer backed directly by torch.nn.Linear.
final class Linear extends Module {
  Linear(int in_features, int out_features, {bool bias = true})
    : super.fromBackend(api.linear(in_features, out_features, bias: bias));

  @override
  Tensor forward(
    List<Tensor> inputs, {
    Map<String, Tensor> kwargs = const {},
  }) => _backend.call(inputs, kwargs: kwargs);
}

/// A two-dimensional convolution backed by torch.nn.Conv2d.
///
/// [kernel_size], [stride], and [dilation] accept an int or a two-element
/// `List<int>`. [padding] additionally accepts `same` or `valid`.
/// PyTorch validates the arguments. Dispose this wrapper once after use.
final class Conv2d extends Module {
  Conv2d(
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
  }) : super.fromBackend(
         api.conv2d(
           in_channels,
           out_channels,
           kernel_size,
           stride: stride,
           padding: padding,
           dilation: dilation,
           groups: groups,
           bias: bias,
           padding_mode: padding_mode,
           device: device,
           dtype: dtype,
         ),
       );

  @override
  Tensor forward(
    List<Tensor> inputs, {
    Map<String, Tensor> kwargs = const {},
  }) => _backend.call(inputs, kwargs: kwargs);
}

@internal
abstract interface class ModuleBackend {
  void save(String path);
  void save_pt(String path, {required List<Tensor> inputs});
  Tensor call(List<Tensor> inputs, {Map<String, Tensor> kwargs = const {}});
  void register_module(String name, ModuleBackend module);
  List<Tensor> parameters();
  bool get training;
  void train(bool mode);
  void zero_grad({bool set_to_none = true});
  void dispose();
}
