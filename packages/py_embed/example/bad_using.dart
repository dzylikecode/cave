import 'dart:ffi';
import 'package:ffi/ffi.dart' as ffi;

Iterable<int> bad() {
  return ffi.using((arena) sync* {
    final ptr = arena<Int32>();
    ptr.value = 123;

    yield ptr.value;

    // 如果继续使用 ptr
    yield ptr.value;
  });
}

void main() {
  final it = bad().iterator;

  print("before moveNext");

  print(it.moveNext());
  print(it.current);

  print(it.moveNext());
  print(it.current);
}