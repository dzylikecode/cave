import 'dart:ffi';

import 'python.g.dart' as g;

/// TODO: 还没有处理多线程的情况
final class PyRef {
  Pointer<g.PyObject> _ptr;

  /// 包装 new reference，不增加引用。
  PyRef.owned(this._ptr);

  /// 将 borrowed reference 提升成 Dart 拥有的引用。
  PyRef.borrowed(this._ptr) {
    g.Py_IncRef(_ptr);
  }

  /// 给 Python 创建一个可以长期持有的新引用。
  Pointer<g.PyObject> newReference() {
    g.Py_IncRef(_ptr);
    return _ptr;
  }

  void dispose() {
    if (_ptr == nullptr) return;

    final ptr = _ptr;
    _ptr = nullptr;
    g.Py_DecRef(ptr);
  }
}
