import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;

import 'python.g.dart' as g;
import 'config.dart';
import 'status.dart';

class Python {
  void init() => g.Py_Initialize();
  void initFromConfig(PyConfig config) =>
      g.Py_InitializeFromConfig(config.ptr).guard();
  void dispose() => g.Py_Finalize();

  void runSimpleString(String code) => ffi.using(
    (arena) =>
        g.PyRun_SimpleString(code.toNativeUtf8(allocator: arena).cast<Char>()),
  );
}
