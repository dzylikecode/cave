import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'exception.dart';
import 'gc.dart';
import 'python.g.dart' as g;
import 'vm.dart';
import 'dylib_loader.dart';

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
      final obj = api.PyObject_GetAttrString(
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
      final result = api.PyObject_SetAttrString(
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
      final result = api.PyObject_HasAttrString(
        ptr,
        attribute.toNativeUtf8(allocator: arena).cast<Char>(),
      );
      return result != 0;
    }),
  );

  int getInt(String attribute) {
    final obj = get(attribute);
    try {
      return obj.toInt();
    } finally {
      obj.dispose();
    }
  }

  double getDouble(String attribute) {
    final obj = get(attribute);
    try {
      return obj.toDouble();
    } finally {
      obj.dispose();
    }
  }

  String getString(String attribute) {
    final obj = get(attribute);
    try {
      return obj.toDartString();
    } finally {
      obj.dispose();
    }
  }

  bool getBool(String attribute) {
    final obj = get(attribute);
    try {
      return obj.toBool();
    } finally {
      obj.dispose();
    }
  }

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
  bool get isTrue => runPython(() => api.PyObject_IsTrue(ptr) != 0);
  bool get isFalse => runPython(() => api.PyObject_Not(ptr) != 0);

  int toInt() => runPython(() => api.PyLong_AsLong(ptr));
  double toDouble() => runPython(() => api.PyFloat_AsDouble(ptr));
  bool toBool() => runPython(() => api.PyObject_IsTrue(ptr) != 0);

  /// Returns Python's `str(self)` for any Python object.
  String get str => runPython(() => objectToDartString(ptr));

  /// Converts this object to Dart text when it is already a Python `str`.
  String toDartString() => runPython(() {
    final bytes = api.PyUnicode_AsUTF8String(ptr);
    if (bytes == nullptr) {
      throwPythonException(context: 'converting a Python string to UTF-8');
    }
    try {
      return api.PyBytes_AsString(bytes).cast<ffi.Utf8>().toDartString();
    } finally {
      api.Py_DecRef(bytes);
    }
  });

  PyObject operator +(PyObject other) =>
      runPython(() => .owned(api.PyNumber_Add(ptr, other.ptr)));
  PyObject operator -() => runPython(() => .owned(api.PyNumber_Negative(ptr)));
  PyObject operator -(PyObject other) =>
      runPython(() => .owned(api.PyNumber_Subtract(ptr, other.ptr)));
  PyObject operator *(PyObject other) =>
      runPython(() => .owned(api.PyNumber_Multiply(ptr, other.ptr)));
  PyObject operator /(PyObject other) =>
      runPython(() => .owned(api.PyNumber_TrueDivide(ptr, other.ptr)));
  PyObject operator ~/(PyObject other) =>
      runPython(() => .owned(api.PyNumber_FloorDivide(ptr, other.ptr)));
  PyObject operator %(PyObject other) =>
      runPython(() => .owned(api.PyNumber_Remainder(ptr, other.ptr)));
  PyObject operator [](PyObject key) =>
      runPython(() => .owned(api.PyObject_GetItem(ptr, key.ptr)));
  void operator []=(PyObject key, PyObject value) =>
      runPython(() => api.PyObject_SetItem(ptr, key.ptr, value.ptr));

  PyObject call(PyTuple args, [PyDict? kwargs]) => runPython(
    () => .owned(
      api.PyObject_Call(ptr, args.ptr, kwargs == null ? nullptr : kwargs.ptr),
    ),
  );

  PyObject call0() =>
      runPython(() => .owned(api.PyObject_CallObject(ptr, nullptr)));

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
    PyDict? keywordArguments;

    try {
      if (kwargs != null) {
        keywordArguments = PyDict();

        for (final MapEntry(:key, :value) in kwargs.entries) {
          keywordArguments.setItemString(key, value);
        }
      }

      return call(arguments, keywordArguments);
    } finally {
      keywordArguments?.dispose();
      arguments.dispose();
    }
  }

  /// Runs [action] inside this Python context manager.
  ///
  /// The value returned by `__enter__` is passed to [action] and remains valid
  /// only for the duration of the callback. This object is not disposed by
  /// this method; its owner remains responsible for disposing it.
  ///
  /// Dart exceptions, including translated [PythonException]s, are propagated
  /// after `__exit__` is called. Because translated Python exceptions have
  /// already crossed and cleared the Python error boundary, `__exit__` receives
  /// `(None, None, None)` for them.
  T withContext<T>(T Function(PyObject value) action) {
    final enter = get('__enter__');
    late final PyObject value;
    try {
      value = enter.call0();
    } finally {
      enter.dispose();
    }

    try {
      return action(value);
    } finally {
      try {
        final exit = get('__exit__');
        try {
          final sys = PyModule('sys');
          try {
            final excInfoFunction = sys.get('exc_info');
            try {
              final excInfoObject = excInfoFunction.call0();
              try {
                final excInfo = excInfoObject.cast<PyTuple>();
                exit.callArgs([
                  excInfo.getItem(0),
                  excInfo.getItem(1),
                  excInfo.getItem(2),
                ]).dispose();
              } finally {
                excInfoObject.dispose();
              }
            } finally {
              excInfoFunction.dispose();
            }
          } finally {
            sys.dispose();
          }
        } finally {
          exit.dispose();
        }
      } finally {
        value.dispose();
      }
    }
  }
}

/// [tuple](https://github.com/python/cpython/blob/main/Include/tupleobject.h)
class PyTuple extends PyObject {
  PyTuple.fromPointer(super.ptr) : super.owned();
  PyTuple.fromBorrowed(super.ptr) : super.borrowed();

  factory PyTuple([int size = 0]) =>
      runPython(() => .fromPointer(api.PyTuple_New(size)));
  factory PyTuple.fromList(List<PyObject> list) {
    final tuple = PyTuple(list.length);
    for (var i = 0; i < list.length; i++) {
      tuple.setItem(i, list[i]);
    }
    return tuple;
  }

  int setItem(int index, PyObject obj) =>
      runPython(() => api.PyTuple_SetItem(ptr, index, obj._ref.newReference()));
  PyObject getItem(int index) =>
      runPython(() => .borrowed(api.PyTuple_GetItem(ptr, index)));
  PyTuple slice(int start, int end) =>
      runPython(() => .fromPointer(api.PyTuple_GetSlice(ptr, start, end)));
}

/// [list](https://github.com/python/cpython/blob/main/Include/listobject.h)
class PyList extends PyObject {
  PyList.fromPointer(super.ptr) : super.owned();
  PyList.fromBorrowed(super.ptr) : super.borrowed();

  factory PyList(int size) => runPython(() => .fromPointer(api.PyList_New(size)));
  factory PyList.fromList(List<PyObject> list) {
    final pyList = PyList(list.length);
    for (var i = 0; i < list.length; i++) {
      pyList.setItem(i, list[i]);
    }
    return pyList;
  }

  int get length => runPython(() => api.PyList_Size(ptr));

  int setItem(int index, PyObject obj) =>
      runPython(() => api.PyList_SetItem(ptr, index, obj._ref.newReference()));
  PyObject getItem(int index) =>
      runPython(() => .borrowed(api.PyList_GetItem(ptr, index)));
  int insert(int index, PyObject obj) =>
      runPython(() => api.PyList_Insert(ptr, index, obj.ptr));
  int append(PyObject obj) => runPython(() => api.PyList_Append(ptr, obj.ptr));
  PyList slice(int start, int end) =>
      runPython(() => .fromPointer(api.PyList_GetSlice(ptr, start, end)));
  int setSlice(int start, int end, PyList items) =>
      runPython(() => api.PyList_SetSlice(ptr, start, end, items.ptr));
  int deleteSlice(int start, int end) =>
      runPython(() => api.PyList_SetSlice(ptr, start, end, nullptr));
  int sort() => runPython(() => api.PyList_Sort(ptr));
  int reverse() => runPython(() => api.PyList_Reverse(ptr));
  PyTuple asTuple() => runPython(() => .fromPointer(api.PyList_AsTuple(ptr)));
}

/// [dict](https://github.com/python/cpython/blob/main/Include/dictobject.h)
class PyDict extends PyObject {
  PyDict.fromPointer(super.ptr) : super.owned();
  PyDict.fromBorrowed(super.ptr) : super.borrowed();

  factory PyDict() => runPython(() => .fromPointer(api.PyDict_New()));
  factory PyDict.fromMap(Map<PyObject, PyObject> map) {
    final dict = PyDict();
    for (final MapEntry(:key, :value) in map.entries) {
      dict.setItem(key, value);
    }
    return dict;
  }

  int get length => runPython(() => api.PyDict_Size(ptr));

  int setItem(PyObject key, PyObject value) =>
      runPython(() => api.PyDict_SetItem(ptr, key.ptr, value.ptr));
  PyObject getItem(PyObject key) =>
      runPython(() => .borrowed(api.PyDict_GetItem(ptr, key.ptr)));
  PyObject getItemWithError(PyObject key) =>
      runPython(() => .borrowed(api.PyDict_GetItemWithError(ptr, key.ptr)));
  int deleteItem(PyObject key) =>
      runPython(() => api.PyDict_DelItem(ptr, key.ptr));
  void clear() => runPython(() => api.PyDict_Clear(ptr));

  // TODO: sync*
  // 不过这个由于 ffi.using 需要谨慎处理
  List<({PyObject key, PyObject value})> get entries => runPython(
    () => ffi.using((arena) {
      final position = arena<g.Py_ssize_t>()..value = 0;
      final key = arena<Pointer<g.PyObject>>();
      final value = arena<Pointer<g.PyObject>>();
      final result = <({PyObject key, PyObject value})>[];

      while (api.PyDict_Next(ptr, position, key, value) != 0) {
        result.add((key: .borrowed(key.value), value: .borrowed(value.value)));
      }
      return result;
    }),
  );

  PyList keys() => runPython(() => .fromPointer(api.PyDict_Keys(ptr)));
  PyList values() => runPython(() => .fromPointer(api.PyDict_Values(ptr)));
  PyList items() => runPython(() => .fromPointer(api.PyDict_Items(ptr)));
  PyDict copy() => runPython(() => .fromPointer(api.PyDict_Copy(ptr)));
  int contains(PyObject key) =>
      runPython(() => api.PyDict_Contains(ptr, key.ptr));
  int update(PyObject other) =>
      runPython(() => api.PyDict_Update(ptr, other.ptr));
  int merge(PyObject other, {bool override = true}) =>
      runPython(() => api.PyDict_Merge(ptr, other.ptr, override ? 1 : 0));
  int mergeFromSequence(PyObject sequence, {bool override = true}) => runPython(
    () => api.PyDict_MergeFromSeq2(ptr, sequence.ptr, override ? 1 : 0),
  );

  PyObject getItemString(String key) => runPython(
    () => ffi.using(
      (arena) => .borrowed(
        api.PyDict_GetItemString(
          ptr,
          key.toNativeUtf8(allocator: arena).cast<Char>(),
        ),
      ),
    ),
  );
  int setItemString(String key, PyObject value) => runPython(
    () => ffi.using(
      (arena) => api.PyDict_SetItemString(
        ptr,
        key.toNativeUtf8(allocator: arena).cast<Char>(),
        value.ptr,
      ),
    ),
  );
  int deleteItemString(String key) => runPython(
    () => ffi.using(
      (arena) => api.PyDict_DelItemString(
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
        api.PyUnicode_FromString(s.toNativeUtf8(allocator: arena).cast<Char>()),
      ),
    ),
  );

  String get value => toDartString();
}

/// [import](https://github.com/python/cpython/blob/main/Include/import.h)
class PyModule extends PyObject {
  PyModule.fromPointer(super.ptr) : super.owned();
  PyModule.fromBorrowed(super.ptr) : super.borrowed();

  factory PyModule(String name) {
    final pyName = PyString(name);
    try {
      return .fromPointer(runPython(() => api.PyImport_Import(pyName.ptr)));
    } finally {
      pyName.dispose();
    }
  }
}

class PyBool extends PyObject {
  PyBool.fromPointer(super.ptr) : super.owned();
  PyBool.fromBorrowed(super.ptr) : super.borrowed();

  factory PyBool(bool value) =>
      runPython(() => .fromPointer(api.PyBool_FromLong(value ? 1 : 0)));

  bool get value => isTrue;
}

class PyInt extends PyObject {
  PyInt.fromPointer(super.ptr) : super.owned();
  PyInt.fromBorrowed(super.ptr) : super.borrowed();

  factory PyInt(int value) =>
      runPython(() => .fromPointer(api.PyLong_FromLong(value)));

  int get value => toInt();
}

class PyDouble extends PyObject {
  PyDouble.fromPointer(super.ptr) : super.owned();
  PyDouble.fromBorrowed(super.ptr) : super.borrowed();

  factory PyDouble(double value) =>
      runPython(() => .fromPointer(api.PyFloat_FromDouble(value)));

  double get value => toDouble();
}
