import 'array.dart';

/// A named view of one sensor's values in an [MjData] instance.
abstract interface class MjSensor {
  int get id;
  String get name;
  MjDoubleArray get data;
}
