import 'package:py_embed/py_embed.dart';

import '../../sensor.dart';
import 'array.dart';

final class MjSensorPython implements MjSensor {
  final PyObject _view;

  @override
  final String name;

  @override
  late final int id = _view.getInt('id');

  MjDoubleArrayPython? _data;

  MjSensorPython._(this._view, this.name);

  factory MjSensorPython.fromData(PyObject data, String name) {
    final sensorMethod = data.get('sensor');
    final pyName = PyString(name);
    try {
      return MjSensorPython._(sensorMethod.call1(pyName), name);
    } finally {
      pyName.dispose();
      sensorMethod.dispose();
    }
  }

  @override
  MjDoubleArrayPython get data => _data ??= _createData();

  MjDoubleArrayPython _createData() {
    final array = _view.get('data');
    try {
      final length = array.getInt('size');
      return MjDoubleArrayPython(array, length);
    } catch (_) { // 不是 finally，所有权转移到 data 上面了
      array.dispose();
      rethrow;
    }
  }

  void dispose() {
    _data?.dispose();
    _view.dispose();
  }
}
