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

/// [tuple](https://github.com/python/cpython/blob/main/Include/tupleobject.h)
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
  PyDynamic getItem(int index) => PyDynamic(g.PyList_GetItem(ptr, index));
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
  PyDynamic getItem(PyObject key) => PyDynamic(g.PyDict_GetItem(ptr, key.ptr));
  PyDynamic getItemWithError(PyObject key) =>
      PyDynamic(g.PyDict_GetItemWithError(ptr, key.ptr));
  int deleteItem(PyObject key) => g.PyDict_DelItem(ptr, key.ptr);
  void clear() => g.PyDict_Clear(ptr);

  // TODO: sync*
  // 不过这个由于 ffi.using 需要谨慎处理 
  List<({PyDynamic key, PyDynamic value})> get entries => ffi.using((arena) {
    final position = arena<g.Py_ssize_t>()..value = 0;
    final key = arena<Pointer<g.PyObject>>();
    final value = arena<Pointer<g.PyObject>>();
    final result = <({PyDynamic key, PyDynamic value})>[];

    while (g.PyDict_Next(ptr, position, key, value) != 0) {
      result.add((key: PyDynamic(key.value), value: PyDynamic(value.value)));
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

  PyDynamic getItemString(String key) => ffi.using(
    (arena) => PyDynamic(
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

class PyDynamic extends PyObject {
  PyDynamic(super.ptr);
}

/// [unicode](https://github.com/python/cpython/blob/main/Include/unicodeobject.h)
class PyString extends PyObject {
  PyString.fromPointer(super.ptr);

  factory PyString(String s) => ffi.using(
    (arena) => .fromPointer(
      g.PyUnicode_FromString(s.toNativeUtf8(allocator: arena).cast<Char>()),
    ),
  );
}

/// [import](https://github.com/python/cpython/blob/main/Include/import.h)
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
