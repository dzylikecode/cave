import 'dart:math' as math;
import 'basic.dart';

class Sym extends Basic {
  final String name;

  const Sym(this.name);

  @override
  List<Object> get hashableContent => [name];
}

/// Dummy symbols are each unique, even if they have the same name:
///
/// ## Examples
///
/// ```dart
/// print(Dummy('x') == Dummy('x')); // false
/// ```
///
/// If a name is not supplied then a string value of an internal count will be
/// used. This is useful when a temporary variable is needed and the name
/// of the variable used in the expression is not important.
///
/// ```dart
/// print(Dummy()); // _Dummy_10
/// ```
class Dummy extends Sym {
  static int _count = 0;
  static final _pseudoRandomNumberGenerator = math.Random();
  static final _baseDummyIndex = _pseudoRandomNumberGenerator.nextInt(1 << 32);

  final int dummyIndex;

  const Dummy([super.name = '']);

  @override
  List<Object> get hashableContent => super.hashableContent..add(dummyIndex);
}
