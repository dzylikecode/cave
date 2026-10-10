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
Tensor zeros(List<int> shape, {DType? dtype, Device? device}) =>
    api.zeros(shape, dtype: dtype, device: device);

Tensor arange(
  num end, {
  num start = 0,
  num step = 1,
  DType? dtype,
  Device? device,
  bool requiresGrad = false,
}) => api.arange(
  end,
  start: start,
  step: step,
  dtype: dtype,
  device: device,
  requiresGrad: requiresGrad,
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
  String get version;
  T inference_mode<T>(T Function() action);
  ScriptModule jit_load(String path, {Device? map_location});
  Tensor zeros(List<int> shape, {DType? dtype, Device? device});

  Tensor arange(
    num end, {
    num start = 0,
    num step = 1,
    DType? dtype,
    Device? device,
    bool requiresGrad = false,
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
  complex128,
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
abstract interface class Tensor {
  List<int> get shape;
  DType get dtype;
  Device get device;

  Tensor reshape(List<int> shape);

  /// Releases this tensor's resources. Do not use the tensor afterward.
  void dispose();
}
