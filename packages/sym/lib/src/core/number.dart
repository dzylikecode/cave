sealed class Number {

}

class Rational extends Number {
  final int numerator;
  final int denominator;

  Rational(this.numerator, this.denominator);


}

class Integer extends Rational {
  Integer(int value) : super(value, 1);
}

class Float extends Number {
  final double value;

  Float(this.value);
}