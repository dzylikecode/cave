import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;
import 'package:meta/meta.dart';

import 'python.g.dart' as g;
import 'status.dart';

class PyConfig extends NativeResource<g.PyConfig> {
  PyConfig._(Pointer<g.PyConfig> ptr) : super(ptr, _releaseConfig);

  static void _releaseConfig(Pointer<g.PyConfig> ptr) {
    g.PyConfig_Clear(ptr);
    ffi.calloc.free(ptr);
  }

  factory PyConfig() {
    final ptr = ffi.calloc<g.PyConfig>();
    g.PyConfig_InitPythonConfig(ptr);
    return ._(ptr);
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

abstract class NativeResource<T extends NativeType> implements Finalizable {
  static final Finalizer<_FinalizerData> _finalizer = Finalizer(
    (data) => data.release(data.pointer),
  );

  Pointer<T> _ptr;

  @internal
  Pointer<T> get ptr {
    if (_isDisposed) {
      throw StateError('$runtimeType has already been disposed');
    }
    return _ptr;
  }

  final void Function(Pointer<T>) _release;
  final Object _detachToken = Object();

  /// [release] 函数不能捕获资源对象本身，否则无法释放
  ///
  /// ```dart
  /// super(ptr, (_) => this.release());
  /// ```
  ///
  /// 像这样会导致资源对象无法释放，因为 release 捕获了 this，导致 this 无法被回收
  NativeResource(this._ptr, void Function(Pointer<T>) release)
    : _release = release {
    if (_ptr == nullptr) {
      throw ArgumentError.value(_ptr, 'ptr', 'Must not be nullptr');
    }

    _finalizer.attach(
      this,
      _FinalizerData(_ptr.cast(), (pointer) => release(pointer.cast<T>())),
      detach: _detachToken,
    );
  }

  bool get _isDisposed => _ptr == nullptr;

  @mustCallSuper
  void dispose() {
    if (_isDisposed) return;

    _finalizer.detach(_detachToken);

    final pointer = _ptr;
    _ptr = nullptr;

    _release(pointer);
  }
}

final class _FinalizerData {
  final Pointer<Void> pointer;
  final void Function(Pointer<Void>) release;

  const _FinalizerData(this.pointer, this.release);
}
