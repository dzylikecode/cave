import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'exception.dart';
import 'gc.dart';
import 'python.g.dart' as g;
import 'vm.dart';

class PyObject {
  final PyRef _ref;

  PyObject.owned(Pointer<g.PyObject> ptr) : _ref = .owned(ptr);
  PyObject.borrowed(Pointer<g.PyObject> ptr) : _ref = .borrowed(ptr);

  @internal
  Pointer<g.PyObject> get ptr => _ref.pointer;

  bool get isDisposed => _ref.isDisposed;

  void dispose() => _ref.dispose();

  /// Get the [attribute] of a Python object by name.
  ///
  /// [attribute] must exist, otherwise a [StateError] will be thrown.
  PyObject get(String attribute) => runPython(
    () => ffi.using((arena) {
      final obj = g.PyObject_GetAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
      );
      if (obj == nullptr) {
        throwPythonException(context: "getting attribute '$attribute'");
      }
      return .owned(obj);
    }),
  );

  void set(String attribute, PyObject value) => runPython(
    () => ffi.using((arena) {
      final result = g.PyObject_SetAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
        value.ptr,
      );
      if (result != 0) {
        throwPythonException(context: "setting attribute '$attribute'");
      }
    }),
  );

  bool has(String attribute) => runPython(
    () => ffi.using((arena) {
      final result = g.PyObject_HasAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
      );
      return result != 0;
    }),
  );

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
  bool get isTrue => runPython(() => g.PyObject_IsTrue(ptr) != 0);
  bool get isFalse => runPython(() => g.PyObject_Not(ptr) != 0);

  PyObject operator +(PyObject other) =>
      runPython(() => .owned(g.PyNumber_Add(ptr, other.ptr)));
  PyObject operator -() => runPython(() => .owned(g.PyNumber_Negative(ptr)));
  PyObject operator -(PyObject other) =>
      runPython(() => .owned(g.PyNumber_Subtract(ptr, other.ptr)));
  PyObject operator *(PyObject other) =>
      runPython(() => .owned(g.PyNumber_Multiply(ptr, other.ptr)));
  PyObject operator /(PyObject other) =>
      runPython(() => .owned(g.PyNumber_TrueDivide(ptr, other.ptr)));
  PyObject operator ~/(PyObject other) =>
      runPython(() => .owned(g.PyNumber_FloorDivide(ptr, other.ptr)));
  PyObject operator %(PyObject other) =>
      runPython(() => .owned(g.PyNumber_Remainder(ptr, other.ptr)));
  PyObject operator [](PyObject key) =>
      runPython(() => .owned(g.PyObject_GetItem(ptr, key.ptr)));
  void operator []=(PyObject key, PyObject value) =>
      runPython(() => g.PyObject_SetItem(ptr, key.ptr, value.ptr));

  PyObject call(PyTuple args, [PyDict? kwargs]) => runPython(
    () => .owned(
      g.PyObject_Call(ptr, args.ptr, kwargs == null ? nullptr : kwargs.ptr),
    ),
  );

  PyObject call0() =>
      runPython(() => .owned(g.PyObject_CallObject(ptr, nullptr)));

  PyObject call1(PyObject arg) {
    final arguments = PyTuple.fromList([arg]);
    try {
      return call(arguments);
    } finally {
      arguments.dispose();
    }
  }

  PyObject call2(PyObject first, PyObject second) {
    final arguments = PyTuple.fromList([first, second]);
    try {
      return call(arguments);
    } finally {
      arguments.dispose();
    }
  }

  PyObject callArgs(List<PyObject> args, [Map<String, PyObject>? kwargs]) {
    final arguments = PyTuple.fromList(args);
    final keywordArguments = kwargs == null
        ? null
        : PyDict.fromMap(kwargs.map((key, value) => MapEntry(PyString(key), value)));
    try {
      return call(arguments, keywordArguments);
    } finally {
      arguments.dispose();
      keywordArguments?.dispose();
    }
  }
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
      runPython(() => g.PyTuple_SetItem(ptr, index, obj._ref.newReference()));
  PyObject getItem(int index) =>
      runPython(() => .borrowed(g.PyTuple_GetItem(ptr, index)));
  PyTuple slice(int start, int end) =>
      runPython(() => .fromPointer(g.PyTuple_GetSlice(ptr, start, end)));
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

  int get length => runPython(() => g.PyList_Size(ptr));

  int setItem(int index, PyObject obj) =>
      runPython(() => g.PyList_SetItem(ptr, index, obj._ref.newReference()));
  PyObject getItem(int index) =>
      runPython(() => .borrowed(g.PyList_GetItem(ptr, index)));
  int insert(int index, PyObject obj) =>
      runPython(() => g.PyList_Insert(ptr, index, obj.ptr));
  int append(PyObject obj) => runPython(() => g.PyList_Append(ptr, obj.ptr));
  PyList slice(int start, int end) =>
      runPython(() => .fromPointer(g.PyList_GetSlice(ptr, start, end)));
  int setSlice(int start, int end, PyList items) =>
      runPython(() => g.PyList_SetSlice(ptr, start, end, items.ptr));
  int deleteSlice(int start, int end) =>
      runPython(() => g.PyList_SetSlice(ptr, start, end, nullptr));
  int sort() => runPython(() => g.PyList_Sort(ptr));
  int reverse() => runPython(() => g.PyList_Reverse(ptr));
  PyTuple asTuple() => runPython(() => .fromPointer(g.PyList_AsTuple(ptr)));
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

  int get length => runPython(() => g.PyDict_Size(ptr));

  int setItem(PyObject key, PyObject value) =>
      runPython(() => g.PyDict_SetItem(ptr, key.ptr, value.ptr));
  PyObject getItem(PyObject key) =>
      runPython(() => .borrowed(g.PyDict_GetItem(ptr, key.ptr)));
  PyObject getItemWithError(PyObject key) =>
      runPython(() => .borrowed(g.PyDict_GetItemWithError(ptr, key.ptr)));
  int deleteItem(PyObject key) =>
      runPython(() => g.PyDict_DelItem(ptr, key.ptr));
  void clear() => runPython(() => g.PyDict_Clear(ptr));

  // TODO: sync*
  // 不过这个由于 ffi.using 需要谨慎处理
  List<({PyObject key, PyObject value})> get entries => runPython(
    () => ffi.using((arena) {
      final position = arena<g.Py_ssize_t>()..value = 0;
      final key = arena<Pointer<g.PyObject>>();
      final value = arena<Pointer<g.PyObject>>();
      final result = <({PyObject key, PyObject value})>[];

      while (g.PyDict_Next(ptr, position, key, value) != 0) {
        result.add((key: .borrowed(key.value), value: .borrowed(value.value)));
      }
      return result;
    }),
  );

  PyList keys() => runPython(() => .fromPointer(g.PyDict_Keys(ptr)));
  PyList values() => runPython(() => .fromPointer(g.PyDict_Values(ptr)));
  PyList items() => runPython(() => .fromPointer(g.PyDict_Items(ptr)));
  PyDict copy() => runPython(() => .fromPointer(g.PyDict_Copy(ptr)));
  int contains(PyObject key) =>
      runPython(() => g.PyDict_Contains(ptr, key.ptr));
  int update(PyObject other) =>
      runPython(() => g.PyDict_Update(ptr, other.ptr));
  int merge(PyObject other, {bool override = true}) =>
      runPython(() => g.PyDict_Merge(ptr, other.ptr, override ? 1 : 0));
  int mergeFromSequence(PyObject sequence, {bool override = true}) => runPython(
    () => g.PyDict_MergeFromSeq2(ptr, sequence.ptr, override ? 1 : 0),
  );

  PyObject getItemString(String key) => runPython(
    () => ffi.using(
      (arena) => .borrowed(
        g.PyDict_GetItemString(
          ptr,
          key.toNativeUtf8(allocator: arena).cast<Char>(),
        ),
      ),
    ),
  );
  int setItemString(String key, PyObject value) => runPython(
    () => ffi.using(
      (arena) => g.PyDict_SetItemString(
        ptr,
        key.toNativeUtf8(allocator: arena).cast<Char>(),
        value.ptr,
      ),
    ),
  );
  int deleteItemString(String key) => runPython(
    () => ffi.using(
      (arena) => g.PyDict_DelItemString(
        ptr,
        key.toNativeUtf8(allocator: arena).cast<Char>(),
      ),
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
      throwPythonException(context: 'converting a Python string to UTF-8');
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
  int get value => runPython(() => g.PyLong_AsLong(ptr));
}

class PyDouble extends PyObject {
  PyDouble.fromPointer(super.ptr) : super.owned();
  PyDouble.fromBorrowed(super.ptr) : super.borrowed();

  factory PyDouble(double value) =>
      runPython(() => .fromPointer(g.PyFloat_FromDouble(value)));

  double get value => runPython(() => g.PyFloat_AsDouble(ptr));
}
