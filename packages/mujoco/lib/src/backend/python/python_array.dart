import 'package:py_embed/py_embed.dart';

import '../../array.dart';

final class PythonMjDoubleArray implements MjDoubleArray {
  final PyObject _array;

  @override
  final int length;

  PythonMjDoubleArray(this._array, this.length);

  void _checkIndex(int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
  }

  @override
  double operator [](int index) {
    _checkIndex(index);

    final key = PyInt(index);
    try {
      final item = _array[key];
      try {
        return item.toDouble();
      } finally {
        item.dispose();
      }
    } finally {
      key.dispose();
    }
  }

  @override
  void operator []=(int index, double value) {
    _checkIndex(index);

    final key = PyInt(index);
    final pyValue = PyDouble(value);
    try {
      _array[key] = pyValue;
    } finally {
      pyValue.dispose();
      key.dispose();
    }
  }

  @override
  List<double> toList() =>
      .generate(length, (index) => this[index], growable: false);

  @override
  void setAll(Iterable<double> values) {
    final snapshot = values.toList(growable: false);
    if (snapshot.length != length) {
      throw ArgumentError.value(
        values,
        'values',
        'Expected $length values, received ${snapshot.length}',
      );
    }
    for (var index = 0; index < length; index++) {
      this[index] = snapshot[index];
    }
  }

  @override
  void fill(double value) {
    for (var index = 0; index < length; index++) {
      this[index] = value;
    }
  }

  void dispose() => _array.dispose();

  /// show value when debugging
  @override
  String toString() => toList().toString();
}
