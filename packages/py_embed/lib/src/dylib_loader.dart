import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

const _rtldNow = 0x00002;
const _rtldGlobal = 0x00100;

@Native<Pointer<Void> Function(Pointer<Char>, Int)>(symbol: 'dlopen')
external Pointer<Void> _dlopen(Pointer<Char> file, int mode);

@Native<Pointer<Char> Function()>(symbol: 'dlerror')
external Pointer<Char> _dlerror();

/// Loads a host-provided dynamic library before any bindings are resolved.
///
/// Linux requires global visibility for plugin hosts such as CPython: native
/// extension modules normally resolve the Python C API from the process-wide
/// symbol scope. Other supported hosts use [DynamicLibrary.open].
void loadHostDynamicLibrary(String path) {
  if (!Platform.isLinux) {
    DynamicLibrary.open(path);
    return;
  }

  using((arena) {
    _dlerror(); // Clear a previous dynamic-loader error.
    final handle = _dlopen(
      path.toNativeUtf8(allocator: arena).cast(),
      _rtldNow | _rtldGlobal,
    );
    if (handle != nullptr) return;

    final error = _dlerror();
    final detail = error == nullptr
        ? 'unknown dynamic-loader error'
        : error.cast<Utf8>().toDartString();
    throw ArgumentError.value(path, 'path', 'Failed to load library: $detail');
  });
}
