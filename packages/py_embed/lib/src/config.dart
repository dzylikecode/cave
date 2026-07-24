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
  Pointer<WChar> _setString(String value, Pointer<WChar> oldValue) =>
      ffi.using((arena) {
        // 让 PyConfig_SetString 负责释放原来的 Python-owned 字符串
        final temp = arena<Pointer<WChar>>()..value = oldValue;
        g.PyConfig_SetString(
          ptr,
          temp,
          value.toNativeWChar(allocator: arena),
        ).guard();
        return temp.value;
      });

  String get executable => ptr.ref.executable.toDartString();
  set executable(String path) =>
      ptr.ref.executable = _setString(path, ptr.ref.executable);
  // set executable(String path) => ptr.ref.executable = path.toNativeWChar();

  String get programName => ptr.ref.program_name.toDartString();
  set programName(String path) =>
      ptr.ref.program_name = _setString(path, ptr.ref.program_name);
  // set programName(String path) => ptr.ref.program_name = path.toNativeWChar();
}

@internal
extension StringToWCharExt on String {
  Pointer<WChar> toNativeWChar({Allocator allocator = ffi.malloc}) {
    // windows platform
    if (sizeOf<WChar>() == 2) {
      return toNativeUtf16(allocator: allocator).cast();
    }
  
    // linux/mac platform
    final codePoints = runes.toList();
    final len = codePoints.length; // 会迭代，所以缓存一下

    final result = allocator<Uint32>(len + 1);
    final nativeString = result.asTypedList(len + 1);

    nativeString.setRange(0, len, codePoints);
    nativeString[len] = 0;

    return result.cast();
  }
}

@internal
extension WCharExt on Pointer<WChar> {
  String toDartString() =>
      .fromCharCodes([for (var i = 0; this[i] != 0; i++) this[i]]);
}
