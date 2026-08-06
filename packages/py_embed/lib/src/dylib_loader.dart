/// https://github.com/dart-lang/sdk/blob/1c34e92492708d1b36afcef9c49e7f48c7659511/tests/ffi/dylib_utils.dart#L49-L63

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// On Android Arm.
const RTLD_GLOBAL_android_arm32 = 0x00002;

/// On Linux and Android Arm64.
const RTLD_GLOBAL_rest = 0x00100;

const _rtldNow = 0x00002;
final _rtldGlobal = Abi.current() == Abi.androidArm
    ? RTLD_GLOBAL_android_arm32
    : RTLD_GLOBAL_rest;

/// If the @Native is not bound in a build hook it is basically doing the same as DynamicLibrary.process().lookup().
@Native<Pointer<Void> Function(Pointer<Char>, Int)>(symbol: 'dlopen')
external Pointer<Void> _dlopen(Pointer<Char> file, int mode);

@Native<Pointer<Char> Function()>(symbol: 'dlerror')
external Pointer<Char> _dlerror();

void loadHostDynamicLibrary(String path) {
  if (Platform.isLinux || Platform.isAndroid || Platform.isFuchsia) {
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
      throw ArgumentError.value(
        path,
        'path',
        'Failed to load library: $detail',
      );
    });
  }

  DynamicLibrary.open(path);
}
