import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'python.g.dart' as g;

class PyObject {
  @internal
  Pointer<g.PyObject> ptr;

  PyObject(this.ptr);
  void dispose() => g.Py_DecRef(ptr);

  PyObject get(String attr) => ffi.using(
    (arena) => PyObject(
      g.PyObject_GetAttrString(
        ptr,
        attr.toNativeUtf8(allocator: arena).cast<Char>(),
      ),
    ),
  );

  T cast<T extends PyObject>() =>
      switch (T) {
            == PyTuple => PyTuple.fromPointer(ptr),
            == PyList => PyList.fromPointer(ptr),
            == PyDict => PyDict.fromPointer(ptr),
            == PyString => PyString.fromPointer(ptr),
            == PyModule => PyModule.fromPointer(ptr),
            == PyBool => PyBool.fromPointer(ptr),
            == PyInt => PyInt.fromPointer(ptr),
            == PyDouble => PyDouble.fromPointer(ptr),
            _ => this,
          }
          as T;

  // bool get isString => g.PyUnicode_Check(ptr) != 0;
  bool get isTrue => g.PyObject_IsTrue(ptr) != 0;
  bool get isFalse => g.PyObject_Not(ptr) != 0;

  PyObject operator +(PyObject other) =>
      PyObject(g.PyNumber_Add(ptr, other.ptr));
  PyObject operator -() => PyObject(g.PyNumber_Negative(ptr));
  PyObject operator -(PyObject other) =>
      PyObject(g.PyNumber_Subtract(ptr, other.ptr));
  PyObject operator *(PyObject other) =>
      PyObject(g.PyNumber_Multiply(ptr, other.ptr));
  PyObject operator /(PyObject other) =>
      PyObject(g.PyNumber_TrueDivide(ptr, other.ptr));
  PyObject operator ~/(PyObject other) =>
      PyObject(g.PyNumber_FloorDivide(ptr, other.ptr));
  PyObject operator %(PyObject other) =>
      PyObject(g.PyNumber_Remainder(ptr, other.ptr));

  PyObject call(PyTuple args, [PyDict? kwargs]) => ffi.using(
    (arena) => PyObject(
      g.PyObject_Call(ptr, args.ptr, kwargs == null ? nullptr : kwargs.ptr),
    ),
  );
}

/// [tuple](https://github.com/python/cpython/blob/main/Include/tupleobject.h)
class PyTuple extends PyObject {
  PyTuple.fromPointer(super.ptr);

  factory PyTuple([int size = 0]) =>
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
  PyObject getItem(int index) => PyObject(g.PyTuple_GetItem(ptr, index));
  PyTuple slice(int start, int end) =>
      .fromPointer(g.PyTuple_GetSlice(ptr, start, end));
}

/// [list](https://github.com/python/cpython/blob/main/Include/listobject.h)
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

  int get length => g.PyList_Size(ptr);

  int setItem(int index, PyObject obj) => g.PyList_SetItem(ptr, index, obj.ptr);
  PyObject getItem(int index) => PyObject(g.PyList_GetItem(ptr, index));
  int insert(int index, PyObject obj) => g.PyList_Insert(ptr, index, obj.ptr);
  int append(PyObject obj) => g.PyList_Append(ptr, obj.ptr);
  PyList slice(int start, int end) =>
      PyList.fromPointer(g.PyList_GetSlice(ptr, start, end));
  int setSlice(int start, int end, PyList items) =>
      g.PyList_SetSlice(ptr, start, end, items.ptr);
  int deleteSlice(int start, int end) =>
      g.PyList_SetSlice(ptr, start, end, nullptr);
  int sort() => g.PyList_Sort(ptr);
  int reverse() => g.PyList_Reverse(ptr);
  PyTuple asTuple() => .fromPointer(g.PyList_AsTuple(ptr));
}

/// [dict](https://github.com/python/cpython/blob/main/Include/dictobject.h)
class PyDict extends PyObject {
  PyDict.fromPointer(super.ptr);

  factory PyDict() => .fromPointer(g.PyDict_New());
  factory PyDict.fromMap(Map<PyObject, PyObject> map) {
    final dict = PyDict();
    for (final MapEntry(:key, :value) in map.entries) {
      dict.setItem(key, value);
    }
    return dict;
  }

  int get length => g.PyDict_Size(ptr);

  int setItem(PyObject key, PyObject value) =>
      g.PyDict_SetItem(ptr, key.ptr, value.ptr);
  PyObject getItem(PyObject key) => PyObject(g.PyDict_GetItem(ptr, key.ptr));
  PyObject getItemWithError(PyObject key) =>
      PyObject(g.PyDict_GetItemWithError(ptr, key.ptr));
  int deleteItem(PyObject key) => g.PyDict_DelItem(ptr, key.ptr);
  void clear() => g.PyDict_Clear(ptr);

  // TODO: sync*
  // 不过这个由于 ffi.using 需要谨慎处理
  List<({PyObject key, PyObject value})> get entries => ffi.using((arena) {
    final position = arena<g.Py_ssize_t>()..value = 0;
    final key = arena<Pointer<g.PyObject>>();
    final value = arena<Pointer<g.PyObject>>();
    final result = <({PyObject key, PyObject value})>[];

    while (g.PyDict_Next(ptr, position, key, value) != 0) {
      result.add((key: PyObject(key.value), value: PyObject(value.value)));
    }
    return result;
  });

  PyList keys() => .fromPointer(g.PyDict_Keys(ptr));
  PyList values() => .fromPointer(g.PyDict_Values(ptr));
  PyList items() => .fromPointer(g.PyDict_Items(ptr));
  PyDict copy() => .fromPointer(g.PyDict_Copy(ptr));
  int contains(PyObject key) => g.PyDict_Contains(ptr, key.ptr);
  int update(PyObject other) => g.PyDict_Update(ptr, other.ptr);
  int merge(PyObject other, {bool override = true}) =>
      g.PyDict_Merge(ptr, other.ptr, override ? 1 : 0);
  int mergeFromSequence(PyObject sequence, {bool override = true}) =>
      g.PyDict_MergeFromSeq2(ptr, sequence.ptr, override ? 1 : 0);

  PyObject getItemString(String key) => ffi.using(
    (arena) => PyObject(
      g.PyDict_GetItemString(
        ptr,
        key.toNativeUtf8(allocator: arena).cast<Char>(),
      ),
    ),
  );
  int setItemString(String key, PyObject value) => ffi.using(
    (arena) => g.PyDict_SetItemString(
      ptr,
      key.toNativeUtf8(allocator: arena).cast<Char>(),
      value.ptr,
    ),
  );
  int deleteItemString(String key) => ffi.using(
    (arena) => g.PyDict_DelItemString(
      ptr,
      key.toNativeUtf8(allocator: arena).cast<Char>(),
    ),
  );
}

/// [unicode](https://github.com/python/cpython/blob/main/Include/unicodeobject.h)
class PyString extends PyObject {
  PyString.fromPointer(super.ptr);

  factory PyString(String s) => ffi.using(
    (arena) => .fromPointer(
      g.PyUnicode_FromString(s.toNativeUtf8(allocator: arena).cast<Char>()),
    ),
  );

  String get value => ffi.using((arena) {
    final bytes = g.PyUnicode_AsUTF8String(ptr);
    return g.PyBytes_AsString(bytes).cast<ffi.Utf8>().toDartString();
  });
}

/// [import](https://github.com/python/cpython/blob/main/Include/import.h)
class PyModule extends PyObject {
  PyModule.fromPointer(super.ptr);

  factory PyModule(String name) =>
      ffi.using((arena) => .fromPointer(g.PyImport_Import(PyString(name).ptr)));
}

class PyBool extends PyObject {
  PyBool.fromPointer(super.ptr);

  factory PyBool(bool value) => .fromPointer(g.PyBool_FromLong(value ? 1 : 0));

  bool get value => isTrue;
}

class PyInt extends PyObject {
  PyInt.fromPointer(super.ptr);

  factory PyInt(int value) => .fromPointer(g.PyLong_FromLong(value));
  int get value => g.PyLong_AsLong(ptr);
}

class PyDouble extends PyObject {
  PyDouble.fromPointer(super.ptr);

  factory PyDouble(double value) => .fromPointer(g.PyFloat_FromDouble(value));

  double get value => g.PyFloat_AsDouble(ptr);
}
