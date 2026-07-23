import 'dart:math' as math;
import 'basic.dart';
import 'dart:core' hide Symbol;

/// Represents string in SymPy.
///
/// ## Explanation
///
/// Previously, [Symbol] was used where string is needed in [args] of SymPy
/// objects, e.g. denoting the name of the instance. However, since [Symbol]
/// represents mathematical scalar, this class should be used instead.
class Str extends Atom {
  final String name;

  Str(this.name);

  @override
  List<Object> get hashableContent => [name];
}

class Symbol extends Basic {
  final String name;

  Symbol(this.name);

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
class Dummy extends Symbol {
  static int _count = 0;
  static final _pseudoRandomNumberGenerator = math.Random();
  static final _baseDummyIndex = _pseudoRandomNumberGenerator.nextInt(1 << 32);

  final int dummyIndex;

  Dummy([super.name = '', this.dummyIndex = 0]);

  @override
  List<Object> get hashableContent => super.hashableContent..add(dummyIndex);
}
