import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'python.g.dart' as g;
import 'status.dart';

class PyConfig {
  @internal
  Pointer<g.PyConfig> ptr;

  PyConfig._(this.ptr);
  factory PyConfig() {
    final ptr = ffi.calloc<g.PyConfig>();
    g.PyConfig_InitPythonConfig(ptr);
    return ._(ptr);
  }
  void dispose() {
    // 释放 Python-owned 字符串
    g.PyConfig_Clear(ptr);
    ffi.calloc.free(ptr);
  }

  /// 由于 dart 无法表达 &config->executable 这种指针的指针类型
  /// 所以这里用一个替身来处理
  Pointer<WChar> _setString(Pointer<WChar> oldValue, String newValue) {
    final input = newValue.toNativeWChar();
    final temp = ffi.calloc<Pointer<WChar>>();

    // 让 PyConfig_SetString 负责释放原来的 Python-owned 字符串
    temp.value = oldValue;
    try {
      g.PyConfig_SetString(ptr, temp, input).guard();
      return temp.value;
    } finally {
      ffi.calloc.free(input);
      ffi.calloc.free(temp);
    }
  }

  String get executable => ptr.ref.executable.toDartString();
  set executable(String path) =>
      ptr.ref.executable = _setString(ptr.ref.executable, path);
  // set executable(String path) => ptr.ref.executable = path.toNativeWChar();

  String get programName => ptr.ref.program_name.toDartString();
  set programName(String path) =>
      ptr.ref.program_name = _setString(ptr.ref.program_name, path);
  // set programName(String path) => ptr.ref.program_name = path.toNativeWChar();
}

extension on String {
  Pointer<WChar> toNativeWChar() {
    final units = codeUnits;
    final result = ffi.calloc<WChar>(units.length + 1);
    for (var i = 0; i < units.length; i++) {
      result[i] = units[i];
    }
    result[units.length] = 0;
    return result;
  }
}

extension on Pointer<WChar> {
  String toDartString() =>
      .fromCharCodes([for (var i = 0; this[i] != 0; i++) this[i]]);
}
