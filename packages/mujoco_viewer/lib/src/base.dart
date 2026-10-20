// ignore_for_file: non_constant_identifier_names
import 'package:mujoco/mujoco.dart';
import 'package:meta/meta.dart';

import 'backend/python.dart';

@internal
final pythonApi = const PythonApi();

BaseApi _api = pythonApi;
@internal
BaseApi get api => _api;

@internal
abstract interface class BaseApi {
  MujocoViewer MujocoViewer_launch_passive(MjModel model, MjData data);
}

/// A passive Python viewer sharing the application's model and data.
///
/// Close the viewer before disposing its data or model. It does not advance
/// physics. Use [withLock] around model/data updates and [sync] outside the lock.
abstract interface class MujocoViewer {
  factory launch_passive(MjModel model, MjData data) =>
      api.MujocoViewer_launch_passive(model, data);

  /// Whether the window is still open.
  bool get is_running;

  /// Whether this handle has been disposed.
  bool get isDisposed;

  /// Runs a synchronous update while holding the viewer's model/data lock.
  T withLock<T>(T Function() action);

  /// Synchronizes the passive viewer with application state.
  void sync();

  /// Closes the window without disposing model or data.
  void close();

  /// Closes the window and releases the Python handle, idempotently.
  void dispose();
}
