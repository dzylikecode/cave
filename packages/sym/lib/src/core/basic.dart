import 'package:meta/meta.dart';
import 'simplify.dart';
import 'symbol.dart';

/// Base class for all the objects in Sym
class Basic {
  final List<Basic> _args;

  /// Returns a tuple of arguments of 'self'
  ///
  /// ## Examples
  ///
  /// ```dart
  /// cot(x).args // (x,)
  ///
  /// cot(x).args[0] // x
  ///
  /// (x*y).args // (x, y)
  ///
  /// (x*y).args[1] // y
  /// ```
  List<Basic> get args => _args;

  /// The same as [args].  Derived classes which do not fix an
  /// order on their arguments should override this method to
  /// produce the sorted representation.
  @protected
  List<Basic> get sortedArgs => args;

  /// Return from the atoms of self those which are free symbols.
  ///
  /// Not all free symbols are [Symbol] (see examples)
  ///
  /// For most expressions, all symbols are free symbols. For some classes
  /// this is not true. e.g. Integrals use Symbols for the dummy variables
  /// which are bound variables, so Integral has a method to return all
  /// symbols except those. Derivative keeps track of symbols with respect
  /// to which it will perform a derivative; those are
  /// bound variables, too, so it has its own free_symbols method.
  ///
  /// Any other method that uses bound variables should implement a
  /// free_symbols method.
  ///
  /// ## Examples
  ///
  /// ```dart
  /// (x + 1).free_symbols // {x}
  ///
  /// Integral(x, y).free_symbols // {x, y}
  /// ```
  ///
  /// Not all free symbols are actually symbols:
  ///
  ///
  /// ```dart
  /// IndexedBase('F')[0].free_symbols // {F, F[0]}
  /// ```
  ///
  /// The symbols of differentiation are not included unless they
  /// appear in the expression being differentiated.
  ///
  /// ```dart
  /// Derivative(x + y, y).free_symbols // {x, y}
  ///
  /// Derivative(x, y).free_symbols // {x}
  ///
  /// Derivative(x, (y, n)).free_symbols // {n, x}
  /// ```
  ///
  /// If you want to know if a symbol is in the variables of the
  /// Derivative you can do so as follows:
  ///
  /// ```dart
  /// Derivative(x, y).has_free(y) // true
  /// ```
  Set<Basic> get freeSymbols {
    final symbols = <Basic>{};
    for (final arg in args) {
      symbols.addAll(arg.freeSymbols);
    }
    return symbols;
  }

  Basic([List<Basic> args = const []])
    : _args = List.unmodifiable(args); // eqs python's tuple

  /// Return a tuple of information about self that can be used to
  /// compute the hash. If a class defines additional attributes,
  /// like [Symbol.name], then this method should be updated
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
  bool get isAtom => false;

  /// Compare two expressions and handle dummy symbols.
  ///
  /// ## Examples
  ///
  /// ```dart
  /// final u = Dummy('u');
  ///
  /// (u**2 + 1).dummy_eq(x**2 + 1) // true
  ///
  /// // u != x
  /// (u**2 + 1) == (x**2 + 1) // false
  ///
  /// (u**2 + y).dummy_eq(x**2 + y, x) // true
  ///
  /// (u**2 + y).dummy_eq(x**2 + y, y) // false
  /// ```
  ///
  /// 由于多个dummy 需要指定规则了，这里只是处理了单个dummy的情况
  bool dummyEquals(Basic other, [Basic? symbol]) {
    final s = asDummy();
    final o = simplify(other).asDummy();
    final dummySymbols = s.freeSymbols.where((e) => e.isDummy).toSet();

    if (dummySymbols.length != 1) {
      return s == o;
    }

    final dummy = dummySymbols.first;

    if (symbol == null) {
      final symbols = o.freeSymbols;
      if (symbols.length != 1) {
        return s == o;
      }
      symbol = symbols.first;
    }

    final tmp = Dummy();

    return s.xreplace({dummy: tmp}) == o.xreplace({symbol: tmp});
  }

  Basic xreplace(Map<Basic, Basic> rule) {
    return this; // TODO: implement this method
  }

  Basic _xreplace(Map<Basic, Basic> rule) {
    return this; // TODO: implement this method
  }

  Basic asDummy() {
    return this; // TODO: implement this method
  }

  /// The top-level function in an expression.
  /// 
  /// The following should hold for all objects:
  /// 
  ///       x == x.func(x.args)
  /// 
  /// ## Examples
  /// 
  /// 
  Basic func(List<Basic> args) => Basic(args);

  /// Evaluate objects that are not evaluated by default like limits,
  /// integrals, sums and products. All objects of this kind will be
  /// evaluated recursively, unless the [deep] hint was set to [false].
  /// 
  /// ```dart
  /// 2*Integral(x, x) // 2*Integral(x, x)
  /// 
  /// (2*Integral(x, x)).doit() // x**2
  /// 
  /// (2*Integral(x, x)).doit(deep=False) // 2*Integral(x, x)
  /// ```
  Basic doIt({bool deep = true}) {
    if (deep == false) return this;
    final args = this.args.map((e) => e.doIt()).toList();
    return func(args);
  }
}

/// A parent class for atomic things. An atom is an expression with no subexpressions.
/// 
/// ## Examples
/// 
/// Symbol, Number, Rational, Integer, ...
/// But not: Add, Mul, Pow, ...
class Atom extends Basic {
  Atom();

  @override
  bool get isAtom => true;

  @override
  List<Basic> get sortedArgs => throw StateError(
    'Atoms have no args. It might be necessary'
    ' to make a check for Atoms in the calling code.',
  );

  @override
  Atom func(List<Basic> args) => throw StateError(
    'Atoms have no args. It might be necessary'
    ' to make a check for Atoms in the calling code.',
  );
}
