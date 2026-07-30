import 'package:py_embed/py_embed.dart';

int readIntAttribute(PyObject object, String name) {
  final attribute = object.get(name);
  try {
    final value = attribute.cast<PyInt>();
    try {
      return value.value;
    } finally {
      value.dispose();
    }
  } finally {
    attribute.dispose();
  }
}

double readDoubleAttribute(PyObject object, String name) {
  final attribute = object.get(name);
  try {
    final value = attribute.cast<PyDouble>();
    try {
      return value.value;
    } finally {
      value.dispose();
    }
  } finally {
    attribute.dispose();
  }
}

String readStringAttribute(PyObject object, String name) {
  final attribute = object.get(name);
  try {
    final value = attribute.cast<PyString>();
    try {
      return value.value;
    } finally {
      value.dispose();
    }
  } finally {
    attribute.dispose();
  }
}
