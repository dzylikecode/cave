/// Base class for all the objects in Sym
///
/// 移植自 sympy/core/basic.py
library;

import 'package:meta/meta.dart';
import 'simplify.dart';
import 'sym.dart';

abstract class Basic {
  final List<Basic> _args;
  List<Basic> get args => _args;

  Set<Basic> get freeSymbols {
    final symbols = <Basic>{};
    for (final arg in args) {
      symbols.addAll(arg.freeSymbols);
    }
    return symbols;
  }

  Basic(List<Basic> args)
    : _args = List.unmodifiable(args); // eqs python's tuple

  /// Return a tuple of information about self that can be used to
  /// compute the hash. If a class defines additional attributes,
  /// like [Sym.name], then this method should be updated
  /// accordingly to return such relevant attributes.
  ///
  /// Defining more than [hashableContent] is necessary if [==] has
  /// been defined by a class. See note about this in [Basic.==].
  @protected
  List<Object> get hashableContent => _args; //  python's _hashable_content

  int? _cachedHashCode;

  @override
  int get hashCode =>
      _cachedHashCode ??= Object.hashAll([runtimeType, ...hashableContent]);

  /// Return a boolean indicating whether a == b on the basis of
  /// their symbolic trees.
  ///
  /// ## References
  ///
  /// from https://dart.dev/tools/linter-rules/hash_and_equals
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Basic) return _doEqualSymplify(other);

    // 类型不一致但是排除都是数字的情况，比如 Integer(1) == Real(1)
    // TODO: 需要验证一下，我觉得很混乱
    if (runtimeType != other.runtimeType && !(isNumber && other.isNumber)) {
      return false;
    }

    final left = hashableContent;
    final right = other.hashableContent;

    if (left.length != right.length) return false;

    for (var i = 0; i < left.length; i++) {
      final a = left[i];
      final b = right[i];
      if (a != b) return false;
      // now a == b
      if (a is! Basic) continue;
      // now a(Basic) == b(Basic)
      if (a.runtimeType != b.runtimeType && a.isNumber) return false;
    }

    return true;
  }

  /// Returns a boolean indicating whether a == b when either a
  /// or b is not a Basic. This is only done for types that were either
  /// added to `converter` by a 3rd party or when the object has `_sympy_`
  /// defined. This essentially reuses the code in `_sympify` that is
  /// specific for this use case. Non-user defined types that are meant
  /// to work with SymPy should be handled directly in the [==] methods
  /// of the `Basic` classes it could equate to and not be converted. Note
  /// that after conversion, [==]  is used again since it is not
  /// necessarily clear whether [this] or [other]'s [==] method needs
  /// to be used.
  bool _doEqualSymplify(Object other) {
    return false; // TODO: implement this method
  }

  bool get isNumber => false;
  bool get isDummy => false;


  bool dummyEquals(Basic other, [Basic? symbol]) {
    final s = asDummy();
    final o = simplify(other).asDummy();
    final dummySymbols = s.freeSymbols.map((e) => e.isDummy).toSet();
    return false; // TODO: implement this method
  }

  Basic asDummy() {
    return this; // TODO: implement this method
  }


}
