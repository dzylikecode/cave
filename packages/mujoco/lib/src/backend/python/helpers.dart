import 'package:py_embed/py_embed.dart';

int readIntAttribute(PyObject object, String name) {
  final attribute = object.get(name);
  try {
    return attribute.toInt();
  } finally {
    attribute.dispose();
  }
}

double readDoubleAttribute(PyObject object, String name) {
  final attribute = object.get(name);
  try {
    return attribute.toDouble();
  } finally {
    attribute.dispose();
  }
}

String readStringAttribute(PyObject object, String name) {
  final attribute = object.get(name);
  try {
    return attribute.toDartString();
  } finally {
    attribute.dispose();
  }
}
