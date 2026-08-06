import 'dart:collection';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'config.dart';
import 'dylib_loader.dart';
import 'exception.dart';
import 'python.g.dart' as g;
import 'status.dart';
import 'venv.dart';

/// Optional configuration and lifecycle controls for the embedded interpreter.
///
/// Python is initialized lazily by the first Python API call. Call [configure]
/// before that first call when a non-default interpreter is required.
abstract final class Python {
  static bool get isInitialized => pythonRuntime.isInitialized;

  static void configure({String? executable}) =>
      pythonRuntime.configure(executable: executable);

  static void configureVenv(String executable) =>
      configure(executable: executable);

  static void runSimpleString(String code) => runPython(
    () => ffi.using(
      (arena) => g.PyRun_SimpleString(
        code.toNativeUtf8(allocator: arena).cast<Char>(),
      ),
    ),
  );

  /// Deterministically releases all Dart-owned Python references and finalizes
  /// the interpreter.
  ///
  /// A finalized runtime cannot currently be initialized again.
  static void shutdown() => pythonRuntime.shutdown();
}

enum _PythonRuntimeState { idle, configured, running, shuttingDown, closed }

/// The state associated with one Dart-owned Python reference.
///
/// This is separate from `PyRef` so the runtime can track native references
/// without keeping their Dart wrappers alive.
@internal
final class PythonReferenceState {
  Pointer<g.PyObject> pointer;
  bool queued = false;

  PythonReferenceState(this.pointer);

  bool get isDisposed => pointer == nullptr;
}

@internal
final pythonRuntime = PythonRuntime._();

@internal
T runPython<T>(T Function() operation) => pythonRuntime.execute(operation);

@internal
final class PythonRuntime {
  _PythonRuntimeState _state = .idle;
  String? _executable;
  int _executionDepth = 0;

  final Set<PythonReferenceState> _references = {};
  final Queue<PythonReferenceState> _pendingReleases = Queue();

  PythonRuntime._();

  bool get isInitialized => _state == .running;

  void configure({String? executable}) {
    switch (_state) {
      case .idle:
      case .configured:
        _executable = executable;
        _state = .configured;
      case .running:
        throw StateError(
          'Python has already been initialized. Configure it before the '
          'first Python API call.',
        );
      case .shuttingDown:
      case .closed:
        throw StateError('Python is shutting down or has been shut down.');
    }
  }

  void ensureInitialized() {
    switch (_state) {
      case .idle:
        _initializeFromExecutable(_resolveDefaultExecutable());
        _state = .running;
      case .configured:
        _initializeFromExecutable(_executable ?? _resolveDefaultExecutable());
        _state = .running;
      case .running:
        return;
      case .shuttingDown:
        throw StateError('Python is shutting down.');
      case .closed:
        throw StateError('Python has already been shut down.');
    }
  }

  String _resolveDefaultExecutable() {
    final virtualEnvironment = Platform.environment['VIRTUAL_ENV'];
    if (virtualEnvironment != null && virtualEnvironment.isNotEmpty) {
      return Platform.isWindows
          ? '$virtualEnvironment\\Scripts\\python.exe'
          : '$virtualEnvironment/bin/python';
    }

    try {
      return getPyExecutableFromShellSync();
    } on ProcessException catch (error) {
      throw StateError(
        'No default Python environment could be resolved. Activate a Python '
        'virtual environment or call Python.configure(executable: ...) before '
        'the first Python API call.\n$error',
      );
    }
  }

  void _initializeFromExecutable(String executable) {
    final libraryPath = getPyLibraryFromShellSync(executable);
    loadHostDynamicLibrary(libraryPath);
    final config = PyConfig()
      ..executable = executable
      ..programName = executable;
    try {
      g.Py_InitializeFromConfig(config.ptr).guard();
    } finally {
      config.dispose();
    }
  }

  T execute<T>(T Function() operation) {
    ensureInitialized();

    final isOutermostCall = _executionDepth == 0;
    if (isOutermostCall) {
      // This is the future boundary for acquiring the GIL.
      _drainPendingReleases();
    }

    _executionDepth++;
    try {
      final result = operation();
      checkPythonError();
      return result;
    } finally {
      _executionDepth--;
      if (isOutermostCall) {
        // This is the future boundary for releasing the GIL.
      }
    }
  }

  PythonReferenceState register(Pointer<g.PyObject> pointer) {
    if (pointer == nullptr) {
      throwPythonException(context: 'creating a Dart Python object');
    }
    if (_state != .running) {
      throw StateError('Python is not running.');
    }

    final state = PythonReferenceState(pointer);
    _references.add(state);
    return state;
  }

  void releaseNow(PythonReferenceState state) {
    if (state.isDisposed) return;
    if (_state != .running) {
      throw StateError('Cannot release a Python object after shutdown.');
    }

    _references.remove(state);
    _release(state);
  }

  /// Called by a Dart finalizer. It deliberately does not call Python.
  void releaseLater(PythonReferenceState state) {
    if (state.isDisposed || state.queued) return;

    state.queued = true;
    _pendingReleases.add(state);
  }

  void _drainPendingReleases() {
    while (_pendingReleases.isNotEmpty) {
      final state = _pendingReleases.removeFirst();
      state.queued = false;
      if (state.isDisposed) continue;

      _references.remove(state);
      _release(state);
    }
  }

  void _release(PythonReferenceState state) {
    final pointer = state.pointer;
    if (pointer == nullptr) return;

    state.pointer = nullptr;
    state.queued = false;
    g.Py_DecRef(pointer);
  }

  void shutdown() {
    if (_state == .idle || _state == .configured) {
      _state = .closed;
      return;
    }
    if (_state == .closed || _state == .shuttingDown) return;
    if (_executionDepth != 0) {
      throw StateError(
        'Python cannot be shut down during an active Python API call.',
      );
    }

    _state = .shuttingDown;

    _drainPendingReleases();
    for (final state in _references.toList(growable: false)) {
      _references.remove(state);
      _release(state);
    }

    g.Py_Finalize();
    _state = .closed;
  }
}
