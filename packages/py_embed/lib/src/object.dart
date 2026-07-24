import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'python.g.dart' as g;

sealed class PyObject {
  @internal
  Pointer<g.PyObject> ptr;

  PyObject(this.ptr);
  void dispose() => g.Py_DecRef(ptr);

  PyDynamic get(String attr) => ffi.using(
    (arena) => PyDynamic(
      g.PyObject_GetAttrString(
        ptr,
        attr.toNativeUtf8(allocator: arena).cast<Char>(),
      ),
    ),
  );

  // bool get isString => g.PyUnicode_Check(ptr) != 0;
}

class PyTuple extends PyObject {
  PyTuple.fromPointer(super.ptr);

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
  PyDynamic getItem(int index) => PyDynamic(g.PyTuple_GetItem(ptr, index));
  PyDynamic slice(int start, int end) =>
      PyDynamic(g.PyTuple_GetSlice(ptr, start, end));
}

class PyList extends PyObject {
  PyList.fromPointer(super.ptr);

  factory PyList(int size) =>
      ffi.using((arena) => .fromPointer(g.PyList_New(size)));
  factory PyList.fromList(List<PyObject> list) {
    final pyList = PyList(list.length);
    for (var i = 0; i < list.length; i++) {
      pyList.setItem(i, list[i]);
    }
    return pyList;
  }

  int setItem(int index, PyObject obj) => g.PyList_SetItem(ptr, index, obj.ptr);
  PyDynamic getItem(int index) => PyDynamic(g.PyList_GetItem(ptr, index));
  int append(PyObject obj) => g.PyList_Append(ptr, obj.ptr);
}

class PyDynamic extends PyObject {
  PyDynamic(super.ptr);
}

class PyString extends PyObject {
  PyString.fromPointer(super.ptr);

  factory PyString(String s) => ffi.using(
    (arena) => .fromPointer(
      g.PyUnicode_FromString(s.toNativeUtf8(allocator: arena).cast<Char>()),
    ),
  );
}

class PyModule extends PyObject {
  PyModule.fromPointer(super.ptr);

  factory PyModule(String name) =>
      ffi.using((arena) => .fromPointer(g.PyImport_Import(PyString(name).ptr)));
}

class PyFunction extends PyObject {
  PyFunction(super.ptr);

  PyDynamic call(List<PyObject> args) => ffi.using(
    (arena) =>
        PyDynamic(g.PyObject_CallObject(ptr, PyTuple.fromList(args).ptr)),
  );
}
