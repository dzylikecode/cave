import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'gc.dart';
import 'python.g.dart' as g;
import 'vm.dart';

class PyObject {
  final PyRef _ref;

  PyObject.owned(Pointer<g.PyObject> ptr) : _ref = PyRef.owned(ptr);
  PyObject.borrowed(Pointer<g.PyObject> ptr) : _ref = PyRef.borrowed(ptr);

  @internal
  Pointer<g.PyObject> get ptr => _ref.pointer;

  bool get isDisposed => _ref.isDisposed;

  void dispose() => _ref.dispose();

  /// Get the [attribute] of a Python object by name.
  ///
  /// [attribute] must exist, otherwise a [StateError] will be thrown.
  PyObject get(String attribute) => ffi.using((arena) {
    final obj = g.PyObject_GetAttrString(
      ptr,
      attribute.toNativeUtf8(allocator: arena).cast<Char>(),
    );
    if (obj == nullptr) {
      throw StateError("Attribute '$attribute' not found.");
    }
    return PyObject.owned(obj);
  });

  void set(String attribute, PyObject value) => ffi.using((arena) {
    final result = g.PyObject_SetAttrString(
      ptr,
      attribute.toNativeUtf8(allocator: arena).cast<Char>(),
      value.ptr,
    );
    if (result != 0) {
      throw StateError("Failed to set attribute '$attribute'.");
    }
  });

  bool has(String attribute) => ffi.using((arena) {
    final result = g.PyObject_HasAttrString(
      ptr,
      attribute.toNativeUtf8(allocator: arena).cast<Char>(),
    );
    return result != 0;
  });

  T cast<T extends PyObject>() =>
      switch (T) {
            == PyTuple => PyTuple.fromBorrowed(ptr),
            == PyList => PyList.fromBorrowed(ptr),
            == PyDict => PyDict.fromBorrowed(ptr),
            == PyString => PyString.fromBorrowed(ptr),
            == PyModule => PyModule.fromBorrowed(ptr),
            == PyBool => PyBool.fromBorrowed(ptr),
            == PyInt => PyInt.fromBorrowed(ptr),
            == PyDouble => PyDouble.fromBorrowed(ptr),
            _ => PyObject.borrowed(ptr),
          }
          as T;

  // bool get isString => g.PyUnicode_Check(ptr) != 0;
  bool get isTrue => g.PyObject_IsTrue(ptr) != 0;
  bool get isFalse => g.PyObject_Not(ptr) != 0;

  PyObject operator +(PyObject other) => .owned(g.PyNumber_Add(ptr, other.ptr));
  PyObject operator -() => PyObject.owned(g.PyNumber_Negative(ptr));
  PyObject operator -(PyObject other) =>
      .owned(g.PyNumber_Subtract(ptr, other.ptr));
  PyObject operator *(PyObject other) =>
      .owned(g.PyNumber_Multiply(ptr, other.ptr));
  PyObject operator /(PyObject other) =>
      .owned(g.PyNumber_TrueDivide(ptr, other.ptr));
  PyObject operator ~/(PyObject other) =>
      .owned(g.PyNumber_FloorDivide(ptr, other.ptr));
  PyObject operator %(PyObject other) =>
      .owned(g.PyNumber_Remainder(ptr, other.ptr));
  PyObject operator [](PyObject key) =>
      .owned(g.PyObject_GetItem(ptr, key.ptr));
  void operator []=(PyObject key, PyObject value) =>
      g.PyObject_SetItem(ptr, key.ptr, value.ptr);

  PyObject call(PyTuple args, [PyDict? kwargs]) => ffi.using(
    (arena) => PyObject.owned(
      g.PyObject_Call(ptr, args.ptr, kwargs == null ? nullptr : kwargs.ptr),
    ),
  );
}

/// [tuple](https://github.com/python/cpython/blob/main/Include/tupleobject.h)
class PyTuple extends PyObject {
  PyTuple.fromPointer(super.ptr) : super.owned();
  PyTuple.fromBorrowed(super.ptr) : super.borrowed();

  factory PyTuple([int size = 0]) =>
      runPython(() => .fromPointer(g.PyTuple_New(size)));
  factory PyTuple.fromList(List<PyObject> list) {
    final tuple = PyTuple(list.length);
    for (var i = 0; i < list.length; i++) {
      tuple.setItem(i, list[i]);
    }
    return tuple;
  }

  int setItem(int index, PyObject obj) =>
      g.PyTuple_SetItem(ptr, index, obj._ref.newReference());
  PyObject getItem(int index) =>
      PyObject.borrowed(g.PyTuple_GetItem(ptr, index));
  PyTuple slice(int start, int end) =>
      .fromPointer(g.PyTuple_GetSlice(ptr, start, end));
}

/// [list](https://github.com/python/cpython/blob/main/Include/listobject.h)
class PyList extends PyObject {
  PyList.fromPointer(super.ptr) : super.owned();
  PyList.fromBorrowed(super.ptr) : super.borrowed();

  factory PyList(int size) => runPython(() => .fromPointer(g.PyList_New(size)));
  factory PyList.fromList(List<PyObject> list) {
    final pyList = PyList(list.length);
    for (var i = 0; i < list.length; i++) {
      pyList.setItem(i, list[i]);
    }
    return pyList;
  }

  int get length => g.PyList_Size(ptr);

  int setItem(int index, PyObject obj) =>
      g.PyList_SetItem(ptr, index, obj._ref.newReference());
  PyObject getItem(int index) =>
      PyObject.borrowed(g.PyList_GetItem(ptr, index));
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
  PyDict.fromPointer(super.ptr) : super.owned();
  PyDict.fromBorrowed(super.ptr) : super.borrowed();

  factory PyDict() => runPython(() => .fromPointer(g.PyDict_New()));
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
  PyObject getItem(PyObject key) =>
      PyObject.borrowed(g.PyDict_GetItem(ptr, key.ptr));
  PyObject getItemWithError(PyObject key) =>
      PyObject.borrowed(g.PyDict_GetItemWithError(ptr, key.ptr));
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
      result.add((
        key: PyObject.borrowed(key.value),
        value: PyObject.borrowed(value.value),
      ));
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
    (arena) => PyObject.borrowed(
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
  PyString.fromPointer(super.ptr) : super.owned();
  PyString.fromBorrowed(super.ptr) : super.borrowed();

  factory PyString(String s) => ffi.using(
    (arena) => runPython(
      () => .fromPointer(
        g.PyUnicode_FromString(s.toNativeUtf8(allocator: arena).cast<Char>()),
      ),
    ),
  );

  String get value => runPython(() {
    final bytes = g.PyUnicode_AsUTF8String(ptr);
    if (bytes == nullptr) {
      throw StateError('Failed to convert Python string to UTF-8.');
    }
    try {
      return g.PyBytes_AsString(bytes).cast<ffi.Utf8>().toDartString();
    } finally {
      g.Py_DecRef(bytes);
    }
  });
}

/// [import](https://github.com/python/cpython/blob/main/Include/import.h)
class PyModule extends PyObject {
  PyModule.fromPointer(super.ptr) : super.owned();
  PyModule.fromBorrowed(super.ptr) : super.borrowed();

  factory PyModule(String name) {
    final pyName = PyString(name);
    try {
      return .fromPointer(runPython(() => g.PyImport_Import(pyName.ptr)));
    } finally {
      pyName.dispose();
    }
  }
}

class PyBool extends PyObject {
  PyBool.fromPointer(super.ptr) : super.owned();
  PyBool.fromBorrowed(super.ptr) : super.borrowed();

  factory PyBool(bool value) =>
      runPython(() => .fromPointer(g.PyBool_FromLong(value ? 1 : 0)));

  bool get value => isTrue;
}

class PyInt extends PyObject {
  PyInt.fromPointer(super.ptr) : super.owned();
  PyInt.fromBorrowed(super.ptr) : super.borrowed();

  factory PyInt(int value) =>
      runPython(() => .fromPointer(g.PyLong_FromLong(value)));
  int get value => g.PyLong_AsLong(ptr);
}

class PyDouble extends PyObject {
  PyDouble.fromPointer(super.ptr) : super.owned();
  PyDouble.fromBorrowed(super.ptr) : super.borrowed();

  factory PyDouble(double value) =>
      runPython(() => .fromPointer(g.PyFloat_FromDouble(value)));

  double get value => g.PyFloat_AsDouble(ptr);
}
