import 'basic.dart';

/// Base class for algebraic expressions.
/// 
/// ## Explanation
/// 
/// Everything that requires arithmetic operations to be defined
/// should subclass this class, instead of [Basic] (which should be
/// used only for argument storage and expression manipulation, i.e.
/// pattern matching, substitutions, etc).
/// 
/// If you want to override the comparisons of expressions:
/// Should use _eval_is_ge for inequality, or _eval_is_eq, with multiple dispatch.
/// _eval_is_ge return true if x >= y, false if x < y, and None if the two types
/// are not comparable or the comparison is indeterminate
class Expression extends Basic {}