import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'python.g.dart' as g;

class PyObject {
  @internal
  Pointer<g.PyObject> ptr;

  PyObject._(this.ptr);
  void dispose() => g.Py_DecRef(ptr);

  factory PyObject.string(String s) => ffi.using(
    (arena) => ._(
      g.PyUnicode_FromString(s.toNativeUtf8(allocator: arena).cast<Char>()),
    ),
  );

  factory PyObject.import(String s) => ffi.using(
    (arena) => ._(
      g.PyImport_Import(
        g.PyUnicode_FromString(s.toNativeUtf8(allocator: arena).cast<Char>()),
      ),
    ),
  );
}
