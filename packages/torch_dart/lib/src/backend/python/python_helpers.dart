import 'package:py_embed/py_embed.dart';

PyObject dartToPython(Object value) {
  if (value is int) return PyInt(value);
  if (value is double) return PyDouble(value);
  if (value is bool) return PyBool(value);
  if (value is List) {
    final items = value.map((item) => dartToPython(item as Object)).toList();
    try {
      return PyList.fromList(items);
    } finally {
      for (final item in items) {
        item.dispose();
      }
    }
  }
  throw ArgumentError.value(
    value,
    'data',
    'Expected a number, bool, or a nested List of those values',
  );
}

PyList intListToPython(List<int> values) {
  final items = values.map(PyInt.new).toList();
  try {
    return PyList.fromList(items);
  } finally {
    for (final item in items) {
      item.dispose();
    }
  }
}

Object pythonToDart(PyObject value, int dimensions) {
  if (dimensions > 0) {
    final list = value.cast<PyList>();
    return List<Object>.generate(
      list.length,
      (index) => pythonToDart(list.getItem(index), dimensions - 1),
      growable: false,
    );
  }
  try {
    return value.toInt();
  } on PythonException {
    return value.toDouble();
  }
}
