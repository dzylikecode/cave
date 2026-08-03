import 'package:mujoco/mujoco.dart';
// ignore: implementation_imports
import 'package:mujoco/src/backend/python/backend.dart';
import 'package:py_embed/py_embed.dart';

final PyModule _viewerModule = PyModule('mujoco.viewer');
final PyObject _launchPassive = _viewerModule.get('launch_passive');

/// A non-blocking interactive MuJoCo viewer.
///
/// The simulation remains controlled by Dart. Call [sync] after advancing or
/// modifying [data] so the window receives the latest state.
final class MujocoViewer {
  final MjModel model;
  final MjData data;
  PyObject? _handle;
  PyObject? _isRunningCallable;
  PyObject? _syncCallable;
  PyObject? _closeCallable;

  MujocoViewer._(this.model, this.data, this._handle);

  /// Opens a passive viewer for [model] and [data].
  ///
  /// The current implementation requires the Python MuJoCo backend.
  factory MujocoViewer.launchPassive(MjModel model, MjData data) {
    final pythonModel = _requirePythonModel(model);
    final pythonData = _requirePythonData(data);
    if (!identical(pythonData.model, pythonModel)) {
      throw ArgumentError('MjData was created from a different MjModel.');
    }

    return ._(
      model,
      data,
      _launchPassive.call2(pythonModel.object, pythonData.object),
    );
  }

  /// Whether the viewer window is still open.
  bool get isRunning {
    final handle = _handle;
    if (handle == null) return false;

    final callable = _isRunningCallable ??= handle.get('is_running');
    final result = callable.call0();
    try {
      return result.toBool();
    } finally {
      result.dispose();
    }
  }

  /// Synchronizes the viewer with the current model and simulation state.
  void sync() {
    final handle = _requireHandle();
    final callable = _syncCallable ??= handle.get('sync');
    final result = callable.call0();
    result.dispose();
  }

  /// Closes the window and releases the Python viewer handle.
  ///
  /// Calling this method more than once has no effect.
  void dispose() {
    final handle = _handle;
    if (handle == null) return;
    _handle = null;

    try {
      final callable = _closeCallable ??= handle.get('close');
      final result = callable.call0();
      result.dispose();
    } finally {
      _isRunningCallable?.dispose();
      _syncCallable?.dispose();
      _closeCallable?.dispose();
      _isRunningCallable = null;
      _syncCallable = null;
      _closeCallable = null;
      handle.dispose();
    }
  }

  PyObject _requireHandle() {
    final handle = _handle;
    if (handle == null) {
      throw StateError('The MuJoCo viewer has already been disposed.');
    }
    return handle;
  }
}

MjModelPython _requirePythonModel(MjModel model) {
  if (model is! MjModelPython) {
    throw StateError('mujoco_viewer requires the Python MuJoCo backend.');
  }
  return model;
}

MjDataPython _requirePythonData(MjData data) {
  if (data is! MjDataPython) {
    throw StateError('mujoco_viewer requires the Python MuJoCo backend.');
  }
  return data;
}
