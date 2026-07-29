import 'dart:ffi';

import 'python.g.dart' as g;

/// TODO: 还没有处理多线程的情况
final class PyRef {
  Pointer<g.PyObject> ptr;
  bool owns;
  bool disposed = false;

  PyRef.owned(this.ptr) : owns = true;
  PyRef.borrowed(this.ptr) : owns = false;

  PyRef newRef() {
    g.Py_IncRef(ptr);
    return .owned(ptr);
  }

  Pointer<g.PyObject> steal() {
    owns = false;
    return ptr;
  }

  void dispose() {
    if (owns && !disposed && ptr != nullptr) {
      g.Py_DecRef(ptr);
      disposed = true;
    }
  }
}