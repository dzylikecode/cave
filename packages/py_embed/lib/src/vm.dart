import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;

import 'python.g.dart' as g;
import 'config.dart';
import 'status.dart';

class Python {
  Python();
  void init() => g.Py_Initialize();
  void initFromConfig(PyConfig config) =>
      g.Py_InitializeFromConfig(config.ptr).guard();
  void dispose() => g.Py_Finalize();

  factory Python.venv(String venvPythonExe) {
    final python = Python();
    final config = PyConfig()
      ..executable = venvPythonExe
      ..programName = venvPythonExe;
    python.initFromConfig(config);
    return python;
  }

  void runSimpleString(String code) => ffi.using(
    (arena) =>
        g.PyRun_SimpleString(code.toNativeUtf8(allocator: arena).cast<Char>()),
  );
}
