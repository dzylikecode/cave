import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'python.g.dart' as g;

class PyObject {
  @internal
  Pointer<g.PyObject> ptr;

  PyObject.fromPointer(this.ptr);
  void dispose() => g.Py_DecRef(ptr);

  factory PyObject.string(String s) => ffi.using(
    (arena) => .fromPointer(
      g.PyUnicode_FromString(s.toNativeUtf8(allocator: arena).cast<Char>()),
    ),
  );

  factory PyObject.import(String s) => ffi.using(
    (arena) => .fromPointer(g.PyImport_Import(PyObject.string(s).ptr)),
  );

  factory PyObject.get(PyObject obj, String attr) => ffi.using(
    (arena) => .fromPointer(
      g.PyObject_GetAttrString(
        obj.ptr,
        attr.toNativeUtf8(allocator: arena).cast<Char>(),
      ),
    ),
  );

  // bool get isString => g.PyUnicode_Check(ptr) != 0;
}

class PyTuple extends PyObject {
  PyTuple.fromPointer(super.ptr) : super.fromPointer();

  factory PyTuple(int size) =>
      ffi.using((arena) => .fromPointer(g.PyTuple_New(size)));
  factory PyTuple.fromList(List<PyObject> list) {
    final tuple = PyTuple(list.length);
    for (var i = 0; i < list.length; i++) {
      tuple.setItem(i, list[i]);
    }
    return tuple;
  }

  int setItem(int index, PyObject obj) =>
      g.PyTuple_SetItem(ptr, index, obj.ptr);
  PyObject getItem(int index) => .fromPointer(g.PyTuple_GetItem(ptr, index));
  PyObject slice(int start, int end) =>
      .fromPointer(g.PyTuple_GetSlice(ptr, start, end));
}


class PyDynamic extends PyObject {
  PyDynamic.fromPointer(super.ptr) : super.fromPointer();

  PyObject call(PyTuple args) =>
      .fromPointer(g.PyObject_CallObject(ptr, args.ptr));
}
