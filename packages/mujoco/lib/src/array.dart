/// A fixed-length, mutable view of a MuJoCo array.
///
/// Writes are applied directly to the simulation state. Use [toList] when an
/// independent Dart snapshot is needed.
abstract interface class MjDoubleArray {
  int get length;

  double operator [](int index);

  void operator []=(int index, double value);

  List<double> toList();

  void setAll(Iterable<double> values);

  void fill(double value);
}
