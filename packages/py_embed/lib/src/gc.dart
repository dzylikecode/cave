import 'dart:ffi';

import 'package:meta/meta.dart';

import 'python.g.dart' as g;
import 'vm.dart';

/// Owns exactly one reference to a Python object.
///
/// `PyRef` is internal lifecycle machinery. Public Python object classes
/// compose it so every live Dart wrapper owns an independent Python reference.
@internal
final class PyRef implements Finalizable {
  static final Finalizer<PythonReferenceState> _finalizer = Finalizer(
    pythonRuntime.releaseLater,
  );

  final PythonReferenceState _state;
  final Object _detachToken = Object();

  PyRef._(Pointer<g.PyObject> pointer)
    : _state = pythonRuntime.register(pointer) {
    _finalizer.attach(this, _state, detach: _detachToken);
  }

  /// Takes ownership of a new reference returned by the Python C API.
  factory PyRef.owned(Pointer<g.PyObject> pointer) => ._(pointer);

  /// Promotes a borrowed reference to an independently owned Dart reference.
  factory PyRef.borrowed(Pointer<g.PyObject> pointer) {
    if (pointer == nullptr) {
      throw StateError('A Python API returned a null object.');
    }
    g.Py_IncRef(pointer);
    return ._(pointer);
  }

  bool get isDisposed => _state.isDisposed;

  Pointer<g.PyObject> get pointer {
    if (isDisposed) {
      throw StateError('The Python object has already been disposed.');
    }
    return _state.pointer;
  }

  PyRef clone() => .borrowed(pointer);

  /// Creates a reference intended for an API that steals its argument.
  Pointer<g.PyObject> newReference() {
    final result = pointer;
    g.Py_IncRef(result);
    return result;
  }

  void dispose() {
    if (isDisposed) return;

    _finalizer.detach(_detachToken);
    pythonRuntime.releaseNow(_state);
  }
}
