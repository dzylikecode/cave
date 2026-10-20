// ignore_for_file: non_constant_identifier_names
import 'package:py_embed/py_embed.dart';
import 'package:mujoco/python.dart';

import '../base.dart';

final class const PythonApi() implements BaseApi {
  @override
  MujocoViewerPython MujocoViewer_launch_passive(
    covariant MjModelPython model,
    covariant MjDataPython data,
  ) {
    if (model.isDisposed || data.isDisposed) {
      throw StateError('Model or data is disposed');
    }
    if (!identical(data.model, model)) {
      throw ArgumentError('Data belongs to another model');
    }
    final handle = ResourceScope.unmanaged(
      () => ResourceScope.returning(() {
        final module = PyModule('mujoco.viewer');
        return module.getAttr('launch_passive').forward([model, data]);
      }),
    );
    return .new(handle, model, data);
  }
}

class MujocoViewerPython(
  final PyObject handle,
  final MjModelPython model,
  final MjDataPython data,
) implements MujocoViewer {
  bool _closed = false;
  bool _disposed = false;
  @override
  bool get isDisposed => _disposed;
  void _ensureAlive() {
    if (isDisposed || _closed) throw StateError('Viewer is closed');
    if (model.isDisposed || data.isDisposed) {
      throw StateError('Model or data is disposed');
    }
  }

  @override
  bool get is_running {
    if (isDisposed || _closed) return false;
    _ensureAlive();
    return ResourceScope.scope(
      () => handle.getAttr('is_running').call0().asBool(),
    );
  }

  @override
  T withLock<T>(T Function() action) {
    _ensureAlive();
    final lock = ResourceScope.unmanaged(
      () => ResourceScope.returning(() => handle.getAttr('lock').call0()),
    );
    try {
      ResourceScope.scope(() => lock.getAttr('__enter__').call0());
      try {
        final result = action();
        if (result is Future) {
          throw ArgumentError('Viewer updates must be synchronous');
        }
        return result;
      } finally {
        ResourceScope.scope(
          () => lock.getAttr('__exit__').forward([null, null, null]),
        );
      }
    } finally {
      lock.dispose();
    }
  }

  @override
  void sync() {
    _ensureAlive();
    ResourceScope.scope(() => handle.getAttr('sync').call0());
  }

  @override
  void close() {
    if (isDisposed || _closed) return;
    ResourceScope.scope(() => handle.getAttr('close').call0());
    _closed = true;
  }

  @override
  void dispose() {
    if (isDisposed) return;
    close();
    handle.dispose();
    _disposed = true;
  }
}
